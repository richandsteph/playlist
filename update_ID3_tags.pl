#!/usr/bin/perl -w

#**********************************************************************************************************
#
#	File: update_ID3_tags.pl
#	Desc: updates ID3 metadata for song files, must pass XML playlist to program in command-line
#
# Usage:              perl C:\git_playlist\update_ID3_tags.pl [PLAYLIST_XML_FILENAME]
#
#	Author: Richard Davis
#	  	rich@richandsteph.com
#
#**********************************************************************************************************
# version 1.0  -  13 Jan 2026	RAD	initial creation
#
#
#   TO-DO:
#         1) create script
#
#**********************************************************************************************************

my $Version = "1.0";

use strict;
use warnings;
use utf8::all;
use feature 'unicode_strings';
use open ':std', IO => ':raw :encoding(UTF-8)';

use Carp qw( croak longmess shortmess );
use Data::Dumper qw( Dumper );
use File::Basename qw( fileparse );
#specify config file for ExifTool
#-x-BEGIN { $Image::ExifTool::configFile = 'C:\Users\rich\.ExifTool_config' }
use Image::ExifTool qw( :Public );
use IPC::Run3;
use JSON;
use XML::LibXML;
use XML::Writer;
use Win32;
use Win32::LongPath qw( abspathL chdirL getcwdL openL renameL testL unlinkL );

my $FS = '\\';
#set error status
my $status = 1;

#start logging
my $logFH;
my $progName = fileparse( $0 );
$progName =~ s#\.\w\w\w?$##;
my $logFile = "$progName.log";
startLog( $logFile );

#pull in playlist XML filename from command-line args
my $playlistFile;
if ( scalar( @ARGV ) != 1 ) {
	badExit( "Number of arguments is incorrect, single correct argument should be playlist XML filename: \n   perl C:\\git_playlist\\$progName.pl \[PLAYLIST_XML_FILENAME\]" );
} elsif ( testL( 'e', $ARGV[0] ) ) {
	$playlistFile = $ARGV[0];
} else {
	badExit( "Playlist XML file: '" . $ARGV[0] . "' does not exist" );
}

#separate out playlist XML filename and directory
my ( $playlistFilename, $playlistFilePath ) = fileparse( abspathL( $playlistFile ) );
$playlistFilename =~ s#\.\w\w\w?$##;
#echo status to console
toLog( 'Processing playlist XML file: "' . $playlistFilename . ".xml\"...\n" );
binmode( STDOUT, ":encoding(UTF-8)" );
print "\n   Processing '$playlistFilename.xml'\n";

#load playlist XML
my $xmlFH;
openL( \$xmlFH, '<:encoding(UTF-8)', $playlistFile ) or badExit( "Not able to open playlist XML file for reading: '" . $playlistFile . "'" );
	binmode $xmlFH;
	my $dom = XML::LibXML->load_xml( IO => $xmlFH );
	badExit( "\n\nCouldn't load playlist XML file: $playlistFilename.xml" ) unless ($dom);

#-x- set filename to temporary testing name -x-
$playlistFile = $playlistFilePath . $playlistFilename . '_test' . '.xml';
toLog( " -x- temporary XML filename: " . $playlistFile . " -x-\n" );

#determine playlist name
my $playlistName;
if ( $dom->findnodes( '/playlist/@name' ) ) {
	$playlistName = $dom->findnodes( '/playlist/@name' );
} else {
	$playlistName = $playlistFilename;
}

#set output object for playlist XML
my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
badExit( "Not able to create new XML::Writer object" ) if ( ! $writer );
#write XML Declaration
$writer->xmlDecl( "UTF-8" ) or badExit( "Not able to write out XML Declaration" );
#write date into root <playlist> tag attribute, with playlist name as attribute
toLog( "Setting date/time for playlist\n" );
my $date = localtime( time() );
$writer->startTag( "playlist", name => $playlistName, date => $date );

#list of necessary ID3 tag names for XML output (for use when creating playlist .m3u file)
my @listOfID3Tags = (
	'Title',
	'Track',
	'Artist',
	'Duration'
);

#list of possible ID3 tag names
my @listOfAllTags = (
	'AlbumArtistSort',
	'Albumartistsort',
	'AlbumArtist',
	'Albumartist',
	'albumartist',
	'album_artist',
	'Album',
	'ArtistSort',
	'Artistsort',
	'Artist',
	'AudioBitrate',
	'Bitrate',
	'bit_rate',
	'Comment',
	'DateTimeOriginal',
	'Date',
	'DiscNumber',
	'Discnumber',
	'Disc',
	'Duration',
	'Ensemble',
	'Genre',
	'Length',
	'Minutes',
	'OriginalDate',
	'OriginalReleaseYear',
	'PartOfSet',
	'Partofset',
	'Path',
	'Title',
	'TrackID',
	'TrackNumber',
	'Tracknumber',
	'tracknumber',
	'Track',
	'Year'
);

#set per song hash for tag metadata
my %tags;

#-x- create rules for different types of song files to use command-line progs for that type -x-


#write out updated XML playlist file
my $xmlOutFH;
openL( \$xmlOutFH, '>:encoding(UTF-8)', $playlistFile ) or badExit( "Not able to create '" . $playlistFile . "'" );
my $newfh = select $xmlOutFH; $| = 1; select $newfh;
print $xmlOutFH $writer or badExit( "Not able to write out XML to '$playlistFile'" );
close( $xmlOutFH );
toLog( "\n...Created playlist XML file: '$playlistFile'\n\n\n" );

#set error status for exit
$status = 0;

#end log file
endLog( $status );
#echo status to console
if ( ! $status ) {
	print "\n...Finished Processing Successfully\n\n";
}
exit;

#set array of tags to lowercase keys for easier processing of XML output
sub lowerCase {
	my $hashRef = shift;
	foreach my $key ( keys %{$hashRef} ) {
		if ( ref( $hashRef->{$key} ) eq 'HASH' ) {
			my $innerHashRef = \%{$hashRef->{$key}};
			$innerHashRef = lowerCase( $innerHashRef );
			%{$hashRef->{$key}} = %{$innerHashRef};
		}
		#lowercase $key
		my $lc_key = lc( $key );
		#set value for lowercase key of %refList
		$hashRef->{$lc_key} = $hashRef->{$key};
		#remove original, if not the same key as lowercase version
		if ( $lc_key !~ m#^$key$# ) {
			delete $hashRef->{$key};
		}
	}
	return $hashRef;
}

#convert HH:MM:SS duration into seconds
sub convertDuration {
    my @time_parts = reverse(split(":", $_[0]));
    my $accum = 0;
    for (my $i = 0; $i < @time_parts; $i++) {
        $accum += $time_parts[$i] * 60 ** $i;
    }
    return $accum;
}

#get file list from working directory
sub getFileLst {
	my $working = $_[0];
	#send notice of folder processing to console
	print ".";
	#don't scour '$' folders, unless for testing
	return if ( $working =~ m#[\\\/]\$(?!program_test)# );

	my $dir2 = Win32::LongPath->new();
	$dir2->opendirL( $working ) || badExit( "Not able to open directory: '" . $working . "' - $^E" );
	foreach my $dirItem ( $dir2->readdirL() ) {
		next if $dirItem =~ m#^\.{1,2}$#;
		my $dirItemPath = $working . $FS . $dirItem;

		if ( testL( 'd', $dirItemPath ) ) {
			getFileLst( $dirItemPath );
			next;
		} elsif ( $dirItem =~ m#\.(aac|alac|flac|m4a|mka|mkv|mp3|ogg|wma)$#i ) {
			#replace erroneous non-Unicode characters
			$dirItemPath = charReplace( $dirItemPath );
			push @fileLst, $dirItemPath;
		} else {
			next;
		}
	}

	$dir2->closedirL();
	return;
}

#warning process
sub warning {
	my ( $msg ) = @_;
	toLog( "\n WARNING: $msg,\n" . shortmess() . "\n" );
}

#failed execution process
sub badExit {
	my ( $msg ) = @_;
	croak( "\n**ERROR: $msg,\n   $!,\n   $?,\n   $@,\n   $^E,\n    " . longmess() . "\n\n" );
	endLog( 1 );
	exit 255;
}

#starting log process
sub startLog {
	my ( $log ) = @_;
	my $time = localtime( time() );
	my $ver_info = "  Running: '$0', Version:$Version";
	my $Sep = "-" x 120;

	openL( \$logFH, '>:encoding(UTF-8)', $log ) or badExit( "Not able to create log file\n\ttrying to create <$log>" );
	open STDERR, '>>:encoding(UTF-8)', $log;
		my $prevfh = select $logFH; $| = 1; select $prevfh;
		#write empty line to batch file in case of file header conflict
		toLog( "\n$Sep\n$time$ver_info\n$Sep\n" );
}

#add to log
sub toLog {
	my ( $msg ) = @_;
	print $logFH $msg;
}

#end log process
sub endLog {
	my ( $stat ) = @_;
	my $time = localtime( time() );
	my $ver_info = "  Ran: '$0', Version:$Version";
	my $Sep = "-" x 120;

	if ( $stat ) {
		$stat = 'Failed';
	} else {
		$stat = 'Completed';
	}
	toLog( "\n$Sep\n$time  $stat$ver_info\n$Sep\n\n" );
	close( $logFH );
}
