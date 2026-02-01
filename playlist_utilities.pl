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
#                                  tkStart1), changed Tk font to 'Lucida Sans Unicode', changed Warning 
#                                  count to hash of warnings per function & global overall count when 
#                                  logging warnings, standardized error & warning message format, cleaned 
#                                  up some code formatting, changed test for selection (or passing) of 
#                                  file/directory to $filePath in function subroutines, added clean-up of 
#                                  warning within function subroutine to return to MainLoop, changed 
#                                  handling of warning/badExit messages to decode raw message into Unicode 
#                                  characters, removed $FS when using $dirName (which ends in backslash), 
#                                  added some log formatting
#
#
#   TO-DO:
#         1) create functions to do items in Desc, modifying tkStart2
#
#**********************************************************************************************************

my $Version = "1.1";

use strict;
use warnings;
use utf8::all;
use feature 'unicode_strings';
use open ':std', IO => ':raw :encoding(UTF-8)';

use Carp qw( carp croak longmess shortmess );
use Config;
use Data::Dumper qw( Dumper );
use Encode qw( decode );
use File::Basename qw( fileparse );
#uncomment line below to specify config file for ExifTool
#BEGIN { $Image::ExifTool::configFile = 'C:\Users\rich\.ExifTool_config' }
use Image::ExifTool qw( :Public );
use IPC::Run3;
use JSON;
use Tk;
use Tk::DialogBox;
use XML::LibXML;
use XML::Writer;
use Win32;
use Win32::LongPath qw( abspathL chdirL getcwdL openL renameL testL unlinkL );

#Tk setup
#colors from rgb.txt
use constant TK_COLOR_BG		=> 'SlateGray1';
use constant TK_COLOR_FIELD	=> 'AliceBlue';
use constant TK_COLOR_FG		=> 'black';
use constant TK_COLOR_ABG		=> 'goldenrod1';
use constant TK_COLOR_LGREEN	=> 'palegreen';
use constant TK_COLOR_GREYBUT	=> 'gray54';
use constant TK_COLOR_LRED		=> 'tomato';
#font using Unix-centric font name:-foundry-family-weight-slant-setwidth-addstyle-pixel-point-resx-resy-spacing-width-charset-encoding, "*" defaults and last "*" defaults remaining values
use constant TK_FNT_BIGGER		=> "-*-{Lucida Sans Unicode}-bold-r-normal-*-18-*";
use constant TK_FNT_BIGB		=> "-*-{Lucida Sans Unicode}-bold-r-normal-*-14-*";
use constant TK_FNT_BIG			=> "-*-{Lucida Sans Unicode}-medium-r-normal-*-14-*";
use constant TK_FNT_BI			=> "-*-{Lucida Sans Unicode}-bold-i-normal-*-12-*";
use constant TK_FNT_B			=> "-*-{Lucida Sans Unicode}-bold-r-normal-*-12-*";
use constant TK_FNT_I			=> "-*-{Lucida Sans Unicode}-medium-i-normal-*-12-*";

umask 000;

#global variables
my $FS = '\\';
my $Sep = "-" x 110;
my $SEP = "=" x 110;
my ( $dirName, $fileName, $filePath, $log, $stat );
#log file handles for function log vs. main log
my ( $funcLogFH, $logFH );
#determine program name
my $progName = progName();
#set warning hash
my %warn;

#command-line tools for song metadata manipulation
my $exifToolCmd = 'C:\Strawberry\perl\site\bin\exiftool';
my $ffprobeCmd = 'C:\Users\rich\Documents\Dev\ffmpeg\FFmpeg-exe\bin\ffprobe.exe';
my $mkvCmd = 'C:\Program Files\MKVToolNix\mkvextract.exe';

#Tk variables
my $proc = 'Waiting on command...';

#array list of possible ID3 tag names in nested arrays (priority is 1st item in sub-array)
my @listOfTagArrays = (
	[ 'albumartist', 'album_artist', 'albumartistsortorder', 'albumartistsort' ],
	[ 'album', 'originalalbum', 'albumsortorder', 'albumsort' ],
	[ 'artist', 'originalartist', 'artistsortorder', 'artistsort', 'ensemble', 'band', 'author' ],
	[ 'bitrate', 'bit_rate', 'audiobitrate' ],
	[ 'comment', 'comment-xxx' ],
	[ 'composer' ],
	[ 'discnumber', 'disc', 'partofset', 'disk' ],
	[ 'length', 'duration' ],
	[ 'genre' ],
	[ 'publisher' ],
	[ 'title', 'titlesortorder', 'titlesort' ],
	[ 'track', 'tracknumber', 'part_number', 'trackid' ],
	[ 'year', 'date', 'originaldate', 'originalreleaseyear', 'release_date', 'datetimeoriginal', 'recordingdates' ]
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

#declare log file handle, start logging
startLog();

#process variables
if ( testL ( 'e', $ARGV[0] ) ) {
	$filePath = $ARGV[0];
	#directory separator default for Windows command line
	$filePath =~ s#[\/\\]#$FS#g;
	( $fileName, $dirName ) = fileparse( abspathL ( $filePath ) );
	if ( ! testL ( 'd', $dirName ) ) {
		$dirName = getcwdL();
	}
	$filePath = "$dirName$fileName";
} elsif ( $ARGV[0] ) {
		badExit( undef, "Optional argument(s) incorrect, single possible correct argument should be playlist XML filename: \n   perl C:\\git_playlist\\$progName.pl \[PLAYLIST_XML_FILENAME\]" );
}

#create initial window and pass to tk caller, start overall logging
my $M->{'window'} = MainWindow->new();
tkMainWindow();
MainLoop;

#----------------------------------------------------------------------------------------------------------
#set array of tags to lowercase keys for easier processing of XML output
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
#convert HH:MM:SS length into seconds
sub convertLength
#----------------------------------------------------------------------------------------------------------
{
    my @time_parts = reverse(split(":", $_[0]));
    my $accum = 0;
    for (my $i = 0; $i < @time_parts; $i++) {
        $accum += $time_parts[$i] * 60 ** $i;
    }
    return $accum;
}

#----------------------------------------------------------------------------------------------------------
sub dateTime
#----------------------------------------------------------------------------------------------------------
{
	my ( $sec, $min, $hr, $day, $monNum, $yr );
	my $tod = 'am';
	my $now = {};
	
	#get date and time
	( undef, $min, $hr, $day, $monNum, $yr ) = localtime( time() );

	#modify for output
	my $mon = ( "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec" )[$monNum];
	$min = sprintf( "%02d",$min );
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
#return the name of the program currently running
sub progName
#----------------------------------------------------------------------------------------------------------
{
	my $prog;

	#running under PerlApp, so get name of program
	if ( defined $PerlApp::VERSION ) { $prog = PerlApp::exe(); }
	# Not running PerlAppified, so file should already exist
	else { $prog = fileparse( $0 ); }

	$prog =~ s#\..*$##;
	return( $prog );
}

#----------------------------------------------------------------------------------------------------------
# read directory and build a list of XML files
sub getFiles
#----------------------------------------------------------------------------------------------------------
{
	my ( @fileFolder, @files );

	updStatus( undef, 'Building list of files...' );

	opendir DIR, $dirName or badExit( undef, "Could not open directory\n looking in: '$dirName'" );
		@fileFolder = readdir DIR;
	closedir DIR;
	@files = grep m/\.xml$/i, @fileFolder;
	unless ( scalar( @files ) ) {
		badExit( undef, "No files were found in directory\n looking in: '$dirName'" );
	}
	
	#change to working directory
	chdirL( $fileFolder[0] );

	return( @files );
}

#----------------------------------------------------------------------------------------------------------
sub tkMainWindow
#----------------------------------------------------------------------------------------------------------
{
	#main window
	$M->{'window'}->configure( -bg=>TK_COLOR_BG, -fg=>TK_COLOR_FG, -title=>"$progName..." );
	
	#frames
	my $title    = $M->{'window'}->Frame( -bg=>TK_COLOR_BG )->grid( -row=>'0' );
	my $choose	 = $M->{'window'}->Frame( -bg=>TK_COLOR_BG )->grid( -row=>'1' );
	my $status   = $M->{'window'}->Frame( -bg=>TK_COLOR_BG )->grid( -row=>'2', -sticky=>'we' );
	my $buttons  = $M->{'window'}->Frame( -bg=>TK_COLOR_BG )->grid( -row=>'3' );
	my $statbar  = $M->{'window'}->Frame()->grid( -row=>'4', -sticky=>'we' );
	
	#title frame
	$title->Label(
		-bg=>TK_COLOR_BG,
		-fg=>TK_COLOR_FG,
		-font=>TK_FNT_BIGGER,
		-text=>"$progName Tool"
	)->pack( -pady=>'0' );
	$title->Label(
		-bg=>TK_COLOR_BG,
		-fg=>TK_COLOR_FG,
		-font=>TK_FNT_I,
		-text=>"Version: $Version",
		-anchor=>'e'
	)->pack( -side=>'right', -pady=>'0' );
	
	#directory or file choose frame:
	#   change the -text value to 'File:' for files
	#   change the -textvariable value to \$filePath for files
	#   change the -command value to '[\&tkGetFile, $filePath]' for files
	$choose->Label(
		-text=>'File:',
		-font=>TK_FNT_BIGB,
		-bg=>TK_COLOR_BG,
		-fg=>TK_COLOR_FG
	)->pack( -side=>'left' );
	my $entry = $choose->Entry(
		-textvariable=>\$filePath,
		-width=>'30',
		-bg=>TK_COLOR_FIELD,
		-fg=>TK_COLOR_FG
	)->pack( -side=>'left' );
	$entry->xview( 'end' );
	$M->{'select'} = $choose->Button(
		-text => "...",
		-command => [ \&tkGetFile, $filePath ],
		-bg => TK_COLOR_BG,
		-fg => TK_COLOR_FG,
		-activebackground=>TK_COLOR_ABG,
		-width => 3
	)->pack( -side=>'left', -padx=>'2', -pady=>'8' );

	#status frame
	my $statframe = $status->Frame( -relief=>'sunken', -borderwidth=>'2', -bg=>TK_COLOR_FIELD )->pack( -padx=>'4', -fill=>'x' );
	$M->{'progress'}= $statframe->Label( -bg=>TK_COLOR_FIELD, -textvariable=>\$stat )->pack( -side=>'left', -fill=>'x' );

	#buttons frame
	$M->{'update'} = $buttons->Button(
		-text=>'Update ID3 Tags',
		-font=>TK_FNT_B,
		-command=>\&update_ID3_tags,
		-borderwidth=>'4',
		-bg=>TK_COLOR_BG,
		-fg=>TK_COLOR_FG,
		-activebackground=>TK_COLOR_LGREEN,
		-disabledforeground=>TK_COLOR_GREYBUT,
		-width=>'11'
	)->pack( -side=>'left', -padx=>'2', -pady=>'8' );
	$M->{'func2'} = $buttons->Button(
		-text=>'Function 2',
		-font=>TK_FNT_B,
		-command=>\&tkStart2,
		-borderwidth=>'4',
		-bg=>TK_COLOR_BG,
		-fg=>TK_COLOR_FG,
		-activebackground=>TK_COLOR_ABG,
		-disabledforeground=>TK_COLOR_GREYBUT,
		-width=>'11'
	)->pack( -side=>'left', -padx=>'2', -pady=>'8' );
	$M->{'exit'} = $buttons->Button(
		-text=>'Exit',
		-font=>TK_FNT_B,
		-command=>\&tkExit,
		-borderwidth=>'4',
		-bg=>TK_COLOR_BG,
		-fg=>TK_COLOR_FG,
		-activebackground=>TK_COLOR_LRED,
		-width=>'11'
	)->pack( -padx=>'2', -pady=>'8' );

	#status bar frame
	my $leftframe = $statbar->Frame( -borderwidth=>'2' )->pack( -side=>'left' );
	$M->{'bottomLeft'}= $leftframe->Label( -text=>' Status ' )->pack( -side=>'left' );
	my $frame2 = $statbar->Frame( -relief=>'sunken', -borderwidth=>'2' )->pack( -side=>'left', -fill=>'x' );
	$M->{'bottomRight'}= $frame2->Label( -textvariable=>\$proc )->pack( -side=>'left' );
	
	#output date and time
	my $now = dateTime();
	my $mesg = $now->{'date'} . " at " . $now->{'time'};
	updStatus( $mesg, undef );
	$M->{'window'}->update();
	
	#set focus
	if ( $dirName ) {
		$M->{'update'}->focus();
	} else {
		$M->{'select'}->focus();
	}
}

#----------------------------------------------------------------------------------------------------------
#update status in window, 1st arg is current status and 2nd arg is current process
sub updStatus
#----------------------------------------------------------------------------------------------------------
{
	if ( $_[0] ) { $stat = $_[0] };
	if ( $_[1] ) { $proc = $_[1] };

	$M->{'window'}->update();
}

#----------------------------------------------------------------------------------------------------------
#creates prompt window
#  -returns user's response (name of button)
#  -if 1st arg specified as 'warning' or 'error', will display that image and include in window title
#  -3rd arg, and so forth, create buttons
#  -3rd arg button has default focus
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
		-title=>$title,
		-background=>TK_COLOR_BG,
		-buttons=>[ @buttons ],
	);
	$dialog->transient( '' );
	$dialog->add(
		'Label',
		-bitmap=>$image,
		-background=>TK_COLOR_BG
	)->pack( -side=>'left', -padx=>'8' );
	$dialog->add(
		'Label',
		-text=>$txt,
		-font=>TK_FNT_BIG,
		-background=>TK_COLOR_BG
	)->pack( -side=>'left' );

	#return user choice
	my $ans = $dialog->Show( -global );
	return( $ans );
}

#----------------------------------------------------------------------------------------------------------
#user chooses directory
sub tkGetDir
#----------------------------------------------------------------------------------------------------------
{
	my ( $filePath ) = @_;
	my $dir;

	if ( testL ( 'e', $filePath ) ) {
		( undef, $dir ) = fileparse( abspathL ( $filePath ) );
	}

	$filePath = $M->{'window'}->chooseDirectory(
		-initialdir=>$dir,
		-title=>'Choose Directory...'
	);

	if ( $dir ) {
		$dirName = $dir;
	}
}

#----------------------------------------------------------------------------------------------------------
#user chooses file
sub tkGetFile
#----------------------------------------------------------------------------------------------------------
{
	my ( $getFilePath ) = @_;

	my ( $dir, $file );
	if ( $getFilePath ) {
		( $file, $dir ) = fileparse( abspathL ( $getFilePath ) );
	}

	$getFilePath = $M->{'window'}->getOpenFile(
		-initialdir=>$dir,
		-initialfile=>$file,
		-title=>'Choose File...'
	);

	if ( $getFilePath ) {
		$filePath = $getFilePath;
		if ( $dir && $file ) {
			$fileName = $file;
			$dirName = $dir;
		} else {
			( $fileName, $dirName ) = fileparse( abspathL ( $filePath ) );
		}
	}
}

#----------------------------------------------------------------------------------------------------------
#second function
sub tkStart2
#----------------------------------------------------------------------------------------------------------
{
	#must specify file or directory
	unless ( $filePath ) {
		my $ans = promptUser( 'warning', "No file (or directory) selected or passed,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( 'Function2', "User chose to stop process,\n no file (or directory) selected or passed" );
		}
		$M->{'select'}->focus();

		return;
	}

	#change buttons to indicate process started
	$M->{'update'}->configure(
		-text=>'update_ID3_tags',
		-font=>TK_FNT_BI,
		-state=>'disabled',
		-fg=>TK_COLOR_GREYBUT,
		-bg=>TK_COLOR_BG,
		-activebackground=>TK_COLOR_BG,
	);
	$M->{'func2'}->configure(
		-text=>'Running...',
		-font=>TK_FNT_B,
		-state=>'disabled',
		-fg=>TK_COLOR_GREYBUT,
		-bg=>TK_COLOR_FIELD,
		-activebackground=>TK_COLOR_FIELD
	);
	$M->{'exit'}->focus();

	#starting log process
	startLog( 'Function2' );
	
	#process ended
	my $folderNm;
	( $folderNm ) = fileparse( abspathL ( $dirName ) );
	updStatus( "Finished processing \"" . $folderNm . "\"" );
	tkEnd( 'Function2' );
}

#----------------------------------------------------------------------------------------------------------
#function to update ID3 metadata with XML input for song files
sub update_ID3_tags
#----------------------------------------------------------------------------------------------------------
{
	#must specify file or directory
	unless ( $filePath ) {
		my $ans = promptUser( 'warning', "No file (or directory) selected or passed,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( 'update_ID3_tags', "User chose to stop process,\n no file (or directory) selected or passed" );
		}
		$M->{'select'}->focus();
		return;
	}

	#change buttons to indicate process started
	$M->{'update'}->configure(
		-text=>'Updating...',
		-font=>TK_FNT_B,
		-state=>'disabled',
		-fg=>TK_COLOR_GREYBUT,
		-bg=>TK_COLOR_FIELD,
		-activebackground=>TK_COLOR_FIELD
	);
	$M->{'func2'}->configure(
		-text=>'Function2',
		-font=>TK_FNT_BI,
		-state=>'disabled',
		-fg=>TK_COLOR_GREYBUT,
		-bg=>TK_COLOR_BG,
		-activebackground=>TK_COLOR_BG,
	);
	$M->{'exit'}->focus();

	#starting log process
	startLog( 'update_ID3_tags' );
	
	#separate out playlist XML filename and directory
	my ( $playlistFilename, $playlistFilePath ) = fileparse( abspathL ( $filePath ) );
	$playlistFilename =~ s#\.\w\w\w?$##;
	#echo status to console
	toLog( 'update_ID3_tags', 'Processing playlist XML file: "' . $playlistFilename . ".xml\"...\n" );
	binmode( STDOUT, ":encoding(UTF-8)" );
	print "\n   Processing '$playlistFilename.xml'\n";
	
	#load playlist XML
	my $xmlFH;
	openL ( \$xmlFH, '<:encoding(UTF-8)', $filePath ) or badExit( 'update_ID3_tags', "Not able to open playlist XML file for reading: '" . $filePath . "'" );
		binmode $xmlFH;
		my $dom = XML::LibXML->load_xml( IO => $xmlFH );
		badExit( 'update_ID3_tags', "\n\nCouldn't load playlist XML file: $playlistFilename.xml" ) unless ( $dom );
	
	#determine playlist name
	my $playlistName;
	if ( $dom->findnodes( '/playlist/@name' ) ) {
		$playlistName = $dom->findnodes( '/playlist/@name' );
	} else {
		$playlistName = $playlistFilename;
	}
	
	#set output object for playlist XML
	toLog( 'update_ID3_tags', "- Initializing XML playlist\n" );
	my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
	badExit( 'update_ID3_tags', "Not able to create new XML::Writer object" ) if ( ! $writer );
	#write XML Declaration
	$writer->xmlDecl( "UTF-8" ) or badExit( 'update_ID3_tags', "Not able to write out XML Declaration" );
	$writer->comment( "*IMPORTANT*: Only 1 attribute/value pair is allowed per each child node of <song>" );
	#write date into root <playlist> tag attribute, with playlist name as attribute
	toLog( 'update_ID3_tags', "- Setting date/time for playlist\n" );
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
					toLog( 'update_ID3_tags', "...Processing song no. " . $num . ": '" . $songFile . "'\n" );
					binmode( STDOUT, ":encoding(UTF-8)" );
					print "     - processing song no. " . $num . ": '" . $songFileName . "'\n";
				} else {
					binmode( STDOUT, ":encoding(UTF-8)" );
					print "    Song no. " . $num . " : '" . $songFileName . "' does not exist\n";
					warning( 'update_ID3_tags', "Song no. " . $num . " : '" . $songFile . "' does not exist" );
					tkEnd( 'update_ID3_tags' );
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
	
		#determine song file type to call best method for ID3 metadata extracting
		if ( $songFile =~ m#\.mkv$#i ) {
			mkvTools( $num, \%tags, $songFile );
		} elsif ( $songFile =~ m#\.mp3$#i ) {
			exifTools( $num, \%tags, $songFile );
		} elsif ( $songFile =~ m#\.m4a$#i ) {
			exifTools( $num, \%tags, $songFile );
		} elsif ( $songFile =~ m#\.aiff$#i ) {
			exifTools( $num, \%tags, $songFile );
		} elsif ( $songFile =~ m#\.(ogg|flac)$#i ) {
			exifTools( $num, \%tags, $songFile );
		} else {
			exifTools( $num, \%tags, $songFile );
		}
	
		#call method to clean and sort metadata tags
		cleanTags( \%tags, $songFile );
	
		#check if crucial tags have been set, try to determine from filename & path
		if ( ( ! $tags{title} ) || ( ! $tags{artist} ) || ( ! $tags{track} ) || ( ! $tags{album} ) || ( ! $tags{year} ) || ( ! $tags{length} ) ) {
			extractTags( $num, \%tags, $songFile );
		}
	
		#check crucial tags in @listOfXmlTags for values
		toLog( 'update_ID3_tags', "   - Scanning tags to see if any desired tags are not defined\n" );
		foreach my $tag ( @listOfXmlTags ) {
			if ( ! $tags{$tag} ) {
				#remove empty hash elements, so they don't get removed by 'ffmpeg'
				toLog( 'update_ID3_tags', "     - '$tag' tag is not declared, removing key from hash\n" );
				delete $tags{$tag};
			}
		}
		
		#write metadata tags to song file
		writeTags( $num, $writer, \%tags, $songFile, $songNode );
	}
	
	#write out close playlist XML tag
	$writer->endTag( "playlist" );
	$writer->end() or badExit( 'update_ID3_tags', "Not able to write end() XML instance to \$writer object" );
	
	#write out new playlist XML
	my $xmlOutFH;
	openL ( \$xmlOutFH, '>:encoding(UTF-8)', $filePath ) or badExit( 'update_ID3_tags', "Not able to create '" . $filePath . "'" );
	my $newfh = select $xmlOutFH; $| = 1; select $newfh;
	print $xmlOutFH $writer or badExit( 'update_ID3_tags', "Not able to write out XML to '$playlistFilename.xml'" );
	close( $xmlOutFH );
	toLog( 'update_ID3_tags', "\n...Created playlist XML file: '$filePath'\n\n" );
	toLog( 'update_ID3_tags', " *WARNING*: There were " . $warn{update_ID3_tags} . " warning(s) for process...\n\n\n" ) if ( $warn{update_ID3_tags} );

	#process ended
	my $folderNm;
	( $folderNm ) = fileparse( abspathL ( $dirName ) );
	updStatus( "Finished processing \"" . $folderNm . "\"" );
	tkEnd( 'update_ID3_tags' );
}

#----------------------------------------------------------------------------------------------------------
#method to edit metadata for .mkv song file types
sub mkvTools
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $tagsRef, $songFile ) = @_;
	toLog( 'update_ID3_tags', "   - Preparing for 'mkvextract' to export metadata tags from song file\n" );
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
	toLog( 'update_ID3_tags', "   - Creating batch file wrapper for 'mkvextract': '" . $mkvBat . "'\n" );
	openL ( \$mkvBatFH, '>:encoding(UTF-8)', $mkvBat ) or badExit( 'update_ID3_tags', "Not able to create temporary batch file to run 'mkvextract': '" . $mkvBat . "'" );
		my $oldFH = select $mkvBatFH; $| = 1; select $oldFH;
		print $mkvBatFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @mkvArgs );
	close( $mkvBatFH );

	#execute batch file wrapper to call 'mkvextract' command batch file
	toLog( 'update_ID3_tags', "   - Executing batch file for 'mkvextract'\n" );
	my ( $rawStdOutErr, $stdOutErr );
	run3( $mkvBat, \undef, \$rawStdOutErr, \$rawStdOutErr );
	$stdOutErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdOutErr );
	badExit( 'update_ID3_tags', "Not able to run 'mkvextract', returned:\n" . $stdOutErr ) if ( $? || $stdOutErr);

	#load XML data
	my $xmlFH;
	openL ( \$xmlFH, '<:encoding(UTF-8)', $songFileXml ) or badExit( 'update_ID3_tags', "Not able to open XML file: '$songFileXml' for input" );
		binmode $xmlFH;
		my $dom = XML::LibXML->load_xml( IO => $xmlFH );
		badExit( 'update_ID3_tags', "\n\nCouldn't load XML file: $songFileXml" ) unless ( $dom );
	close( $xmlFH );

	foreach my $xmlNode ( $dom->findnodes( '//Simple' ) ) {
		my $tagName = $xmlNode->findvalue( './Name' );
		my $tagValue = $xmlNode->findvalue( './String' );
		my $lcTagName = lc( $tagName );
		if ( grep /$lcTagName/, @listOfTagArrays ) {
			$tagsRef->{$lcTagName} = $tagValue unless ( $tagsRef->{$lcTagName} );
		}
	}

	toLog( 'update_ID3_tags', "   - Cleaning up temporary 'mkvextract' files\n" );
	if ( testL ( 'e', $songFileXml ) ) {
		my $unlinkErr;
		my $fileDel = unlinkL ( $mkvBat );
		$unlinkErr = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( 'update_ID3_tags', "Not able to remove temporary 'mkvextract' batch file: '" . $mkvBat . "', returned:\n" . $unlinkErr ) if ( ! $fileDel );
		$fileDel = unlinkL ( $songFileXml );
		$unlinkErr = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( 'update_ID3_tags', "Not able to remove XML data for song file: '" . $songFileXml . "', returned:\n" . $unlinkErr ) if ( ! $fileDel );
	} else {
		badExit( 'update_ID3_tags', "XML data not created for song file: '" . $songFile . "'" );
	}
}

#----------------------------------------------------------------------------------------------------------
#method to edit metadata for all other song file types
sub exifTools
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $tagsRef, $songFile ) = @_;
	toLog( 'update_ID3_tags', "   - Preparing for 'ExifTool' to export metadata tags from song file\n" );
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
	toLog( 'update_ID3_tags', "   - Creating batch file wrapper for 'exiftool': '" . $jsonBat . "'\n" );
	openL ( \$jsonBatFH, '>:encoding(UTF-8)', $jsonBat ) or badExit( 'update_ID3_tags', "Not able to create temporary batch file to run 'exiftool': '" . $jsonBat . "'" );
		my $oldFH = select $jsonBatFH; $| = 1; select $oldFH;
		print $jsonBatFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @exifToolArgs );
	close( $jsonBatFH );
	#open/close 'exiftool' args file with arguments written to it
	toLog( 'update_ID3_tags', "   - Creating argument file for 'exiftool': '" . $exifToolArgsFile . "'\n" );
	openL ( \$argsFH, '>:encoding(UTF-8)', $exifToolArgsFile ) or badExit( 'update_ID3_tags', "Not able to create temporary arguments file to run 'exiftool': '" . $exifToolArgsFile . "'" );
		$oldFH = select $argsFH; $| = 1; select $oldFH;
		print $argsFH @exifToolFileArgs;
	close( $argsFH );

	#execute batch file wrapper to call 'exiftool' command batch file
	toLog( 'update_ID3_tags', "   - Executing batch file for 'exiftool'\n" );
	my ( $songFileJson, $rawStdErr, $stdErr );
	run3( $jsonBat, \undef, \$songFileJson, \$rawStdErr );
	$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
	badExit( 'update_ID3_tags', "ExifTool is not able to read the metadata of the file, returned:\n" . $stdErr ) if ( $? || $stdErr );
	my $jsonTxt;
	if ( $songFileJson =~ m#(\n\[\{.+)#s ) {
		$jsonTxt = $1;
	}
	#parse json data for song file
	my $json = JSON->new->utf8();
	my $jsonDataRef = $json->decode( $jsonTxt );
	badExit( 'update_ID3_tags', "JSON data not created for song file: '" . $songFile . "'" ) unless ( $jsonDataRef );

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
	toLog( 'update_ID3_tags', "   - Cleaning up temporary 'exiftool' files\n" );
	if ( testL ( 'e', $jsonBat ) || testL ( 'e', $exifToolArgsFile ) ) {
		my $unlinkErr;
		my $fileDel = unlinkL ( $jsonBat );
		$unlinkErr = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( 'update_ID3_tags', "Not able to remove temporary 'exiftool' batch file: '" . $jsonBat . "', returned:\n" . $unlinkErr ) if ( ! $fileDel );
		$fileDel = unlinkL ( $exifToolArgsFile );
		$unlinkErr = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( 'update_ID3_tags', "Not able to remove arguments file for 'exiftool': '" . $exifToolArgsFile . "', returned:\n" . $unlinkErr ) if ( ! $fileDel );
	}
}

#----------------------------------------------------------------------------------------------------------
#checking each tag - to set/clean-up values and/or delete values
sub cleanTags
#----------------------------------------------------------------------------------------------------------
{
	my ( $tagsRef, $songFile ) = @_;
	toLog( 'update_ID3_tags', "   - Examining each tag retrieved\n" );

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
			#only set when original had a value
			$tagsRef->{$tagName} = $tagsRef->{$priorityTagName} if ( $tagsRef->{$tagName} );
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
				$tagsRef->{'album_artist'} = $tagsRef->{albumartist} unless ( $tagsRef->{'album_artist'} );
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
			if ( $songFile =~ m#\.(ogg|flac)$#i ) {
				$tagsRef->{tracknumber} = $tagsRef->{$key} unless ( $tagsRef->{tracknumber} );
			} elsif ( $songFile =~ m#\.mkv$#i ) {
				$tagsRef->{'part_number'} = $tagsRef->{$key} unless ( $tagsRef->{'part_number'} );
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

#----------------------------------------------------------------------------------------------------------
sub extractTags
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $tagsRef, $songFile ) = @_;
	toLog( 'update_ID3_tags', "   - <title> or <artist> (or other) tags have not been set, attempting to set from filename & path\n" );
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
		#correct 'AC/DC'
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
		#correct 'AC/DC'
		$tagsRef->{artist} =~ s#^AC[_ ]DC$#AC\/DC#i;
		#remove extra artist info
		$tagsRef->{albumartist} =~ s#^([^;]+)(?<!&amp);.*$#$1#;
		#correct 'AC/DC'
		$tagsRef->{albumartist} =~ s#^AC[_ ]DC$#AC\/DC#i;
	}

	if ( $fileName =~ m#((\d)-)?(\d*)\s*-?\s*([^\.]+)\.(aac|alac|flac|m4a|mka|mkv|mp3|ogg|wma)$#i ) {
		$tagsRef->{title} = $4 if ( ! $tagsRef->{title} );
		$tagsRef->{track} = $3 if ( ! $tagsRef->{track} );
		$tagsRef->{discnumber} = $2 if ( ( $2 ) && ( ! $tagsRef->{discnumber} ) );
	}

	if ( ( ! $tagsRef->{length} ) && ( ! $tagsRef->{duration} ) ) {
		#set ffprobe command for finding 'length' on song files that don't have the value
		toLog( 'update_ID3_tags', "   - Preparing command for 'ffprobe' to determine 'length'\n" );
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
		toLog( 'update_ID3_tags', "   - Creating 'ffprobe' batch file: '" . $ffprobeBat . "'\n" );
		openL ( \$ffprobeFH, '>:encoding(UTF-8)', $ffprobeBat ) or badExit( 'update_ID3_tags', "Not able to create temporary batch file to run 'ffprobe': '" . $ffprobeBat . "'" );
			my $oldfh = select $ffprobeFH; $| = 1; select $oldfh;
			#write empty line to batch file in case of file header conflict
			print $ffprobeFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @ffprobeCmd );
		close( $ffprobeFH );
	
		toLog( 'update_ID3_tags', "   - Executing 'ffprobe' batch file\n" );
		my ( $rawStdErr, $stdErr );
		run3( $ffprobeBat, \undef, \$length, \$rawStdErr );
		$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
		warning( 'update_ID3_tags', "Not able to run 'ffprobe', returned:\n" . $stdErr ) if ( $? || $stdErr );
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
			warning( 'update_ID3_tags', "Could not determine <title>, <artist>, or possibly other tags" );
		}
	
		toLog( 'update_ID3_tags', "   - Cleaning up temporary 'ffprobe' files\n" );
		if ( testL ( 'e', $ffprobeBat ) ) {
			my $unlinkErr;
			my $fileDel = unlinkL ( $ffprobeBat );
			$unlinkErr = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			warning( 'update_ID3_tags', "Not able to remove temporary 'ffprobe' batch file: '" . $ffprobeBat . "', returned:\n" . $unlinkErr ) if ( ! $fileDel );
		} else {
			warning( 'update_ID3_tags', "'ffprobe' batch file '" . $ffprobeBat . "' does not exist (trying to delete)" );
		}
	}

	#set 'discnumber' to default value, if not present
	if ( ! $tagsRef->{discnumber} ) {
		$tagsRef->{discnumber} = 1;
	}
}

#----------------------------------------------------------------------------------------------------------
#write tags to metadata of song file, using 'ffmpeg'
sub writeTags
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $writer, $tagsRef, $songFile, $songNode ) = @_;

	#write out tags to XML
	toLog( 'update_ID3_tags', "   - Writing XML nodes to XML playlist\n" );
	my $numberVal = $songNode->findvalue( './@number' );
	#write out XML 'song' element
	$writer->startTag( "song", number => $numberVal );

	#mirror 'subnodes', but in particular order
	toLog( 'update_ID3_tags', "   - Reordering XML nodes\n" );
	my $newSongNode = $songNode->cloneNode( 1 );
	$newSongNode->removeChildNodes();
	#add children nodes back in specified order
	foreach my $nodeName ( @listOfXmlTags ) {
		if ( ! $songNode->exists( $nodeName ) ) {
			warning( 'update_ID3_tags', "'" . $nodeName . "' does not exist in XML instanace" );
		} else {
			#determine if multiple nodes with same name - warn & don't add to $newSongNode
			my $nodeCnt = 0;
			foreach ( $songNode->findnodes( $nodeName ) ) {
				++$nodeCnt;
			}
			if ( $nodeCnt > 1 ) {
				warning( 'update_ID3_tags', "Song node has duplicate tags in song no. " . $numberVal . ": '" . $nodeName . "'" );
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
	toLog( 'update_ID3_tags', "   - Creating temporary song file for 'ffmpeg' to use as original song file\n" );
	my ( $songFileName, $songFilePath ) = fileparse( abspathL ( $songFile ) );
	my $tmpSongFileName = $songFileName;
	if ( $tmpSongFileName =~ s#(.)\.(\w\w\w\w?)$#$1_tmp\.$2#i ) {
		#verifying file is not left open by other process
		close( $songFilePath . $tmpSongFileName );
		close( $songFilePath . $songFileName );
		renameL ( $songFilePath . $songFileName, $songFilePath . $tmpSongFileName );
		sleep 1;
		if ( ! testL ( 'e', $songFilePath . $tmpSongFileName ) ) {
			badExit( 'update_ID3_tags', "Not able to rename song file: '" . $songFilePath . $songFileName . "' to temp file: '" . $songFilePath . $tmpSongFileName . "', $!, $^E\n" );
		}
	}

	#create array of metadata tag args to add in ffmpeg (will splice into command args array)
	toLog( 'update_ID3_tags', "   - Creating 'ffmpeg' arguments for submission of metadata to song file\n" );
	my @newMeta;
	foreach my $key ( keys %{$tagsRef} ) {
		#create variable for metadata key (keys with spaces can cause to fail content test)
		my $metaKey = $key;
		#use Unicode curved double quote in key
		$metaKey =~ s#"#\N{U+201D}#g;
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

	toLog( 'update_ID3_tags', "   - Building 'ffmpeg' command statement\n" );
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
	toLog( 'update_ID3_tags', "   - System command to rewrite song metadata with 'ffmpeg': '" . join( " ", @ffmpeg ) . "'\n" );

	#start process to create batch file with 'ffmpeg' commands
	my $ffmpegBat = $ENV{TEMP} . $FS . 'ffmpeg-' . $num . '.bat';
	#batch file handle ref
	my $ffmpegFH;
	#open/close batch file with commands written to it
	toLog( 'update_ID3_tags', "   - Creating batch file with 'ffmpeg' commands: '" . $ffmpegBat . "'\n" );
	openL ( \$ffmpegFH, '>:encoding(UTF-8)', $ffmpegBat ) or badExit( 'update_ID3_tags', "Not able to create temporary batch file to run 'ffmpeg': '" . $ffmpegBat . "'" );
		my $prevfh = select $ffmpegFH; $| = 1; select $prevfh;
		#write empty line to batch file in case of file header conflict
		print $ffmpegFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @ffmpeg );
	close( $ffmpegFH );

	#execute batch file wrapper to call 'ffmpeg' commands batch file
	toLog( 'update_ID3_tags', "   - Executing batch file for 'ffmpeg'\n" );
	my ( $rawStdOutErr, $stdOutErr );
	run3( $ffmpegBat, \undef, \$rawStdOutErr, \$rawStdOutErr );
	$stdOutErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdOutErr );
	badExit( 'update_ID3_tags', "Not able to run 'ffmpeg', returned:\n" . $stdOutErr ) if ( $? || $stdOutErr );

	#removing temp song file & 'ffmpeg' batch file, if successful
	toLog( 'update_ID3_tags', "   - Removing temporary song files & batch files\n" );
	if ( testL ( 'e', $songFile ) ) {
		my $unlinkErr;
		my $fileDel = unlinkL ( $songFilePath . $tmpSongFileName );
		$unlinkErr = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( 'update_ID3_tags', "Not able to remove temporary song file: '" . $songFilePath . $tmpSongFileName . "', returned:\n" . $unlinkErr ) if ( ! $fileDel );
		$fileDel = unlinkL ( $ffmpegBat );
		$unlinkErr = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( 'update_ID3_tags', "Not able to remove temporary 'ffmpeg' batch file: '" . $ffmpegBat . "', returned:\n" . $unlinkErr ) if ( ! $fileDel );
	} else {
		badExit( 'update_ID3_tags', "Not able to remove temporary song file & batch files for song file: '" . $songFile . "'" );
	}
}

#----------------------------------------------------------------------------------------------------------
#warning process
sub warning
#----------------------------------------------------------------------------------------------------------
{
	my ( $funcName, $msg ) = @_;

	updStatus( undef, 'Warning...' );

	#set global warn hash with increasing warning count
	++$warn{global};
	if ( $funcName ) {
		#set warn hash for function with increasing warning count
		++$warn{$funcName};
		toLog( $funcName, "\n *WARNING* (" . $warn{$funcName} . "): $msg,\n" . shortmess() . "\n" );
	} else {
		toLog( undef, "\n *WARNING* (" . $warn{global} . "): $msg,\n" . shortmess() . "\n" );
	}

	promptUser( 'warning', $msg );
}

#----------------------------------------------------------------------------------------------------------
#failed execution process
sub badExit
#----------------------------------------------------------------------------------------------------------
{
	my ( $funcName, $error ) = @_;

	#store any returned system error info
	my $rawSysError = $!;
	my $rawEvalError = $@;
	#decode raw error to use Unicode
	my $sysError = decode( $Config{enc_to_system} || 'UTF-8', $rawSysError );
	my $evalError = decode( $Config{enc_to_system} || 'UTF-8', $rawEvalError );
	if ( $sysError or $evalError ) {
	  $error .= "\n\n *Failed with following system error message: $sysError\n *Failed with following eval error message: $evalError";
	}
	updStatus( undef, 'ERROR...' );

	if ( fileno( $funcLogFH ) ) {
		toLog( $funcName, " **ERROR: $error\n" );
	}
	if ( fileno( $logFH ) ) {
		toLog( undef, " **ERROR: $error\n" );
	}

	promptUser( 'error', $error );

	#close logs if open
	if ( ( $funcName ) && ( fileno( $funcLogFH ) ) ) {
		endLog( $funcName );
	}
	if ( fileno( $logFH ) ) {
		endLog();
	}

	#close window
	$M->{'window'}->destroy;

	#return exception code
	exit 255;
}

#----------------------------------------------------------------------------------------------------------
# function ends successfully - log closed and window refreshed for restart
sub tkEnd
#----------------------------------------------------------------------------------------------------------
{
	my ( $funcName ) = @_;

	#close log file
	endLog( $funcName );
	undef $log;
  $log = "$dirName$progName.log";

	#focus on exit button and reset status
	$proc = 'Waiting on command...';
	$M->{'exit'}->focus();

	#reset buttons
	$M->{'update'}->configure(
		-text=>'Update ID3 Tags',
		-font=>TK_FNT_B,
		-state=>'normal',
		-bg=>TK_COLOR_BG,
		-fg=>TK_COLOR_FG,
		-activebackground=>TK_COLOR_LGREEN
	);
	$M->{'func2'}->configure(
		-text=>'Function 2',
		-font=>TK_FNT_B,
		-state=>'normal',
		-bg=>TK_COLOR_BG,
		-fg=>TK_COLOR_FG,
		-activebackground=>TK_COLOR_ABG
	);

	$M->{'window'}->update();
}

#----------------------------------------------------------------------------------------------------------
# program exits
sub tkExit
#----------------------------------------------------------------------------------------------------------
{
	#close log file
	endLog();

	$M->{'window'}->destroy;
	exit( 0 );
}

#----------------------------------------------------------------------------------------------------------
#start logging to file, if no arg then set as main program log otherwise set to passed arg function name
sub startLog
#----------------------------------------------------------------------------------------------------------
{
  my ( $funcName ) = @_;

	my $now = dateTime();
	my $timeSt = $now->{'date'} . " at " . $now->{'time'};

	if ( $funcName ) {
		if ( testL ( 'd', $dirName ) ) {
	    $log = "$dirName$funcName.log";
		} else {
	  	my $dir = getcwdL();
	    $log = "$dir$FS$progName.log";
		}
		openL ( \$funcLogFH, '>:encoding(UTF-8)', $log ) or badExit( $funcName, "Not able to create log file: '" . $log . "'" );
		#redirect STDERR to log file
		open STDERR, '>>:encoding(UTF-8)', $log;
		my $oldfh = select $funcLogFH; $| = 1; select $oldfh;

		toLog( $funcName, "$Sep\nFunction: $funcName\n\tDate: $timeSt\n$Sep" );
	} else {
    if ( testL ( 'd', $dirName ) ) {
	    $log = "$dirName$progName.log";
	  } else {
	  	my $dir = getcwdL();
	    $log = "$dir$FS$progName.log";
	  }
		openL ( \$logFH, '>:encoding(UTF-8)', $log ) or badExit( undef, "Not able to create log file: '" . $log . "'" );
		#redirect STDERR to log file
		open STDERR, '>>:encoding(UTF-8)', $log;
		my $oldfh = select $logFH; $| = 1; select $oldfh;

		toLog( undef, "$SEP\nTool: $progName\n\tVersion: $Version\n\n\tDate: $timeSt\n$Sep" );
		toLog( undef, "$progName Process Started\n$Sep\n" );
	}
}

#----------------------------------------------------------------------------------------------------------
#write out to log
sub toLog
#----------------------------------------------------------------------------------------------------------
{
	my ( $funcName, $msg ) = @_;

	if ( $funcName ) {
		if ( fileno( $funcLogFH ) ) {
			print $funcLogFH $msg;
		} else {
			#log file is not open, write to error window
			my ( $package, $file, $line, $subname ) = caller( 1 );
			$subname =~ s#main::##;
			unless ( $subname =~ m#badExit#i ) {
				badExit( $funcName, "$msg" );
			}
		}
	} else {
		if ( fileno( $logFH ) ) {
			print $logFH $msg;
		} else {
			#log file is not open, write to error window
			my ( $package, $file, $line, $subname ) = caller( 1 );
			$subname =~ s#main::##;
			unless ( $subname =~ m#badExit#i ) {
				badExit( undef, "$msg" );
			}
		}
	}
}

#----------------------------------------------------------------------------------------------------------
#end log process
sub endLog
#----------------------------------------------------------------------------------------------------------
{
  my ( $funcName ) = @_;

	my $now = dateTime();
	my $timeSt = $now->{'date'} . " at " . $now->{'time'};

	if ( ( $funcName ) && ( fileno( $funcLogFH ) ) ) {
		#output any warning data
		if ( $warn{$funcName} ) {
			toLog( $funcName, "\n   **(" . $warn{$funcName} . ") Warnings were detected**\n\n" );
		}
		toLog( $funcName, "$funcName Process Completed\n$SEP\n\n" );
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
