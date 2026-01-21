#!/usr/bin/perl -w

#**********************************************************************************************************
#
#	File: update_ID3_tags.pl
#	Desc: updates ID3 metadata with XML input for song files (then uses command tools to populate remaining 
#       undefined tags) and updates metadata to song files, must pass playlist XML file to program in 
#       command-line
#
# Usage:  perl C:\git_playlist\update_ID3_tags.pl [PLAYLIST_XML_FILE]
#
#	Author: Richard Davis
#	  	rich@richandsteph.com
#
#**********************************************************************************************************
# version 1.0  -  19 Jan 2026	RAD	initial creation
#         1.1  -  19 Jan 2026	RAD	removed creation of 'ensemble' from extractTags() / added some filtering 
#                                 of 'artist' & 'albumartist' in extractTags() / added 'titlesortorder' to 
#                                 cleanTags() / edited other tags in extractTags()
#         1.2  -  19 Jan 2026 RAD added warning count for output at end of process / changed badExit() to 
#                                 warning() for non-essential task failures / output warning status to 
#                                 console & log
#         1.3  -  19 Jan 2026 RAD added missing end '}' at line #610 / corrected if loop for checking when 
#                                 $key is 'title' - was using $tagsRef->{title}
#         1.4  -  20 Jan 2026 RAD changed substitution of double quote in writeTags() key & value to use 
#                                 Unicode double quote (keybaord double quote is not allowed in command 
#                                 line args for Windows) / reformatted some coding
#         1.5  -  20 Jan 2026 RAD changed substitution of double quote in writeTags() from character to 
#                                 hex entity / updated error message when running exifTool
#         1.6  -  21 Jan 2026 RAD removed escaping of single quotes in writeTags() / updated description / 
#                                 removed Encode pragma / added 'else' to if loop when not matching 
#                                 established song file type when calling extract metadata method
#
#
#   TO-DO:
#         1) determine 'bitrate' for .mkv song files / write 'track' to .mkv song files
#
#**********************************************************************************************************

my $Version = "1.6";

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
my $warnCnt = 0;

#start logging
my $logFH;
my $progName = fileparse( $0 );
$progName =~ s#\.\w\w\w?$##;
my $logFile = "$progName.log";
startLog( $logFile );

#command-line tools for song metadata manipulation
my $exifToolCmd = 'C:\Strawberry\perl\site\bin\exiftool';
my $ffprobeCmd = 'C:\Users\rich\Documents\Dev\ffmpeg\FFmpeg-exe\bin\ffprobe.exe';
my $mkvCmd = 'C:\Program Files\MKVToolNix\mkvextract.exe';

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

#array list of possible ID3 tag names in nested arrays (priority is 1st item in sub-array)
my @listOfTagArrays = (
	[ 'albumartist', 'album_artist', 'album artist', 'albumartistsortorder', 'albumartistsort' ],
	[ 'album', 'originalalbum', 'albumsortorder', 'albumsort' ],
	[ 'artist', 'originalartist', 'artistsortorder', 'artistsort', 'ensemble', 'band', 'author' ],
	[ 'bitrate', 'bit_rate', 'audiobitrate' ],
	[ 'comment', 'comment-xxx' ],
	[ 'composer' ],
	[ 'discnumber', 'disc', 'disk', 'partofset' ],
	[ 'length', 'duration' ],
	[ 'genre' ],
	[ 'publisher' ],
	[ 'title', 'titlesortorder', 'titlesort' ],
	[ 'track', 'tracknumber', 'part_number', 'trackid' ],
	[ 'year', 'date', 'originaldate', 'originalreleaseyear', 'release date', 'datetimeoriginal', 'recordingdates' ]
);

#pull in playlist XML filename from command-line args
my $playlistFile;
if ( scalar( @ARGV ) != 1 ) {
	badExit( "Number of arguments is incorrect, single correct argument should be playlist XML filename: \n   perl C:\\git_playlist\\$progName.pl \[PLAYLIST_XML_FILENAME\]" );
} elsif ( testL ( 'e', $ARGV[0] ) ) {
	$playlistFile = $ARGV[0];
} else {
	badExit( "Playlist XML file: '" . $ARGV[0] . "' does not exist" );
}

#separate out playlist XML filename and directory
my ( $playlistFilename, $playlistFilePath ) = fileparse( abspathL ( $playlistFile ) );
$playlistFilename =~ s#\.\w\w\w?$##;
#echo status to console
toLog( 'Processing playlist XML file: "' . $playlistFilename . ".xml\"...\n" );
binmode( STDOUT, ":encoding(UTF-8)" );
print "\n   Processing '$playlistFilename.xml'\n";

#load playlist XML
my $xmlFH;
openL ( \$xmlFH, '<:encoding(UTF-8)', $playlistFile ) or badExit( "Not able to open playlist XML file for reading: '" . $playlistFile . "'" );
	binmode $xmlFH;
	my $dom = XML::LibXML->load_xml( IO => $xmlFH );
	badExit( "\n\nCouldn't load playlist XML file: $playlistFilename.xml" ) unless ( $dom );

#determine playlist name
my $playlistName;
if ( $dom->findnodes( '/playlist/@name' ) ) {
	$playlistName = $dom->findnodes( '/playlist/@name' );
} else {
	$playlistName = $playlistFilename;
}

#set output object for playlist XML
toLog( "- Initializing XML playlist\n" );
my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
badExit( "Not able to create new XML::Writer object" ) if ( ! $writer );
#write XML Declaration
$writer->xmlDecl( "UTF-8" ) or badExit( "Not able to write out XML Declaration" );
$writer->comment( "*IMPORTANT*: Only 1 attribute/value pair is allowed per each child node of <song>" );
#write date into root <playlist> tag attribute, with playlist name as attribute
toLog( "- Setting date/time for playlist\n" );
my $date = localtime( time() );
$writer->startTag( "playlist", name => $playlistName, date => $date );

#set overall counter for songs
my $num = 0;
#loop through each <song> node to determine best tool to use for song file
foreach my $songNode ( $dom->findnodes( '//song' ) ) {
	++$num;
	#set per song hash for tag metadata
	my ( %tags, $songFile, $songFileName, $songFilePath );
	
	#search empty elements and add empty node to avoid collapsed tag output
	foreach my $subNode ( $songNode->findnodes( '*' ) ) {
		my $nodeName = lc( $subNode->nodeName );
		#check each tag for empty content
		my $nodeContent = $subNode->textContent;

		#set each tag value from XML, as priority over other tool extraction
		if ( $nodeName =~ m#^path$# ) {
			#set $songFile from <path>
			$songFile = $nodeContent if ( $nodeContent );
			( $songFileName ) = fileparse( abspathL ( $songFile ) );
			if ( testL ( 'e', $songFile ) ) {
				toLog( "...Processing song no. " . $num . ": '" . $songFile . "'\n" );
				binmode( STDOUT, ":encoding(UTF-8)" );
				print "     - processing song no. " . $num . ": '" . $songFileName . "'\n";
			} else {
				warning( "Song no. " . $num . " file: '" . $songFile . "' does not exist" );
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

	#determine song file type to call best method for ID3 metadata extracting
	if ( $songFile =~ m#\.mkv$#i ) {
		mkvTools( \%tags, $songFile );
	} elsif ( $songFile =~ m#\.mp3$#i ) {
		exifTools( \%tags, $songFile );
	} elsif ( $songFile =~ m#\.m4a$#i ) {
		exifTools( \%tags, $songFile );
	} elsif ( $songFile =~ m#\.aiff$#i ) {
		exifTools( \%tags, $songFile );
	} elsif ( $songFile =~ m#\.(ogg|flac)$#i ) {
		exifTools( \%tags, $songFile );
	} else {
		exifTools( \%tags, $songFile );
	}

	#call method to clean and sort metadata tags
	cleanTags( \%tags, $songFile );

	#check if crucial tags have been set, try to determine from filename & path
	if ( ( ! $tags{title} ) || ( ! $tags{artist} ) || ( ! $tags{track} ) || ( ! $tags{album} ) || ( ! $tags{year} ) || ( ! $tags{length} ) ) {
		extractTags( \%tags, $songFile );
	}

	#check crucial tags in @listOfXmlTags for values
	toLog( "   - Scanning tags to see if any desired tags are not defined\n" );
	foreach my $tag ( @listOfXmlTags ) {
		if ( ! $tags{$tag} ) {
			#remove empty hash elements, so they don't get removed by 'ffmpeg'
			toLog( "     - '$tag' tag is not declared, removing key from hash\n" );
			delete $tags{$tag};
		}
	}
	
	#write metadata tags to song file
	writeTags( \%tags, $songFile, $songNode );
}

#write out close playlist XML tag
$writer->endTag( "playlist" );
$writer->end() or badExit( "Not able to write end() XML instance to \$writer object" );

#write out new playlist XML
my $xmlOutFH;
openL ( \$xmlOutFH, '>:encoding(UTF-8)', $playlistFile ) or badExit( "Not able to create '" . $playlistFile . "'" );
my $newfh = select $xmlOutFH; $| = 1; select $newfh;
print $xmlOutFH $writer or badExit( "Not able to write out XML to '$playlistFilename.xml'" );
close( $xmlOutFH );
toLog( "\n...Created playlist XML file: '$playlistFile'\n\n" );
toLog( " *WARNING*: There were " . $warnCnt . " warning(s) for process...\n\n\n" ) if ( $warnCnt );

#set error status for exit
$status = 0 unless ( $warnCnt > 1 );

#end log file
endLog( $status );
#echo status to console
if ( $status == 0 ) {
	print "\n...Finished Processing Successfully\n\n";
} elsif ( $status == 2 ) {
	print "\n...Finished Processing with (" . $warnCnt . ") Warnings\n\n";
} else {
	print "\n...Processing Failed\n\n";
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

#method to edit metadata for .mkv song file types
sub mkvTools {
	my ( $tagsRef, $songFile ) = @_;
	toLog( "   - Preparing for 'mkvextract' to export metadata tags from song file\n" );
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
	toLog( "   - Creating batch file wrapper for 'mkvextract': '" . $mkvBat . "'\n" );
	openL ( \$mkvBatFH, '>:encoding(UTF-8)', $mkvBat ) or badExit( "Not able to create temporary batch file to run 'mkvextract': $^E, $!" );
		my $oldFH = select $mkvBatFH; $| = 1; select $oldFH;
		print $mkvBatFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @mkvArgs );
	close( $mkvBatFH );

	#execute batch file wrapper to call 'mkvextract' command batch file
	toLog( "   - Executing batch file for 'mkvextract'\n" );
	my $stdOutErr;
	run3( $mkvBat, \undef, \$stdOutErr, \$stdOutErr );
	badExit( "Not able to run 'mkvextract' batch file wrapper: '" . $mkvBat . "', returned: " . $? . ", and: " . $stdOutErr ) if ( $? );

	#load XML data
	my $xmlFH;
	openL ( \$xmlFH, '<:encoding(UTF-8)', $songFileXml ) or badExit( "Not able to open XML file: '$songFileXml' for input" );
		binmode $xmlFH;
		my $dom = XML::LibXML->load_xml( IO => $xmlFH );
		badExit( "\n\nCouldn't load XML file: $songFileXml" ) unless ( $dom );
	close( $xmlFH );

	foreach my $xmlNode ( $dom->findnodes( '//Simple' ) ) {
		my $tagName = $xmlNode->findvalue( './Name' );
		my $tagValue = $xmlNode->findvalue( './String' );
		my $lcTagName = lc( $tagName );
		if ( grep /$lcTagName/, @listOfTagArrays ) {
			$tagsRef->{$lcTagName} = $tagValue unless ( $tagsRef->{$lcTagName} );
		}
	}

	toLog( "   - Cleaning up temporary 'mkvextract' files\n" );
	if ( testL ( 'e', $songFileXml ) ) {
		unlinkL ( $mkvBat ) or warning( "Not able to remove temporary 'mkvextract' batch file: '" . $mkvBat . "': $^E, $!" );
		unlinkL ( $songFileXml ) or warning( "Not able to remove XML data for song file: '" . $songFileXml . "': $^E, $!" );
	} else {
		badExit( "XML data not created for song file: '" . $songFile . "'" );
	}
}

#method to edit metadata for all other song file types
sub exifTools {
	my ( $tagsRef, $songFile ) = @_;
	toLog( "   - Preparing for 'ExifTool' to export metadata tags from song file\n" );
	#arguments for calling 'exiftool' command-line program
	my $exifToolArgsFile = $ENV{TEMP} . $FS . 'exiftoolargs-' . $num . '.txt';
	my @exifToolArgs = (
		#exiftool command-line program
		'"' . $exifToolCmd . '"',
		#read arguments from text file
		'-@ ' . '"' . $exifToolArgsFile . '"'
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
	toLog( "   - Creating batch file wrapper for 'exiftool': '" . $jsonBat . "'\n" );
	openL ( \$jsonBatFH, '>:encoding(UTF-8)', $jsonBat ) or badExit( "Not able to create temporary batch file to run 'exiftool': $^E, $!" );
		my $oldFH = select $jsonBatFH; $| = 1; select $oldFH;
		print $jsonBatFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @exifToolArgs );
	close( $jsonBatFH );
	#open/close 'exiftool' args file with arguments written to it
	toLog( "   - Creating argument file for 'exiftool': '" . $exifToolArgsFile . "'\n" );
	openL ( \$argsFH, '>:encoding(UTF-8)', $exifToolArgsFile ) or badExit( "Not able to create temporary arguments file to run 'exiftool': $^E, $!" );
		$oldFH = select $argsFH; $| = 1; select $oldFH;
		print $argsFH @exifToolFileArgs;
	close( $argsFH );

	#execute batch file wrapper to call 'exiftool' command batch file
	toLog( "   - Executing batch file for 'exiftool'\n" );
	my ( $songFileJson, $stdOutErr );
	run3( $jsonBat, \undef, \$songFileJson, \$stdOutErr );
	badExit( "ExifTool is not able to read the metadata of the file, returned: " . $? . ", and: " . $stdOutErr ) if ( $? );
	my $jsonTxt;
	if ( $songFileJson =~ m#(\n\[\{.+)#s ) {
		$jsonTxt = $1;
	}
	#parse json data for song file
	my $json = JSON->new->utf8();
	my $jsonDataRef = $json->decode( $jsonTxt );
	badExit( "JSON data not created for song file: '" . $songFile . "'" ) unless ( $jsonDataRef );

	#create hashref for hash of tags => values
	my $tagsInnerHashRef = \%{${$jsonDataRef}[0]};
	foreach my $key ( keys %{$tagsInnerHashRef} ) {
		#set to lowercase version of keys
		my $lcKey = lc( $key );
		#check MKV tag names and substitute to actual tag name
		foreach my $jsonRef ( @listOfTagArrays ) {
			if ( grep /$lcKey/, @{$jsonRef} ) {
				$tagsRef->{$lcKey} = $tagsInnerHashRef->{$key} unless ( $tagsRef->{$lcKey} );
			}
		}
	}
	toLog( "   - Cleaning up temporary 'exiftool' files\n" );
	if ( testL ( 'e', $jsonBat ) || testL ( 'e', $exifToolArgsFile ) ) {
		unlinkL ( $jsonBat ) or warning( "Not able to remove temporary 'exiftool' batch file: '" . $jsonBat . "': $^E, $!" );
		unlinkL ( $exifToolArgsFile ) or warning( "Not able to remove arguments file for 'exiftool': '" . $exifToolArgsFile . "': $^E, $!" );
	}
}

#checking each tag - to set/clean-up values and/or delete values
sub cleanTags {
	my ( $tagsRef, $songFile ) = @_;
	toLog( "   - Examining each tag retrieved\n" );

	#loop through array of arrays for possible tags to clean/set tag's value
	for my $tagsRow ( 0 .. $#listOfTagArrays ) {
		my $innerArrayRef = $listOfTagArrays[$tagsRow];
		#loop through inner array in reverse for each tag name, so priority is last (lowest array item) value set
		my $priorityTagName = $listOfTagArrays[$tagsRow][0];
		#save initial base value
		my $priorityTagValue = $tagsRef->{$priorityTagName};
		for ( my $tagsCol = $#{$innerArrayRef}; $tagsCol >= 1; $tagsCol-- ) {
			my $tagName = $listOfTagArrays[$tagsRow][$tagsCol];
			$tagsRef->{$priorityTagName} = $tagsRef->{$tagName} if ( $tagsRef->{$tagName} );
		}
		#reset base value to starting value, before setting all others
		$tagsRef->{$priorityTagName} = $priorityTagValue if ( $priorityTagValue );
		for my $tagsCol ( 1 .. $#{$innerArrayRef} ) {
			my $tagName = $listOfTagArrays[$tagsRow][$tagsCol];
			#only set when original had a value
			$tagsRef->{$tagName} = $tagsRef->{$priorityTagName} if ( $tagsRef->{$tagName} );
		}
	}

	foreach my $key ( keys %{$tagsRef} ) {
		#clean 'artist'
		if ( $key =~ m#^artist$# ) {
			#correct previous error in diagnostic testing for 'AC/DC'
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
				$tagsRef->{'album artist'} = $tagsRef->{albumartist} unless ( $tagsRef->{'album artist'} );
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
			#correct previous error in diagnostic testing for 'AC/DC'
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
			if ( $songFile =~ m#\.(ogg|flac)$#i ) {
				$tagsRef->{tracknumber} = $tagsRef->{$key} unless ( $tagsRef->{tracknumber} );
			} elsif ( $songFile =~ m#\.mkv$#i ) {
				$tagsRef->{'track number'} = $tagsRef->{$key} unless ( $tagsRef->{'track number'} );
			}
		} elsif ( $key =~ m#^year$#i ) {
			#remove duplicates, etc. from 'year' value
			$tagsRef->{$key} =~ s#^(\d\d\d\d).*$#$1#;
			if ( $tagsRef->{$key} =~ m#^$# ) {
				if ( ( $tagsRef->{date} ) && ( $tagsRef->{date} !~ m#^$# ) ) {
					#remove duplicates, etc.
					$tagsRef->{date} =~ s#^(\d\d\d\d).*$#$1#;
					$tagsRef->{$key} = $tagsRef->{date};
				}
			}
		} elsif ( $key =~ m#^bitrate$#i ) {
			#'bitrate' needs some format checks
			#match at least 6 digits (for 1,000's), but also capture any trailing digits but leaving the rest off)
			if ( $tagsRef->{$key} =~ s#^(\d{6}\d*).*$#$1# ) {
				$tagsRef->{$key} = $tagsRef->{$key} / 1000;
				$tagsRef->{$key} = int( $tagsRef->{$key} );
			} else {
				#strip any extraneous characters from digits otherwise
				$tagsRef->{$key} =~ s#^(\d+).*$#$1#;
			}
		} elsif ( $key =~ m#^comment$#i ) {
			#if 'comment' has previously used diagnostic text, remove it
			if ( ( $tagsRef->{$key} =~ m#created from filename#i ) || ( $tagsRef->{$key} =~ m#updated with default#i ) || ( $tagsRef->{$key} =~ m#^vendor$#i ) || ( $tagsRef->{$key} =~ m#^\s+$#i ) ) {
				$tagsRef->{$key} = '';
			}
		} elsif ( $key =~ m#^genre$#i ) {
			#if 'genre' has previously used diagnostic text, remove it
			if ( ( $tagsRef->{$key} =~ m#^music$#i ) || ( $tagsRef->{$key} =~ m#^none$#i ) || ( $tagsRef->{$key} =~ m#^other$#i ) ) {
				$tagsRef->{$key} = '';
			}
		} elsif ( $key =~ m#^length$#i ) {
			if ( ( $tagsRef->{$key} =~ m#^$# ) && ( $tagsRef->{duration} ) ) {
				$tagsRef->{$key} = $tagsRef->{duration};
			}
			#if 'length' set to approximate value, clean up
			if ( $tagsRef->{$key} =~ m#\(approx\)#i ) {
					$tagsRef->{$key} =~ s#^(.+)\s*\(approx\)\s*$#$1#i;
			} elsif ( $tagsRef->{$key} =~ m#^0\.# ) {
				delete $tagsRef->{$key};
			}
			#remove 'duration'
			delete $tagsRef->{duration};
			#length value can be given in HH:MM:SS format
			my ( $minutes, $seconds );
			if ( $tagsRef->{$key} =~ m#^(\d+:\d+:\d+\.?\d*)# ) {
				$seconds = convertLength( $1 );
				$tagsRef->{$key} = int( $seconds );
			} elsif ( $tagsRef->{$key} =~ m#^(\d?\d{5})\.?\d*# ) {
				#possible length in milliseconds
				$tagsRef->{$key} = int( $1 / 1000 );
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

sub extractTags {
	my ( $tagsRef, $songFile ) = @_;
	toLog( "   - <title> or <artist> (or other) tags have not been set, attempting to set from filename & path\n" );
	my ( $fileName, $filePath ) = fileparse( abspathL ( $songFile ) );

	#determine values from path of song file, using expected 'Music' directory
	if ( $filePath =~ m#\\Music\\([^\\]+)\\([^\\]+)\\#i ) {
		#song file is inside 'Album'\\'Artist'\\song file format
		my $artist = $1;
		my $album = $2;
		#add escape '\' to square brackets for match expression
		my $albumMatch = $album;
		$albumMatch =~ s#([\[\]])#\\$1#g;
		$tagsRef->{artist} = $artist if ( ! $tagsRef->{artist} );
		#determine if directory is actually a compilation with 'Disc' folders
		if ( ( $artist =~ m#^$albumMatch$#i ) || ( $album =~ m#^dis[ck]\s*\d+$#i ) ) {
			$tagsRef->{album} = $artist if ( ! $tagsRef->{album} );
		} else {
			$tagsRef->{album} = $album if ( ! $tagsRef->{album} );
		}
		#correct previous error in diagnostic testing for 'AC/DC'
		$tagsRef->{artist} =~ s#^AC[_ ]DC$#AC\/DC#i;
		if ( ! $tagsRef->{albumartist} ) {
			$tagsRef->{albumartist} = $tagsRef->{artist};
			#remove extra artist info
			$tagsRef->{albumartist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
		}
	} elsif ( $filePath =~ m#\\Music\\([^\\]+)\\#i ) {
		#song file is inside 'Album\\song file' format
		$tagsRef->{artist} = $1 if ( ! $tagsRef->{artist} );
		$tagsRef->{album} = $1 if ( ! $tagsRef->{album} );
		$tagsRef->{albumartist} = $1 if ( ! $tagsRef->{albumartist} );
		#correct previous error in diagnostic testing for 'AC/DC'
		$tagsRef->{artist} =~ s#^AC[_ ]DC$#AC\/DC#i;
		#remove extra artist info
		$tagsRef->{albumartist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
		#correct previous error in diagnostic testing for 'AC/DC'
		$tagsRef->{albumartist} =~ s#^AC[_ ]DC$#AC\/DC#i;
	}

	if ( $fileName =~ m#((\d)\-)?(\d+)\s*\-?\s+([^\\]+)\.(aac|alac|flac|m4a|mka|mkv|mp3|ogg|wma)$#i ) {
		$tagsRef->{title} = $4 if ( ! $tagsRef->{title} );
		if ( ! $tagsRef->{track} ) {
			$tagsRef->{track} = $3;
		}
		if ( ( $2 ) && ( ! $tagsRef->{discnumber} ) ) {
			$tagsRef->{discnumber} = $2;
		}
	}

	if ( ( ! $tagsRef->{length} ) && ( ! $tagsRef->{duration} ) ) {
		#set ffprobe command for finding 'length' on song files that don't have the value
		toLog( "   - Preparing command for 'ffprobe' to determine 'length'\n" );
		my @ffprobeCmd = (
			'"' . $ffprobeCmd . '"',
			'-v error',
			'-show_entries format=duration',
			'-of default=noprint_wrappers=1:nokey=1',
			'"' . $songFile . '"'
		);
	
		#call 'ffprobe' to extract length of song file
		my $length;
		#start process to create batch file with 'ffprobe' command
		my $ffprobeBat = $ENV{TEMP} . $FS . 'ffprobe-' . $num . '.bat';
		#batch file handle ref
		my $ffprobeFH;
		#open/close batch file with commands written to it
		toLog( "   - Creating 'ffprobe' batch file: '" . $ffprobeBat . "'\n" );
		openL ( \$ffprobeFH, '>:encoding(UTF-8)', $ffprobeBat ) or badExit( "Not able to create temporary batch file to run 'ffprobe': $^E, $!" );
			my $oldfh = select $ffprobeFH; $| = 1; select $oldfh;
			#write empty line to batch file in case of file header conflict
			print $ffprobeFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @ffprobeCmd );
		close( $ffprobeFH );
	
		toLog( "   - Executing 'ffprobe' batch file\n" );
		run3( $ffprobeBat, \undef, \$length );
		if ( $length =~ m#\n(\d+)# ) {
			$length = $1;
			my $minutes = $length / 60;
			$minutes = sprintf "%2d", $minutes;
			my $remSecs = $length - ( $minutes * 60 );
			$remSecs = sprintf "%.02d", $remSecs;
			$tagsRef->{minutes} = $minutes . ':' . $remSecs;
			$tagsRef->{length} = int( $length );
		}
	
		if ( ( ! $tagsRef->{title} ) && ( ! $tagsRef->{artist} ) ) {
			warning( "Could not determine <title>, <artist>, or possibly other tags" );
		}
	
		toLog( "   - Cleaning up temporary 'ffprobe' files\n" );
		if ( testL ( 'e', $ffprobeBat ) ) {
			unlinkL ( $ffprobeBat ) or warning( "Not able to remove temporary 'ffprobe' batch file: '" . $ffprobeBat . "': $^E, $!" );
		}
	}

	#set 'discnumber' to default value, if not present
	if ( ! $tagsRef->{discnumber} ) {
		$tagsRef->{discnumber} = 1;
	}
}

#write tags to metadata of song file, using 'ffmpeg'
sub writeTags {
	my ( $tagsRef, $songFile, $songNode ) = @_;

	#write out tags to XML
	toLog( "   - Writing XML nodes to XML playlist\n" );
	my $numberVal = $songNode->findvalue( './@number' );
	#write out XML 'song' element
	$writer->startTag( "song", number => $numberVal );

	#mirror 'subnodes', but in particular order
	toLog( "   - Reordering XML nodes\n" );
	my $newSongNode = $songNode->cloneNode( 1 );
	$newSongNode->removeChildNodes();
	#add children nodes back in specified order
	foreach my $nodeName ( @listOfXmlTags ) {
		if ( ! $songNode->exists( $nodeName ) ) {
			warning( "'" . $nodeName . "' does not exist in XML instanace" );
		} else {
			#determine if multiple nodes with same name - warn & don't add to $newSongNode
			my $nodeCnt = 0;
			foreach ( $songNode->findnodes( $nodeName ) ) {
				++$nodeCnt;
			}
			if ( $nodeCnt > 1 ) {
				warning( "Song node has duplicate tags in song no. " . $numberVal . ": '" . $nodeName . "'" );
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
	$writer->endTag( "song" );

	#prepare file for ffmpeg to write metadata (can't write out to self) - copy original to temp file
	toLog( "   - Creating temporary song file for 'ffmpeg' to use as original song file\n" );
	my ( $songFileName, $songFilePath ) = fileparse( abspathL ( $songFile ) );
	my $tmpSongFileName = $songFileName;
	if ( $tmpSongFileName =~ s#(.)\.(\w\w\w\w?)$#$1_tmp\.$2#i ) {
		#verifying file is not left open by other process
		close( $songFilePath . $tmpSongFileName );
		close( $songFilePath . $songFileName );
		sleep 1;
		renameL ( $songFilePath . $songFileName, $songFilePath . $tmpSongFileName );
		if ( ! testL ( 'e', $songFilePath . $tmpSongFileName ) ) {
			badExit( "Not able to rename song file: '" . $songFilePath . $songFileName . "' to temp file: '" . $songFilePath . $tmpSongFileName . "', $!, $^E\n" );
		}
	}

	#create array of metadata tag args to add in ffmpeg (will splice into command args array)
	toLog( "   - Creating 'ffmpeg' arguments for submission of metadata to song file\n" );
	my @newMeta;
	foreach my $key ( keys %{$tagsRef} ) {
		#create variable for metadata key (keys with spaces can cause to fail content test)
		my $metaKey = $key;
		#remove escaped single quote from entries (added in previous versions v1.4 & v1.5 of 'update_ID3_tags')
		$metaKey =~ s#\\'##g;
		$tagsRef->{$key} =~ s#\\'##g;
		#use Unicode curved double quote in key
		$metaKey =~ s#"#\x{94}#g;
		#use Unicode curved double quote in value
		$tagsRef->{$key} =~ s#"#\x{94}#g;
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

	toLog( "   - Building 'ffmpeg' command statement\n" );
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
	toLog( "   - System command to rewrite song metadata with 'ffmpeg': '" . join( " ", @ffmpeg ) . "'\n" );

	#start process to create batch file with 'ffmpeg' commands
	my $ffmpegBat = $ENV{TEMP} . $FS . 'ffmpeg-' . $num . '.bat';
	#batch file handle ref
	my $ffmpegFH;
	#open/close batch file with commands written to it
	toLog( "   - Creating batch file with 'ffmpeg' commands: '" . $ffmpegBat . "'\n" );
	openL ( \$ffmpegFH, '>:encoding(UTF-8)', $ffmpegBat ) or badExit( "Not able to create temporary batch file to run 'ffmpeg': $^E, $!" );
		my $prevfh = select $ffmpegFH; $| = 1; select $prevfh;
		#write empty line to batch file in case of file header conflict
		print $ffmpegFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @ffmpeg );
	close( $ffmpegFH );

	#execute batch file wrapper to call 'ffmpeg' commands batch file
	toLog( "   - Executing batch file for 'ffmpeg'\n" );
	my $outAndError;
	run3( $ffmpegBat, \undef, \$outAndError, \$outAndError );
	badExit( "Not able to run batch file wrapper: " . $ffmpegBat . ", returned: " . $? . ", and: " . $outAndError ) if ( $? );

	#removing temp song file & 'ffmpeg' batch file, if successful
	toLog( "   - Removing temporary song files & batch files\n" );
	if ( testL ( 'e', $songFile ) ) {
		unlinkL ( $songFilePath . $tmpSongFileName ) or warning( "Not able to remove temporary song file: '" . $songFilePath . $tmpSongFileName . "': $^E, $!" );
		unlinkL ( $ffmpegBat ) or warning( "Not able to remove temporary 'ffmpeg' batch file: '" . $ffmpegBat . "': $^E, $!" );
	} else {
		badExit( "Not able to remove temporary song file & batch files for song file: '" . $songFile . "'" );
	}
}

#warning process
sub warning {
	my ( $msg ) = @_;
	#increase overall warning count
	++$warnCnt;
	$status = 2;
	toLog( "\n *WARNING* (" . $warnCnt . "): $msg,\n" . shortmess() . "\n" );
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

	openL ( \$logFH, '>:encoding(UTF-8)', $log ) or badExit( "Not able to create log file\n\ttrying to create <$log>" );
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

	if ( $stat == 0 ) {
		$stat = 'Completed';
	} elsif ( $stat == 2 ) {
		$stat = 'Completed with Warnings';
		toLog( "\n\n   (" . $warnCnt . ") Warnings were detected\n\n" );
	} else {
		$stat = 'Failed';
	}
	toLog( "\n$Sep\n$time  $stat$ver_info\n$Sep\n\n" );
	close( $logFH );
}
