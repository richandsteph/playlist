#!/usr/bin/perl -w

#**********************************************************************************************************
#
#	File: make_XML_playlist.pl
#	Desc: creates a M3U XML playlist from songs crawled in root (starting) directory (*must be a top-level, 
#       'Music' folder with artist subfolders) setting MP3 ID3v2 tag to current values, removing any 
#       existing MP3 ID3v1 or ID3v2.4 tags & updating MP3 ID3v2.3 tag
#
#	Author: Richard Davis
#	  	rich@richandsteph.com
#
#**********************************************************************************************************
# version 1.0  -  26 Mar 2025	 RAD initial creation
#         1.1  -  28 Mar 2025  RAD added match pattern for single album folder (no artist), adjusted match 
#                                  pattern for song file title to include negative lookahead for 
#                                  "\Music" for artist that start with number
#         1.2  -  30 Mar 2025  RAD reworked MP3 tag logic for present/not present/remove existing 
#         1.3  -   2 Apr 2025  RAD added check for return status to 
#                                  functions or badExit(), corrected use of updating tags
#         1.4  -   3 Apr 2025  RAD changed MP3 tag hash to be initially set to 'undef' / added modules: 
#                                  Audio::FLAC::Header to properly read FLAC, 
#                                  Ogg::Vorbis::Header::PurePerl to properly read OGG, & 
#                                  system calls to 'ffmpeg' & 'ffprobe' to properly read M4A / removed 
#                                  default values setting tags
#         1.5  -   5 Apr 2025  RAD added write_tag() to follow remove_tag() - updates change to tag when 
#                                  removing / add removal of previously used comments 'created from 
#                                  filename and path' & 'updated with default values' & genre 'music' / 
#                                  force ID3v2.3 version for tags with ffmpeg / added 'albumartist'
#                                  value
#         1.6  -   7 Apr 2025  RAD Corrected logic of checking if song file is OGG, M4A, or FLAC / added 
#                                  more concise messaging for when song file is OGG, M4A, or FLAC / 
#                                  improved logic and warnings when using write_tag(), since no status 
#                                  value returned from call / changed usage of warn() to carp() in new 
#                                  method warning(), changed calls for further errors in badExit() to use 
#                                  toLog() after initial croak()
#         1.7  -  10 Apr 2025  RAD Changed logic to use exiftool & ffmpeg for ID3v2 tag reading/setting
#         1.8  -  15 Apr 2025  RAD Corrected handling of all program arguments and metadata handling to 
#                                  use Windows/Unicode encoding, for presence of non-ASCII characters / 
#                                  added better error handling for system calls to 'ffprobe', 'ffmpeg', & 
#                                  'exiftool' / added read of top-level music directory & use that value 
#                                  for processing album, artist, etc. when no metadata is present / 
#                                  corrected format/calc/logic for bitrate, year, comment, & other tags / 
#                                  prioritized 'tracknumber' over 'trackid' for 'track' (not present) 
#                                  when both are present
#         1.9  -  16 Apr 2025  RAD Added variable for path to 'musicDir' to include in path check for 
#                                  items that have no ID3 tags / changed check for no exitsing tags to 
#                                  check <track>, instead of <artist> - some have <artist> set with 
#                                  nothing else
#         1.10 -  19 Apr 2025  RAD Removed logic for 2nd run of 'ffprobe' if flag set - changed to 
#                                  always run 1st run, then test if $tags{title} and $tags{track} not set 
#                                  for run of 'exiftool' / changed logic for 'date' to be preferred year
#                                  value / added logic for compilation albums with 'Disc' folders to 
#                                  ignore those folders / corrected code for phone path replacement
#         1.11 -  30 Apr 2025  RAD Changed logic to use 'exiftool' for all extractions & writing tags
#         1.12 -  14 May 2025  RAD Added back in 'ffmpeg' to write metadata / corrected non-Unicode 
#                                  characters replacement / added use of batch file (& wrapper) to call 
#                                  'ffmpeg' commands for files that have Unicode characters in the name
#         1.13 -   1 Jun 2025  RAD &wanted not scouring folder names with Unicode characters - created 
#                                  getFileLst() to use readdirL() (opendirL() & closedirL()) instead / 
#                                  added 'ffprobe' & batch file to get duration when no tags are set
#         1.14 -   5 Jun 2025  RAD Changed to use batch file to run 'exiftool' and return JSON data / 
#                                  removed 2nd batch file wrapper for 'ffmpeg' - storing batch file in 
#                                  temp folder, don't need 2nd batch file wrapper / added parsing of JSON 
#                                  data to %tags / added 'mkvextract' (with batch file) for extraction of 
#                                  tag data from MKV song files
#         1.15 -   8 Jun 2025  RAD Added use of 'exiftools' args file to pass arguments (including 
#                                  filenames with Unicode) / corrected some 'Duration' errors / changed 
#                                  Windows 11 system locale to use 'utf8' - resolves any remaining Unicode 
#                                  filename issues
#         1.16 -   1 Jan 2026  RAD replaced 'export from plex...' folder with new 'phone_music' / changed
#                                  'Year' tag to 'Date' / added 'Path' to possible tags
#         1.17 -   2 Jan 2026  RAD corrected logic for some tags to be deleted / removed 'date' from
#                                  listOfID3Tags list / reorganized listOfAllTags tags / added logic for 
#                                  'AlbumArtistSort' & 'ArtistSort' tag cleanup / changed to use 'date' 
#                                  over 'year' / removed stripping of leading 0's in 'track' & added 
#                                  padding of 1 '0' to single digit 'track' numbers in XML output / added 
#                                  $program_test as directory in hierarchy that is allowed, while all 
#                                  other '$' folders are skipped / added stripping of leading '0' from 
#                                  'disc' / added replacement of drive letter with UNC path
#         1.18 -   5 Jan 2026  RAD **changed use of 'utf8' to 'UTF-8' for stricter Unicode Perl rules / 
#                                  changed JSON creation / added echo to console for each song / added 
#                                  binmode() for STDOUT (need to write unicode to console updates) / 
#                                  removed binmode()'s from header / changed location of ExifTool to 
#                                  Strawberry Perl version
#         1.19 -   6 Jan 2026  RAD added Carp module w/ longmess / added 'chcp 65001' command to batch 
#                                  files / added 'chcp 65001' to batch files for running Unicode filenames 
#                                  / added batch file to set console code page in command shell for output 
#                                  of progress status
#         1.20 -  10 Jan 2026  RAD added if statement to check $status before echoing finished to console /
#                                  added shortmess() to pragmas
#         1.21 -  14 Jan 2026  RAD changed escape of single quote to double quote in 'ffmpeg' data / moved 
#                                  delete tag statements inside if loops to outside of loop (was only 
#                                  deleting tag if correct tag didn't exist)
#          2.0 -  18 Jan 2026  RAD changed use of 'disc' attribute/tag to 'discnumber' / changed use of 
#                                  <date> to <year> / changed use of <duration> to <length> / removed 
#                                  check for 'phone_music' folder to set paths to phone folders / renamed 
#                                  lowerCase() to lowerHashCase()
#          2.1 -  18 Jan 2026  RAD reordered output of XML nodes to ordered list in 'update_ID3_tags.pl' / 
#                                  set all tag names to uniform lowercase / removed 'ensemble' tag / added 
#                                  updated -charset encoding arguments to 'exiftool' / edited clean up of 
#                                  tags
#          2.2 -  21 Jan 2026  RAD changed substitution of double quote from escaped quote to Unicode 
#                                  double quote (Windows doesn't allow double quote in command-line) / 
#                                  added if loop for extracting length via 'ffprobe' when neither 'length' 
#                                  or 'duration' set / added 'part_number' for 'track' metadata in .mkv 
#                                  song file / lowercased tag keys / removed 'ffmpeg' code to NOT update 
#                                  metadata to song file / removed unused @listOfID3Tags
#
#
#   TO-DO:
#         1) none
#
#**********************************************************************************************************

my $Version = "2.2";

use strict;
use warnings;
use utf8::all;
use feature 'unicode_strings';
use open ':std', IO => ':raw :encoding(UTF-8)';

use Carp qw( carp croak longmess shortmess );
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
my $fileName = fileparse( $0 );
$fileName =~ s#\.\w\w\w?$##;
my $logFile = "$fileName.log";
startLog( $logFile );

#set directories of song files from current and recursive directories
my @workDir = getcwdL() or badExit( "Not able to get working directory with 'getcwdL()'" );
$workDir[0] =~ s#[\\\/]#$FS#g;
#get top-level root folder name & path for processing non-tagged items below
my ( $musicDir, $musicDirPath ) = fileparse( abspathL( $workDir[0] ) );
#set path folder for use in regex - '\' to '\\''
$musicDirPath =~ s#\\#\\\\#g;
#set music directory folder with '$' for use in regex - '$' to '\\$'
$musicDir =~ s#^\$#\\\$#;
chdirL( $workDir[0] ) || badExit( "Not able to change into working directory '" . $workDir[0] . "'" );
my @fileLst;
toLog( "Scouring Music folders to build list of song files...\n" );
getFileLst( @workDir );

toLog( "----\n...Processing Song Files in: $workDir[0]\n\n" );

#parse out XML node data from songs to XML file
my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
badExit( "Not able to create new XML::Writer object" ) if ( ! $writer );
#write XML Declaration
$writer->xmlDecl( "UTF-8" ) or badExit( "Not able to write out XML Declaration" );
#determine playlist name
my $playlist_name;
if ( $workDir[0] =~ m#phone_music#i ) {
	$playlist_name = 'phone-favorites';
} else {
	$playlist_name = 'rich-all-songs';
}
#write date into <playlist> tag attribute
my $date = localtime( time() );
$writer->startTag( "playlist", name => $playlist_name, date => $date );

#start process to create batch file for calling 'chcp 65001' for files/folders with Unicode characters
my $statBat = $ENV{TEMP} . $FS . 'stat' . '.bat';
my $statBatFH;
#open/close batch file with commands written to it
toLog( " - Creating batch file wrapper set console code page: '" . $statBat . "'\n" );
openL( \$statBatFH, '>:encoding(UTF-8)', $statBat ) or badExit( "Not able to create temporary batch file to set console code page: $^E, $!" );
	my $statFH = select $statBatFH; $| = 1; select $statFH;
	print $statBatFH "\n" . '@echo off' . "\n" . 'echo   **Setting Console Code Page to 65001**' . "\n" . 'chcp 65001';
close( $statBatFH );

#execute batch file wrapper to set console code page
toLog( " - Executing batch file to set console code page\n" );
my $outErr;
run3( $statBat, \undef, \$outErr, \$outErr );
badExit( "Not able to run set console code page batch file wrapper: '" . $statBat . "', returned: " . $? . ", and: " . $outErr ) if ( $? );

#clean up batch file
toLog( " - Cleaning up temporary console code page batch file\n" );
if ( testL( 'e', $statBat ) ) {
	unlinkL( $statBat ) or badExit( "Not able to remove temporary console code page batch file: '" . $statBat . "': $^E, $!" );
} else {
	badExit( "No console code page batch file to delete: $^E, $!" );
}

#set overall counter for songs
my $num = 0;
#loop through each song file in file list
foreach my $songFile ( @fileLst ) {
	#song counter for XML file output
	++$num;
	#list of ID3 possible tag names
	my @listOfAllTags = (
		'album_artist',
		'albumartistsortorder',
		'albumartistsort',
		'albumartist',
		'album',
		'artistsortorder',
		'artistsort',
		'artist',
		'audiobitrate',
		'bit_rate',
		'bitrate',
		'comment',
		'datetimeoriginal',
		'date',
		'discnumber',
		'disc',
		'ensemble',
		'genre',
		'length',
		'minutes',
		'originaldate',
		'originalreleaseyear',
		'part_number',
		'partofset',
		'path',
		'title',
		'trackid',
		'tracknumber',
		'track',
		'year'
	);

	#echo status to console
	toLog( 'Processing song file: "' . $songFile . "\"...\n" );
	binmode( STDOUT, ":encoding(UTF-8)" );
	print "\n   Processing '$songFile'\n";

	#set per song hash for tag metadata
	my %tags;

	#if song file is 'mkv' format, use 'mkvextract' for tag extraction
	if ( $songFile =~ m#\.mkv$#i ) {
		toLog( " - Preparing for 'mkvextract' to export metadata tags from song file\n" );
		my $mkvCmd = 'C:\Program Files\MKVToolNix\mkvextract.exe';
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
		my $mkvBatFH;
		#open/close batch file with commands written to it
		toLog( " - Creating batch file wrapper for 'mkvextract': '" . $mkvBat . "'\n" );
		openL( \$mkvBatFH, '>:encoding(UTF-8)', $mkvBat ) or badExit( "Not able to create temporary batch file to run 'mkvextract': $^E, $!" );
			my $oldFH = select $mkvBatFH; $| = 1; select $oldFH;
			print $mkvBatFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @mkvArgs );
		close( $mkvBatFH );

		#execute batch file wrapper to call 'mkvextract' command batch file
		toLog( " - Executing batch file for 'mkvextract'\n" );
		my $stdOutErr;
		run3( $mkvBat, \undef, \$stdOutErr, \$stdOutErr );
		badExit( "Not able to run 'mkvextract' batch file wrapper: '" . $mkvBat . "', returned: " . $? . ", and: " . $stdOutErr ) if ( $? );

		#load XML data
		my $xmlFH;
		openL( \$xmlFH, '<:encoding(UTF-8)', $songFileXml ) or badExit( "Not able to open XML file: '$songFileXml' for input" );
			binmode $xmlFH;
			my $dom = XML::LibXML->load_xml( IO => $xmlFH );
			badExit( "\n\nCouldn't load XML file: $songFileXml" ) unless ( $dom );
		close( $xmlFH );

		foreach my $xmlNode ( $dom->findnodes( '//Simple' ) ) {
			my $tagName = $xmlNode->findvalue( './Name' );
			my $tagValue = $xmlNode->findvalue( './String' );
			if ( grep /$tagName/i, @listOfAllTags ) {
				#tag names should be initial-capped
				if ( $tagName =~ m#ALBUMARTISTSORTORDER# ) {
					$tagName = 'albumartistsortorder';
				} elsif ( $tagName =~ m#ALBUMARTISTSORT# ) {
					$tagName = 'albumartistsort';
				} elsif ( $tagName =~ m#ALBUM_ARTIST# ) {
					$tagName = 'albumartist';
				} elsif ( $tagName =~ m#ARTISTSORTORDER# ) {
					$tagName = 'artistsortorder';
				} elsif ( $tagName =~ m#ARTISTSORT# ) {
					$tagName = 'artistsort';
				} elsif ( $tagName =~ m#^[A-Z]# ) {
					$tagName =~ s#([\w']+)#\L$1\E#
				}
				$tags{$tagName} = $tagValue;
			}
		}

		toLog( " - Cleaning up temporary 'mkvextract' files\n" );
		if ( testL( 'e', $songFileXml ) ) {
			unlinkL( $mkvBat ) or badExit( "Not able to remove temporary 'mkvextract' batch file: '" . $mkvBat . "': $^E, $!" );
			unlinkL( $songFileXml ) or badExit( "Not able to remove XML data for song file: '" . $songFileXml . "': $^E, $!" );
		} else {
			badExit( "XML data not created for song file: '" . $songFile . "'" );
		}
	#otherwise, create 'exiftool' batch file for all other song file types
	} else {
		toLog( " - Preparing for 'ExifTool' to export metadata tags from song file\n" );
		#arguments for calling 'exiftool' command-line program
		my $exifToolCmd = 'C:\Strawberry\perl\site\bin\exiftool';
		my $exifToolArgsFile = $ENV{TEMP} . $FS . 'exiftoolargs-' . $num . '.txt';
		my $songFileJson = $songFile . '.json';
		my @exifToolArgs = (
			#exiftool command-line program
			'"' . $exifToolCmd . '"',
			#read arguments from text file
			'-@ ' . '"' . $exifToolArgsFile . '"',
			#redirect output to JSON file
			'>"' . $songFileJson . '"'
		);
		my @exifToolFileArgs = (
		#set encoding for filenames, also sets wide-character I/O
		'-charset' . "\n" . 'filename=UTF8' . "\n",
		#set encoding for IPTC values
		'-charset' . "\n" . 'exif=UTF8' . "\n",
		#set encoding for exifTool
		'-charset' . "\n" . 'exiftool=UTF8' . "\n",
		#set encoding of ID3 metadata
		'-charset' . "\n" . 'id3=UTF8' . "\n",
			#allow duplicate tags
			'-duplicates' . "\n",
			#quiet processing
			'-quiet' . "\n",
			#output in json format
			'-json' . "\n",
			#convert array data to string
			'-separator' . "\n" . ', ' . "\n",
			#get tag values from song file
			$songFile
		);

		#start process to create batch file for calling 'exiftool' for files/folders with Unicode characters
		my $jsonBat = $ENV{TEMP} . $FS . 'exiftool-' . $num . '.bat';
		my ( $jsonBatFH, $jsonFH, $argsFH );
		#open/close batch file with commands written to it
		toLog( " - Creating batch file wrapper for 'exiftool': '" . $jsonBat . "'\n" );
		openL( \$jsonBatFH, '>:encoding(UTF-8)', $jsonBat ) or badExit( "Not able to create temporary batch file to run 'exiftool': $^E, $!" );
			my $oldFH = select $jsonBatFH; $| = 1; select $oldFH;
			print $jsonBatFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @exifToolArgs );
		close( $jsonBatFH );
		#open/close 'exiftool' args file with arguments written to it
		toLog( " - Creating argument file for 'exiftool': '" . $exifToolArgsFile . "'\n" );
		openL( \$argsFH, '>:encoding(UTF-8)', $exifToolArgsFile ) or badExit( "Not able to create temporary arguments file to run 'exiftool': $^E, $!" );
			$oldFH = select $argsFH; $| = 1; select $oldFH;
			print $argsFH @exifToolFileArgs;
		close( $argsFH );

		#execute batch file wrapper to call 'exiftool' command batch file
		toLog( " - Executing batch file for 'exiftool'\n" );
		my $stdOutErr;
		run3( $jsonBat, \undef, \$stdOutErr, \$stdOutErr );
		badExit( "Not able to run batch file wrapper: '" . $jsonBat . "', returned: " . $? . ", and: " . $stdOutErr ) if ( $? );
		
		#read in json data for song file
		openL( \$jsonFH, '<:encoding(UTF-8)', $songFileJson ) or badExit( "Not able to open JSON data file: '" . $songFileJson . "', $^E, $!" );
			local $/;
			my $jsonTxt = <$jsonFH>;
		close( $jsonFH );
		my $json = JSON->new;
		my $jsonData = $json->decode( $jsonTxt );

		#create hashref for hash of tags => values
		my $tagsArray = $jsonData;
		foreach my $key ( keys %{${$tagsArray}[0]} ) {
			my $lcKey = lc( $key );
			#check MKV tag names and substitute to actual tag name
			if ( grep /$lcKey/, @listOfAllTags ) {
				$tags{$lcKey} = ${$tagsArray}[0]{$lcKey};
			}
		}
		toLog( " - Cleaning up temporary 'exiftool' files\n" );
		if ( testL( 'e', $songFileJson ) ) {
			unlinkL( $jsonBat ) or badExit( "Not able to remove temporary 'exiftool' batch file: '" . $jsonBat . "': $^E, $!" );
			unlinkL( $songFileJson ) or badExit( "Not able to remove JSON data for song file: '" . $songFileJson . "': $^E, $!" );
			unlinkL( $exifToolArgsFile ) or badExit( "Not able to remove arguments file for 'exiftool': '" . $exifToolArgsFile . "': $^E, $!" );
		} else {
			badExit( "JSON data not created for song file: '" . $songFile . "'" );
		}
	}

	#checking each tag - to set/clean-up values and/or delete values
	toLog( " - Examining each tag retrieved\n" );
	foreach my $key ( keys %tags ) {
		#set 'album artist' if not specified
		if ( $key =~ m#^artist$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{$lcKey} =~ s#^AC[_ ]DC$#AC\/DC#i;
			if ( $tags{'album_artist'} ) {
				$tags{albumartist} = $tags{'album_artist'};
				#correct previous error in diagnostic testing for 'AC/DC'
				$tags{albumartist} =~ s#^AC[_ ]DC$#AC\/DC#i;
				#remove for preferred 'albumartist' key
				delete $tags{'album_artist'};
			} elsif ( $tags{'ALBUM_ARTIST'} ) {
				$tags{albumartist} = $tags{'ALBUM_ARTIST'};
				#correct previous error in diagnostic testing for 'AC/DC'
				$tags{albumartist} =~ s#^AC[_ ]DC$#AC\/DC#i;
				#remove for preferred 'albumartist' key
				delete $tags{'ALBUM_ARIST'};
			}
			$tags{albumartist} = $tags{$lcKey} if ( ! $tags{albumartist} );
		}
		#remove extra artist info
		$tags{albumartist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
		if ( $key =~ m#^artists$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
		} elsif ( $key =~ m#^album$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
		} elsif ( $key =~ m#^discnumber$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
		}
		#clean up 'albumartistsort'
		if ( ( $key =~ m#^albumartistsortorder$#i ) || ( $key =~ m#^albumartistsort$#i ) ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
			#remove extra artist info
			$tags{$lcKey} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{$lcKey} =~ s#^AC[_ ]DC$#AC\/DC#i;
			#strip starting articles
			$tags{$lcKey} =~ s#^(the|a|an)\s+(.+)#$2#i;
		}
		#clean up 'artistsort'
		if ( ( $key =~ m#^artistsortorder$#i ) || ( $key =~ m#^artistsort$#i ) ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
			#remove extra artist info
			$tags{$lcKey} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{$lcKey} =~ s#^AC[_ ]DC$#AC\/DC#i;
			#strip starting articles
			$tags{$lcKey} =~ s#^(the|a|an)\s+(.+)#$2#i;
		}
		#'track' value keyed as 'track id' or 'tracknumber' or 'part_number'
		if ( ( $key =~ m#^tracknumber$#i ) || ( $key =~ m#^trackid$#i ) || ( $key =~ m#^part_number$#i ) ) {
			if ( ! $tags{track} ) {
				#prefer 'track number' over 'track id'
				if ( $key =~ m#^tracknumber$#i ) {
					$tags{track} = $tags{$key};
				} elsif ( $key =~ m#^trackid$#i ) {
					$tags{track} = $tags{$key};
				} elsif ( $key =~ m#^part_number$#i ) {
					$tags{track} = $tags{$key};
				}
			}
			delete $tags{$key};
		}
		#'discnumber' value keyed as 'partofset', but keep 'part of set' - is listed as standard tag for ID3v2.3
		if ( $key =~ m#^partofset$#i ) {
			if ( ! $tags{discnumber} ) {
				$tags{discnumber} = $tags{$key};
			}
		}
		#remove duplicates, etc. from 'year' value
		if ( $key =~ m#^year$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
			#remove duplicate
			$tags{$lcKey} =~ s#^(\d\d\d\d).*$#$1#;
			#if 'date' not equal 'year', use 'date' value
			if ( ( $tags{date} ) && ( $tags{date} !~ m#^$tags{$lcKey}$# ) ) {
				$tags{$lcKey} = $tags{date};
			} else {
				$tags{date} = $tags{$lcKey};
			}
		}
		#remove duplicates, etc. from 'date' value
		if ( $key =~ m#^date$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
			#remove duplicate
			$tags{$lcKey} =~ s#^(\d\d\d\d).*$#$1#;
			if ( ( ! $tags{year} ) && ( $tags{$lcKey} !~ m#^$# ) ) {
				#add 'year' key for 'date' value
				$tags{year} = $tags{$lcKey};
			}
			delete $tags{date};
		}
		#'year' value keyed as 'original release year', but keep 'original release year' - is listed as standard tag for ID3v2.3
		if ( $key =~ m#^originalreleaseyear$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
			#remove duplicate
			$tags{$lcKey} =~ s#^(\d\d\d\d).*$#$1#;
			if ( ! $tags{year} ) {
				$tags{year} = $tags{$lcKey};
			}
		}
		#'year' value keyed as 'original date'
		if ( $key =~ m#^originaldate$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
			#remove duplicate
			$tags{$lcKey} =~ s#^(\d\d\d\d).*$#$1#;
			if ( ! $tags{year} ) {
				$tags{year} = $tags{$lcKey};
			}
		}
		#'year' value keyed as 'DateTimeOriginal'
		if ( $key =~ m#^datetimeoriginal$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
			#remove duplicate
			$tags{$lcKey} =~ s#^(\d\d\d\d).*$#$1#;
			if ( ! $tags{year} ) {
				$tags{year} = $tags{$lcKey};
			}
		}
		#'bitrate' needs some format checks
		if ( $key =~ m#^bitrate$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
			}
			#match at least 6 digits (for 1,000's), but also capture any trailing digits but leaving the rest off)
			if ( $tags{$lcKey} =~ s#^(\d{6}\d*).*$#$1# ) {
				$tags{$lcKey} = $tags{$lcKey} / 1000;
				$tags{$lcKey} = int( $tags{$lcKey} );
			} else {
				#strip any extraneous characters from digits otherwise
				$tags{$lcKey} =~ s#^(\d+).*$#$1#;
			}
		}
		#'bitrate' value keyed as 'bit_rate'
		if ( $key =~ m#^bit_rate$#i ) {
			if ( ! $tags{bitrate} ) {
				#lowercase key
				my $lcKey = lc( $key );
				if ( $key =~ m#^[A-Z]# ) {
					#resetting to lowercase value
					$tags{$lcKey} = $tags{$key};
					delete $tags{$key};
				}
				#match at least 6 digits (for 1,000's), but also capture any trailing digits but leaving the rest off)
				if ( $tags{$lcKey} =~ s#^(\d{6}\d*).*$#$1# ) {
					$tags{$lcKey} = $tags{$lcKey} / 1000;
					$tags{$lcKey} = int( $tags{$lcKey} );
				} else {
					#strip any extraneous characters from digits otherwise
					$tags{$lcKey} =~ s#^(\d+).*$#$1#;
				}
				$tags{bitrate} = $tags{$lcKey};
			}
		}
		#'bitrate' value keyed as 'AudioBitrate'
		if ( $key =~ m#^audiobitrate$#i ) {
			if ( ! $tags{bitrate} ) {
				#lowercase key
				my $lcKey = lc( $key );
				if ( $key =~ m#^[A-Z]# ) {
					#resetting to lowercase value
					$tags{$lcKey} = $tags{$key};
					delete $tags{$key};
				}
				#match at least 6 digits (for 1,000's), but also capture any trailing digits but leaving the rest off)
				if ( $tags{$lcKey} =~ s#^(\d{6}\d*).*$#$1# ) {
					$tags{$lcKey} = $tags{$lcKey} / 1000;
					$tags{$lcKey} = int( $tags{$lcKey} );
				} else {
					#strip any extraneous characters from digits otherwise
					$tags{$lcKey} =~ s#^(\d+).*$#$1#;
				}
				$tags{bitrate} = $tags{$lcKey};
			}
		}
		#if 'comment' has previously used diagnostic text, remove it
		if ( $key =~ m#^comment$#i ) {
			if ( ( $tags{$key} =~ m#created from filename#i ) || ( $tags{$key} =~ m#updated with default#i ) || ( $tags{$key} =~ m#^vendor$#i ) || ( $tags{$key} =~ m#^\s+$#i ) ) {
				delete $tags{$key};
			}
		}
		#if 'comment' value stored in 'comment-xxx'
		if ( $key =~ m#^comment-xxx$#i ) {
			if ( ! $tags{comment} ) {
				$tags{comment} = $tags{$key} unless ( ( $tags{$key} =~ m#created from filename#i ) || ( $tags{$key} =~ m#updated with default#i ) || ( $tags{$key} =~ m#^vendor$#i ) || ( $tags{$key} =~ m#^\s+$#i ) );
			}
			delete $tags{$key};
		}
		#if 'genre' has previously used diagnostic text, remove it
		if ( $key =~ m#^genre$#i ) {
			if ( ( $tags{$key} =~ m#^music$#i ) || ( $tags{$key} =~ m#^none$#i ) || ( $tags{$key} =~ m#^other$#i ) ) {
				delete $tags{$key};
			}
		}
		#calc 'length' for MM:SS value of 'minutes'
		if ( $key =~ m#^length$#i ) {
			#lowercase key
			my $lcKey = lc( $key );
			if ( $key =~ m#^[A-Z]# ) {
				#resetting to lowercase value
				$tags{$lcKey} = $tags{$key};
				delete $tags{$key};
				if ( grep /^Minutes$/, keys %tags ) {
					delete $tags{Minutes};
				}
			}
			#if 'length' set to approximate value, clean up
			if ( $tags{$lcKey} =~ m#\(approx\)#i ) {
					$tags{$lcKey} =~ s#^(.+)\s*\(approx\)\s*$#$1#i;
			}
			#length value can be given in HH:MM:SS format
			my ( $minutes, $seconds );
			if ( $tags{$lcKey} =~ m#^(\d+:\d+:\d+\.?\d*)# ) {
				$seconds = convertLength( $1 );
				$tags{$lcKey} = int( $seconds );
			} else {
				$seconds = $tags{$lcKey};
			}
			#set value for 'minutes' in MM:SS
			$minutes = $seconds / 60;
			$minutes = sprintf "%d", $minutes;
			my $remSecs = $seconds - ( $minutes * 60 );
			$remSecs = sprintf "%.02d", $remSecs;
			#delete existing 'minutes' - diagnostic testing caused several erroneous calcs for minutes
			if ( grep /^(minutes)$/i, keys %tags ) {
				delete $tags{$1};
			}
			$tags{minutes} = $minutes . ':' . $remSecs;
		}
		#'length' value keyed as 'duration'
		if ( $key =~ m#^duration$#i ) {
			if ( ! $tags{length} ) {
				#lowercase key
				my $lcKey = lc( $key );
				if ( $key =~ m#^[A-Z]# ) {
					#resetting to lowercase value
					$tags{$lcKey} = $tags{$key};
					delete $tags{$key};
					if ( grep /^Minutes$/, keys %tags ) {
						delete $tags{Minutes};
					}
				}
				if ( $tags{$lcKey} =~ m#^0\.# ) {
					delete $tags{$lcKey};
				} else {
					#'duration' value can be given in HH:MM:SS format
					my ( $minutes, $seconds );
					if ( $tags{$lcKey} =~ m#^(\d+:\d+:\d+\.?\d*)# ) {
						$seconds = convertLength( $1 );
					} else {
						$seconds = $tags{$lcKey};
					}
					#set value for 'minutes' in MM:SS
					$minutes = $seconds / 60;
					$minutes = sprintf "%d", $minutes;
					my $remSecs = $seconds - ( $minutes * 60 );
					$remSecs = sprintf "%.02d", $remSecs;
					#delete existing 'minutes' - diagnostic testing caused several erroneous calcs for minutes
					if ( exists $tags{minutes} ) {
						delete $tags{minutes};
					}
					$tags{minutes} = $minutes . ':' . $remSecs;
					#reset 'length' value in total seconds
					$tags{length} = int( $seconds );
				}
			}
			delete $tags{lc( $key )} if ( $tags{length} );
		}
	}

	#check if crucial tags have been set, try to determine from filename & path
	if ( ( ! $tags{title} ) || ( ! $tags{artist} ) || ( ! $tags{track} ) || ( ! $tags{album} ) || ( ! $tags{length} ) ) {
		toLog( " - <title> or <artist> (or others) have not been set, attempting to set from filename & path\n" );
		my ( $fileName, $filePath ) = fileparse( abspathL( $songFile ) );
		if ( $filePath =~ m#^$musicDirPath$musicDir\\([^\\]+)\\([^\\]+)\\#i ) {
			my $artist = $1;
			my $album = $2;
			#add escape '\' to square brackets for match expression
			my $albumMatch = $album;
			$albumMatch =~ s#([\[\]])#\\$1#g;
			$tags{artist} = $artist if ( ! $tags{artist} );
			#determine if directory is actually a compilation with 'Disc' folders
			if ( ( $artist =~ m#^$albumMatch$#i ) || ( $album =~ m#^dis[ck]\s*\d+$#i ) ) {
				$tags{album} = $artist if ( ! $tags{album} );
			} else {
				$tags{album} = $album if ( ! $tags{album} );
			}
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{artist} =~ s#^AC[_ ]DC$#AC\/DC#i;
			if ( ! $tags{albumartist} ) {
				$tags{albumartist} = $tags{artist};
				#remove extra artist info
				$tags{albumartist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
			}
		} elsif ( $filePath =~ m#^$musicDirPath$musicDir\\([^\\]+)\\#i ) {
			$tags{artist} = $1 if ( ! $tags{artist} );
			$tags{album} = $1 if ( ! $tags{album} );
			$tags{albumartist} = $1 if ( ! $tags{albumartist} );
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{artist} =~ s#^AC[_ ]DC$#AC\/DC#i;
			#remove extra artist info
			$tags{albumartist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{albumartist} =~ s#^AC[_ ]DC$#AC\/DC#i;
		}

		if ( $fileName =~ m#((\d)\-)?(\d+)\s*\-?\s+([^\\]+)\.(aac|alac|flac|m4a|mka|mkv|mp3|ogg|wma)$#i ) {
			$tags{title} = $4 if ( ! $tags{title} );
			if ( ! $tags{track} ) {
				$tags{track} = $3;
			}
			if ( ( $2 ) && ( ! $tags{discnumber} ) ) {
				$tags{discnumber} = $2;
			}
		}

		if ( ( ! $tags{length} ) && ( ! $tags{duration} ) ) {
			#set ffprobe command for finding duration on song files that are not readable by 'ffmpeg', or have not tag data
			toLog( " - Preparing command for 'ffprobe' to determine 'Length'\n" );
			my @ffprobeCmd = (
				'"' . 'C:\\Users\\rich\\Documents\\Dev\\ffmpeg\\FFmpeg-exe\\bin\\ffprobe.exe' . '"',
				'-v error',
				'-show_entries format=duration',
				'-of default=noprint_wrappers=1:nokey=1',
				'"' . $songFile . '"'
			);
	
			#call 'ffprobe' to extract duration of song file
			my $duration;
			#start process to create batch file with 'ffprobe' command
			my $ffprobeBat = $ENV{TEMP} . $FS . 'ffprobe-' . $num . '.bat';
			#batch file handle ref
			my $ffprobeFH;
			#open/close batch file with commands written to it
			toLog( " - Creating 'ffprobe' batch file: '" . $ffprobeBat . "'\n" );
			openL( \$ffprobeFH, '>:encoding(UTF-8)', $ffprobeBat ) or badExit( "Not able to create temporary batch file to run 'ffprobe': $^E, $!" );
				my $oldfh = select $ffprobeFH; $| = 1; select $oldfh;
				#write empty line to batch file in case of file header conflict
				print $ffprobeFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @ffprobeCmd );
			close( $ffprobeFH );
	
			toLog( " - Executing 'ffprobe' batch file\n" );
			run3( $ffprobeBat, \undef, \$duration );
			if ( $duration =~ m#\n(\d+)# ) {
				$duration = $1;
				my $minutes = $duration / 60;
				$minutes = sprintf "%.02d", $minutes;
				my $remSecs = $duration - ( $minutes * 60 );
				$remSecs = sprintf "%.02d", $remSecs;
				$tags{minutes} = $minutes . ':' . $remSecs;
				$tags{length} = int( $duration );
			}

			if ( ( ! $tags{title} ) && ( ! $tags{artist} ) ) {
				warning( "Could not determine <title>, <artist>, or possibly other tags" );
			}

			toLog( " - Cleaning up temporary 'ffprobe' files\n" );
			if ( testL( 'e', $ffprobeBat ) ) {
				unlinkL( $ffprobeBat ) or badExit( "Not able to remove temporary 'ffprobe' batch file: '" . $ffprobeBat . "': $^E, $!" );
			}
		}
	}

	#set 'discnumber' to default value, if not present
	if ( ! $tags{discnumber} ) {
		$tags{discnumber} = 1;
	}

	#write out XML to file of metadata for song file
	toLog( " - Writing out XML to list\n" );
	#build and output new playlist song node
	$writer->startTag( "song", number => $num );
	#write <track>
	#strip leading '0' in 'Discnumber' tag
	if ( $tags{discnumber} =~ m#^0(.+)$# ) {
		$tags{discnumber} = $1;
	}
	$writer->startTag( "track", discnumber => $tags{discnumber} );
	#padding with '0' in 'track' tag
	if ( $tags{track} =~ m#^\d$# ) {
		$tags{track} = '0' . $tags{track};
	}
	$writer->characters( $tags{track} ) if ( $tags{track} );
	$writer->endTag( "track" );
	#write <title>
	$writer->startTag( "title" );
	#replace extraneous characters
	$tags{title} = charReplace( $tags{title} );
	$writer->characters( $tags{title} ) if ( $tags{title} );
	$writer->endTag( "title" );
	#write <artist>
	$writer->startTag( "artist" );
	#replace extraneous characters
	$tags{artist} = charReplace( $tags{artist} );
	$writer->characters( $tags{artist} ) if ( $tags{artist} );
	$writer->endTag( "artist" );
	#write <albumartist>
	$writer->startTag( "albumartist" );
	#replace extraneous characters
	$tags{albumartist} = charReplace( $tags{albumartist} );
	$writer->characters( $tags{albumartist} ) if ( $tags{albumartist} );
	$writer->endTag( "albumartist" );
	#write <album>
	$writer->startTag( "album" );
	#replace extraneous characters
	$tags{album} = charReplace( $tags{album} );
	$writer->characters( $tags{album} ) if ( $tags{album} );
	$writer->endTag( "album" );
	#write <year>
	$writer->startTag( "year" );
	$writer->characters( $tags{year} ) if ( $tags{date} );
	$writer->endTag( "year" );
	#write <genre>
	$writer->startTag( "genre" );
	#replace extraneous characters
	$tags{genre} = charReplace( $tags{genre} );
	$writer->characters( $tags{genre} ) if ( $tags{genre} );
	$writer->endTag( "genre" );
	#write <bitrate>
	$writer->startTag( "bitrate", unit => 'kbps' );
	$writer->characters( $tags{bitrate} ) if ( $tags{bitrate} );
	$writer->endTag( "bitrate" );
	#write <length>
	if ( $tags{minutes} ) {
		$writer->startTag( "length", minutes => $tags{minutes} );
	} else {
		$writer->startTag( "length", minutes => '' );
	}
	$writer->characters( $tags{length} ) if ( $tags{length} );
	$writer->endTag( "length" );
	#write <comment>
	$writer->startTag( "comment" );
	#replace extraneous characters
	$tags{comment} = charReplace( $tags{comment} );
	$writer->characters( $tags{comment} ) if ( $tags{comment} );
	$writer->endTag( "comment" );
	#replace extraneous characters for adding <path> content
	my $songFileClean = charReplace( $songFile );
	#clean up path
	if ( $songFileClean =~ s#^[A-Z]\:[\\\/]Music[\\\/]#\\\\DavisServer_1\\Music\\#i ) {
		#replace 'M:\' drive letter path with UNC path
		toLog( " - Replacing drive letter with UNC path\n" );
		#replace any remaining forward slashes with backslashes
		$songFileClean =~ s#\/#\\#g;
	}
	#write <path>
	$writer->startTag( "path" );
	$writer->characters( $songFileClean );
	$writer->endTag( "path" );

	#write out close song XML tag
	$writer->endTag( "song" );

	toLog( "Writing \"" . $tags{title} . "\" by \"" . $tags{artist} . "\" as number $num to playlist XML file\n" );
}

#write out close playlist XML tag
$writer->endTag( "playlist" );
$writer->end() or badExit( "Not able to write complete XML to file" );

#write out new XML playlist file
my $playlistXmlFile = "$workDir[0]$FS$playlist_name.xml";
my $xmlOutFH;
openL( \$xmlOutFH, '>:encoding(UTF-8)', $playlistXmlFile ) or badExit( "Not able to create '" . $playlistXmlFile . "'" );
my $newfh = select $xmlOutFH; $| = 1; select $newfh;
print $xmlOutFH $writer or badExit( "Not able to write out XML to '$playlistXmlFile'" );
close( $xmlOutFH );
toLog( "\n...Created playlist XML file: '$playlistXmlFile'\n\n\n" );

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
sub lowerHashCase {
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

#convert HH:MM:SS length into seconds
sub convertLength {
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

#replace extraneous non-UTF-8 characters
sub charReplace {
	my ( $chars ) = @_;

	#repalce non-Unicode coded characters with character - HTML entity - <alt> keyboard entry
	if ( $chars ) {
		#horizontal ellipsis - &hellip; - <alt> 0133
		$chars =~ s/\x{85}/\…/g;
#-x-		$chars =~ s/\x{85}/\x{2026}/g;
		#left single quotation mark - &lsquo; - <alt> 0145
		$chars =~ s/\x{91}/‘/g;
#-x-		$chars =~ s/\x{91}/\x{2018}/g;
		#right single quotation mark - &rsquo; - <alt> 0146
		$chars =~ s/\x{92}/’/g;
#-x-		$chars =~ s/\x{92}/\x{2019}/g;
		#left double quotation mark - &ldquo; - <alt> 0147
		$chars =~ s/\x{93}/“/g;
#-x-		$chars =~ s/\x{93}/\x{201c}/g;
		#right double quotation mark - &rdquo; - <alt> 0148
		$chars =~ s/\x{94}/”/g;
#-x-		$chars =~ s/\x{94}/\x{201d}/g;
		#en dash - &ndash; - <alt> 0150
		$chars =~ s/\x{96}/–/g;
#-x-		$chars =~ s/\x{96}/\x{2013}/g;
		#em dash - &mdash; - <alt> 0151
		$chars =~ s/\x{97}/—/g;
#-x-		$chars =~ s/\x{97}/\x{2014}/g;
		#latin small letter e with acute - &eacute; - <alt> 0233
		$chars =~ s/\x{e9}/é/g;
#-x-		$chars =~ s/\x{c3}\x{a9}/\x{e9}/g;
	}
	return $chars;
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
	my $Sep = "-" x 110;

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
	my $Sep = "-" x 110;

	if ( $stat ) {
		$stat = 'Failed';
	} else {
		$stat = 'Completed';
	}
	toLog( "\n$Sep\n$time  $stat$ver_info\n$Sep\n\n" );
	close( $logFH );
}
