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
# version 1.0  -  26 Mar 2025	RAD	initial creation
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
#         1.20 -  10 Jan 2026  RAD added if statement to check $status before echoing finished to console
#
#
#   TO-DO:
#         1) need to figure out how to get 'date' & write data from/to .mkv songs
#
#**********************************************************************************************************

my $Version = "1.19";

use strict;
use warnings;
use utf8::all;
use feature 'unicode_strings';
use open ':std', IO => ':raw :encoding(UTF-8)';

use Carp qw( carp croak longmess );
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

#list of ID3 verified tag names
my @listOfID3Tags = (
	'Title',
	'Track',
	'Artist',
	'Album',
	'AlbumArtist',
	'Duration'
);

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
				if ( $tagName =~ m#ALBUMARTISTSORT# ) {
					$tagName = 'AlbumArtistSort';
				} elsif ( $tagName =~ m#ALBUMARTIST# ) {
					$tagName = 'AlbumArtist';
				} elsif ( $tagName =~ m#ARTISTSORT# ) {
					$tagName = 'ArtistSort';
				} elsif ( $tagName =~ m#^[A-Z]+$# ) {
					$tagName =~ s#([\w']+)#\u\L$1#
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
			'-charset' . "\n" . 'FileName=UTF8' . "\n",
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
			#check MKV tag names and substitute to actual tag name
			if ( grep /$key/, @listOfAllTags ) {
				$tags{$key} = ${$tagsArray}[0]{$key};
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
			if ( ! $tags{AlbumArtist} ) {
				if ( $tags{Albumartist} ) {
					$tags{AlbumArtist} = $tags{Albumartist};
					#remove for preferred 'albumartist' key
					delete $tags{Albumartist};
				} elsif ( $tags{albumartist} ) {
					$tags{AlbumArtist} = $tags{albumartist};
					#remove for preferred 'albumartist' key
					delete $tags{albumartist};
				} elsif ( $tags{album_artist} ) {
					$tags{AlbumArtist} = $tags{album_artist};
					#remove for preferred 'albumartist' key
					delete $tags{album_artist};
				} else {
					$tags{AlbumArtist} = $tags{$key};
				}
			}
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{$key} =~ s#^AC[_ ]DC$#AC\/DC#i;
			#remove extra artist info
			$tags{AlbumArtist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{AlbumArtist} =~ s#^AC[_ ]DC$#AC\/DC#i;
			#set 'album artist sort' if not specified
			if ( ! $tags{AlbumArtistSort} ) {
				if ( $tags{Albumartistsort} ) {
					$tags{AlbumArtistSort} = $tags{Albumartistsort};
					#remove for preferred 'albumartistsort' key
					delete $tags{Albumartistsort};
				} else {
					$tags{AlbumArtistSort} = $tags{AlbumArtist};
					#strip starting articles
					$tags{AlbumArtistSort} =~ s#^(the|a|an)\s+(.+)#$2#i;
				}
			}
			#set 'artist sort' if not specified
			if ( ! $tags{ArtistSort} ) {
				if ( $key =~ m#Artistsort# ) {
					$tags{ArtistSort} = $tags{Artistsort};
					#remove for preferred 'artistsort' key
					delete $tags{Artistsort};
				} else {
					$tags{ArtistSort} = $tags{$key};
					#remove extra artist info
					$tags{ArtistSort} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
					#correct previous error in diagnostic testing for 'AC/DC'
					$tags{ArtistSort} =~ s#^AC[_ ]DC$#AC\/DC#i;
					#strip starting articles
					$tags{ArtistSort} =~ s#^(the|a|an)\s+(.+)#$2#i;
				}
			}
			#set 'ensemble' if not specified
			if ( ! $tags{Ensemble} ) {
				$tags{Ensemble} = $tags{$key};
			}
		}
		#'track' value keyed as 'track id' or 'tracknumber'
		if ( ( $key =~ m#^tracknumber$#i ) || ( $key =~ m#^trackid$#i ) ) {
			if ( ! $tags{Track} ) {
				#prefer 'track number' over 'track id'
				if ( $key =~ m#^tracknumber$#i ) {
					$tags{Track} = $tags{$key};
				} elsif ( $key =~ m#^trackid$#i ) {
					$tags{Track} = $tags{$key};
				}
				delete $tags{$key};
			}
		}
		#'disc' value keyed as 'partofset', but keep 'part of set' - is listed as standard tag for ID3v2.3
		if ( $key =~ m#^PartOfSet$# ) {
			if ( ! $tags{Disc} ) {
				$tags{Disc} = $tags{$key};
			}
		}
		#set 'discnumber' to better 'disc' value
		if ( $key =~ m#^discnumber$#i ) {
			if ( ! $tags{Disc} ) {
				$tags{Disc} = $tags{$key};
				delete $tags{$key};
			}
		}
		#remove duplicates, etc. from 'year' value
		if ( $key =~ m#^year$#i ) {
			#remove duplicate
			$tags{$key} =~ s#^(\d\d\d\d).*$#$1#;
			#if 'date' not equal 'year', use 'date' value
			if ( ( $tags{Date} ) && ( $tags{Date} !~ m#^$tags{$key}$# ) ) {
				$tags{$key} = $tags{Date};
			} else {
				$tags{Date} = $tags{$key};
			}
			if ( $tags{$key} =~ m#^$# ) {
				delete $tags{$key};
			}
		}
		#remove duplicates, etc. from 'date' value
		if ( $key =~ m#^date$#i ) {
			#remove duplicate
			$tags{$key} =~ s#^(\d\d\d\d).*$#$1#;
			#if 'date' not equal to 'year', use 'date' value
			if ( ( $tags{Year} ) && ( $tags{Year} !~ m#^$tags{$key}$# ) ) {
				$tags{Year} = $tags{$key};
			} elsif ( ( ! $tags{Year} ) && ( $tags{$key} !~ m#^$# ) ) {
				#add 'year' key for 'date' value
				$tags{Year} = $tags{$key};
			}
			if ( $tags{$key} =~ m#^$# ) {
				delete $tags{$key};
			}
		}
		#'year' value keyed as 'original release year', but keep 'original release year' - is listed as standard tag for ID3v2.3
		if ( $key =~ m#^originalreleaseyear$#i ) {
			#remove duplicate
			$tags{$key} =~ s#^(\d\d\d\d).*$#$1#;
			if ( ! $tags{Date} ) {
				$tags{Date} = $tags{$key};
			}
			if ( ! $tags{Year} ) {
				$tags{Year} = $tags{$key};
			}
		}
		#'year' value keyed as 'original date'
		if ( $key =~ m#^originaldate$#i ) {
			#remove duplicate
			$tags{$key} =~ s#^(\d\d\d\d).*$#$1#;
			if ( ! $tags{Date} ) {
				$tags{Date} = $tags{$key};
			}
			if ( ! $tags{Year} ) {
				$tags{Year} = $tags{$key};
			}
			delete $tags{$key};
		}
		#'year' value keyed as 'DateTimeOriginal'
		if ( $key =~ m#^datetimeoriginal$#i ) {
			#remove duplicate
			$tags{$key} =~ s#^(\d\d\d\d).*$#$1#;
			if ( ! $tags{Date} ) {
				$tags{Date} = $tags{$key};
			}
			if ( ! $tags{Year} ) {
				$tags{Year} = $tags{$key};
			}
			delete $tags{$key};
		}
		#'bitrate' needs some format checks
		if ( $key =~ m#^bitrate$#i ) {
			#match at least 6 digits (for 1,000's), but also capture any trailing digits but leaving the rest off)
			if ( $tags{$key} =~ s#^(\d{6}\d*).*$#$1# ) {
				$tags{$key} = $tags{$key} / 1000;
				$tags{$key} = int( $tags{$key} );
			} else {
				#strip any extraneous characters from digits otherwise
				$tags{$key} =~ s#^(\d+).*$#$1#;
			}
		}
		#'bitrate' value keyed as 'bit_rate'
		if ( $key =~ m#^bit_rate$#i ) {
			if ( ! $tags{Bitrate} ) {
				#match at least 6 digits (for 1,000's), but also capture any trailing digits but leaving the rest off)
				if ( $tags{$key} =~ s#^(\d{6}\d*).*$#$1# ) {
					$tags{$key} = $tags{$key} / 1000;
					$tags{$key} = int( $tags{$key} );
				} else {
					#strip any extraneous characters from digits otherwise
					$tags{$key} =~ s#^(\d+).*$#$1#;
				}
				$tags{Bitrate} = $tags{$key};
				delete $tags{$key};
			}
		}
		#'bitrate' value keyed as 'AudioBitrate'
		if ( $key =~ m#^audiobitrate$#i ) {
			if ( ! $tags{Bitrate} ) {
				#match at least 6 digits (for 1,000's), but also capture any trailing digits but leaving the rest off)
				if ( $tags{$key} =~ s#^(\d{6}\d*).*$#$1# ) {
					$tags{$key} = $tags{$key} / 1000;
					$tags{$key} = int( $tags{$key} );
				} else {
					#strip any extraneous characters from digits otherwise
					$tags{$key} =~ s#^(\d+).*$#$1#;
			}
				$tags{Bitrate} = $tags{$key};
				delete $tags{$key};
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
			if ( ! $tags{Comment} ) {
				$tags{Comment} = $tags{$key} unless ( ( $tags{$key} =~ m#created from filename#i ) || ( $tags{$key} =~ m#updated with default#i ) || ( $tags{$key} =~ m#^vendor$#i ) || ( $tags{$key} =~ m#^\s+$#i ) );
			}
			delete $tags{$key};
		}
		#if 'genre' has previously used diagnostic text, remove it
		if ( $key =~ m#^genre$#i ) {
			if ( ( $tags{$key} =~ m#^music$#i ) || ( $tags{$key} =~ m#^none$#i ) || ( $tags{$key} =~ m#^other$#i ) ) {
				delete $tags{$key};
			}
		}
		#calc 'duration' for MM:SS value of 'minutes'
		if ( $key =~ m#^duration$#i ) {
			#if 'duration' set to approximate value, clean up
			if ( $tags{$key} =~ m#\(approx\)#i ) {
					$tags{$key} =~ s#^(.+)\s*\(approx\)\s*$#$1#i;
			}
			#duration value can be given in HH:MM:SS format
			my ( $minutes, $seconds );
			if ( $tags{$key} =~ m#^(\d+:\d+:\d+\.?\d*)# ) {
				$seconds = convertDuration( $1 );
				$tags{$key} = int( $seconds );
			} else {
				$seconds = $tags{$key};
			}
			#set value for 'minutes' in MM:SS
			$minutes = $seconds / 60;
			$minutes = sprintf "%.02d", $minutes;
			my $remSecs = $seconds - ( $minutes * 60 );
			$remSecs = sprintf "%.02d", $remSecs;
			#delete existing 'minutes' - diagnostic testing caused several erroneous calcs for minutes
			if ( exists $tags{Minutes} ) {
				delete $tags{Minutes};
			}
			$tags{Minutes} = $minutes . ':' . $remSecs;
		}
		#'duration' value keyed as 'length'
		if ( $key =~ m#^length$#i ) {
			if ( ! $tags{Duration} ) {
				if ( $tags{$key} =~ m#^0\.# ) {
					delete $tags{$key};
				} else {
					#'duration' value can be given in HH:MM:SS format
					my ( $minutes, $seconds );
					if ( $tags{$key} =~ m#^(\d+:\d+:\d+\.?\d*)# ) {
						$seconds = convertDuration( $1 );
					} else {
						$seconds = $tags{$key};
					}
					#set value for 'minutes' in MM:SS
					$minutes = $seconds / 60;
					$minutes = sprintf "%.02d", $minutes;
					my $remSecs = $seconds - ( $minutes * 60 );
					$remSecs = sprintf "%.02d", $remSecs;
					#delete existing 'minutes' - diagnostic testing caused several erroneous calcs for minutes
					if ( exists $tags{Minutes} ) {
						delete $tags{Minutes};
					}
					$tags{Minutes} = $minutes . ':' . $remSecs;
					#reset 'duration' value in total seconds
					$tags{Duration} = int( $seconds );
				}
			}
		}
	}

	#check if crucial tags have been set, try to determine from filename & path
	if ( ( ! $tags{Title} ) || ( ! $tags{Artist} ) || ( ! $tags{Track} ) || ( ! $tags{Album} ) || ( ! $tags{Duration} ) ) {
		toLog( " - <title> or <artist> (or others) have not been set, attempting to set from filename & path\n" );
		my ( $fileName, $filePath ) = fileparse( abspathL( $songFile ) );
		if ( $filePath =~ m#^$musicDirPath$musicDir\\([^\\]+)\\([^\\]+)\\#i ) {
			my $artist = $1;
			my $album = $2;
			$tags{Artist} = $artist if ( ! $tags{Artist} );
			#determine if directory is actually a compilation with 'Disc' folders
			if ( ( $artist =~ m#^$album$#i ) || ( $album =~ m#^dis[ck]\s*\d+$#i ) ) {
				$tags{Album} = $artist if ( ! $tags{Album} );
			} else {
				$tags{Album} = $album if ( ! $tags{Album} );
			}
			$tags{AlbumArtist} = $tags{Artist} if ( ! $tags{AlbumArtist} );
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{Artist} =~ s#^AC[_ ]DC$#AC\/DC#i;
			$tags{Ensemble} = $tags{Artist} if ( ! $tags{Ensemble} );
			#remove extra artist info
			$tags{AlbumArtist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{AlbumArtist} =~ s#^AC[_ ]DC$#AC\/DC#i;
		} elsif ( $filePath =~ m#^$musicDirPath$musicDir\\([^\\]+)\\#i ) {
			$tags{Artist} = $1 if ( ! $tags{Artist} );
			$tags{Album} = $1 if ( ! $tags{Album} );
			$tags{AlbumArtist} = $1 if ( ! $tags{AlbumArtist} );
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{Artist} =~ s#^AC[_ ]DC$#AC\/DC#i;
			$tags{Ensemble} = $tags{Artist} if ( ! $tags{Ensemble} );
			#remove extra artist info
			$tags{AlbumArtist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
			#correct previous error in diagnostic testing for 'AC/DC'
			$tags{AlbumArtist} =~ s#^AC[_ ]DC$#AC\/DC#i;
		}
		if ( $fileName =~ m#((\d)\-)?(\d+)\s*\-?\s+([^\\]+)\.(aac|alac|flac|m4a|mka|mkv|mp3|ogg|wma)$#i ) {
			$tags{Title} = $4 if ( ! $tags{Title} );
			if ( ! $tags{Track} ) {
				$tags{Track} = $3;
			}
			if ( ( $2 ) && ( ! $tags{Disc} ) ) {
				$tags{Disc} = $2;
			}
		}
		#set ffprobe command for finding duration on song files that are not readable by 'ffmpeg', or have not tag data
		toLog( " - Preparing command for 'ffprobe' to determine 'Duration'\n" );
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
			$tags{Minutes} = $minutes . ':' . $remSecs;
			$tags{Duration} = int( $duration );
		} else {
			delete $tags{Duration};
		}
		if ( ( ! $tags{Title} ) && ( ! $tags{Artist} ) ) {
			warning( "Could not determine <title>, <artist>, or possibly other tags" );
		}
		toLog( " - Cleaning up temporary 'ffprobe' files\n" );
		if ( testL( 'e', $ffprobeBat ) ) {
			unlinkL( $ffprobeBat ) or badExit( "Not able to remove temporary 'ffprobe' batch file: '" . $ffprobeBat . "': $^E, $!" );
		}
	}
	#set 'disc number' to default value, if not present
	if ( ! $tags{Disc} ) {
		$tags{Disc} = 1;
	}

	#prepare file for ffmpeg to write metadata (can't write out to self) - copy original to temp file
	toLog( " - Creating temporary song file for 'ffmpeg' to use as original song file\n" );
	my ( $songFileName, $songFilePath ) = fileparse( abspathL( $songFile ) );
	my $tmpSongFileName = $songFileName;
	if ( $tmpSongFileName =~ s#(.)\.(\w\w\w\w?)$#$1_tmp\.$2#i ) {
		wait;
		renameL( $songFilePath . $songFileName, $songFilePath . $tmpSongFileName ) or badExit( "Not able to rename song file: '" . $songFilePath . $songFileName . "' to temp file: '" . $songFilePath . $tmpSongFileName . "', $!, $^E\n" );
		wait;
	}

	#create array of metadata tag args to add in ffmpeg (will splice into command args array)
	toLog( " - Creating 'ffmpeg' arguments for submission of metadata to song file\n" );
	my @newMeta;
	foreach my $key ( keys %tags ) {
		#fix any keys that have double quotes
		$key =~ s#"#\\'#g;
		#fix any values that have double quotes
		$tags{$key} =~ s#"#\\'#g;
		#replace any values that contain newlines
		$tags{$key} =~ s#\r?\n#,#g;
		#replace any values above unicode
		if ( $tags{$key} =~ m#[^\x00-\x7F]# ) {
			$tags{$key} = charReplace( $tags{$key} );
		}
		#fix any keys that have whitespace in the name
		if ( $key =~ m#\s# ) {
			$key = "\"$key\"";
		}
		if ( ! $tags{$key} ) {
			push( @newMeta, "-metadata $key=\"\"" );
		} else {
			push( @newMeta, "-metadata $key=\"" . $tags{$key} . "\"" );
		}
	}

	toLog( " - Building 'ffmpeg' command statement\n" );
	my @ffmpeg = ( 
		#ffmpeg executable
		'"' . 'C:\\Users\\rich\\Documents\\Dev\\ffmpeg\\FFmpeg-exe\\bin\\ffmpeg.exe' . '"',
		#input file is temporary song file
		'-i "' . $songFilePath . $tmpSongFileName . '"',
		#wipe existing metadata - fix some files not accepting changes if not cleared first
		'-map_metadata -1',
		#copy audio, no need for encoding/decoding
		'-c:a copy',
		#force ID3v2.3 tag version
		'-id3v2_version 3',
		#don't return numerous lines of output from 'ffmpeg'
		'-v quiet',
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
		'"' . $songFilePath . $songFileName . '"'
	);
	#splice in array of '-metadata' switches into @ffmpeg args
	splice( @ffmpeg, 11, 0, @newMeta );
	toLog( " - System command to rewrite song metadata with 'ffmpeg': '" . join( " ", @ffmpeg ) . "'\n" );

	#start process to create batch file with 'ffmpeg' commands
	my $ffmpegBat = $ENV{TEMP} . $FS . 'ffmpeg-' . $num . '.bat';
	#batch file handle ref
	my $ffmpegFH;
	#open/close batch file with commands written to it
	toLog( " - Creating batch file with 'ffmpeg' commands: '" . $ffmpegBat . "'\n" );
	openL( \$ffmpegFH, '>:encoding(UTF-8)', $ffmpegBat ) or badExit( "Not able to create temporary batch file to run 'ffmpeg': $^E, $!" );
		my $prevfh = select $ffmpegFH; $| = 1; select $prevfh;
		#write empty line to batch file in case of file header conflict
		print $ffmpegFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @ffmpeg );
	close( $ffmpegFH );

	#execute batch file wrapper to call 'ffmpeg' commands batch file
	toLog( " - Executing batch file for 'ffmpeg'\n" );
	my $outAndError;
	run3( $ffmpegBat, \undef, \$outAndError, \$outAndError );
	badExit( "Not able to run batch file wrapper: " . $ffmpegBat . ", returned: " . $? . ", and: " . $outAndError ) if ( $? );

	#removing temp song file & 'ffmpeg' batch file, if successful
	toLog( " - Removing temporary song files & batch files\n" );
	if ( testL( 'e', $songFile ) ) {
		unlinkL( $songFilePath . $tmpSongFileName ) or badExit( "Not able to remove temporary song file: '" . $songFilePath . $tmpSongFileName . "': $^E, $!" );
		unlinkL( $ffmpegBat ) or badExit( "Not able to remove temporary 'ffmpeg' batch file: '" . $ffmpegBat . "': $^E, $!" );
	} else {
		badExit( "Not able to remove temporary song file & batch files for song file: '" . $songFile . "'" );
	}

	#check crucial tags in @listOfID3Tags for values
	toLog( " - Scanning tags to see if any desired tags are not defined\n" );
	foreach my $tag ( @listOfID3Tags ) {
		if ( ! $tags{$tag} ) {
			toLog( "    - '$tag' tag is not declared\n" );
		}
	}

	#write out XML to file of metadata for song file
	toLog( " - Writing out XML to list\n" );
	#build and output new playlist song node
	$writer->startTag( "song", number => $num );
	#write <title>
	$writer->startTag( "title" );
	#replace extraneous characters
	$tags{Title} = charReplace( $tags{Title} );
	$writer->characters( $tags{Title} ) if ( $tags{Title} );
	$writer->endTag( "title" );
	#write <track>
	#strip leading '0' in 'disc' tag
	if ( $tags{Disc} =~ m#^0(.+)$# ) {
		$tags{Disc} = $1;
	}
	$writer->startTag( "track", disc => $tags{Disc} );
	#padding with '0' in 'track' tag
	if ( $tags{Track} =~ m#^\d$# ) {
		$tags{Track} = '0' . $tags{Track};
	}
	$writer->characters( $tags{Track} ) if ( $tags{Track} );
	$writer->endTag( "track" );
	#write <artist>
	$writer->startTag( "artist" );
	#replace extraneous characters
	$tags{Artist} = charReplace( $tags{Artist} );
	$writer->characters( $tags{Artist} ) if ( $tags{Artist} );
	$writer->endTag( "artist" );
	#write <albumartist>
	$writer->startTag( "albumartist" );
	#replace extraneous characters
	$tags{AlbumArtist} = charReplace( $tags{AlbumArtist} );
	$writer->characters( $tags{AlbumArtist} ) if ( $tags{AlbumArtist} );
	$writer->endTag( "albumartist" );
	#write <album>
	$writer->startTag( "album" );
	#replace extraneous characters
	$tags{Album} = charReplace( $tags{Album} );
	$writer->characters( $tags{Album} ) if ( $tags{Album} );
	$writer->endTag( "album" );
	#write <comment>
	$writer->startTag( "comment" );
	#replace extraneous characters
	$tags{Comment} = charReplace( $tags{Comment} );
	$writer->characters( $tags{Comment} ) if ( $tags{Comment} );
	$writer->endTag( "comment" );
	#write <year>
	$writer->startTag( "date" );
	$writer->characters( $tags{Year} ) if ( $tags{Date} );
	$writer->endTag( "date" );
	#write <genre>
	$writer->startTag( "genre" );
	#replace extraneous characters
	$tags{Genre} = charReplace( $tags{Genre} );
	$writer->characters( $tags{Genre} ) if ( $tags{Genre} );
	$writer->endTag( "genre" );
	#replace extraneous characters for adding <path> content
	my $songFileClean = charReplace( $songFile );
	#replace existing server path with phone music path, when run from phone export folder
	if ( $workDir[0] =~ m#phone_music#i ) {
		toLog( " - Phone 'export' directory, resetting path to phone path\n" );
		$songFileClean =~ s#^$musicDirPath$musicDir\\#/storage/emulated/0/Music/#i;
		#replace remaining backslashes with forward slashes for Android
		$songFileClean =~ s#\\#\/#g;
	} elsif ( $songFileClean =~ s#^M\:[\\/]Music[\\/]#\\\\DavisServer_1\\Music\\#i ) {
		#replace 'M:\' drive letter path with UNC path
		toLog( " - Replacing drive letter with UNC path\n" );
		#replace any remaining forward slashes with backslashes
		$songFileClean =~ s#\/#\\#g;
	}
	#write <path>
	$writer->startTag( "path" );
	$writer->characters( $songFileClean );
	$writer->endTag( "path" );
	#write <bitrate>
	$writer->startTag( "bitrate", unit => 'kbps' );
	$writer->characters( $tags{Bitrate} ) if ( $tags{Bitrate} );
	$writer->endTag( "bitrate" );
	#write <duration>
	if ( $tags{Minutes} ) {
		$writer->startTag( "duration", minutes => $tags{Minutes} );
	} else {
		$writer->startTag( "duration", minutes => '' );
	}
	$writer->characters( $tags{Duration} ) if ( $tags{Duration} );
	$writer->endTag( "duration" );

	#write out close song XML tag
	$writer->endTag( "song" );

	toLog( "Writing \"" . $tags{Title} . "\" by \"" . $tags{Artist} . "\" as number $num to playlist XML file\n" );
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
