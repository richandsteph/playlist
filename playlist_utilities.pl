#!/usr/bin/perl -w

#**********************************************************************************************************
#
#	File: playlist_utilities.pl
#	Desc: using Tk module for processing window, gives choices to run functions from the following scripts:
#       1) 'update_ID3_tags' - update ID3 metadata with XML input for song files (then uses command tools 
#          to populate remaining undefined tags) and update metadata to song files
#       2) 'renumber' - renumber KEY values for XML nodes in XML playlist
#       3) 'make_m3u' - create playlist .m3u file from XML playlist input
#       4) 'make_XML_playlist' - create an XML playlist from songs crawled in root (starting) 
#          directory (*must be a top-level, 'Music' folder with artist subfolders)
#
# Usage:  perl C:\git_playlist\playlist_utilities.pl [PLAYLIST_XML_FILE](optional)
#
#	Author: Richard Davis
#         rich@richandsteph.com
#
#**********************************************************************************************************
#
# Version 1.0 - 31 Jan 2026	 RAD initial creation
#         1.1 -  1 Feb 2026	 RAD incorporated 'update_ID3_tags' script into function subroutine (replacing 
#                                tkStart1), changed Tk font to 'Lucida Sans Unicode', changed Warning 
#                                count to hash of warnings per function & global overall count when 
#                                logging warnings, standardized error & warning message format, cleaned 
#                                up some code formatting, changed test for selection (or passing) of 
#                                file/directory to $filePath in function subroutines, added clean-up of 
#                                warning within function subroutine to return to MainLoop, changed 
#                                handling of warning/badExit messages to decode raw message into Unicode 
#                                characters, removed $FS when using $dirName (which ends in backslash), 
#                                added some log formatting
#         1.2 -  1 Feb 2026	 RAD incorporated 'renumber' script into function subroutine / modified all 
#                                badExit() subroutine calls to decode Unicode in messages / updated TO-DO 
#                                / reformatted coding
#         1.3 -  5 Feb 2026	 RAD updated logging messages & formats in logs & console output / removed 
#                                extraneous code line in getXML_List() / incorporated 'make_m3u' script 
#                                into function subroutine / removed tkStart2() - unused / added background 
#                                colors: yellow, medium violet red, & turquoise / incorporated 
#                                'make_XML_playlist' script into function subroutine / added 
#                                saving/reading of last value(s) used in selection boxes for next program 
#                                run / added retrieve of calling subroutine for logging functions, etc. / 
#                                added getSongList() for populating song files discovered in root 'Music' 
#                                folder
#         1.4 -  5 Feb 2026	 RAD refactored use of double quotes to single quotes where interpolation is 
#                                not required / corrected output of path value for make_XML_playlist() / 
#                                created $Server & $Share for replacement of drive letter in path in 
#                                make_XML_playlist() / added 4th permission value for umask() / changed 
#                                '...' to occur in status bar & not in status frame / added comments for 
#                                all subroutines, including optional/required arguments / corrected 
#                                duplicate (or missing) file separator in getSongList() / added directory 
#                                to .m3u filename in make_m3u() for logging purposes
#         1.5 -  6 Feb 2026	 RAD changed logging before MainLoop to print to console / corrected adding of 
#                                ending slash to $dirName in tkGetDir(), tkGetFile(), & readLastVal() / 
#                                changed match expression to escape special characaters in match for 
#                                renumber() & extractTags() / added test for content & open log handle in 
#                                toLog()
#         1.6 -  7 Feb 2026	 RAD added processing instruction for output of XML in make_XML_playlist() / 
#                                changed order of cleanTags() to after extractTags() in make_XML_playlist() 
#                                corrected output of 'year' metadata in make_XML_playlist() / corrected 
#                                setting tag value to primary tag name in @listOfTagArray in mkvTools() & 
#                                exifTools() / added stripping of "/[total_tracks]" in 'track' tag / added 
#                                date/time output in make_XML_playlist() ending log entry
#         1.7 -  7 Feb 2026	 RAD updated output to console in getSongList() / corrected grep statements to 
#                                match tag name exactly in exifTools() & mkvTools() / corrected storing & 
#                                looping through XML values, based on priority of @listOfTagArrays in 
#                                mkvTools() / created deleteFile(), createFile(), & loadXml() for common 
#                                operations / corrected match expression when determining 'title' & 
#                                content includes '.' in extractTags() / added calling 'ffprobe' to 
#                                determine 'bitrate' in mkvTools() / changed matching expression for 
#                                'bitrate' to accept number in 10,000's in cleanTags() / changed matching 
#                                expression to properly match folder hierarchy when determining tags by 
#                                path in extractTags() / added '+' to $albummatch in extractTags() / 
#                                corrected match expression when determining 'title', 'album', 'artist', 
#                                etc. from song filename in extractTags() / added test for existence when 
#                                close() statements in writeTags() / added check for Windows error in 
#                                badExit() / added check for $funcName when writing toLog() in badExit() / 
#                                added calling of exifTools() when song file is .mkv, for determining some 
#                                tags that mkvTools() doesn't
#         1.8 - 11 Feb 2026	 RAD added calling 'ffprobe' to determine 'title' in mkvTools() / replaced 
#                                global $filePath with $fileFQN (Fully Qualified Name) / replaced global 
#                                $dirName with $dirPath (more accurate identifier) / added to tag array: 
#                                'artists', 'sort_with', & 'part' / removed handling of Unicode errors in 
#                                each openL() & opendirL(), and moved to handle in badExit() & warning() / 
#                                added output to console about global log location in tkGetDir() & 
#                                tkGetFile() / changed running exifTools() in make_XML_playlist() & 
#                                update_ID3_tags() to only run if not .mkv file type / changed test for 
#                                population of $fileFQN to test if file exists in make_XML_playlist() & 
#                                make_m3u() / refactored some logging in make_m3u(), renumber(), & 
#                                update_ID3_tags() / refactored run3() to decode raw error into Unicode / 
#                                removed attempted close() & sleep() on song file & temporary song file in 
#                                writeTags() / added check for .mkv & .m4a song file types in writeTags() 
#                                to replace certain different tags / changed logging parameter in 
#                                writeTags() to only log errors / added test of song file size in 
#                                writeTags() to check for errors
#         1.9 - 11 Feb 2026	 RAD removed completion test for XML playlist file in make_XML_playlist() / 
#                                changed completion test for .m3u file in make_m3u() to check for $fileFQN 
#                                / changed button order in GUI, changed button text to 'Make XML Playlist' 
#                                & 'Making Playlist...', & changed width of 'Make XML Playlist' button / 
#                                added test for current directory vs. previous directory in tkGetFile() to 
#                                print logging message to console / removed mkvTools() calls - using 
#                                exifTools() for all metadata reading / removed command-line call for 
#                                utility - using Perl modules for exifTool instead / added use of ExifTool 
#                                config file / changed check for no tag values to use 'defined' in tag 
#                                tests in make_XML_playlist() & update_ID3_tags() / refactored some 
#                                variable names for clarity
#        1.10 - 13 Feb 2026  RAD added 'avgbitrate' to @listOfTagArrays for 'bitrate' in .m4a song files / 
#                                replaced use of int() with sprintf() - need rounding / removed defined() 
#                                in tests where checking for non-empty value / added some value tests when 
#                                checking for existance of tag value / added rules for checking 'part', 
#                                'disk', & 'createdate'
#
#
#   TO-DO:
#         1) none
#
#**********************************************************************************************************

my $Version = '1.10';

use strict;
use warnings;
use utf8::all;
use feature 'unicode_strings';
use open ':std', IO => ':raw :encoding(UTF-8)';

use Carp qw( carp croak longmess shortmess );
use Config;
use Data::Dumper qw( Dumper );
use Encode qw( decode encode );
use File::Basename qw( fileparse );
#uncomment line below to specify config file for ExifTool
BEGIN { $Image::ExifTool::configFile = 'C:\Users\rich\.ExifTool_config' }
use Image::ExifTool qw( :Public );
use IPC::Run3;
use JSON;
use Tk;
use Tk::DialogBox;
use XML::LibXML;
use XML::Writer;
use Win32;
use Win32::LongPath qw( abspathL chdirL getcwdL mkdirL openL renameL testL unlinkL );

#Tk setup
#colors from rgb.txt
use constant TK_COLOR_BG			=> 'SlateGray1';
use constant TK_COLOR_FIELD		=> 'AliceBlue';
use constant TK_COLOR_FG			=> 'black';
use constant TK_COLOR_ABG			=> 'goldenrod1';
use constant TK_COLOR_LGREEN	=> 'palegreen';
use constant TK_COLOR_GREYBUT	=> 'gray54';
use constant TK_COLOR_LRED		=> 'tomato';
use constant TK_COLOR_YELLOW	=> 'yellow';
use constant TK_COLOR_TURQ		=> 'turquoise';
use constant TK_COLOR_VIOL		=> 'MediumVioletRed';
#font using Unix-centric font name:-foundry-family-weight-slant-setwidth-addstyle-pixel-point-resx-resy-spacing-width-charset-encoding, "*" defaults and last "*" defaults remaining values
use constant TK_FNT_BIGGER		=> "-*-{Lucida Sans Unicode}-bold-r-normal-*-18-*";
use constant TK_FNT_BIGB			=> "-*-{Lucida Sans Unicode}-bold-r-normal-*-14-*";
use constant TK_FNT_BIG				=> "-*-{Lucida Sans Unicode}-medium-r-normal-*-14-*";
use constant TK_FNT_BI				=> "-*-{Lucida Sans Unicode}-bold-i-normal-*-12-*";
use constant TK_FNT_B					=> "-*-{Lucida Sans Unicode}-bold-r-normal-*-12-*";
use constant TK_FNT_I					=> "-*-{Lucida Sans Unicode}-medium-i-normal-*-12-*";

umask 0000;

#global variables
my ( $dirPath, $fileFQN, $fileName, $log );
my $FS = '\\';
my $Sep = '-' x 110;
my $SEP = '=' x 110;
#specify server\share for replacement of drive letter in path
my $Server = 'DavisServer_1';
my $Share = 'Movies_Music_Pics';
#log file handles for function log vs. main log
my ( $funcLogFH, $logFH );
#instantiate warning hash
my %warn;
#determine program name
my $progName = progName();

#command-line tools for song metadata manipulation
my $exifToolCmd = 'C:\Strawberry\perl\site\bin\exiftool';
my $ffmpegCmd = 'C:\Users\rich\Documents\Dev\ffmpeg\FFmpeg-exe\bin\ffmpeg.exe';
my $ffprobeCmd = 'C:\Users\rich\Documents\Dev\ffmpeg\FFmpeg-exe\bin\ffprobe.exe';
my $mkvCmd = 'C:\Program Files\MKVToolNix\mkvextract.exe';

#Tk variables
my $proc = 'Waiting on command...';
my $stat;

#array list of possible ID3 tag names in nested arrays (priority is 1st item in sub-array)
my @listOfTagArrays = (
	[ 'albumartist', 'album_artist' ],
	[ 'albumartistsortorder', 'albumartistsort' ],
	[ 'album', 'originalalbum' ],
	[ 'albumsortorder', 'albumsort' ],
	[ 'artist', 'originalartist', 'ensemble', 'band', 'author', 'artists' ],
	[ 'artistsortorder', 'artistsort' ],
	[ 'bitrate', 'bit_rate', 'audiobitrate', 'avgbitrate' ],
	[ 'comment', 'comment-xxx' ],
	[ 'composer' ],
	[ 'discnumber', 'disc', 'partofset', 'disk' ],
	[ 'length', 'duration' ],
	[ 'genre' ],
	[ 'publisher' ],
	[ 'title' ],
	[ 'titlesortorder', 'titlesort', 'sort_with' ],
	[ 'track', 'part', 'tracknumber', 'part_number', 'trackid' ],
	[ 'year', 'date', 'createdate', 'originaldate', 'originalreleaseyear', 'release_date', 'datetimeoriginal', 'recordingdates' ]
);

#array list of necessary ID3 tags for XML output, in order of desired XML output
my @listOfXmlTags = (
	'track',
	'title',
	'artist',
	'albumartist',
	'album',
	'year',
	'genre',
	'bitrate',
	'length',
	'comment'
);

#process passed argument(s)
if ( testL ( 's', $ARGV[0] ) ) {
	$fileFQN = $ARGV[0];
	#directory separator default for Windows command line
	$fileFQN =~ s#[\/\\]#$FS#g;
	( $fileName, $dirPath ) = fileparse( abspathL ( $fileFQN ) );
	if ( ! testL ( 'd', $dirPath ) ) {
		$dirPath = getcwdL();
		$dirPath =~ s#[\/\\]#$FS#g;
	}
	$fileFQN = $dirPath . $fileName;
} elsif ( testL ( 'd', $ARGV[0] ) ) {
	$dirPath = $ARGV[0];
} elsif ( $ARGV[0] ) {
		print "\n\n*WARNING: Optional argument(s) incorrect,\n  single possible correct argument should be XML playlist filename:\n    \"perl C:\\git_playlist\\$progName.pl \[XML_PLAYLIST_FILENAME\]\"\n\n";
}

#read possible last value file for setting of $dirPath and/or $fileFQN
readLastVal();

#declare log file handle, start logging
startLog();

#create initial window and pass to tk caller
my $M->{'window'} = MainWindow->new();
tkMainWindow();
MainLoop;

#----------------------------------------------------------------------------------------------------------
# change keys in hash to lowercase
# **args:
#     1 - hash reference
sub lowerHashCase
#----------------------------------------------------------------------------------------------------------
{
	my $hashRef = shift;
	foreach my $key ( keys %{$hashRef} ) {
		if ( ref( $hashRef->{$key} ) eq 'HASH' ) {
			my $innerHashRef = \%{$hashRef->{$key}};
			$innerHashRef = lowerHashCase( $innerHashRef );
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

#----------------------------------------------------------------------------------------------------------
# convert HH:MM:SS length into seconds
sub convertLength
#----------------------------------------------------------------------------------------------------------
{
    my @time_parts = reverse( split( ':', $_[0] ) );
    my $accum = 0;
    for ( my $i = 0; $i < @time_parts; $i++ ) {
        $accum += $time_parts[$i] * 60 ** $i;
    }
    return $accum;
}

#----------------------------------------------------------------------------------------------------------
# create date & time in readable format
sub dateTime
#----------------------------------------------------------------------------------------------------------
{
	my ( $sec, $min, $hr, $day, $monNum, $yr );
	my $tod = 'am';
	my $now = {};
	
	#get date and time
	( undef, $min, $hr, $day, $monNum, $yr ) = localtime( time() );

	#modify for output
	my $mon = ( 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec' )[$monNum];
	$min = sprintf( "%02d", $min );
	if ( $hr > 12 ) {
		$hr = $hr - 12;
		$tod = 'pm';
	} elsif ( $hr == 12 ) {
		$tod = 'pm';
	}
	$yr = 1900 + $yr;

	#set available forms of date & time
	$now->{'date'} = "$mon $day, $yr";
	$now->{'time'} = "$hr:$min $tod";
	
	return( $now );		
}

#----------------------------------------------------------------------------------------------------------
# return the name of the program currently running
sub progName
#----------------------------------------------------------------------------------------------------------
{
	my $prog;

	#running under PerlApp, so get name of program
	if ( defined $PerlApp::VERSION ) {
		$prog = PerlApp::exe();
	} else {
	# Not running PerlAppified, so file should already exist
		$prog = fileparse( $0 );
	}

	$prog =~ s#\..*$##;
	return( $prog );
}

#----------------------------------------------------------------------------------------------------------
# delete file & log error/warning messages
# **args:
#     1 - file to delete
#     2 - $subName from passing routine
#     3 - description of file
sub deleteFile
#----------------------------------------------------------------------------------------------------------
{
	my ( $file, $subName, $desc ) = @_;

	toLog( $subName, "   - Cleaning up temporary " . $desc . " file\n" );

	if ( testL ( 'e', $file ) ) {
		my $fileDel = unlinkL ( $file );
		warning( $subName, "Not able to remove temporary " . $desc . " file: '" . $file . "'" ) if ( ! $fileDel );
	} else {
		badExit( $subName, "No " . $desc . " file to delete: '" . $file . "'" );
	}

	return;
}

#----------------------------------------------------------------------------------------------------------
# create file & log error/warning messages
# **args:
#     1 - file to create
#     2 - $subName from passing routine
#     3 - content of file
#     4 - description of file
sub createFile
#----------------------------------------------------------------------------------------------------------
{
	my ( $file, $subName, $content, $desc ) = @_;
	my $fileFH;

	#open/close file with commands written to it
	toLog( $subName, "   - Creating " . $desc . " file: '" . $file . "'\n" );
	openL ( \$fileFH, '>:encoding(UTF-8)', $file ) or badExit( $subName, "Not able to create $desc file: '" . $file . "'" );
	my $newFH = select $fileFH; $| = 1; select $newFH;
	print $fileFH $content;
	close( $fileFH );

	return;
}

#----------------------------------------------------------------------------------------------------------
# load XML instance and return $dom object
# **args:
#     1 - file to load
#     2 - $subName from passing routine
sub loadXml
#----------------------------------------------------------------------------------------------------------
{
	my ( $file, $subName ) = @_;
	my ( $dom, $xmlFH );

	toLog( $subName, "   - Loading XML: '" . $file . "' into DOM\n" );
	openL ( \$xmlFH, '<:encoding(UTF-8)', $file ) or badExit( $subName, "Not able to open XML file: '" . $file . "'" );
	binmode $xmlFH;
	$dom = XML::LibXML->load_xml( IO => $xmlFH );
	if ( ! $dom ) {
		badExit( $subName, "Couldn't load XML file: '" . $file . "'" );
	} else {
		close( $xmlFH );
	}

	return( $dom );
}

#----------------------------------------------------------------------------------------------------------
# read directory and return a list of XML files [$dirPath must be populated globally]
sub getXML_List
#----------------------------------------------------------------------------------------------------------
{
	my @xmlList;

	#determine calling subroutine
	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;

	toLog( $subName, "   - Building list of XML files\n");
	updStatus( 'Building list of XML files' );

	my $dir = Win32::LongPath->new();
	$dir->opendirL ( $dirPath ) or badExit( $subName, "Not able to open directory: '" . $dirPath . "'" );

	@xmlList = grep m/\.xml$/i, $dir->readdirL();
	$dir->closedirL();

	#add path info to each XML file in list
	my @newList;
	foreach my $file ( @xmlList ) {
		push @newList, $dirPath . $file;
	}

	badExit( $subName, "No files were found in directory: '" . $dirPath . "'" ) unless ( scalar( @newList ) );

	return( @newList );
}

#----------------------------------------------------------------------------------------------------------
# read directory & recurse subdirectories to return a list of song file
# **args:
#     1 - array reference for song file list
#     2 - directory to crawl
sub getSongList
#----------------------------------------------------------------------------------------------------------
{
	my ( $songArrayRef, $workingDir ) = @_;

	#don't scour '$' folders, unless for testing
	return if ( $workingDir =~ m#[\\\/]\$(?!program_test)# );

	#determine calling subroutine
	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;

	updStatus( 'Building list of song files' );

	my $dir = Win32::LongPath->new();
	$dir->opendirL ( $workingDir ) or badExit( $subName, "Not able to open directory: '" . $workingDir . "'" );

	foreach my $dirItem ( $dir->readdirL() ) {
		next if $dirItem =~ m#^\.{1,2}$#;

		#send notice of folder processing to console
		my $conFH = select STDOUT; $| = 1; select $conFH;
		print '.';

		my $dirItemPath = $workingDir . $dirItem;

		if ( testL ( 'd', $dirItemPath ) ) {
			getSongList( $songArrayRef, $dirItemPath . $FS);
			next;
		} elsif ( $dirItem =~ m#\.(aac|alac|flac|m4a|mka|mkv|mp3|ogg|wma)$#i ) {
			push @{$songArrayRef}, $dirItemPath;
		} else {
			next;
		}
	}

	$dir->closedirL();

	return;
}

#----------------------------------------------------------------------------------------------------------
# draw main GUI window
sub tkMainWindow
#----------------------------------------------------------------------------------------------------------
{
	#main window
	$M->{'window'}->configure(
		-bg		 => TK_COLOR_BG,
		-fg		 => TK_COLOR_FG,
		-title => "$progName..."
	);
	
	#frames
	my $title				= $M->{'window'}->Frame( -bg => TK_COLOR_BG )->grid( -row => '0' );
	my $chooseFile	= $M->{'window'}->Frame( -bg => TK_COLOR_BG )->grid( -row => '1' );
	my $chooseDir		= $M->{'window'}->Frame( -bg => TK_COLOR_BG )->grid( -row => '2', -sticky => 'we' );
	my $status   		= $M->{'window'}->Frame( -bg => TK_COLOR_BG )->grid( -row => '3', -sticky => 'we' );
	my $buttons1 		= $M->{'window'}->Frame( -bg => TK_COLOR_BG )->grid( -row => '4' );
	my $buttons2 		= $M->{'window'}->Frame( -bg => TK_COLOR_BG )->grid( -row => '5' );
	my $statbar  		= $M->{'window'}->Frame()->grid( -row => '6', -sticky => 'we' );
	
	#title frame
	$title->Label(
		-bg 	=> TK_COLOR_BG,
		-fg 	=> TK_COLOR_FG,
		-font => TK_FNT_BIGGER,
		-text => "$progName Tool"
	)->pack(
		-pady => '0'
	);
	$title->Label(
		-bg 		=> TK_COLOR_BG,
		-fg 		=> TK_COLOR_FG,
		-font 	=> TK_FNT_I,
		-text 	=> "Version: $Version",
		-anchor => 'e'
	)->pack(
		-side 	=> 'right',
		-pady 	=> '0'
	);

	#file choose frame:
	$chooseFile->Label(
		-text => 'File:',
		-font => TK_FNT_BIGB,
		-bg 	=> TK_COLOR_BG,
		-fg 	=> TK_COLOR_FG
	)->pack(
		-side => 'left',
		-pady => '0',
		-padx => [ 38, 0 ]
	);
	my $fileEntry = $chooseFile->Entry(
		-textvariable => \$fileFQN,
		-width				=> '30',
		-bg						=> TK_COLOR_FIELD,
		-fg						=> TK_COLOR_FG
	)->pack(
		-side					=> 'left',
		-pady					=> '0'
	);
	$fileEntry->xview( 'end' );
	$M->{'select'} = $chooseFile->Button(
		-text							=> '...',
		-command					=> [ \&tkGetFile, $fileFQN ],
		-bg								=> TK_COLOR_BG,
		-fg								=> TK_COLOR_FG,
		-activebackground => TK_COLOR_VIOL,
		-width						=> '3'
	)->pack(
		-side							=> 'left',
		-padx							=> '2',
		-pady							=> '0'
	);

	#directory choose frame:
	$chooseDir->Label(
		-text => 'Directory:',
		-font => TK_FNT_BIGB,
		-bg		=> TK_COLOR_BG,
		-fg		=> TK_COLOR_FG
	)->pack(
		-side => 'left'
	);
	my $dirEntry = $chooseDir->Entry(
		-textvariable => \$dirPath,
		-width	=> '30',
		-bg			=> TK_COLOR_FIELD,
		-fg			=> TK_COLOR_FG
	)->pack(
		-side		=> 'left'
	);
	$dirEntry->xview( 'end' );
	$M->{'select'} = $chooseDir->Button(
		-text							=> '...',
		-command					=> [ \&tkGetDir, $dirPath ],
		-bg								=> TK_COLOR_BG,
		-fg								=> TK_COLOR_FG,
		-activebackground => TK_COLOR_VIOL,
		-width						=> '3'
	)->pack(
		-side							=> 'left',
		-padx							=> '2',
		-pady							=> '8'
	);

	#status frame
	my $statframe = $status->Frame(
		-relief				=> 'sunken',
		-borderwidth	=> '2',
		-bg						=> TK_COLOR_FIELD
	)->pack(
		-padx					=> '4',
		-pady					=> '6',
		-fill					=> 'x'
	);
	$M->{'progress'} = $statframe->Label(
		-bg						=> TK_COLOR_FIELD,
		-textvariable => \$stat
	)->pack(
		-side					=> 'left',
		-pady					=> '0',
		-fill					=> 'x'
	);

	#buttons1 frame
	$M->{'update_ID3_tags'} = $buttons1->Button(
		-text								=> 'Update ID3 Tags',
		-font								=> TK_FNT_B,
		-command						=> \&update_ID3_tags,
		-borderwidth				=> '4',
		-bg									=> TK_COLOR_BG,
		-fg									=> TK_COLOR_FG,
		-activebackground		=> TK_COLOR_YELLOW,
		-disabledforeground => TK_COLOR_GREYBUT,
		-width							=> '14'
	)->pack(
		-side								=> 'left',
		-padx								=> '2',
		-pady								=> '0'
	);
	$M->{'make_XML_playlist'} = $buttons1->Button(
		-text								=> 'Make XML Playlist',
		-font								=> TK_FNT_B,
		-command						=> \&make_XML_playlist,
		-borderwidth				=> '4',
		-bg									=> TK_COLOR_BG,
		-fg									=> TK_COLOR_FG,
		-activebackground		=> TK_COLOR_ABG,
		-disabledforeground => TK_COLOR_GREYBUT,
		-width							=> '16'
	)->pack(
		-side								=> 'left',
		-padx								=> '2',
		-pady								=> '8'
	);
	#buttons2 frame
	$M->{'make_m3u'} = $buttons2->Button(
		-text								=> 'Make .m3u',
		-font								=> TK_FNT_B,
		-command						=> \&make_m3u,
		-borderwidth				=> '4',
		-bg									=> TK_COLOR_BG,
		-fg									=> TK_COLOR_FG,
		-activebackground		=> TK_COLOR_LGREEN,
		-disabledforeground => TK_COLOR_GREYBUT,
		-width							=> '11'
	)->pack(
		-side								=> 'left',
		-padx								=> '2',
		-pady								=> '8'
	);
	$M->{'renumber'} = $buttons2->Button(
		-text								=> 'Renumber',
		-font								=> TK_FNT_B,
		-command						=> \&renumber,
		-borderwidth				=> '4',
		-bg									=> TK_COLOR_BG,
		-fg									=> TK_COLOR_FG,
		-activebackground		=> TK_COLOR_TURQ,
		-disabledforeground => TK_COLOR_GREYBUT,
		-width							=> '11'
	)->pack(
		-side								=> 'left',
		-padx								=> '2',
		-pady								=> '0'
	);
	$M->{'exit'} = $buttons2->Button(
		-text							=> 'Exit',
		-font							=> TK_FNT_B,
		-command					=> \&tkExit,
		-borderwidth			=> '4',
		-bg								=> TK_COLOR_BG,
		-fg								=> TK_COLOR_FG,
		-activebackground => TK_COLOR_LRED,
		-width						=> '8'
	)->pack(
		-padx							=> '2',
		-pady							=> '8'
	);

	#status bar frame
	my $leftframe = $statbar->Frame(
		-borderwidth	=> '2'
	)->pack(
		-side					=> 'left'
	);
	$M->{'bottomLeft'}= $leftframe->Label(
		-text					=> ' Status '
	)->pack(
		-side					=> 'left'
	);
	my $frame2 = $statbar->Frame(
		-relief				=> 'sunken',
		-borderwidth	=> '2'
	)->pack(
		-side					=> 'left',
		-fill					=> 'x'
	);
	$M->{'bottomRight'}= $frame2->Label(
		-textvariable => \$proc
	)->pack(
		-side					=> 'left'
	);
	
	#output date and time
	my $now = dateTime();
	my $mesg = $now->{'date'} . ' at ' . $now->{'time'};
	updStatus( $mesg, undef );
	$M->{'window'}->update();
	
	#set focus
	$M->{'select'}->focus();
}

#----------------------------------------------------------------------------------------------------------
# update status in GUI window
# **args:
#     1 - current status frame
#     2 - current process status bar
sub updStatus
#----------------------------------------------------------------------------------------------------------
{
	if ( $_[0] ) { $stat = $_[0] };
	if ( $_[1] ) { $proc = $_[1] };

	$M->{'window'}->update();
}

#----------------------------------------------------------------------------------------------------------
# creates prompt window
#  -returns user's response (name of button)
#  -if 1st arg specified as 'warning' or 'error', will display that image and include in window title
#  -3rd arg, and so forth, create buttons
#  -3rd arg button has default focus
# **args:
#     1 - 'warning' or 'error', to display icon (opt) [pass 'undef' if not using]
#     2 - text for prompt window
#     3 - array of buttons for answer to prompt (opt) [if not passed, 'OK' will be single button]
sub promptUser
#----------------------------------------------------------------------------------------------------------
{
	my ( $type, $txt, @buttons ) = @_;
	my $image = '';
	my $title = '';

	if ( $type ) {
		if ( $type =~ m#(error|warning)#i ) {
      $title = uc($type);
    } else {
      $image = lc($type);
    }
	}
	unless ( scalar(@buttons) ) {
		push @buttons, 'OK';
	}
	$title = "$progName...$title";

	#create prompt window
	my $win = $M->{'window'};
	my $dialog = $win->DialogBox(
		-title			=> $title,
		-background => TK_COLOR_BG,
		-buttons		=> [ @buttons ]
	);
	$dialog->transient( '' );
	$dialog->add(
		'Label',
		-bitmap			=> $image,
		-background => TK_COLOR_BG
	)->pack(
		-side				=> 'left',
		-padx				=> '8'
	);
	$dialog->add(
		'Label',
		-text				=> $txt,
		-font				=> TK_FNT_BIG,
		-background => TK_COLOR_BG
	)->pack(
		-side				=> 'left'
	);

	#return user choice
	my $ans = $dialog->Show( -global );
	return( $ans );
}

#----------------------------------------------------------------------------------------------------------
# GUI directory selection
# **args:
#     1 - initial directory selection (opt)
sub tkGetDir
#----------------------------------------------------------------------------------------------------------
{
	my ( $getDirPath ) = @_;

	if ( $getDirPath ) {
		$getDirPath =~ s#[\/\\]#$FS#g;
		if ( $getDirPath !~ m#[\/\\]$# ) {
			$getDirPath = $getDirPath . $FS;
		}
		#if directory already populated & changed, note to console about different global log location
		print "\n *NOTE: The global log file is saved in opening directory as:\n  " . $log . "\n\n";
	}

	$getDirPath = $M->{'window'}->chooseDirectory(
		-initialdir => $getDirPath,
		-title			=> 'Choose Directory...'
	);

	if ( testL ( 'd', $getDirPath ) ) {
		$dirPath = $getDirPath;
		$dirPath =~ s#[\/\\]#$FS#g;
		if ( $dirPath !~ m#[\/\\]$# ) {
			$dirPath = $dirPath . $FS;
		}
	}
}

#----------------------------------------------------------------------------------------------------------
# GUI file selection
# **args:
#     1 - initial file & directory selection (opt)
sub tkGetFile
#----------------------------------------------------------------------------------------------------------
{
	my ( $getFilePath ) = @_;
	my ( $currentDir, $dir, $file );

	$currentDir = $dirPath;
	#prepare directory for match expression
	$currentDir =~ s#[\/\\]#\/#g;
	if ( testL ( 'e', $getFilePath ) ) {
		( $file, $dir ) = fileparse( abspathL ( $getFilePath ) );
		#prepare directory for match expression
		$dir =~ s#[\/\\]#\/#g;
		$dir =~ s#\$#\\\$#g;
		#if file already populated & changed (which affects directory), note to console about different global log location
		if ( $currentDir !~ m#^$dir$#i ) {
			print "\n *NOTE: The global log file is saved in directory as:\n  " . $log . "\n\n";
		}
		#return $dir back
		$dir =~ s#\\\$#\$#g;
		$dir =~ s#[\/\\]#$FS#g;
	}

	$getFilePath = $M->{'window'}->getOpenFile(
		-initialdir		=> $dir,
		-initialfile	=> $file,
		-title				=> 'Choose File...'
	);

	$getFilePath =~ s#[\/\\]#$FS#g;
	if ( testL ( 'e', $getFilePath ) ) {
		$fileFQN = $getFilePath;
		( $fileName, $dirPath ) = fileparse( abspathL ( $fileFQN ) );
		if ( $dirPath !~ m#[\/\\]$# ) {
			$dirPath = $dirPath . $FS;
		}

		#prepare directory for match expression
		$dir = $dirPath;
		$dir =~ s#[\/\\]#\/#g;
		$dir =~ s#\$#\\\$#g;
		#if file already populated & changed (which affects directory), note to console about different global log location
		if ( $currentDir !~ m#^$dir$#i ) {
			print "\n *NOTE: The global log file is saved in directory as:\n  " . $log . "\n\n";
		}
	}
}

#----------------------------------------------------------------------------------------------------------
# update GUI & create XML playlist from selected root 'Music' folder, crawls all artist/album subfolders, 
#   calls command-line utility for extraction based on song file type
#  - $dirPath must be populated globally (user directory selection in GUI)
sub make_XML_playlist
#----------------------------------------------------------------------------------------------------------
{
	#determine subroutine
	my ( $package, $file, $line, $subName ) = caller( 0 );
	$subName =~ s#main::##;
	updStatus( undef, 'Make XML Playlist...' );

	#must specify directory or file
	unless ( $dirPath ) {
		my $ans = promptUser( 'warning', "No music directory selected or passed,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( $subName, "User chose to stop process,\n no music directory selected or passed" );
		}
		$M->{'select'}->focus();
		return;
	}

	$M->{'make_m3u'}->configure(
		-text							=> 'Make .m3u',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'renumber'}->configure(
		-text							=> 'Renumber',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'update_ID3_tags'}->configure(
		-text							=> 'Update ID3 Tags',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'make_XML_playlist'}->configure(
		-text							=> 'Making Playlist...',
		-font							=> TK_FNT_B,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_FIELD,
		-activebackground => TK_COLOR_FIELD
	);
	$M->{'exit'}->focus();

	#starting log process
	toLog( undef, "  Creating XML Playlist...\n    See '" . $dirPath . $subName . ".log' for details\n\n" );
	startLog( $subName );
	
	toLog( $subName, "Scouring Music folders to build list of song files...\n" );

	my @songList;
	print "\n  Crawling through folders:\n";
	getSongList( \@songList, $dirPath );
	print "\n  ...Finished crawling folders\n";
	
	toLog( $subName, "====\n...Processing Song Files in: $dirPath\n\n" );
	
	#parse out XML node data from songs to XML file
	updStatus( 'Creating XML document' );
	my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
	badExit( $subName, 'Not able to create new XML::Writer object' ) if ( ! $writer );
	#write XML Declaration
	$writer->xmlDecl( 'UTF-8' ) or badExit( $subName, "Not able to write out XML Declaration" );
	$writer->comment( '*IMPORTANT*: Only 1 attribute/value pair is allowed per each child node of <song>' );
	#determine playlist name
	my $playlist_name;
	if ( $dirPath =~ m#phone_music#i ) {
		$playlist_name = 'phone-favorites';
	} else {
		$playlist_name = 'rich-all-songs';
	}
	#write date into <playlist> tag attribute
	my $now = dateTime();
	my $today = $now->{'date'} . ' at ' . $now->{'time'};
	$writer->startTag( 'playlist', name => $playlist_name, date => $today );
	
	#start process to create batch file for calling 'chcp 65001' for files/folders with Unicode characters
	my $statBat = $ENV{TEMP} . $FS . 'stat.bat';
	my $content = "\n" . '@echo off' . "\n" . 'echo   **Setting Console Code Page to 65001**' . "\n" . 'chcp 65001';
	createFile( $statBat, $subName, $content, 'batch file wrapper to set console code page' );
	
	#execute batch file wrapper to set console code page
	toLog( $subName, "   - Executing batch file to set console code page\n" );
	my ( $rawStdErr, $stdErr );
	run3( $statBat, \undef, \undef, \$rawStdErr );
	$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
	badExit( $subName, "Not able to run set console code page batch file wrapper: '" . $statBat . "', returned:\n" . $stdErr ) if ( $? || $stdErr );
	
	#clean up temporary file
	deleteFile( $statBat, $subName, 'console code page batch' );
	
	#set overall counter for songs
	my $num = 0;
	#loop through each song file in file list
	foreach my $songFile ( @songList ) {
		#song counter for XML file output
		++$num;
		
		#echo status to console
		my $songFileName;
		( $songFileName ) = fileparse( abspathL ( $songFile ) );
		toLog( $subName, 'Processing song no. ' . $num . ": '" . $songFile . "'\n" );
		updStatus( 'Processing song no. ' . $num );
		binmode( STDOUT, ":encoding(UTF-8)" );
		print "\n" if ( $num == 1 );
		print '   - processing song no. ' . $num . ": '" . $songFileName . "'\n";
	
		#set per song hash for tag metadata
		my %tags;
	
		#read song metadata
		exifTools( $num, \%tags, $songFile );

		#check if crucial tags have been set, try to determine from filename & path
		if ( ( ! $tags{title} ) || ( ! $tags{artist} ) || ( ! $tags{track} ) || ( ! $tags{album} ) || ( ! $tags{length} ) || ( ! $tags{albumartist} ) || ( ! $tags{discnumber} ) ) {
			extractTags( $num, \%tags, $songFile );
		}

		#call method to clean and sort metadata tags
		cleanTags( \%tags, $songFile );

		#write out XML to file of metadata for song file
		toLog( $subName, "   - Writing XML nodes to DOM\n" );
		#build and output new playlist song node
		$writer->startTag( 'song', number => $num );
		#write <track>
		#strip leading '0' in 'Discnumber' tag
		if ( $tags{discnumber} =~ m#^0(.+)$# ) {
			$tags{discnumber} = $1;
		}
		$writer->startTag( 'track', discnumber => $tags{discnumber} );
		#padding with '0' in 'track' tag
		if ( $tags{track} =~ m#^\d$# ) {
			$tags{track} = '0' . $tags{track};
		}
		$writer->characters( $tags{track} ) if ( $tags{track} );
		$writer->endTag( 'track' );
		#write <title>
		$writer->startTag( 'title' );
		#replace extraneous characters
		$writer->characters( $tags{title} ) if ( $tags{title} );
		$writer->endTag( 'title' );
		#write <artist>
		$writer->startTag( 'artist' );
		#replace extraneous characters
		$writer->characters( $tags{artist} ) if ( $tags{artist} );
		$writer->endTag( 'artist' );
		#write <albumartist>
		$writer->startTag( 'albumartist' );
		#replace extraneous characters
		$writer->characters( $tags{albumartist} ) if ( $tags{albumartist} );
		$writer->endTag( 'albumartist' );
		#write <album>
		$writer->startTag( 'album' );
		#replace extraneous characters
		$writer->characters( $tags{album} ) if ( $tags{album} );
		$writer->endTag( 'album' );
		#write <year>
		$writer->startTag( 'year' );
		$writer->characters( $tags{year} ) if ( $tags{year} );
		$writer->endTag( 'year' );
		#write <genre>
		$writer->startTag( 'genre' );
		#replace extraneous characters
		$writer->characters( $tags{genre} ) if ( $tags{genre} );
		$writer->endTag( 'genre' );
		#write <bitrate>
		$writer->startTag( 'bitrate', unit => 'kbps' );
		$writer->characters( $tags{bitrate} ) if ( $tags{bitrate} );
		$writer->endTag( 'bitrate' );
		#write <length>
		if ( $tags{minutes} ) {
			$writer->startTag( 'length', minutes => $tags{minutes} );
		} else {
			$writer->startTag( 'length', minutes => '' );
		}
		$writer->characters( $tags{length} ) if ( $tags{length} );
		$writer->endTag( 'length' );
		#write <comment>
		$writer->startTag( 'comment' );
		#replace extraneous characters
		$writer->characters( $tags{comment} ) if ( $tags{comment} );
		$writer->endTag( 'comment' );
		#replace extraneous characters for adding <path> content
		my $songFileClean = $songFile;
		#clean up path
		if ( $songFileClean =~ s#^[A-Za-z]:[\/\\]#\\\\$Server\\$Share\\#i ) {
			#replace 'M:\' drive letter path with UNC path
			toLog( $subName, "   - Replacing drive letter with UNC path\n" );
			#replace any remaining forward slashes with backslashes
			$songFileClean =~ s#\/#$FS#g;
		}
		#write <path>
		$writer->startTag( 'path' );
		$writer->characters( $songFileClean );
		$writer->endTag( 'path' );
	
		#write out close song XML tag
		$writer->endTag( 'song' );
	
		toLog( $subName, "  Writing \"" . $tags{title} . "\" by \"" . $tags{artist} . "\" as number $num to XML playlist file\n" );
	}
	
	#write out close playlist XML tag
	$writer->endTag( 'playlist' );
	$writer->end() or badExit( $subName, 'Not able to write complete XML to file' );
	
	#write out new XML playlist file
	my $xmlPlaylistFile = $dirPath . $playlist_name . '.xml';
	createFile( $xmlPlaylistFile, $subName, $writer, 'XML playlist' );

	toLog( $subName, "\n...Created XML Playlist: '" . $xmlPlaylistFile . "'\n\n\n" );
	toLog( $subName, " *WARNING*: There were " . $warn{$subName} . " warning(s) for process...\n\n\n" ) if ( $warn{$subName} );
	toLog( undef, "  ...Finished Creating XML Playlist from: '" . $dirPath . "'\n\n" );
	#echo status to console
	my ( $xmlName ) = fileparse( abspathL ( $xmlPlaylistFile ) );
	binmode( STDOUT, ":encoding(UTF-8)" );
	print "   Finished Creating XML Playlist '" . $xmlName . "'\n";

	#process end
	my $folderNm;
	( $folderNm ) = fileparse( abspathL ( $dirPath ) );
	updStatus( "Finished Creating XML Playlist(s) from: \"" . $folderNm . "\" folder" );

	tkEnd( $subName );
}

#----------------------------------------------------------------------------------------------------------
# update GUI & create .m3u playlist from XML playlist
#  - runs on single XML playlist file, when $fileName populated (1st priority)
#  - gathers XML playlist files in selected directory, when $dirPath populated
sub make_m3u
#----------------------------------------------------------------------------------------------------------
{
	#determine subroutine
	my ( $package, $file, $line, $subName ) = caller( 0 );
	$subName =~ s#main::##;
	updStatus( undef, 'Make .m3u Playlist...' );
	updStatus( 'Making .m3u playlist' );

	#must specify directory or file
	unless ( $dirPath || $fileName ) {
		my $ans = promptUser( 'warning', "No directory (or file) selected or passed,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( $subName, "User chose to stop process,\n no directory (or file) selected or passed" );
		}
		$M->{'select'}->focus();
		return;
	}

	#change buttons to indicate process started
	$M->{'make_m3u'}->configure(
		-text							=> 'Making .m3u...',
		-font							=> TK_FNT_B,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_FIELD,
		-activebackground => TK_COLOR_FIELD
	);
	$M->{'renumber'}->configure(
		-text							=> 'Renumber',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'update_ID3_tags'}->configure(
		-text							=> 'Update ID3 Tags',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'make_XML_playlist'}->configure(
		-text							=> 'Make XML Playlist',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'exit'}->focus();

	#starting log process
	toLog( undef, "  Making .m3u Playlist...\n    See '" . $dirPath . $subName . ".log' for details\n\n" );
	startLog( $subName );
	
	#retrieve list of XML files in $dirPath, unless file is selected - just push single item into array
	my @fileList;
	if ( $fileFQN ) {
		if ( $fileName =~ m#\.xml$#i ) {
			push @fileList, $fileFQN;
		} else {
			promptUser( 'warning', 'Selected file is not an XML instance' );
			toLog( $subName, "File selected is not an XML instance, ending '" . $subName . "' function\n\n" );
			tkEnd( $subName );
			return;
		}
	} else {
		@fileList = getXML_List( $dirPath );
	}

	#loop through each XML file in directory
	my $m3uFileName;
	foreach my $xmlFile ( @fileList ) {
		toLog( $subName, "...Making .m3u playlist from XML: '$xmlFile'\n\n" );
		updStatus( "Making .m3u from XML: '" . $xmlFile . "'" );
		#echo status to console
		binmode( STDOUT, ":encoding(UTF-8)" );
		print "\n   Making .m3u for: '" . $xmlFile . "'\n";

		#load XML data
		my $dom = loadXml( $xmlFile, $subName );

		#create M3U playlist header
		my $m3uData = "#EXTM3U\n#EXTENC: UTF-8\n#PLAYLIST:";
		$m3uFileName = '';
		if ( $dom->findnodes( '/playlist/@name' ) ) {
			$m3uFileName = $dom->findnodes( '/playlist/@name' );
		} else {
			( $m3uFileName ) = fileparse( abspathL ( $xmlFile ) );
			$m3uFileName =~ s#\.\w\w\w?$##;
		}
		$m3uData .= "$m3uFileName\n";
		updStatus( "Creating .m3u playlist: '" . $m3uFileName . "'" );

		toLog( $subName, "Setting date/time for playlist\n" );
		my $now = dateTime();
		my $today = $now->{'date'} . ' at ' . $now->{'time'};
		$m3uData .= '#EXTINF:DATE - ' . $today . "\n";
	
		#create hashes of sorted data for output / title, artist, & song number for logging
		my %m3uItem;
		my %m3uTitle;
		my %m3uArtist;
		my %m3uNum;
		#parse out data for .m3u entry
		foreach my $songNode ( $dom->findnodes( '//song' ) ) {
			my ( $length, $title, $artist, $path );
			$length = ( $songNode->findvalue( 'length' ) );
			$title = ( $songNode->findvalue( 'title' ) );
			$artist = ( $songNode->findvalue( 'artist' ) );
			$path = ( $songNode->findvalue( 'path' ) );
			$m3uNum{$path} = ( $songNode->findvalue( './@number' ) );
			
			#exit if no .m3u data found
			badExit( $subName, "No .m3u entry made, missing (at least) 1 of path: '" . $path . "', title: '" . $title . "', artist: '" . $artist . "', length: '" . $length . "'" ) unless ( $length && $title && $artist && $path );
			#add to m3u hash keyed by path
			$m3uItem{$path} = '#EXTINF:' . $length . ',' . $title . ' - ' . $artist . "\n" . $path . "\n";
			$m3uTitle{$path} = $title;
			$m3uArtist{$path} = $artist;
	
			#add song to compiled data
			$m3uData .= $m3uItem{$path};
			toLog( $subName, "Writing \"$m3uTitle{$path}\" by \"$m3uArtist{$path}\" from number $m3uNum{$path} to .m3u file\n" );
		}
	
		#write out new .m3u playlist file
		my ( $m3uFile, $m3uFilePath );
		$m3uFile = $m3uFileName . '.m3u';
		$m3uFilePath = $dirPath . $m3uFile;
		createFile( $m3uFilePath, $subName, $m3uData, '.m3u' );

		toLog( $subName, "\n...Made .m3u Playlist: '" . $m3uFilePath . "'\n\n\n" );
		toLog( $subName, " *WARNING*: There were " . $warn{make_m3u} . " warning(s) for process...\n\n\n" ) if ( $warn{make_m3u} );
		toLog( undef, "  ...Finished Making .m3u Playlist from: '" . $xmlFile . "'\n\n" );
		#echo status to console
		my ( $xmlName ) = fileparse( abspathL ( $xmlFile ) );
		binmode( STDOUT, ":encoding(UTF-8)" );
		print "   Finished Making .m3u Playlist '" . $m3uFile . "'\n";
	}
	
	#process end
	if ( $fileFQN ) {
		updStatus( "Finished Making .m3u Playlist: \"" . $m3uFileName . "\"" );
	} else {
		my $folderNm;
		( $folderNm ) = fileparse( abspathL ( $dirPath ) );
		updStatus( "Finished Making .m3u Playlist(s) from: \"" . $folderNm . "\" folder" );
	}
	tkEnd( $subName );
}

#----------------------------------------------------------------------------------------------------------
# update GUI & renumber XML nodes in selected XML playlist file(s) or directory of XML playlist file(s)
#  - runs on single XML playlist file, when $fileName populated (1st priority)
#  - gathers XML playlist files in selected directory, when $dirPath populated
sub renumber
#----------------------------------------------------------------------------------------------------------
{
	#determine subroutine
	my ( $package, $file, $line, $subName ) = caller( 0 );
	$subName =~ s#main::##;
	updStatus( undef, 'Renumber...' );

	#must specify directory or file
	unless ( $dirPath || $fileName ) {
		my $ans = promptUser( 'warning', "No directory (or file) selected or passed,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( $subName, "User chose to stop process,\n no directory (or file) selected or passed" );
		}
		$M->{'select'}->focus();
		return;
	}

	#change buttons to indicate process started
	$M->{'make_m3u'}->configure(
		-text							=> 'Make .m3u',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'update_ID3_tags'}->configure(
		-text							=> 'Update ID3 Tags',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'make_XML_playlist'}->configure(
		-text							=> 'Make XML Playlist',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'renumber'}->configure(
		-text							=> 'Renumbering...',
		-font							=> TK_FNT_B,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_FIELD,
		-activebackground => TK_COLOR_FIELD
	);
	$M->{'exit'}->focus();

	#starting log process
	toLog( undef, "  Renumbering...\n    See '" . $dirPath . $subName . ".log' for details\n\n" );
	startLog( $subName );
	updStatus( "Renumbering XML files in '" . $dirPath . "'" );
	
	#retrieve list of XML files in $dirPath, unless file is selected - just push single item into array
	my @fileList;
	if ( $fileFQN ) {
		if ( $fileName =~ m#\.xml$#i ) {
			push @fileList, $fileFQN;
		} else {
			promptUser( 'warning', 'Selected file is not an XML instance' );
			toLog( $subName, "File selected is not an XML instance, ending 'renumber' function\n\n" );
			tkEnd( $subName );
			return;
		}
	} else {
		@fileList = getXML_List( $dirPath );
	}

	#loop through each XML file in directory
	foreach my $xmlFile ( @fileList ) {
		toLog( $subName, "...Renumbering XML File: '$xmlFile'\n\n" );
		updStatus( "Renumbering XML file: '" . $xmlFile . "'" );
		#echo status to console
		binmode( STDOUT, ":encoding(UTF-8)" );
		print "\n   Renumbering '" . $xmlFile . "'\n";
	
		#load XML data
		my $dom = loadXml( $xmlFile, $subName );
	
		#create XML writer object, so can output empty XML elements without collapsing
		my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1, ENCODING => 'utf-8' );
		if ( ! $writer ) {
			badExit( $subName, 'Not able to create new XML::Writer object' );
		} else {
			#write XML Declaration
			$writer->xmlDecl( 'UTF-8' ) or badExit( $subName, 'Not able to write out XML Declaration' );
			$writer->comment( '*IMPORTANT*: Only 1 attribute/value pair is allowed per each child node of <song>' );
		}
		
		#cycle through number nodes
		my $nodeCnt = 0;
		#set date in <playlist> attribute
		my $playlistNode = $dom->findnodes( '/playlist' );
		toLog( $subName, "\tSetting current date/time in <playlist> node\n" );
		#get playlist @name for writing out
		my @playlistName = $dom->findvalue( '/playlist/@name' );
		my $now = dateTime();
		my $today = $now->{'date'} . ' at ' . $now->{'time'};
		$writer->startTag( 'playlist', name => $playlistName[0], date => $today );
	
		my %title;
	
		foreach my $songNode ( $dom->findnodes( '//song' ) ) {
			#renumber node textual content
			++$nodeCnt;
	
			#get @number value and compare to counter, then write XML 'song' start tag
			my $numberVal = $songNode->findvalue( './@number' );
			if ( $numberVal !~ m#^$nodeCnt$# ) {
				#change @number to new $nodeCnt
				toLog( $subName, "\tNode content changed from: $numberVal to $nodeCnt\n" );
				#write out XML 'song' element
				$writer->startTag( 'song', number => $nodeCnt );
			} else {
				#write out XML 'song' element
				$writer->startTag( 'song', number => $numberVal );
			}
	
			#search empty elements and add empty node to avoid collapsed tag output
			foreach my $subNode ( $songNode->findnodes( '*' ) ) {
				my $nodeName = $subNode->nodeName;

				#determine if <title> has duplicate content with another node
				if ( $nodeName =~ m#^title$#i ) {
					my $titleContent = $subNode->textContent;
					foreach my $val ( values( %title ) ) {
						$titleContent =~ s#([\(\)\[\]\*\+])#\$1#g;
						if ( $val =~ m#^$titleContent$#i ) {
							toLog( $subName, "\tNOTE: The content '" . $titleContent . "' in <title> of <song> no. " . $nodeCnt . " is duplicated\n" );
						}
					}
					#store current <title> content in hash for checking against other nodes
					$title{$nodeCnt} = $titleContent;
				}

				#determine attributes for tag, **can only process 1 attribute=value per $subNode**
				if ( $subNode->hasAttributes() ) {
					#get list of attributes
					my @nodeAtts = $subNode->attributes();
					#format atts for start tag code
					my ( $listAtt, $listAttVal );
					if ( $nodeAtts[0] =~ m#\s*([^=\n]+)="([^"\n]+)"# ) {
						$listAtt = $1;
						$listAttVal = $2;
					}
					$writer->startTag( $nodeName, $listAtt => $listAttVal );
				} else {
					$writer->startTag( $nodeName );
				}
				#check each tag for empty content
				if ( ! $subNode->hasChildNodes() ) {
					$writer->characters( '' );
				} else {
					my $nodeContent = $subNode->textContent;
					$writer->characters( $nodeContent );
				}
				#write each end tag
				$writer->endTag( $nodeName );
			}
			#write out close 'song' XML tag
			$writer->endTag( 'song' );
		}
			#write out close 'playlist' XML tag
		$writer->endTag( 'playlist' );
		$writer->end() or badExit( $subName, 'Not able to end XML document' );
	
		#write out renumbered XML playlist file
		createFile( $xmlFile, $subName, $writer, 'XML playlist' );

		toLog( $subName, "\n...Finished Renumbering XML file: '" . $xmlFile . "'\n\n\n" );
		toLog( $subName, " *WARNING*: There were " . $warn{renumber} . " warning(s) for process...\n\n\n" ) if ( $warn{renumber} );
		toLog( undef, "  ...Finished Renumbering XML file: '" . $xmlFile . "'\n\n" );
		#echo status to console
		my ( $xmlName ) = fileparse( abspathL ( $xmlFile ) );
		binmode( STDOUT, ":encoding(UTF-8)" );
		print "   Finished Renumbering '" . $xmlName . "'\n";
	}

	#process end
	if ( $fileFQN ) {
		updStatus( "Finished Renumbering \"" . $fileName . "\"" );
	} else {
		my $folderNm;
		( $folderNm ) = fileparse( abspathL ( $dirPath ) );
		updStatus( "Finished Renumbering \"" . $folderNm . "\" folder" );
	}
	tkEnd( $subName );
}

#----------------------------------------------------------------------------------------------------------
# update GUI & update ID3 metadata in song files with XML input from XML playlist file, calls command-line 
#   utility for orignial extraction based on song file type
#  - $fileName must be populated globally (user file selection in GUI)
sub update_ID3_tags
#----------------------------------------------------------------------------------------------------------
{
	#determine subroutine
	my ( $package, $file, $line, $subName ) = caller( 0 );
	$subName =~ s#main::##;
	updStatus( undef, 'Update ID3 Tags...' );

	#must specify file or directory
	unless ( $fileFQN ) {
		my $ans = promptUser( 'warning', "No XML file selected or passed,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( $subName, "User chose to stop process,\n no XML file selected or passed" );
		}
		$M->{'select'}->focus();
		return;
	}

	#change buttons to indicate process started
	$M->{'update_ID3_tags'}->configure(
		-text							=> 'Updating...',
		-font							=> TK_FNT_B,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_FIELD,
		-activebackground => TK_COLOR_FIELD
	);
	$M->{'make_m3u'}->configure(
		-text							=> 'Make .m3u',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'make_XML_playlist'}->configure(
		-text							=> 'Make XML Playlist',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'renumber'}->configure(
		-text							=> 'Renumber',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'exit'}->focus();

	#starting log process
	toLog( undef, "  Updating ID3 Tags:\n    See '" . $dirPath . $subName . ".log' for details\n\n" );
	startLog( $subName );
	updStatus( "Updating ID3 tags in '" . $dirPath . "'" );
	
	#separate out playlist XML filename and directory
	my ( $playlistFilename, $playlistFilePath ) = fileparse( abspathL ( $fileFQN ) );
	$playlistFilename =~ s#\.\w\w\w?$##;
	#echo status to console
	toLog( $subName, "Updating ID3 Tags in XML playlist file: '" . $playlistFilename . ".xml'...\n" );
	binmode( STDOUT, ":encoding(UTF-8)" );
	print "\n   Updating ID3 Tags in: '" . $playlistFilename . ".xml'\n";
	
	#load playlist XML
	my $dom = loadXml( $fileFQN, $subName );

	#determine playlist name
	my $playlistName;
	if ( $dom->findnodes( '/playlist/@name' ) ) {
		$playlistName = $dom->findnodes( '/playlist/@name' );
	} else {
		$playlistName = $playlistFilename;
	}
	
	#set output object for playlist XML
	toLog( $subName, "   - Initializing XML playlist DOM\n" );
	my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
	badExit( $subName, 'Not able to create new XML::Writer object' ) if ( ! $writer );
	#write XML Declaration
	$writer->xmlDecl( 'UTF-8' ) or badExit( $subName, 'Not able to write out XML Declaration' );
	$writer->comment( '*IMPORTANT*: Only 1 attribute/value pair is allowed per each child node of <song>' );
	#write date into root <playlist> tag attribute, with playlist name as attribute
	toLog( $subName, "   - Setting date/time for playlist\n" );
	my $now = dateTime();
	my $today = $now->{'date'} . ' at ' . $now->{'time'};
	$writer->startTag( 'playlist', name => $playlistName, date => $today );
	
	#set overall counter for songs
	my $num = 0;
	#loop through each <song> node to determine best tool to use for song file
	foreach my $songNode ( $dom->findnodes( '//song' ) ) {
		++$num;

		updStatus( 'Processing song no. ' . $num );

		#set per song hash for tag metadata
		my ( %tags, $pathContent, $songFileName );
		
		#search empty elements and add empty node to avoid collapsed tag output
		foreach my $subNode ( $songNode->findnodes( '*' ) ) {
			my $nodeName = lc( $subNode->nodeName );
			#check each tag for empty content
			my $nodeContent = $subNode->textContent;
	
			#set each tag value from XML, as priority over other tool extraction
			if ( $nodeName =~ m#^path$# ) {
				#set $pathContent from <path>
				$pathContent = $nodeContent if ( $nodeContent );
				( $songFileName ) = fileparse( abspathL ( $pathContent ) );
				if ( testL ( 'e', $pathContent ) ) {
					toLog( $subName, '...Processing song no. ' . $num . ": '" . $pathContent . "'\n" );
					binmode( STDOUT, ":encoding(UTF-8)" );
					print '     - processing song no. ' . $num . ": '" . $songFileName . "'\n";
				} else {
					binmode( STDOUT, ":encoding(UTF-8)" );
					print '    Song no. ' . $num . " : '" . $songFileName . "' does not exist\n";
					warning( $subName, 'Song no. ' . $num . " : '" . $pathContent . "' does not exist" );
					tkEnd( $subName );
					return();
				}
			} elsif ( $nodeName =~ m#^track$# ) {
				$tags{$nodeName} = $nodeContent if ( $nodeContent );
				#pull @discnumber from node
				$tags{discnumber} = $subNode->findvalue( './@discnumber' ) if ( $subNode->exists( './@discnumber' ) );
			} elsif ( $nodeName =~ m#^length$# ) {
				$tags{$nodeName} = $nodeContent if ( $nodeContent );
				#pull @minutes from node
				$tags{minutes} = $subNode->findvalue( './@minutes' ) if ( $subNode->exists( './@minutes' ) );
			} else {
				$tags{$nodeName} = $nodeContent if ( $nodeContent );
			}
		}
	
		#read metadata from song
		exifTools( $num, \%tags, $pathContent );
	
		#check if crucial tags have been set, try to determine from filename & path
		if ( ( ! $tags{title} ) || ( ! $tags{artist} ) || ( ! $tags{track} ) || ( ! $tags{album} ) || ( ! $tags{length} ) || ( ! $tags{albumartist} ) || ( ! $tags{discnumber} ) ) {
			extractTags( $num, \%tags, $pathContent );
		}
	
		#call method to clean and sort metadata tags
		cleanTags( \%tags, $pathContent );
	
		#check crucial tags in @listOfXmlTags for values
		toLog( $subName, "   - Scanning tags to see if any desired tags are not defined\n" );
		foreach my $tagName ( @listOfXmlTags ) {
			if ( ! $tags{$tagName} ) {
				#remove empty hash elements, so they don't get removed by 'ffmpeg'
				toLog( $subName, "     - '" . $tagName . "' tag is not declared, removing key from hash\n" );
				delete $tags{$tagName};
			}
		}
		
		#write metadata tags to song file
		writeTags( $num, $writer, \%tags, $pathContent, $songNode );
	}
	
	#write out close playlist XML tag
	$writer->endTag( 'playlist' );
	$writer->end() or badExit( $subName, 'Not able to write end() XML instance to $writer object' );
	
	#write out new playlist XML
	createFile( $fileFQN, $subName, $writer, 'XML playlist' );

	toLog( $subName, "\n...Created Updated XML Playlist file: '" . $fileFQN . "'\n\n\n" );
	toLog( $subName, ' *WARNING*: There were ' . $warn{update_ID3_tags} . " warning(s) for process...\n\n\n" ) if ( $warn{update_ID3_tags} );
	toLog( undef, "  ...Finished Updating ID3 Tags in: '" . $dirPath . "'\n\n" );
	#echo status to console
	binmode( STDOUT, ":encoding(UTF-8)" );
	print "   Finished Updating ID3 Tags in '" . $fileName . "'\n";

	#process end
	updStatus( "Finished Updating ID3 Tags in '" . $fileName . "'" );
	tkEnd( $subName );
}

#----------------------------------------------------------------------------------------------------------
# extract metadata from song file for .mkv song file type, uses 'mkvextract' command-line utility for 
#   extraction
# **args:
#     1 - number of current song file
#     2 - tags hash reference
#     3 - song file to be run on
sub mkvTools
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $tagsRef, $songFile ) = @_;

	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;
	toLog( $subName, "   - Preparing for 'mkvextract' to export metadata tags from song file\n" );
	updStatus( "Running 'mkvextract' to export metadata" );

	my $songFileXml = $songFile . '.xml';
	my @mkvArgs = (
		#'mkvextract' command-line program
		'"' . $mkvCmd . '"',
		#get tag values from song file
		'"' . $songFile . '"',
		#extract tags
		'tags',
		#output to xml file
		'"' . $songFileXml . '"'
	);
	#start process to create batch file for calling 'mkvextract' for files/folders with Unicode characters
	my $mkvBat = $ENV{TEMP} . $FS . 'mkv-' . $num . '.bat';
	my $content = "\n" . 'chcp 65001' . "\n" . 'call ' . join( ' ', @mkvArgs );
	createFile( $mkvBat, $subName, $content, "'mkvextract' batch" );

	#execute batch file wrapper to call 'mkvextract' command batch file
	toLog( $subName, "   - Executing batch file for 'mkvextract'\n" );
	my ( $rawStdErr, $stdErr );
	run3( $mkvBat, \undef, \undef, \$rawStdErr );
	$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
	badExit( $subName, "Not able to run 'mkvextract', returned:\n" . $stdErr ) if ( $? || $stdErr );

	#load XML data
	my $dom = loadXml( $songFileXml, $subName );

	#store values from XML in tags hash
	foreach my $xmlNode ( $dom->findnodes( '//Simple' ) ) {
		my $tagName = $xmlNode->findvalue( './Name' );
		my $tagValue = $xmlNode->findvalue( './String' );
		my $lcTagName = lc( $tagName );
		foreach my $tagArrayRef ( @listOfTagArrays ) {
			if ( grep /^$lcTagName$/, @{$tagArrayRef} ) {
				$tagsRef->{$lcTagName} = $tagValue unless ( $tagsRef->{$lcTagName} );
			}
		}
	}
	#loop through array of arrays for possible tags to set tag's value, according to priority of array
	for my $tagsRow ( 0 .. $#listOfTagArrays ) {
		my $tagsRowRef = $listOfTagArrays[$tagsRow];
		#loop through inner array in reverse for each tag name, so priority is last (lowest array item) value set
		my $primaryTagName = $listOfTagArrays[$tagsRow][0];
		my $primaryTagValue;
		#save initial base value
		for my $tagsCol ( 0 .. $#{$listOfTagArrays[0]} ) {
			my $tagName = $listOfTagArrays[$tagsRow][$tagsCol];
			$primaryTagValue = $tagsRef->{$tagName} unless ( $primaryTagValue );
		}
		for ( my $tagsCol = $#{$tagsRowRef}; $tagsCol >= 0; $tagsCol-- ) {
			my $tagName = $listOfTagArrays[$tagsRow][$tagsCol];
			$tagsRef->{$primaryTagName} = $tagsRef->{$tagName} if ( $tagsRef->{$tagName} );
		}
		#reset base value to starting value, before setting all others
		$tagsRef->{$primaryTagName} = $primaryTagValue if ( $primaryTagValue );
		for my $tagsCol ( 0 .. $#{$tagsRowRef} ) {
			my $tagName = $listOfTagArrays[$tagsRow][$tagsCol];
			#only set when original had a value
			$tagsRef->{$tagName} = $tagsRef->{$primaryTagName} if ( exists $tagsRef->{$tagName} );
		}
	}

	deleteFile( $mkvBat, $subName, "'mkvextract'" );
	deleteFile( $songFileXml, $subName, 'XML data for song' );

	#determine 'title', if not specified previously
	if ( ! $tagsRef->{title} ) {
		#set ffprobe command for finding 'title' on song files that don't have the value
		toLog( $subName, "   - Preparing command for 'ffprobe' to determine 'title'\n" );
		my @ffprobeArgs = (
			'"' . $ffprobeCmd . '"',
			'-v error',
			'-show_entries format_tags=title',
			'-of default=noprint_wrappers=1:nokey=1',
			'"' . $songFile . '"'
		);
	
		#call 'ffprobe' to extract 'title' of song file
		my ( $rawTitle, $title );
		#start process to create batch file with 'ffprobe' command
		my $ffprobeBat = $ENV{TEMP} . $FS . 'ffprobe-title-' . $num . '.bat';
		my $content = "\n" . 'chcp 65001' . "\n" . 'call ' . join( ' ', @ffprobeArgs );
		createFile( $ffprobeBat, $subName, $content, "'ffprobe-title' batch" );
	
		toLog( $subName, "   - Executing 'ffprobe-title' batch file\n" );
		my ( $rawStdErr, $stdErr );
		run3( $ffprobeBat, \undef, \$rawTitle, \$rawStdErr );
		$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
		warning( $subName, "Not able to run 'ffprobe-title', returned:\n" . $stdErr ) if ( $? || $stdErr );
		$title = decode( $Config{enc_to_system} || 'UTF-8', $rawTitle );

		#'title' needs some format checks
		if ( $title =~ m#\n(.+)$# ) {
			$title = $1;
		}

		#assign to metadata tag
		$tagsRef->{title} = $title;

		#clean up temporary files
		deleteFile( $ffprobeBat, $subName, "'ffprobe-title' batch" );
	}

	#determine 'bitrate', if not specified previously
	if ( ! $tagsRef->{bitrate} ) {
		#set ffprobe command for finding 'bitrate' on song files that don't have the value
		toLog( $subName, "   - Preparing command for 'ffprobe' to determine 'bitrate'\n" );
		my @ffprobeArgs = (
			'"' . $ffprobeCmd . '"',
			'-v error',
			'-show_entries format=bit_rate',
			'-of default=noprint_wrappers=1:nokey=1',
			'"' . $songFile . '"'
		);
	
		#call 'ffprobe' to extract 'bitrate' of song file
		my $bitrate;
		#start process to create batch file with 'ffprobe' command
		my $ffprobeBat = $ENV{TEMP} . $FS . 'ffprobe-bitrate-' . $num . '.bat';
		my $content = "\n" . 'chcp 65001' . "\n" . 'call ' . join( ' ', @ffprobeArgs );
		createFile( $ffprobeBat, $subName, $content, "'ffprobe-bitrate' batch" );
	
		toLog( $subName, "   - Executing 'ffprobe-bitrate' batch file\n" );
		my ( $rawStdErr, $stdErr );
		run3( $ffprobeBat, \undef, \$bitrate, \$rawStdErr );
		$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
		warning( $subName, "Not able to run 'ffprobe-bitrate', returned:\n" . $stdErr ) if ( $? || $stdErr );

		#'bitrate' needs some format checks
		#match at least 6 digits (for 1,000's), but also capture any trailing digits but leaving the rest off)
		if ( $bitrate =~ m#\n(\d+)# ) {
			$bitrate = $1;
			if ( $bitrate =~ s#^(\d{5}\d*).*$#$1# ) {
				$bitrate = $bitrate / 1000;
				$bitrate = sprintf "%d", $bitrate;
			} else {
				#strip any extraneous characters from digits otherwise
				$bitrate =~ s#^(\d+).*$#$1#;
			}
		}

		#assign to metadata tag
		$tagsRef->{bitrate} = $bitrate;

		#clean up temporary files
		deleteFile( $ffprobeBat, $subName, "'ffprobe-bitrate' batch" );
	}
}

#----------------------------------------------------------------------------------------------------------
# generic extract metadata from song file, calls 'exifTool' command-line utility for extraction
# **args:
#     1 - number of current song file
#     2 - tags hash reference
#     3 - song file to be run on
sub exifTools
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $tagsRef, $songFile ) = @_;

	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;
	toLog( $subName, "   - Retrieving metadata from song file with 'ExifTool'\n" );
	updStatus( "Using 'exifTool' to read metadata" );

	#use ExifTool Perl modules
	my ( @exifTagList, $exifHashRef );
	#encode filename for use by ExifTool with Unicode characters
	my $encSongFile = encode( 'utf8', $songFile );
	my $exifTool = Image::ExifTool->new;
	$exifHashRef = $exifTool->ImageInfo( $encSongFile );
	foreach my $key ( keys %{$exifHashRef} ) {
		my $decodedVal = decode( $Config{enc_to_system} || 'UTF-8', ${$exifHashRef}{$key} );
		my $lcKey = lc( $key );
		foreach my $tagArrayRef ( @listOfTagArrays ) {
			if ( grep /^$lcKey$/, @{$tagArrayRef} ) {
				$tagsRef->{$lcKey} = $decodedVal unless ( $tagsRef->{$lcKey} );
			}
		}
	}
	#loop through array of arrays for possible tags to set tag's value, according to priority of array
	for my $tagsRow ( 0 .. $#listOfTagArrays ) {
		my $tagsRowRef = $listOfTagArrays[$tagsRow];
		#loop through inner array in reverse for each tag name, so priority is last (lowest array item) value set
		my $primaryTagName = $listOfTagArrays[$tagsRow][0];
		my $primaryTagValue;
		#save initial base value, or higher if lower not available
		for my $tagsCol ( 0 .. $#{$listOfTagArrays[0]} ) {
			my $tagName = $listOfTagArrays[$tagsRow][$tagsCol];
			$primaryTagValue = $tagsRef->{$tagName} unless ( $primaryTagValue );
		}
		for ( my $tagsCol = $#{$tagsRowRef}; $tagsCol >= 0; $tagsCol-- ) {
			my $tagName = $listOfTagArrays[$tagsRow][$tagsCol];
			$tagsRef->{$primaryTagName} = $tagsRef->{$tagName} if ( $tagsRef->{$tagName} );
		}
		#reset base value to starting value, before setting all others
		$tagsRef->{$primaryTagName} = $primaryTagValue if ( $primaryTagValue );
		for my $tagsCol ( 0 .. $#{$tagsRowRef} ) {
			my $tagName = $listOfTagArrays[$tagsRow][$tagsCol];
			#only set when original is instantiated
			$tagsRef->{$tagName} = $tagsRef->{$primaryTagName} if ( exists $tagsRef->{$tagName} );
		}
	}
}

#----------------------------------------------------------------------------------------------------------
# check each tag in hash - to set/clean-up values and/or modify/delete values
# **args:
#     1 - tags hash reference
#     2 - song file to be run on
sub cleanTags
#----------------------------------------------------------------------------------------------------------
{
	my ( $tagsRef, $songFile ) = @_;

	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;
	toLog( $subName, "   - Examining each tag retrieved\n" );
	updStatus( 'Cleaning up metadata tags' );

	#loop through array of arrays for possible tags to clean/set tag's value
	for my $tagsRow ( 0 .. $#listOfTagArrays ) {
		my $innerArrayRef = $listOfTagArrays[$tagsRow];
		#loop through inner array in reverse for each tag name, so priority is last (lowest array item) value set
		my $priorityTagName = $listOfTagArrays[$tagsRow][0];
		#save initial base value
		my $priorityTagValue = $tagsRef->{$priorityTagName};
		for ( my $tagsCol = $#{$innerArrayRef}; $tagsCol >= 0; $tagsCol-- ) {
			my $tagName = $listOfTagArrays[$tagsRow][$tagsCol];
			$tagsRef->{$priorityTagName} = $tagsRef->{$tagName} if ( $tagsRef->{$tagName} );
		}
		#reset base value to starting value, before setting all others
		$tagsRef->{$priorityTagName} = $priorityTagValue if ( $priorityTagValue );
		for my $tagsCol ( 0 .. $#{$innerArrayRef} ) {
			my $tagName = $listOfTagArrays[$tagsRow][$tagsCol];
			#only set when original is instantiated
			$tagsRef->{$tagName} = $tagsRef->{$priorityTagName} if ( exists $tagsRef->{$tagName} );
		}
	}

	foreach my $key ( keys %{$tagsRef} ) {
		#use Unicode curved double quote in $tagsRef value
		$tagsRef->{$key} =~ s#"#\N{U+201D}#g;

		#clean 'artist'
		if ( $key =~ m#^artist$# ) {
			#correct 'AC/DC'
			$tagsRef->{$key} =~ s#^AC[_ ]DC$#AC\/DC#i;
			#set 'albumartist' if not specified
			if ( ! $tagsRef->{albumartist} ) {
				$tagsRef->{albumartist} = $tagsRef->{$key};
			}
			#set 'artistsortorder' if not specified
			if ( ! $tagsRef->{artistsortorder} ) {
				$tagsRef->{artistsortorder} = $tagsRef->{$key};
				#remove extra artist info
				$tagsRef->{artistsortorder} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
				#strip starting articles
				$tagsRef->{artistsortorder} =~ s#^(the|a|an)\s+(.+)#$2#i;
			}
			#set 'band' if not specified, when it exists already
			if ( ( exists $tagsRef->{band} ) && ( ! $tagsRef->{band} ) ) {
				$tagsRef->{band} = $tagsRef->{$key};
			}
			#set 'ensemble' if not specified, when it exists already
			if ( ( exists $tagsRef->{ensemble} ) && ( ! $tagsRef->{ensemble} ) ) {
				$tagsRef->{ensemble} = $tagsRef->{$key};
			}
			#rename certain tags to .m4a or .mkv specific tags
			if ( $songFile =~ m#\.m4a$#i ) {
				$tagsRef->{author} = $tagsRef->{$key} unless ( $tagsRef->{author} );
				$tagsRef->{album_artist} = $tagsRef->{albumartist} unless ( $tagsRef->{album_artist} );
			} elsif ( $songFile =~ m#\.mkv$#i ) {
				$tagsRef->{album_artist} = $tagsRef->{albumartist} unless ( $tagsRef->{album_artist} );
				$tagsRef->{artists} = $tagsRef->{$key} unless ( $tagsRef->{artists} );
			}
		} elsif ( $key =~ m#^title$# ) {
			#set 'titlesortorder' if not specified
			if ( ! $tagsRef->{titlesortorder} ) {
				$tagsRef->{titlesortorder} = $tagsRef->{$key};
				#strip starting articles
				$tagsRef->{titlesortorder} =~ s#^(the|a|an)\s+(.+)#$2#i;
			}
		} elsif ( $key =~ m#^albumartist$# ) {
			#correct 'AC/DC'
			$tagsRef->{$key} =~ s#^AC[_ ]DC$#AC\/DC#i;
			#remove extra artist info
			$tagsRef->{$key} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
			#set 'albumartistsortorder' if not specified
			if ( ! $tagsRef->{albumartistsortorder} ) {
				$tagsRef->{albumartistsortorder} = $tagsRef->{$key};
				#strip starting articles
				$tagsRef->{albumartistsortorder} =~ s#^(the|a|an)\s+(.+)#$2#i;
			}
		} elsif ( $key =~ m#^album$# ) {
			#set 'albumsortorder' if not specified
			if ( ! $tagsRef->{albumsortorder} ) {
				$tagsRef->{albumsortorder} = $tagsRef->{$key};
				#strip starting articles
				$tagsRef->{albumsortorder} =~ s#^(the|a|an)\s+(.+)#$2#i;
			}
		} elsif ( $key =~ m#^track$#i ) {
			#remove total number
			if ( $tagsRef->{$key} =~ m#(\d+)\/\d+# ) {
				$tagsRef->{$key} = $1;
			}
			if ( $songFile =~ m#\.(ogg|flac)$#i ) {
				$tagsRef->{tracknumber} = $tagsRef->{$key} unless ( $tagsRef->{tracknumber} );
			} elsif ( $songFile =~ m#\.mkv$#i ) {
				$tagsRef->{part_number} = $tagsRef->{$key} unless ( $tagsRef->{part_number} );
			}
		} elsif ( ( $key =~ m#^part$#i ) && ( $songFile =~ m#\.m4a$# ) ) {
			#remove total number
			if ( $tagsRef->{$key} =~ m#(\d+)\/\d+# ) {
				$tagsRef->{$key} = $1;
			}
		} elsif ( ( $key =~ m#^disk$#i ) && ( $songFile =~ m#\.m4a$# ) ) {
			if ( ! $tagsRef->{discnumber} ) {
				$tagsRef->{discnumber} = $tagsRef->{$key};
			}
		} elsif ( ( $key =~ m#^createdate$#i ) && ( $songFile =~ m#\.m4a$# ) ) {
			#remove if set to 0's
			if ( $tagsRef->{$key} =~ m#^0000:# ) {
				delete $tagsRef->{$key};
			} elsif ( $tagsRef->{$key} =~ m#^0000$# ) {
				#if copied from year, then reset for writing metadata in writeTags()
				$tagsRef->{$key} .= ':01:01 00:00:00';
			}
		} elsif ( $key =~ m#^year$#i ) {
			#remove extraneous from 'year' value
			$tagsRef->{$key} =~ s#^(\d\d\d\d).*$#$1#;
			#remove tag if year is '0000'
			delete $tagsRef->{$key} if ( $tagsRef->{$key} =~ m#^0000$# );
			#remove 'createdate' tag for .m4a song files, if set to 0's
			if ( $tagsRef->{$key} =~ m#^$# ) {
				if ( ( $tagsRef->{date} ) && ( $tagsRef->{date} !~ m#^$# ) ) {
					#remove extraneous
					$tagsRef->{date} =~ s#^(\d\d\d\d).*$#$1#;
					$tagsRef->{$key} = $tagsRef->{date};
				}
			}
		} elsif ( $key =~ m#^bitrate$#i ) {
			#match at least 5 digits (for 10,000's), but also capture any trailing digits & leaving rest off)
			if ( $tagsRef->{$key} =~ s#^(\d{5}\d*).*$#$1# ) {
				$tagsRef->{$key} = $tagsRef->{$key} / 1000;
				$tagsRef->{$key} = sprintf "%d", $tagsRef->{$key};
			} elsif ( $tagsRef->{$key} =~ m#^([\d\.]+)\s+Mbps$#i ) {
				#bitrate in Mbps
				$tagsRef->{$key} = $1;
				$tagsRef->{$key} = $tagsRef->{$key} * 1000;
				$tagsRef->{$key} = sprintf "%d", $tagsRef->{$key};
			} else {
				#strip any extraneous characters from digits otherwise
				$tagsRef->{$key} =~ s#^([\d\.]+).*$#$1#;
				$tagsRef->{$key} = sprintf "%d", $tagsRef->{$key};
			}
		} elsif ( ( $key =~ m#^avgbitrate$#i ) && ( $songFile =~ m#\.m4a$# ) ) {
			if ( $tagsRef->{$key} =~ m#^([\d\.]+)\s+Mbps$#i ) {
				#bitrate in Mbps
				$tagsRef->{$key} = $1;
				$tagsRef->{$key} = $tagsRef->{$key} * 1000;
				$tagsRef->{$key} = sprintf "%d", $tagsRef->{$key};
			} else {
				#strip any extraneous characters from digits otherwise
				$tagsRef->{$key} =~ s#^([\d\.]+).*$#$1#;
				$tagsRef->{$key} = sprintf "%d", $tagsRef->{$key};
			}
		} elsif ( $key =~ m#^comment$#i ) {
			#if 'comment' has previously used diagnostic text, remove it
			if ( ( $tagsRef->{$key} =~ m#created from filename#i ) || ( $tagsRef->{$key} =~ m#updated with default#i ) || ( $tagsRef->{$key} =~ m#^vendor$#i ) ) {
				$tagsRef->{$key} = '';
			} elsif ( ( $tagsRef->{$key} =~ m#^\s*0000# ) || ( $tagsRef->{$key} =~ m#^\s+$#i ) ) {
				#long range of numbers or space
				$tagsRef->{$key} = '';
			}
		} elsif ( $key =~ m#^genre$#i ) {
			#if 'genre' has previously used diagnostic text, remove it
			if ( ( $tagsRef->{$key} =~ m#^music$#i ) || ( $tagsRef->{$key} =~ m#^none$#i ) || ( $tagsRef->{$key} =~ m#^other$#i ) ) {
				$tagsRef->{$key} = '';
			}
		} elsif ( $key =~ m#^length$#i ) {
			if ( ( ! $tagsRef->{$key} ) && ( $tagsRef->{duration} ) ) {
				$tagsRef->{$key} = $tagsRef->{duration};
			}
			if ( $tagsRef->{$key} ) {
				unless ( $tagsRef->{$key} =~ m#^\d+$# ) {
					if ( $tagsRef->{duration} ) {
						$tagsRef->{$key} = $tagsRef->{duration};
						#remove 'duration'
						delete $tagsRef->{duration};
					}
				}
				#if 'length' set to approximate value, clean up
				if ( $tagsRef->{$key} =~ m#\(approx\)#i ) {
						$tagsRef->{$key} =~ s#^(.+)\s*\(approx\)\s*$#$1#i;
				} elsif ( $tagsRef->{$key} =~ m#^0\.# ) {
					delete $tagsRef->{$key};
				}
				#length value can be given in HH:MM:SS format
				my ( $minutes, $seconds );
				if ( $tagsRef->{$key} =~ m#^(\d+:\d+:\d+\.?\d*)# ) {
					$seconds = convertLength( $1 );
					$tagsRef->{$key} = sprintf "%d", $seconds;
				} elsif ( $tagsRef->{$key} =~ m#^(\d?\d{5})\.?\d*# ) {
					#possible length in milliseconds
					$tagsRef->{$key} = sprintf "%d", $1 / 1000;
				} else {
					$seconds = $tagsRef->{$key};
				}
				#set value for 'minutes' in MM:SS
				$minutes = $seconds / 60;
				$minutes = sprintf "%d", $minutes;
				my $remSecs = $seconds - ( $minutes * 60 );
				$remSecs = sprintf "%.02d", $remSecs;
				#use new calc for 'minutes'
				delete $tagsRef->{minutes};
				$tagsRef->{minutes} = $minutes . ':' . $remSecs;
			} else {
				#length is empty
				warning( $subName, "'length' tag has no value" );
			}
		} else {
			my $lc = lc( $key );
			if ( $lc !~ m#^$key$# ) {
				$tagsRef->{$lc} = $tagsRef->{$key};
				delete $tagsRef->{$key};
			}
		}
		#remove 'date' & 'disk'
		$tagsRef->{date} = '';
		$tagsRef->{disk} = '';
	}
}

#----------------------------------------------------------------------------------------------------------
# extract metadata from song file path, when song file does not have complete metadata (calls 'ffprobe' 
#   command-line utility when 'length' is not present)
# **args:
#     1 - number of current song file
#     2 - tags hash reference
#     3 - song file to be run on
sub extractTags
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $tagsRef, $songFile ) = @_;

	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;
	toLog( $subName, "   - <title> or <artist> (and/or other) tags have not been set, attempting to set from filename & path\n" );

	my ( $songFileName, $songFileDir ) = fileparse( abspathL ( $songFile ) );
	updStatus( "Determining tags in: '" . $songFileName . "'" );

	#determine values from path of song file, using expected 'Music' directory
	if ( $songFileDir =~ m#\\Music\\([^\\]+)\\([^\\]+)\\$#i ) {
		#song file is inside 'Album'\'Artist'\song file format
		my $artist = $1;
		my $album = $2;
		#add escape '\' to square brackets for match expression
		my $albumMatch = $album;
		$albumMatch =~ s#([\(\)\[\]\*\+])#\$1#g;
		$tagsRef->{artist} = $artist if ( ! $tagsRef->{artist} );
		#determine if directory is actually a compilation with 'Disc' folders
		if ( ( $artist =~ m#^$albumMatch$#i ) || ( $album =~ m#^dis[ck]\s*\d+$#i ) ) {
			$tagsRef->{album} = $artist if ( ! $tagsRef->{album} );
		} else {
			$tagsRef->{album} = $album if ( ! $tagsRef->{album} );
		}
		#correct 'AC/DC'
		$tagsRef->{artist} =~ s#^AC[_ ]DC$#AC\/DC#i;
		if ( ! $tagsRef->{albumartist} ) {
			$tagsRef->{albumartist} = $tagsRef->{artist};
			#remove extra artist info
			$tagsRef->{albumartist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
		}
	} elsif ( $songFileDir =~ m#\\Music\\([^\\]+)\\$#i ) {
		#song file is inside 'Album\song file' format
		$tagsRef->{artist} = $1 if ( ! $tagsRef->{artist} );
		$tagsRef->{album} = $1 if ( ! $tagsRef->{album} );
		$tagsRef->{albumartist} = $1 if ( ! $tagsRef->{albumartist} );
		#correct 'AC/DC'
		$tagsRef->{artist} =~ s#^AC[_ ]DC$#AC\/DC#i;
		#remove extra artist info
		$tagsRef->{albumartist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
		#correct 'AC/DC'
		$tagsRef->{albumartist} =~ s#^AC[_ ]DC$#AC\/DC#i;
	}

	if ( $songFileName =~ m#((\d)-)?(\d*)\s*-?\s*(.+)\.(aac|alac|flac|m4a|mka|mkv|mp3|ogg|wma)$#i ) {
		$tagsRef->{title} = $4 if ( ! $tagsRef->{title} );
		$tagsRef->{track} = $3 if ( ! $tagsRef->{track} );
		$tagsRef->{discnumber} = $2 if ( ( $2 ) && ( ! $tagsRef->{discnumber} ) );
	}

	if ( ( ! $tagsRef->{length} ) && ( ! $tagsRef->{duration} ) ) {
		#set ffprobe command for finding 'length' on song files that don't have the value
		toLog( $subName, "   - Preparing command for 'ffprobe' to determine 'length'\n" );
		my @ffprobeArgs = (
			'"' . $ffprobeCmd . '"',
			'-v error',
			'-show_entries format=duration',
			'-of default=noprint_wrappers=1:nokey=1',
			'"' . $songFile . '"'
		);
	
		#call 'ffprobe' to extract length of song file
		my $length;
		#start process to create batch file with 'ffprobe' command
		my $ffprobeBat = $ENV{TEMP} . $FS . 'ffprobe-length-' . $num . '.bat';
		my $content = "\n" . 'chcp 65001' . "\n" . 'call ' . join( ' ', @ffprobeArgs );
		createFile( $ffprobeBat, $subName, $content, "'ffprobe-length' batch" );
	
		toLog( $subName, "   - Executing 'ffprobe-length' batch file\n" );
		my ( $rawStdErr, $stdErr );
		run3( $ffprobeBat, \undef, \$length, \$rawStdErr );
		$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
		warning( $subName, "Not able to run 'ffprobe-length', returned:\n" . $stdErr ) if ( $? || $stdErr );
		if ( $length =~ m#\n(\d+)# ) {
			$length = $1;
			my $minutes = $length / 60;
			$minutes = sprintf "%d", $minutes;
			my $remSecs = $length - ( $minutes * 60 );
			$remSecs = sprintf "%.02d", $remSecs;
			$tagsRef->{minutes} = $minutes . ':' . $remSecs;
			$tagsRef->{length} = sprintf "%d", $length;
		}
	
		#clean up temporary files
		deleteFile( $ffprobeBat, $subName, "'ffprobe-length' batch" );

		if ( ( ! $tagsRef->{title} ) || ( ! $tagsRef->{artist} ) || ( ! $tagsRef->{track} ) || ( ! $tagsRef->{album} ) || ( ! $tagsRef->{length} ) ) {
			warning( $subName, 'Could not determine <title>, <artist>, and/or possibly other necessary tags' );
		}
	}

	#set 'discnumber' to default value, if not present
	if ( ! $tagsRef->{discnumber} ) {
		$tagsRef->{discnumber} = 1;
	}
}

#----------------------------------------------------------------------------------------------------------
# write metadata to song file & builds song file node for writing to XML playlist, calls 'ffmpeg' command-
#   line utility
# **args:
#     1 - number of current song file
#     2 - $writer object used to write out XML nodes to XML playlist
#     3 - tags hash reference
#     4 - song file to be run on
#     5 - $songNode object for current song node
sub writeTags
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $writer, $tagsRef, $songFile, $songNode ) = @_;

	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;
	toLog( $subName, "   - Writing XML nodes to XML playlist dom\n" );
	updStatus( 'Writing updated tag metadata to XML playlist dom' );

	#write out tags to XML
	my $numberVal = $songNode->findvalue( './@number' );
	#write out XML 'song' element
	$writer->startTag( 'song', number => $numberVal );

	#mirror 'subnodes', but in particular order
	toLog( $subName, "   - Reordering XML nodes\n" );
	my $newSongNode = $songNode->cloneNode( 1 );
	$newSongNode->removeChildNodes();
	#add children nodes back in specified order
	foreach my $nodeName ( @listOfXmlTags ) {
		if ( ! $songNode->exists( $nodeName ) ) {
			warning( $subName, "'" . $nodeName . "' does not exist in XML instanace" );
		} else {
			#determine if multiple nodes with same name - warn & don't add to $newSongNode
			my $nodeCnt = 0;
			foreach ( $songNode->findnodes( $nodeName ) ) {
				++$nodeCnt;
			}
			if ( $nodeCnt > 1 ) {
				warning( $subName, "Song node has duplicate tags in song no. " . $numberVal . ": '" . $nodeName . "'" );
			} else {
				$newSongNode->addChild( $songNode->findnodes( $nodeName ) );
			}
		}
	}
	#add in <path>
	$newSongNode->addChild( $songNode->findnodes( 'path' ) );
	#search empty elements and add empty node to avoid collapsed tag output
	foreach my $subNode ( $newSongNode->findnodes( '*' ) ) {
		my $nodeName = lc( $subNode->nodeName );
		#determine attributes for tag, **can only process 1 attribute=value per $subNode**
		if ( $subNode->hasAttributes() ) {
			#get list of attributes
			my @nodeAtts = $subNode->attributes();
			#format atts for start tag code
			my ( $listAtt, $listAttVal );
			if ( $nodeAtts[0] =~ m#\s*([^=\n]+)="([^"\n]+)"# ) {
				$listAtt = $1;
				$listAttVal = $2;
			}
			$writer->startTag( $nodeName, $listAtt => $listAttVal );
		} else {
			$writer->startTag( $nodeName );
		}
		#check each tag for empty content
		my $nodeContent = $tagsRef->{$nodeName};
		if ( $nodeName =~ m#^path$# ) {
			$writer->characters( $subNode->textContent );
		} elsif ( ! $nodeContent ) {
			$writer->characters( '' );
		} else {
			$writer->characters( $nodeContent );
		}
		#write each end tag
		$writer->endTag( $nodeName );
	}
	#write out close 'song' XML tag
	$writer->endTag( 'song' );

	#prepare file for ffmpeg to write metadata (can't write out to self) - copy original to temp file
	toLog( $subName, "   - Creating temporary song file for 'ffmpeg' to use as original song file\n" );
	my ( $songFileName, $songFileDir ) = fileparse( abspathL ( $songFile ) );
	my $tmpSongFileName = $songFileName;
	if ( $tmpSongFileName =~ s#(.)\.(\w\w\w\w?)$#$1_tmp\.$2#i ) {
		#verifying file is not left open by other process
		renameL ( $songFileDir . $songFileName, $songFileDir . $tmpSongFileName ) or badExit( $subName, "Not able to rename song file: '" . $songFileDir . $songFileName . "' to temp file: '" . $songFileDir . $tmpSongFileName . "'" );
	}

	#create array of metadata tag args to add in ffmpeg (will splice into command args array)
	toLog( $subName, "   - Creating 'ffmpeg' arguments for submission of metadata to song file\n" );
	my @newMeta;
	foreach my $key ( keys %{$tagsRef} ) {
		#create variable for metadata key (keys with spaces can cause to fail content test)
		my $metaKey;
		#use Unicode curved double quote in key
		$key =~ s#"#\N{U+201D}#g;
		$metaKey = $key;
		#use 'part' & 'sort_with' when .mkv song file type
		if ( $songFileName =~ m#\.mkv$#i ) {
			if ( ( $key =~ m#^track$#i ) && ( $tagsRef->{part} ) ) {
				$tagsRef->{$key} = $tagsRef->{part};
			} elsif ( ( $key =~ m#^titlesortorder$#i ) && ( $tagsRef->{sort_with} ) ) {
				$tagsRef->{$key} = $tagsRef->{sort_with};
			} elsif ( ( $key =~ m#^titlesort$#i ) && ( $tagsRef->{sort_with} ) ) {
				#only set if preferred value not set
				if ( ! $tagsRef->{titlesortorder} ) {
					$tagsRef->{$key} = $tagsRef->{sort_with};
				}
			}
		}
		#set 'disk', 'album_artist', & 'createdate' when .m4a song file type
		if ( $songFileName =~ m#\.m4a$#i ) {
			#key for 'year' may also be: '©day'
			if ( ( $key =~ m#^discnumber$#i ) && ( ! $tagsRef->{$key} ) && ( $tagsRef->{disk} ) ) {
				$tagsRef->{$key} = $tagsRef->{disk};
			} elsif ( ( $key =~ m#^albumartist$#i ) && ( ! $tagsRef->{$key} ) && ( $tagsRef->{album_artist} ) ) {
				$tagsRef->{$key} = $tagsRef->{album_artist};
			} elsif ( ( $key =~ m#^createdate$#i ) && ( $tagsRef->{$key} =~ m#^\d\d\d\d$# ) ) {
				#set year value with special format required
				$tagsRef->{$key} .= ':01:01 00:00:00';
			}
		}
		#replace any values that contain newlines
		$tagsRef->{$key} =~ s#\r?\n#,#g;
		if ( ! $tagsRef->{$key} ) {
			#fix any keys that have whitespace in the name
			if ( $key =~ m#\s# ) {
				$metaKey = "\"$key\"";
			}
			push( @newMeta, "-metadata $metaKey=\"\"" );
		} else {
			#fix any keys that have whitespace in the name
			if ( $key =~ m#\s# ) {
				$metaKey = "\"$key\"";
			}
			push( @newMeta, "-metadata $metaKey=\"" . $tagsRef->{$key} . "\"" );
		}
	}

	toLog( $subName, "   - Building 'ffmpeg' command statement\n" );
	my @ffmpegArgs = ( 
		#ffmpeg executable
		'"' . $ffmpegCmd . '"',
		#input file is temporary song file
		'-i "' . $songFileDir . $tmpSongFileName . '"',
		#wipe existing metadata - fix some files not accepting changes if not cleared first
		'-map_metadata -1',
		#copy audio, no need for encoding/decoding
		'-c:a copy',
		#force ID3v2.3 tag version
		'-id3v2_version 3',
		#don't return numerous lines of output from 'ffmpeg'
		'-v error',
		#copy timestamp - copy song file, don't encode
		'-copyts',
		#for timestamp copy - start timestamp at 0
		'-start_at_zero',
		#hide extra info from ffmpeg
		'-hide_banner',
		#overwrite existing
		'-y',
		#no video
		'-vn',
		#output song file
		'"' . $songFileDir . $songFileName . '"'
	);
	#splice in array of '-metadata' switches into @ffmpeg args
	splice( @ffmpegArgs, 11, 0, @newMeta );
	toLog( $subName, "   - System command to rewrite song metadata with 'ffmpeg': '" . join( ' ', @ffmpegArgs ) . "'\n" );

	#start process to create batch file with 'ffmpeg' commands
	my $ffmpegBat = $ENV{TEMP} . $FS . 'ffmpeg-' . $num . '.bat';
	my $content = "\n" . 'chcp 65001' . "\n" . 'call ' . join( ' ', @ffmpegArgs );
	createFile( $ffmpegBat, $subName, $content, "'ffmpeg' batch" );

	#execute batch file wrapper to call 'ffmpeg' commands batch file
	toLog( $subName, "   - Executing batch file for 'ffmpeg'\n" );
	my ( $rawStdErr, $stdErr );
	run3( $ffmpegBat, \undef, \undef, \$rawStdErr );
	$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
	#clean error header from 'ffmpeg'
	$stdErr =~ s#^ffmpeg version.+libswresample[\d\.\s\/]+$##is;
	if ( $? || $stdErr || ( ! testL ( 's', $songFileDir . $songFileName ) ) ) {
		badExit( $subName, "Not able to run 'ffmpeg' for song: '" . $songFileName . "', returned:\n" . $stdErr );
	}
	#removing temp song file & 'ffmpeg' batch file
	deleteFile( $songFileDir . $tmpSongFileName, $subName, 'song' );
	deleteFile( $ffmpegBat, $subName, "'ffmpeg' batch" );
}

#----------------------------------------------------------------------------------------------------------
# output & log warning process
# **args:
#     1 - function name of calling subroutine (opt) [use 'undef' if global]
#     2 - warning message
sub warning
#----------------------------------------------------------------------------------------------------------
{
	my ( $funcName, $msg ) = @_;

	#store any returned system error info
	my $rawSysWarn = $!;
	my $rawEvalWarn = $@;
	my $rawOS_Warn = $^E;
	#decode raw warning to use Unicode
	my $sysWarn = decode( $Config{enc_to_system} || 'UTF-8', $rawSysWarn );
	my $evalWarn = decode( $Config{enc_to_system} || 'UTF-8', $rawEvalWarn );
	my $OS_Warn = decode( $Config{enc_to_system} || 'UTF-8', $rawOS_Warn );
	if ( $sysWarn ) {
	  $msg .= "\n\n *Warn with following Perl system error message: " . $sysWarn;
	}
	if ( $evalWarn ) {
	  $msg .= "\n\n *Warn with following Perl eval error message: " . $evalWarn;
	}
	if ( $OS_Warn ) {
	  $msg .= "\n\n *Warn with following Windows error message: " . $OS_Warn;
	}
	updStatus( undef, 'Warning...' );

	#set global warn hash with increasing warning count
	++$warn{global};
	if ( $funcName ) {
		#set warn hash for function with increasing warning count
		++$warn{$funcName};
		toLog( $funcName, "\n *WARNING* (" . $warn{$funcName} . "): " . $msg . ",\n" . shortmess() . "\n" );
	} else {
		toLog( undef, "\n *WARNING* (" . $warn{global} . "): " . $msg . ",\n" . shortmess() . "\n" );
	}

	promptUser( 'warning', $msg );
}

#----------------------------------------------------------------------------------------------------------
# output & log failed execution process
# **args:
#     1 - function name of calling subroutine (opt) [use 'undef' if global]
#     2 - error message
sub badExit
#----------------------------------------------------------------------------------------------------------
{
	my ( $funcName, $error ) = @_;

	#store any returned system error info
	my $rawSysError = $!;
	my $rawEvalError = $@;
	my $rawOS_Error = $^E;
	#decode raw error to use Unicode
	my $sysError = decode( $Config{enc_to_system} || 'UTF-8', $rawSysError );
	my $evalError = decode( $Config{enc_to_system} || 'UTF-8', $rawEvalError );
	my $OS_Error = decode( $Config{enc_to_system} || 'UTF-8', $rawOS_Error );
	if ( $sysError ) {
	  $error .= "\n\n *Failed with following Perl system error message: " . $sysError;
	}
	if ( $evalError ) {
	  $error .= "\n\n *Failed with following Perl eval error message: " . $evalError;
	}
	if ( $OS_Error ) {
	  $error .= "\n\n *Failed with following Windows error message: " . $OS_Error;
	}
	updStatus( undef, 'ERROR...' );

	if ( ( $funcName ) && ( fileno( $funcLogFH ) ) ) {
		toLog( $funcName, " **ERROR: $error\n" );
	} elsif ( fileno( $logFH ) ) {
		toLog( undef, " **ERROR: $error\n" );
	} else {
		print "\n\n*ERROR: Not able to write to log file: " . $log . "\n";
		print "Returned error(s):\n" . $error;
	}

	promptUser( 'error', $error );

	#close logs if open
	if ( ( $funcName ) && ( fileno( $funcLogFH ) ) ) {
		endLog( $funcName );
	} elsif ( fileno( $logFH ) ) {
		endLog();
	} else {
		print "\n\n*ERROR: Not able to end log file: " . $log;
	}

	#close window
	$M->{'window'}->destroy;

	#return exception code
	exit( 255 );
}

#----------------------------------------------------------------------------------------------------------
# function ends successfully - log closed and window refreshed for restart
# **args:
#     1 - function name of calling subroutine (opt) [use 'undef' if global]
sub tkEnd
#----------------------------------------------------------------------------------------------------------
{
	my ( $funcName ) = @_;

	#close log file
	endLog( $funcName );
	undef $log;
  $log = $dirPath . $progName . '.log';

	#focus on exit button and reset status
	$proc = 'Waiting on command...';
	$M->{'exit'}->focus();

	#reset buttons
	$M->{'update_ID3_tags'}->configure(
		-text							=> 'Update ID3 Tags',
		-font							=> TK_FNT_B,
		-state						=> 'normal',
		-bg								=> TK_COLOR_BG,
		-fg								=> TK_COLOR_FG,
		-activebackground => TK_COLOR_YELLOW
	);
	$M->{'renumber'}->configure(
		-text							=> 'Renumber',
		-font							=> TK_FNT_B,
		-state						=> 'normal',
		-bg								=> TK_COLOR_BG,
		-fg								=> TK_COLOR_FG,
		-activebackground => TK_COLOR_TURQ
	);
	$M->{'make_m3u'}->configure(
		-text							=> 'Make .m3u',
		-font							=> TK_FNT_B,
		-state						=> 'normal',
		-bg								=> TK_COLOR_BG,
		-fg								=> TK_COLOR_FG,
		-activebackground => TK_COLOR_LGREEN
	);
	$M->{'make_XML_playlist'}->configure(
		-text							=> 'Make XML Playlist',
		-font							=> TK_FNT_B,
		-state						=> 'normal',
		-bg								=> TK_COLOR_BG,
		-fg								=> TK_COLOR_FG,
		-activebackground => TK_COLOR_ABG
	);

	$M->{'window'}->update();
}

#----------------------------------------------------------------------------------------------------------
# GUI program exit & write out selections from GUI for next run use
sub tkExit
#----------------------------------------------------------------------------------------------------------
{
	#call to save current file/directory selection
	saveLastVal();

	#close log file
	endLog( undef );

	$M->{'window'}->destroy;
	exit( 0 );
}

#----------------------------------------------------------------------------------------------------------
# save current file/directory selection for next use
sub saveLastVal
#----------------------------------------------------------------------------------------------------------
{
	my ( $dirOS_Err, $dirSysErr, $lastFH );

	#create last value directory, if not exists
	my $lastValDir = $ENV{APPDATA} . $FS . $progName;
	if ( ! testL ( 'd', $lastValDir ) ) {
		mkdirL ( $lastValDir ) or warning( undef, "Not able to create 'lastValue.cfg' directory: '" . $lastValDir . "'" );
	}

	my $lastFile = $lastValDir . $FS . 'lastValue.cfg';
	openL ( \$lastFH, '>:encoding(UTF-8)', $lastFile ) or warning( undef, "Not able to open last value file: '" . $lastFile . "'" );
	my $lastValFH = select $lastFH; $| = 1; select $lastValFH;
	if ( $fileFQN && $dirPath ) {
		print $lastFH $fileFQN . "\n" . $dirPath;
	} elsif ( $fileFQN ) {
		print $lastFH $fileFQN;
	} elsif ( $dirPath ) {
		print $lastFH "\n" . $dirPath;
	}

	close( $lastFH );
}

#----------------------------------------------------------------------------------------------------------
# read previous run file/directory selection for current use
sub readLastVal
#----------------------------------------------------------------------------------------------------------
{
	my @lastVal;

	my $lastValDir = $ENV{APPDATA} . $FS . $progName;
	my $lastFile = $lastValDir . $FS . 'lastValue.cfg';
	#only read if value not passed
	if ( ( testL ( 's', $lastFile ) ) && ( ! $ARGV[0] ) ) {
		my $lastFH;
		openL ( \$lastFH, '<:encoding(UTF-8)', $lastFile ) or print "\n\n*WARNING: Not able to open last value config file: '" . $lastFile . "'\n\n";
		@lastVal = <$lastFH>;
		close( $lastFH );

		#clean up file content
		chomp( @lastVal );
		$fileFQN = $lastVal[0];
		$fileFQN =~ s#[\/\\]#$FS#g;
		$dirPath = $lastVal[1];
		$dirPath =~ s#[\/\\]#$FS#g;
		if ( $lastVal[0] ) {
			( $fileName, $dirPath ) = fileparse( abspathL ( $fileFQN ) );
			#value returned in 1st line of lastValue.cfg has zero-width character(s) at end of value - rebuild
			$fileFQN = $dirPath . $fileName;
		}
		if ( $dirPath !~ m#[\/\\]$# ) {
			$dirPath = $dirPath . $FS;
		}
	}
}

#----------------------------------------------------------------------------------------------------------
# start logging (if subroutine name passed log will be for subroutine, otherwise log will be global)
# **args:
#     1 - function name of calling subroutine (opt) [use 'undef' if global]
sub startLog
#----------------------------------------------------------------------------------------------------------
{
  my ( $funcName ) = @_;

	my $now = dateTime();
	my $timeSt = $now->{'date'} . ' at ' . $now->{'time'};

	if ( $funcName ) {
		if ( testL ( 'd', $dirPath ) ) {
	    $log = $dirPath . $funcName . '.log';
		} else {
	  	my $dir = getcwdL();
	    $log = $dir . $FS . $progName . '.log';
		}
		openL ( \$funcLogFH, '>:encoding(UTF-8)', $log ) or badExit( $funcName, "Not able to create log file: '" . $log . "'" );
		#redirect STDERR to log file
		open( STDERR, '>>:encoding(UTF-8)', $log ) or warning( undef, 'Not able to redirect STDERR' );
		my $oldfh = select $funcLogFH; $| = 1; select $oldfh;

		toLog( $funcName, "$Sep\nFunction: $funcName\n\tDate: $timeSt\n$Sep" );
	} else {
    if ( testL ( 'd', $dirPath ) ) {
	    $log = $dirPath . $progName . '.log';
	  } else {
	  	my $dir = getcwdL();
	    $log = $dir . $FS . $progName . '.log';
			#if directory not populated in GUI, note to console about current global log location
	    print "\n *NOTE: The global log file is saved in current directory as:\n  " . $log . "\n\n";
	  }
		openL ( \$logFH, '>:encoding(UTF-8)', $log );
		if ( ! fileno( $logFH ) ) {
			my $logSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $logOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			print "\n\n*ERROR: Not able to create log file: '" . $log . "', returned:\n" . $logSysErr . "\nand:\n" . $logOS_Err . "\n\n";
			exit( 255 );
		} else {
			my $oldfh = select $logFH; $| = 1; select $oldfh;
			#redirect STDERR to log file
			open( STDERR, '>>:encoding(UTF-8)', $log ) or warning( undef, 'Not able to redirect STDERR' );
		}

		toLog( undef, "$SEP\nTool: $progName\n\tVersion: $Version\n\n\tDate: $timeSt\n$Sep" );
		toLog( undef, "$progName Process Started\n$Sep\n" );
	}
}

#----------------------------------------------------------------------------------------------------------
# add to log (if subroutine name passed log will be for subroutine, otherwise log will be global)
# **args:
#     1 - function name of calling subroutine (opt) [use 'undef' if global]
#     2 - log message
sub toLog
#----------------------------------------------------------------------------------------------------------
{
	my ( $funcName, $msg ) = @_;
	my ( $package, $file, $line, $subname ) = caller( 1 );
	$subname =~ s#main::##;
	

	if ( $funcName ) {
		if ( fileno( $funcLogFH ) ) {
			print $funcLogFH $msg;
		} else {
			#log file is not open, write to error function
			unless ( $subname =~ m#badExit#i ) {
				badExit( $funcName, $msg );
			}
		}
	} elsif ( fileno( $logFH ) ) {
		#write to global log file
		print $logFH $msg;
	} else {
		#log file is not open, write to error window
		unless ( $subname =~ m#badExit#i ) {
			promptUser( 'error', $msg );
		}
	}
}

#----------------------------------------------------------------------------------------------------------
# end logging (if subroutine name passed log will be for subroutine, otherwise log will be global)
# **args:
#     1 - function name of calling subroutine (opt) [use 'undef' if global]
sub endLog
#----------------------------------------------------------------------------------------------------------
{
  my ( $funcName ) = @_;

	my $now = dateTime();
	my $timeSt = $now->{'date'} . ' at ' . $now->{'time'};

	if ( ( $funcName ) && ( fileno( $funcLogFH ) ) ) {
		#output any warning data
		if ( $warn{$funcName} ) {
			toLog( $funcName, "\n   **(" . $warn{$funcName} . ") Warnings were detected**\n\n" );
		}
		toLog( $funcName, "$funcName Process Completed\n\tDate: $timeSt\n$SEP\n\n" );
		close $funcLogFH;
	} elsif ( fileno( $logFH ) ) {
		#output any warning data
		if ( $warn{global} ) {
			toLog( undef, "\n   **(" . $warn{global} . ") Warnings were detected**\n\n" );
		}
    toLog( undef, "$SEP\nTool: $progName\n\tVersion: $Version\n\n\tDate: $timeSt\n$Sep" );
		toLog( undef, "$progName Process Completed\n$SEP\n\n" );
		close $logFH;
	}
}
