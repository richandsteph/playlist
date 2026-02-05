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
#
#
#   TO-DO:
#         1) add comments for args in subroutines
#         2) change double quotes to single quotes when interpreting not required
#         3) make status bar updates to follow with '...' / make status frame updates to NOT use '...'
#
#**********************************************************************************************************

my $Version = "1.3";

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
#initialize warning hash
my %warn;

#command-line tools for song metadata manipulation
my $exifToolCmd = 'C:\Strawberry\perl\site\bin\exiftool';
my $ffprobeCmd = 'C:\Users\rich\Documents\Dev\ffmpeg\FFmpeg-exe\bin\ffprobe.exe';
my $mkvCmd = 'C:\Program Files\MKVToolNix\mkvextract.exe';
my $ffmpegCmd = 'C:\Users\rich\Documents\Dev\ffmpeg\FFmpeg-exe\bin\ffmpeg.exe';

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

#process passed argument(s)
if ( testL ( 's', $ARGV[0] ) ) {
	$filePath = $ARGV[0];
	#directory separator default for Windows command line
	$filePath =~ s#[\/\\]#$FS#g;
	( $fileName, $dirName ) = fileparse( abspathL ( $filePath ) );
	if ( ! testL ( 'd', $dirName ) ) {
		$dirName = getcwdL();
	}
	$filePath = "$dirName$fileName";
} elsif ( testL ( 'd', $ARGV[0] ) ) {
	$dirName = $ARGV[0];
} elsif ( $ARGV[0] ) {
		badExit( undef, "Optional argument(s) incorrect, single possible correct argument should be playlist XML filename: \n   perl C:\\git_playlist\\$progName.pl \[PLAYLIST_XML_FILENAME\]" );
}

#read possible last value file for setting of $dirName and/or $filePath
readLastVal();

#create initial window and pass to tk caller
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
    my @time_parts = reverse( split( ":", $_[0] ) );
    my $accum = 0;
    for ( my $i = 0; $i < @time_parts; $i++ ) {
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
# read directory and returns a list of XML files
sub getXML_List
#----------------------------------------------------------------------------------------------------------
{
	my @xmlList;

	#determine calling subroutine
	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;

	updStatus( 'Building list of XML files...' );

	my $dir = Win32::LongPath->new();
	$dir->opendirL ( $dirName );
	my $dirSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
	my $dirOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
	if ( ! testL ( 'd', $dirName ) ) {
		badExit( $subName, "Not able to open directory: '" . $dirName . "', returned:\n" . $dirSysErr . "\nand:\n" . $dirOS_Err );
	}

	@xmlList = grep m/\.xml$/i, $dir->readdirL();
	$dir->closedirL();

	#add path info to each XML file in list
	my @newList;
	foreach my $file ( @xmlList ) {
		push @newList, $dirName . $file;
	}

	unless ( scalar( @newList ) ) {
		badExit( $subName, "No files were found in directory: '" . $dirName . "'" );
	}

	return( @newList );
}

#----------------------------------------------------------------------------------------------------------
# get song list from working directory
sub getSongList
#----------------------------------------------------------------------------------------------------------
{
	my ( $songArrayRef, $workingDir ) = @_;

	#don't scour '$' folders, unless for testing
	return if ( $workingDir =~ m#[\\\/]\$(?!program_test)# );

	#determine calling subroutine
	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;

	updStatus( 'Building list of song files...' );

	my $dir = Win32::LongPath->new();
	$dir->opendirL ( $workingDir );
	my $dirSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
	my $dirOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
	if ( ! testL ( 'd', $workingDir ) ) {
		badExit( $subName, "Not able to open directory: '" . $workingDir . "', returned:\n" . $dirSysErr . "\nand:\n" . $dirOS_Err );
	}

	foreach my $dirItem ( $dir->readdirL() ) {
		next if $dirItem =~ m#^\.{1,2}$#;

		#send notice of folder processing to console
		my $conFH = select STDOUT; $| = 1; select $conFH;
		print ".";

		my $dirItemPath = $workingDir . $FS . $dirItem;

		if ( testL ( 'd', $dirItemPath ) ) {
			getSongList( $songArrayRef, $dirItemPath );
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
		-textvariable => \$filePath,
		-width				=> '30',
		-bg						=> TK_COLOR_FIELD,
		-fg						=> TK_COLOR_FG
	)->pack(
		-side					=> 'left',
		-pady					=> '0'
	);
	$fileEntry->xview( 'end' );
	$M->{'select'} = $chooseFile->Button(
		-text							=> "...",
		-command					=> [ \&tkGetFile, $filePath ],
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
		-textvariable => \$dirName,
		-width	=> '30',
		-bg			=> TK_COLOR_FIELD,
		-fg			=> TK_COLOR_FG
	)->pack(
		-side		=> 'left'
	);
	$dirEntry->xview( 'end' );
	$M->{'select'} = $chooseDir->Button(
		-text							=> "...",
		-command					=> [ \&tkGetDir, $dirName ],
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
	$M->{'renumber'} = $buttons1->Button(
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
	$M->{'make_XML_playlist'} = $buttons2->Button(
		-text								=> 'Create XML',
		-font								=> TK_FNT_B,
		-command						=> \&make_XML_playlist,
		-borderwidth				=> '4',
		-bg									=> TK_COLOR_BG,
		-fg									=> TK_COLOR_FG,
		-activebackground		=> TK_COLOR_ABG,
		-disabledforeground => TK_COLOR_GREYBUT,
		-width							=> '14'
	)->pack(
		-side								=> 'left',
		-padx								=> '2',
		-pady								=> '8'
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
	my $mesg = $now->{'date'} . " at " . $now->{'time'};
	updStatus( $mesg, undef );
	$M->{'window'}->update();
	
	#set focus
	$M->{'select'}->focus();
}

#----------------------------------------------------------------------------------------------------------
#update status in window, 1st arg is current status frame and 2nd arg is current process status bar
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
#user chooses directory
sub tkGetDir
#----------------------------------------------------------------------------------------------------------
{
	my ( $getDirPath ) = @_;
	my $dir;

	if ( testL ( 'd', $getDirPath ) ) {
		( undef, $dir ) = fileparse( abspathL ( $getDirPath ) );
	}

	$getDirPath = $M->{'window'}->chooseDirectory(
		-initialdir => $dir,
		-title			=> 'Choose Directory...'
	);

	if ( testL ( 'd', $getDirPath ) ) {
		$dirName = $getDirPath;
		$dirName = $dirName;
		$dirName =~ s#[\/\\]#$FS#g;
	}
}

#----------------------------------------------------------------------------------------------------------
#user chooses file
sub tkGetFile
#----------------------------------------------------------------------------------------------------------
{
	my ( $getFilePath ) = @_;

	my ( $dir, $file );
	if ( testL ( 'e', $getFilePath ) ) {
		( $file, $dir ) = fileparse( abspathL ( $getFilePath ) );
	}

	$getFilePath = $M->{'window'}->getOpenFile(
		-initialdir		=> $dir,
		-initialfile	=> $file,
		-title				=> 'Choose File...'
	);

	$getFilePath =~ s#[\/\\]#$FS#g;
	if ( testL ( 'e', $getFilePath ) ) {
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
#function to create XML playlist from selected root music folder, crawls all artist/album folders in root
sub make_XML_playlist
#----------------------------------------------------------------------------------------------------------
{
	#determine subroutine
	my ( $package, $file, $line, $subName ) = caller( 0 );
	$subName =~ s#main::##;
	updStatus( undef, 'Make XML Playlist' );

	#must specify directory or file
	unless ( $dirName ) {
		my $ans = promptUser( 'warning', "No directory selected or passed,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( $subName, "User chose to stop process,\n no directory selected or passed" );
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
		-text							=> 'Creating XML...',
		-font							=> TK_FNT_B,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_FIELD,
		-activebackground => TK_COLOR_FIELD
	);
	$M->{'exit'}->focus();

	#starting log process
	toLog( undef, "  Creating XML Playlist...\n    See '" . $dirName . $subName . ".log' for details\n\n" );
	startLog( $subName );
	
	toLog( $subName, "Scouring Music folders to build list of song files...\n" );

	my @songList;
	getSongList( \@songList, $dirName );
	
	toLog( $subName, "----\n...Processing Song Files in: $dirName\n\n" );
	
	#parse out XML node data from songs to XML file
	updStatus( 'Creating XML document...' );
	my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
	badExit( $subName, "Not able to create new XML::Writer object" ) if ( ! $writer );
	#write XML Declaration
	$writer->xmlDecl( "UTF-8" ) or badExit( $subName, "Not able to write out XML Declaration" );
	#determine playlist name
	my $playlist_name;
	if ( $dirName =~ m#phone_music#i ) {
		$playlist_name = 'phone-favorites';
	} else {
		$playlist_name = 'rich-all-songs';
	}
	#write date into <playlist> tag attribute
	my $now = dateTime();
	my $today = $now->{'date'} . " at " . $now->{'time'};
	$writer->startTag( "playlist", name => $playlist_name, date => $today );
	
	#start process to create batch file for calling 'chcp 65001' for files/folders with Unicode characters
	my $statBat = $ENV{TEMP} . $FS . 'stat.bat';
	my $statBatFH;
	#open/close batch file with commands written to it
	toLog( $subName, " - Creating batch file wrapper set console code page: '" . $statBat . "'\n" );
	openL ( \$statBatFH, '>:encoding(UTF-8)', $statBat );
	if ( ! fileno( $statBatFH ) ) {
		my $statSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $statOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		badExit( $subName, "Not able to create temporary batch file: '" . $statBat . "', returned:\n" . $statSysErr . "\nand:\n" . $statOS_Err );
	} else {
		my $statFH = select $statBatFH; $| = 1; select $statFH;
		print $statBatFH "\n" . '@echo off' . "\n" . 'echo   **Setting Console Code Page to 65001**' . "\n" . 'chcp 65001';
		close( $statBatFH );
	}
	
	#execute batch file wrapper to set console code page
	toLog( $subName, " - Executing batch file to set console code page\n" );
	my $stdErr;
	run3( $statBat, \undef, \undef, \$stdErr );
	badExit( $subName, "Not able to run set console code page batch file wrapper: '" . $statBat . "', returned: " . $stdErr ) if ( $? || $stdErr );
	
	#clean up batch file
	toLog( $subName, " - Cleaning up temporary console code page batch file\n" );
	if ( testL ( 'e', $statBat ) ) {
		my $fileDel = unlinkL ( $statBat );
		my $unlinkSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $unlinkOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( $subName, "Not able to remove temporary console code page batch file: '" . $statBat . "', returned:\n" . $unlinkSysErr . "\nand:\n" , $unlinkOS_Err ) if ( ! $fileDel );
	} else {
		badExit( $subName, "No console code page batch file to delete: '" . $statBat . "'" );
	}
	
	#set overall counter for songs
	my $num = 0;
	#loop through each song file in file list
	foreach my $songFile ( @songList ) {
		#song counter for XML file output
		++$num;
		
		#echo status to console
		my $songFileName;
		( $songFileName ) = fileparse( abspathL ( $songFile ) );
		toLog( $subName, "Processing song no. " . $num . ": '" . $songFile . "'\n" );
		updStatus( "Processing song no. " . $num . " ..." );
		binmode( STDOUT, ":encoding(UTF-8)" );
		print "\n" if ( $num == 1 );
		print "   - processing song no. " . $num . ": '" . $songFileName . "'\n";
	
		#set per song hash for tag metadata
		my %tags;
	
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

		#write out XML to file of metadata for song file
		toLog( $subName, " - Writing out XML to list\n" );
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
		$writer->characters( $tags{title} ) if ( $tags{title} );
		$writer->endTag( "title" );
		#write <artist>
		$writer->startTag( "artist" );
		#replace extraneous characters
		$writer->characters( $tags{artist} ) if ( $tags{artist} );
		$writer->endTag( "artist" );
		#write <albumartist>
		$writer->startTag( "albumartist" );
		#replace extraneous characters
		$writer->characters( $tags{albumartist} ) if ( $tags{albumartist} );
		$writer->endTag( "albumartist" );
		#write <album>
		$writer->startTag( "album" );
		#replace extraneous characters
		$writer->characters( $tags{album} ) if ( $tags{album} );
		$writer->endTag( "album" );
		#write <year>
		$writer->startTag( "year" );
		$writer->characters( $tags{year} ) if ( $tags{date} );
		$writer->endTag( "year" );
		#write <genre>
		$writer->startTag( "genre" );
		#replace extraneous characters
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
		$writer->characters( $tags{comment} ) if ( $tags{comment} );
		$writer->endTag( "comment" );
		#replace extraneous characters for adding <path> content
		my $songFileClean;
		#clean up path
		if ( $songFileClean =~ s#^[A-Za-z]:[\\\/]#\\\\DavisServer_1\\Movies_Music_Pics\\#i ) {
			#replace 'M:\' drive letter path with UNC path
			toLog( $subName, " - Replacing drive letter with UNC path\n" );
			#replace any remaining forward slashes with backslashes
			$songFileClean =~ s#\/#$FS#g;
		}
		#write <path>
		$writer->startTag( "path" );
		$writer->characters( $songFileClean );
		$writer->endTag( "path" );
	
		#write out close song XML tag
		$writer->endTag( "song" );
	
		toLog( $subName, "Writing \"" . $tags{title} . "\" by \"" . $tags{artist} . "\" as number $num to playlist XML file\n" );
	}
	
	#write out close playlist XML tag
	$writer->endTag( "playlist" );
	$writer->end() or badExit( $subName, "Not able to write complete XML to file" );
	
	#write out new XML playlist file
	my $playlistXmlFile = "$dirName$playlist_name.xml";
	my $xmlOutFH;
	openL ( \$xmlOutFH, '>:encoding(UTF-8)', $playlistXmlFile );
	if ( ! fileno( $xmlOutFH ) ) {
		my $xmlSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $xmlOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		badExit( $subName, "Not able to create XML playlist file: '" . $playlistXmlFile . "', returned:\n" . $xmlSysErr . "\nand:\n" . $xmlOS_Err );
	} else {
		my $xmlfh = select $xmlOutFH; $| = 1; select $xmlfh;
		print $xmlOutFH $writer;
		close( $xmlOutFH );
	}

	toLog( $subName, "\n...Created XML Playlist: '" . $playlistXmlFile . "'\n\n\n" );
	toLog( $subName, " *WARNING*: There were " . $warn{$subName} . " warning(s) for process...\n\n\n" ) if ( $warn{$subName} );
	toLog( undef, "  ...Finished Creating XML Playlist from: '" . $dirName . "'\n\n" );
	#echo status to console
	my ( $xmlName ) = fileparse( abspathL ( $playlistXmlFile ) );
	binmode( STDOUT, ":encoding(UTF-8)" );
	print "   Finished Creating XML Playlist '" . $xmlName . "'\n";

	#process end
	if ( $filePath ) {
		updStatus( "Finished Creating XML Playlist: '" . $playlistXmlFile . "'" );
	} else {
		my $folderNm;
		( $folderNm ) = fileparse( abspathL ( $dirName ) );
		updStatus( "Finished Creating XML Playlist(s) from: \"" . $folderNm . "\" folder" );
	}

	tkEnd( $subName );
}

#----------------------------------------------------------------------------------------------------------
#function to create .m3u playlist from XML playlist, can search through directories from selected root or 
#  accept passed file
sub make_m3u
#----------------------------------------------------------------------------------------------------------
{
	#determine subroutine
	my ( $package, $file, $line, $subName ) = caller( 0 );
	$subName =~ s#main::##;
	updStatus( undef, 'Make .m3u Playlist' );
	updStatus( "Making .m3u playlist..." );

	#must specify directory or file
	unless ( $dirName || $fileName ) {
		my $ans = promptUser( 'warning', "No directory (or file) selected or passed,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( 'renumber', "User chose to stop process,\n no directory (or file) selected or passed" );
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
		-text							=> 'Create XML',
		-font							=> TK_FNT_BI,
		-state						=> 'disabled',
		-fg								=> TK_COLOR_GREYBUT,
		-bg								=> TK_COLOR_BG,
		-activebackground => TK_COLOR_BG
	);
	$M->{'exit'}->focus();

	#starting log process
	toLog( undef, "  Making .m3u Playlist...\n    See '" . $dirName . $subName . ".log' for details\n\n" );
	startLog( $subName );
	
	#retrieve list of XML files in $dirName, unless file is selected - just push single item into array
	my @fileList;
	if ( $filePath ) {
		if ( $fileName =~ m#\.xml$#i ) {
			push @fileList, $filePath;
		} else {
			promptUser( 'warning', "Selected file is not an XML instance" );
			toLog( $subName, "File selected is not an XML instance, ending '" . $subName . "' function\n\n" );
			tkEnd( $subName );
			return;
		}
	} else {
		@fileList = getXML_List( $dirName );
	}

	#loop through each XML file in directory
	my $m3uFileName;
	foreach my $xmlFile ( @fileList ) {
		toLog( $subName, "...Processing XML file: '$xmlFile'\n\n" );
		updStatus( "Processing XML file: '" . $xmlFile . "' ..." );
		#echo status to console
		binmode( STDOUT, ":encoding(UTF-8)" );
		print "\n   Processing '$xmlFile'\n";

		#load XML data
		my ( $dom, $xmlFH );
		openL ( \$xmlFH, '<:encoding(UTF-8)', $xmlFile );
		if ( ! fileno( $xmlFH ) ) {
			my $xmlSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $xmlOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			badExit( $subName, "Not able to open XML file: '" . $xmlFile . "', returned:\n" . $xmlSysErr . "\nand:\n" . $xmlOS_Err );
		} else {
			binmode $xmlFH;
			$dom = XML::LibXML->load_xml( IO => $xmlFH );
			if ( ! $dom ) {
				my $xmlSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
				my $xmlEvalErr = decode( $Config{enc_to_system} || 'UTF-8', $@ );
				badExit( $subName, "Couldn't load XML file: '" . $xmlFile . "', returned:\n" . $xmlSysErr . "\nand:\n" . $xmlEvalErr );
			} else {
				close( $xmlFH );
			}
		}

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
		updStatus( "Creating .m3u playlist: '" . $m3uFileName . "' ..." );

		toLog( $subName, "Setting date/time for playlist\n" );
		my $now = dateTime();
		my $today = $now->{'date'} . " at " . $now->{'time'};
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
		my $m3uFH;
		my $m3uFile = $xmlFile;
		$m3uFile = $m3uFileName . '.m3u';
		openL ( \$m3uFH, '>:encoding(UTF-8)', $m3uFile );
		if ( ! fileno( $m3uFH ) ) {
			my $m3uSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $m3uOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			badExit( $subName, "Not able to create '" . $m3uFile . "', returned:\n" . $m3uSysErr . "\nand:\n" . $m3uOS_Err );
		} else {
			my $oldfh = select $m3uFH; $| = 1; select $oldfh;
			print $m3uFH $m3uData;
			close( $m3uFH );
		}

		toLog( $subName, "\n...Made .m3u Playlist: '" . $m3uFile . "'\n\n\n" );
		toLog( $subName, " *WARNING*: There were " . $warn{make_m3u} . " warning(s) for process...\n\n\n" ) if ( $warn{make_m3u} );
		toLog( undef, "  ...Finished Making .m3u Playlist from: '" . $xmlFile . "'\n\n" );
		#echo status to console
		my ( $xmlName ) = fileparse( abspathL ( $xmlFile ) );
		binmode( STDOUT, ":encoding(UTF-8)" );
		print "   Finished Making .m3u Playlist '" . $m3uFileName . "'\n";
	}
	
	#process end
	if ( $filePath ) {
		updStatus( "Finished Making .m3u Playlist: \"" . $m3uFileName . "\"" );
	} else {
		my $folderNm;
		( $folderNm ) = fileparse( abspathL ( $dirName ) );
		updStatus( "Finished Making .m3u Playlist(s) from: \"" . $folderNm . "\" folder" );
	}
	tkEnd( $subName );
}

#----------------------------------------------------------------------------------------------------------
#function to renumber XML nodes in single selected XML playlist, or all XML instances in selected root 
#  folder
sub renumber
#----------------------------------------------------------------------------------------------------------
{
	#determine subroutine
	my ( $package, $file, $line, $subName ) = caller( 0 );
	$subName =~ s#main::##;
	updStatus( undef, 'Renumber' );

	#must specify directory or file
	unless ( $dirName || $fileName ) {
		my $ans = promptUser( 'warning', "No directory (or file) selected or passed,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( 'renumber', "User chose to stop process,\n no directory (or file) selected or passed" );
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
		-text							=> 'Create XML',
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
	toLog( undef, "  Renumbering...\n    See '" . $dirName . $subName . ".log' for details\n\n" );
	startLog( $subName );
	updStatus( "Renumbering XML files in '" . $dirName . "' ..." );
	
	#retrieve list of XML files in $dirName, unless file is selected - just push single item into array
	my @fileList;
	if ( $filePath ) {
		if ( $fileName =~ m#\.xml$#i ) {
			push @fileList, $filePath;
		} else {
			promptUser( 'warning', "Selected file is not an XML instance" );
			toLog( $subName, "File selected is not an XML instance, ending 'renumber' function\n\n" );
			tkEnd( $subName );
			return;
		}
	} else {
		@fileList = getXML_List( $dirName );
	}

	#loop through each XML file in directory
	foreach my $xmlFile ( @fileList ) {
		toLog( $subName, "...Processing XML File: '$xmlFile'\n\n" );
		updStatus( "Processing XML file: '" . $xmlFile . "' ..." );
		#echo status to console
		binmode( STDOUT, ":encoding(UTF-8)" );
		print "\n   Renumbering '$xmlFile'\n";
	
		#load XML data
		my ( $dom, $xmlInFH );
		openL ( \$xmlInFH, '<:encoding(UTF-8)', $xmlFile );
		if ( ! fileno( $xmlInFH ) ) {
			my $xmlSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $xmlOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			badExit( $subName, "Not able to open XML file: '" . $xmlFile . "', returned:\n" . $xmlSysErr . "\nand:\n" . $xmlOS_Err );
		} else {
			binmode( $xmlInFH );
			$dom = XML::LibXML->load_xml( IO => $xmlInFH );
			if ( ! $dom ) {
				my $xmlSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
				my $xmlEvalErr = decode( $Config{enc_to_system} || 'UTF-8', $@ );
				badExit( $subName, "Couldn't load XML file: '" . $xmlFile . "', returned:\n" . $xmlSysErr . "\nand:\n" . $xmlEvalErr );
			} else {
				close( $xmlInFH );
			}
		}
	
		#create XML writer object, so can output empty XML elements without collapsing
		my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1, ENCODING => 'utf-8' );
		if ( ! $writer ) {
			my $writeSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $writeEvalErr = decode( $Config{enc_to_system} || 'UTF-8', $@ );
			badExit( $subName, "Not able to create new XML::Writer object, returned:\n" . $writeSysErr . "and:\n" . $writeEvalErr );
		} else {
			#write XML Declaration
			$writer->xmlDecl( "UTF-8" ) or badExit( $subName, "Not able to write out XML Declaration" );
			$writer->comment( "*IMPORTANT*: Only 1 attribute/value pair is allowed per each child node of <song>" );
		}
		
		#cycle through number nodes
		my $nodeCnt = 0;
		#set date in <playlist> attribute
		my $playlistNode = $dom->findnodes( '/playlist' );
		toLog( $subName, "\tSetting current date/time in <playlist> node\n" );
		#get playlist @name for writing out
		my @playlistName = $dom->findvalue( '/playlist/@name' );
		my $now = dateTime();
		my $today = $now->{'date'} . " at " . $now->{'time'};
		$writer->startTag( "playlist", name => $playlistName[0], date => $today );
	
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
				$writer->startTag( "song", number => $nodeCnt );
			} else {
				#write out XML 'song' element
				$writer->startTag( "song", number => $numberVal );
			}
	
			#search empty elements and add empty node to avoid collapsed tag output
			foreach my $subNode ( $songNode->findnodes( '*' ) ) {
				my $nodeName = $subNode->nodeName;

				#determine if <title> has duplicate content with another node
				if ( $nodeName =~ m#^title$#i ) {
					my $titleContent = $subNode->textContent;
					foreach my $val ( values( %title ) ) {
						if ( $val =~ m#^$titleContent$#i ) {
							toLog( $subName, "\tNOTE: The content '" . $titleContent . "' of <title> in <song> no. " . $nodeCnt . " is duplicated\n" );
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
			$writer->endTag( "song" );
		}
			#write out close 'playlist' XML tag
		$writer->endTag( "playlist" );
		$writer->end() or badExit( $subName, "Not able to end XML document" );
	
		#write out renumbered XML playlist file
		my $xmlOutFH;
		openL ( \$xmlOutFH, '>:encoding(UTF-8)', $xmlFile );
		if ( ! fileno( $xmlOutFH ) ) {
			my $outSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $outOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			badExit( $subName, "Not able to create '" . $xmlFile . "', returned:\n" . $outSysErr . "\nand:\n" . $outOS_Err );
		} else {
			my $newfh = select $xmlOutFH; $| = 1; select $newfh;
			print $xmlOutFH $writer;
			close( $xmlOutFH );
		}
		toLog( $subName, "\n...Finished Renumbering XML file: '" . $xmlFile . "'\n\n\n" );
		toLog( $subName, " *WARNING*: There were " . $warn{renumber} . " warning(s) for process...\n\n\n" ) if ( $warn{renumber} );
		toLog( undef, "  ...Finished Renumbering XML file: '" . $xmlFile . "'\n\n" );
		#echo status to console
		my ( $xmlName ) = fileparse( abspathL ( $xmlFile ) );
		binmode( STDOUT, ":encoding(UTF-8)" );
		print "   Finished Renumbering '" . $xmlName . "'\n";
	}

	#process end
	if ( $filePath ) {
		updStatus( "Finished Renumbering \"" . $fileName . "\"" );
	} else {
		my $folderNm;
		( $folderNm ) = fileparse( abspathL ( $dirName ) );
		updStatus( "Finished Renumbering \"" . $folderNm . "\" folder" );
	}
	tkEnd( $subName );
}

#----------------------------------------------------------------------------------------------------------
#function to update ID3 metadata with XML input for song files
sub update_ID3_tags
#----------------------------------------------------------------------------------------------------------
{
	#determine subroutine
	my ( $package, $file, $line, $subName ) = caller( 0 );
	$subName =~ s#main::##;
	updStatus( undef, 'Update ID3 Tags' );

	#must specify file or directory
	unless ( $filePath ) {
		my $ans = promptUser( 'warning', "No file (or directory) selected or passed,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( $subName, "User chose to stop process,\n no file (or directory) selected or passed" );
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
		-text							=> 'Create XML',
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
	toLog( undef, "  Updating ID3 Tags:\n    See '" . $dirName . $subName . ".log' for details\n\n" );
	startLog( $subName );
	updStatus( "Updating ID3 tags in '" . $dirName . "' ..." );
	
	#separate out playlist XML filename and directory
	my ( $playlistFilename, $playlistFilePath ) = fileparse( abspathL ( $filePath ) );
	$playlistFilename =~ s#\.\w\w\w?$##;
	#echo status to console
	toLog( $subName, 'Processing playlist XML file: "' . $playlistFilename . ".xml\"...\n" );
	binmode( STDOUT, ":encoding(UTF-8)" );
	print "\n   Processing '$playlistFilename.xml'\n";
	
	#load playlist XML
	my ( $dom, $xmlFH );
	openL ( \$xmlFH, '<:encoding(UTF-8)', $filePath );
	if ( ! fileno( $xmlFH ) ) {
		my $xmlSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $xmlOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		badExit( $subName, "Not able to open playlist XML file for reading: '" . $filePath . "', returned:\n" . $xmlSysErr . "\nand:\n" . $xmlOS_Err );
	} else {
		binmode $xmlFH;
		$dom = XML::LibXML->load_xml( IO => $xmlFH );
		badExit( $subName, "Couldn't load playlist XML file: $playlistFilename.xml" ) unless ( $dom );
	}
	
	#determine playlist name
	my $playlistName;
	if ( $dom->findnodes( '/playlist/@name' ) ) {
		$playlistName = $dom->findnodes( '/playlist/@name' );
	} else {
		$playlistName = $playlistFilename;
	}
	
	#set output object for playlist XML
	toLog( $subName, "- Initializing XML playlist\n" );
	my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
	badExit( $subName, "Not able to create new XML::Writer object" ) if ( ! $writer );
	#write XML Declaration
	$writer->xmlDecl( "UTF-8" ) or badExit( $subName, "Not able to write out XML Declaration" );
	$writer->comment( "*IMPORTANT*: Only 1 attribute/value pair is allowed per each child node of <song>" );
	#write date into root <playlist> tag attribute, with playlist name as attribute
	toLog( $subName, "- Setting date/time for playlist\n" );
	my $now = dateTime();
	my $today = $now->{'date'} . " at " . $now->{'time'};
	$writer->startTag( "playlist", name => $playlistName, date => $today );
	
	#set overall counter for songs
	my $num = 0;
	#loop through each <song> node to determine best tool to use for song file
	foreach my $songNode ( $dom->findnodes( '//song' ) ) {
		++$num;

		updStatus( "Processing song no. " . $num . " ..." );

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
					toLog( $subName, "...Processing song no. " . $num . ": '" . $songFile . "'\n" );
					binmode( STDOUT, ":encoding(UTF-8)" );
					print "     - processing song no. " . $num . ": '" . $songFileName . "'\n";
				} else {
					binmode( STDOUT, ":encoding(UTF-8)" );
					print "    Song no. " . $num . " : '" . $songFileName . "' does not exist\n";
					warning( $subName, "Song no. " . $num . " : '" . $songFile . "' does not exist" );
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
		toLog( $subName, "   - Scanning tags to see if any desired tags are not defined\n" );
		foreach my $tag ( @listOfXmlTags ) {
			if ( ! $tags{$tag} ) {
				#remove empty hash elements, so they don't get removed by 'ffmpeg'
				toLog( $subName, "     - '$tag' tag is not declared, removing key from hash\n" );
				delete $tags{$tag};
			}
		}
		
		#write metadata tags to song file
		writeTags( $num, $writer, \%tags, $songFile, $songNode );
	}
	
	#write out close playlist XML tag
	$writer->endTag( "playlist" );
	$writer->end() or badExit( $subName, "Not able to write end() XML instance to \$writer object" );
	
	#write out new playlist XML
	my $xmlOutFH;
	openL ( \$xmlOutFH, '>:encoding(UTF-8)', $filePath );
	if ( ! fileno( $xmlOutFH ) ) {
		my $xmlSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $xmlOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		badExit( $subName, "Not able to create '" . $filePath . "', returned:\n" . $xmlSysErr . "\nand:\n" . $xmlOS_Err );
	} else {
		my $newfh = select $xmlOutFH; $| = 1; select $newfh;
		print $xmlOutFH $writer or badExit( $subName, "Not able to write out XML to '" . $playlistFilename . ".xml'" );
		close( $xmlOutFH );
	}

	toLog( $subName, "\n...Created Updated Playlist XML file: '" . $filePath . "'\n\n\n" );
	toLog( $subName, " *WARNING*: There were " . $warn{update_ID3_tags} . " warning(s) for process...\n\n\n" ) if ( $warn{update_ID3_tags} );
	toLog( undef, "  ...Finished Updating ID3 Tags for XML in: '" . $dirName . "'\n\n" );
	#echo status to console
	binmode( STDOUT, ":encoding(UTF-8)" );
	print "   Finished Updating ID3 Tags '" . $fileName . "'\n";

	#process end
	updStatus( "Finished Updating ID3 Tags \"" . $fileName . "\"" );
	tkEnd( $subName );
}

#----------------------------------------------------------------------------------------------------------
#method to edit metadata for .mkv song file types
sub mkvTools
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $tagsRef, $songFile ) = @_;

	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;
	toLog( $subName, "   - Preparing for 'mkvextract' to export metadata tags from song file\n" );
	updStatus( "Running 'mkvextract' to export metadata..." );

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
	toLog( $subName, "   - Creating batch file wrapper for 'mkvextract': '" . $mkvBat . "'\n" );
	openL ( \$mkvBatFH, '>:encoding(UTF-8)', $mkvBat );
	if ( ! fileno( $mkvBatFH ) ) {
		my $mkvSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $mkvOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		badExit( $subName, "Not able to create temporary batch file to run 'mkvextract': '" . $mkvBat . "', returned:\n" . $mkvSysErr . "\nand:\n" . $mkvOS_Err );
	} else {
		my $oldFH = select $mkvBatFH; $| = 1; select $oldFH;
		print $mkvBatFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @mkvArgs );
		close( $mkvBatFH );
}

	#execute batch file wrapper to call 'mkvextract' command batch file
	toLog( $subName, "   - Executing batch file for 'mkvextract'\n" );
	my ( $rawStdErr, $stdErr );
	run3( $mkvBat, \undef, \undef, \$rawStdErr );
	$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
	badExit( $subName, "Not able to run 'mkvextract', returned:\n" . $stdErr ) if ( $? || $stdErr);

	#load XML data
	my ( $dom, $xmlFH );
	openL ( \$xmlFH, '<:encoding(UTF-8)', $songFileXml );
	if ( ! fileno( $xmlFH ) ) {
		my $xmlSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $xmlOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		badExit( $subName, "Not able to open XML file: '" . $songFileXml . "', returned:\n" . $xmlSysErr . "\nand:\n" . $xmlOS_Err );
	} else {
		binmode $xmlFH;
		$dom = XML::LibXML->load_xml( IO => $xmlFH );
		badExit( $subName, "Couldn't load XML file: '" . $songFileXml . "'" ) unless ( $dom );
		close( $xmlFH );
	}

	foreach my $xmlNode ( $dom->findnodes( '//Simple' ) ) {
		my $tagName = $xmlNode->findvalue( './Name' );
		my $tagValue = $xmlNode->findvalue( './String' );
		my $lcTagName = lc( $tagName );
		if ( grep /$lcTagName/, @listOfTagArrays ) {
			$tagsRef->{$lcTagName} = $tagValue unless ( $tagsRef->{$lcTagName} );
		}
	}

	toLog( $subName, "   - Cleaning up temporary 'mkvextract' files\n" );
	if ( testL ( 'e', $songFileXml ) ) {
		my $fileDel = unlinkL ( $mkvBat );
		my $unlinkSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $unlinkOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( $subName, "Not able to remove temporary 'mkvextract' batch file: '" . $mkvBat . "', returned:\n" . $unlinkSysErr . "\nand:\n" . $unlinkOS_Err ) if ( ! $fileDel );
		$fileDel = unlinkL ( $songFileXml );
		$unlinkSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		$unlinkOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( $subName, "Not able to remove XML data for song file: '" . $songFileXml . "', returned:\n" . $unlinkSysErr . "\nand:\n" . $unlinkOS_Err ) if ( ! $fileDel );
	} else {
		badExit( $subName, "XML data not created for song file: '" . $songFile . "'" );
	}
}

#----------------------------------------------------------------------------------------------------------
#method to edit metadata for all other song file types
sub exifTools
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $tagsRef, $songFile ) = @_;

	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;
	toLog( $subName, "   - Preparing for 'ExifTool' to export metadata tags from song file\n" );
	updStatus( "Running 'exifTool' to export metadata..." );

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
	toLog( $subName, "   - Creating batch file wrapper for 'exiftool': '" . $jsonBat . "'\n" );
	openL ( \$jsonBatFH, '>:encoding(UTF-8)', $jsonBat );
	if ( ! fileno( $jsonBatFH ) ) {
		my $jsonSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $jsonOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		badExit( $subName, "Not able to create temporary batch file to run 'exiftool': '" . $jsonBat . "', returned:\n" . $jsonSysErr . "\nand:\n" . $jsonOS_Err );
	} else {
		my $oldFH = select $jsonBatFH; $| = 1; select $oldFH;
		print $jsonBatFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @exifToolArgs );
		close( $jsonBatFH );
	}
	#open/close 'exiftool' args file with arguments written to it
	toLog( $subName, "   - Creating argument file for 'exiftool': '" . $exifToolArgsFile . "'\n" );
	openL ( \$argsFH, '>:encoding(UTF-8)', $exifToolArgsFile );
	if ( ! fileno( $argsFH ) ) {
		my $argsSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $argsOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		badExit( $subName, "Not able to create temporary arguments file to run 'exiftool': '" . $exifToolArgsFile . "', returned:\n" . $argsSysErr . "\nand:\n" . $argsOS_Err );
	} else {
		my $oldFH = select $argsFH; $| = 1; select $oldFH;
		print $argsFH @exifToolFileArgs;
		close( $argsFH );
	}

	#execute batch file wrapper to call 'exiftool' command batch file
	toLog( $subName, "   - Executing batch file for 'exiftool'\n" );
	my ( $songFileJson, $rawStdErr, $stdErr );
	run3( $jsonBat, \undef, \$songFileJson, \$rawStdErr );
	$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
	badExit( $subName, "ExifTool is not able to read the metadata of the file, returned:\n" . $stdErr ) if ( $? || $stdErr );
	my $jsonTxt;
	if ( $songFileJson =~ m#(\n\[\{.+)#s ) {
		$jsonTxt = $1;
	}
	#parse json data for song file
	my $json = JSON->new->utf8();
	my $jsonDataRef = $json->decode( $jsonTxt );
	badExit( $subName, "JSON data not created for song file: '" . $songFile . "'" ) unless ( $jsonDataRef );

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
	toLog( $subName, "   - Cleaning up temporary 'exiftool' files\n" );
	if ( testL ( 'e', $jsonBat ) || testL ( 'e', $exifToolArgsFile ) ) {
		my $fileDel = unlinkL ( $jsonBat );
		my $unlinkSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $unlinkOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( $subName, "Not able to remove temporary 'exiftool' batch file: '" . $jsonBat . "', returned:\n" . $unlinkSysErr . "\nand:\n" . $unlinkOS_Err ) if ( ! $fileDel );
		$fileDel = unlinkL ( $exifToolArgsFile );
		$unlinkSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		$unlinkOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( $subName, "Not able to remove arguments file for 'exiftool': '" . $exifToolArgsFile . "', returned:\n" . $unlinkSysErr . "\nand:\n" . $unlinkOS_Err ) if ( ! $fileDel );
	}
}

#----------------------------------------------------------------------------------------------------------
#checking each tag - to set/clean-up values and/or delete values
sub cleanTags
#----------------------------------------------------------------------------------------------------------
{
	my ( $tagsRef, $songFile ) = @_;

	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;
	toLog( $subName, "   - Examining each tag retrieved\n" );
	updStatus( "Cleaning up metadata tags..." );

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
			if ( ( ! $tagsRef->{$key} ) && ( defined $tagsRef->{duration} ) ) {
				$tagsRef->{$key} = $tagsRef->{duration};
			}
			#length is empty
			if ( defined $tagsRef->{$key} ) {
				#if 'length' set to approximate value, clean up
				if ( $tagsRef->{$key} =~ m#\(approx\)#i ) {
						$tagsRef->{$key} =~ s#^(.+)\s*\(approx\)\s*$#$1#i;
				} elsif ( $tagsRef->{$key} =~ m#^0\.# ) {
					undef $tagsRef->{$key};#-x-  0.06 s
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
sub extractTags
#----------------------------------------------------------------------------------------------------------
{
	my ( $num, $tagsRef, $songFile ) = @_;

	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;
	toLog( $subName, "   - <title> or <artist> (or other) tags have not been set, attempting to set from filename & path\n" );


	my ( $fileName, $filePath ) = fileparse( abspathL ( $songFile ) );
	updStatus( "Extracting tags in song: '" . $fileName . "'" );

	#determine values from path of song file, using expected 'Music' directory
	if ( $filePath =~ m#\\Music\\([^\\]+)\\([^\\]+)\\#i ) {
		#song file is inside 'Album'\'Artist'\song file format
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

	if ( $fileName =~ m#((\d)-)?(\d*)\s*-?\s*([^\.]+)\.(aac|alac|flac|m4a|mka|mkv|mp3|ogg|wma)$#i ) {
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
		my $ffprobeBat = $ENV{TEMP} . $FS . 'ffprobe-' . $num . '.bat';
		#batch file handle ref
		my $ffprobeFH;
		#open/close batch file with commands written to it
		toLog( $subName, "   - Creating 'ffprobe' batch file: '" . $ffprobeBat . "'\n" );
		openL ( \$ffprobeFH, '>:encoding(UTF-8)', $ffprobeBat );
		if ( ! fileno( $ffprobeFH ) ) {
			my $ffSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $ffOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			badExit( $subName, "Not able to create temporary batch file to run 'ffprobe': '" . $ffprobeBat . "', returned:\n" . $ffSysErr . "\nand:\n" . $ffOS_Err );
		} else {
			my $oldfh = select $ffprobeFH; $| = 1; select $oldfh;
			#write empty line to batch file in case of file header conflict
			print $ffprobeFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @ffprobeArgs );
			close( $ffprobeFH );
		}
	
		toLog( $subName, "   - Executing 'ffprobe' batch file\n" );
		my ( $rawStdErr, $stdErr );
		run3( $ffprobeBat, \undef, \$length, \$rawStdErr );
		$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
		warning( $subName, "Not able to run 'ffprobe', returned:\n" . $stdErr ) if ( $? || $stdErr );
		if ( $length =~ m#\n(\d+)# ) {
			$length = $1;
			my $minutes = $length / 60;
			$minutes = sprintf "%d", $minutes;
			my $remSecs = $length - ( $minutes * 60 );
			$remSecs = sprintf "%.02d", $remSecs;
			$tagsRef->{minutes} = $minutes . ':' . $remSecs;
			$tagsRef->{length} = int( $length );
		}
	
		if ( ( ! $tagsRef->{title} ) && ( ! $tagsRef->{artist} ) ) {
			warning( $subName, "Could not determine <title>, <artist>, or possibly other tags" );
		}
	
		toLog( $subName, "   - Cleaning up temporary 'ffprobe' files\n" );
		if ( testL ( 'e', $ffprobeBat ) ) {
			my $fileDel = unlinkL ( $ffprobeBat );
			my $unlinkSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $unlinkOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			warning( $subName, "Not able to remove temporary 'ffprobe' batch file: '" . $ffprobeBat . "', returned:\n" . $unlinkSysErr . "\nand:\n" . $unlinkOS_Err ) if ( ! $fileDel );
		} else {
			warning( $subName, "Not able to delete 'ffprobe' batch file: '" . $ffprobeBat . "'" );
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

	my ( $package, $file, $line, $subName ) = caller( 1 );
	$subName =~ s#main::##;
	toLog( $subName, "   - Writing XML nodes to XML playlist\n" );
	updStatus( "Writing updated tag metadata to XML playlist..." );

	#write out tags to XML
	my $numberVal = $songNode->findvalue( './@number' );
	#write out XML 'song' element
	$writer->startTag( "song", number => $numberVal );

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
	$writer->endTag( "song" );

	#prepare file for ffmpeg to write metadata (can't write out to self) - copy original to temp file
	toLog( $subName, "   - Creating temporary song file for 'ffmpeg' to use as original song file\n" );
	my ( $songFileName, $songFilePath ) = fileparse( abspathL ( $songFile ) );
	my $tmpSongFileName = $songFileName;
	if ( $tmpSongFileName =~ s#(.)\.(\w\w\w\w?)$#$1_tmp\.$2#i ) {
		#verifying file is not left open by other process
		close( $songFilePath . $tmpSongFileName );
		close( $songFilePath . $songFileName );
		renameL ( $songFilePath . $songFileName, $songFilePath . $tmpSongFileName );
		sleep 1;
		if ( ! testL ( 'e', $songFilePath . $tmpSongFileName ) ) {
			my $songSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $songOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			badExit( $subName, "Not able to rename song file: '" . $songFilePath . $songFileName . "' to temp file: '" . $songFilePath . $tmpSongFileName . "', returned:\n" . $songSysErr . "\nand:\n" . $songOS_Err );
		}
	}

	#create array of metadata tag args to add in ffmpeg (will splice into command args array)
	toLog( $subName, "   - Creating 'ffmpeg' arguments for submission of metadata to song file\n" );
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

	toLog( $subName, "   - Building 'ffmpeg' command statement\n" );
	my @ffmpegArgs = ( 
		#ffmpeg executable
		'"' . $ffmpegCmd . '"',
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
	splice( @ffmpegArgs, 11, 0, @newMeta );
	toLog( $subName, "   - System command to rewrite song metadata with 'ffmpeg': '" . join( " ", @ffmpegArgs ) . "'\n" );

	#start process to create batch file with 'ffmpeg' commands
	my $ffmpegBat = $ENV{TEMP} . $FS . 'ffmpeg-' . $num . '.bat';
	#batch file handle ref
	my $ffmpegFH;
	#open/close batch file with commands written to it
	toLog( $subName, "   - Creating batch file with 'ffmpeg' commands: '" . $ffmpegBat . "'\n" );
	openL ( \$ffmpegFH, '>:encoding(UTF-8)', $ffmpegBat );
	if ( ! fileno( $ffmpegFH ) ) {
		my $ffmpegSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $ffmpegOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		badExit( $subName, "Not able to create temporary batch file to run 'ffmpeg': '" . $ffmpegBat . "', returned:\n" . $ffmpegSysErr . "\nand:\n" . $ffmpegOS_Err );
	} else {
		my $prevfh = select $ffmpegFH; $| = 1; select $prevfh;
		#write empty line to batch file in case of file header conflict
		print $ffmpegFH "\n" . 'chcp 65001' . "\n" . 'call ' . join( " ", @ffmpegArgs );
		close( $ffmpegFH );
	}

	#execute batch file wrapper to call 'ffmpeg' commands batch file
	toLog( $subName, "   - Executing batch file for 'ffmpeg'\n" );
	my ( $rawStdErr, $stdErr );
	run3( $ffmpegBat, \undef, \undef, \$rawStdErr );
	$stdErr = decode( $Config{enc_to_system} || 'UTF-8', $rawStdErr );
	badExit( $subName, "Not able to run 'ffmpeg', returned:\n" . $stdErr ) if ( $? || $stdErr );

	#removing temp song file & 'ffmpeg' batch file, if successful
	toLog( $subName, "   - Removing temporary song files & batch files\n" );
	if ( testL ( 'e', $songFile ) ) {
		my $fileDel = unlinkL ( $songFilePath . $tmpSongFileName );
		my $unlinkSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $unlinkOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( $subName, "Not able to remove temporary song file: '" . $songFilePath . $tmpSongFileName . "', returned:\n" . $unlinkSysErr . "\nand:\n" . $unlinkOS_Err ) if ( ! $fileDel );
		$fileDel = unlinkL ( $ffmpegBat );
		$unlinkSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		$unlinkOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		warning( $subName, "Not able to remove temporary 'ffmpeg' batch file: '" . $ffmpegBat . "', returned:\n" . $unlinkSysErr . "\nand:\n" . $unlinkOS_Err ) if ( ! $fileDel );
	} else {
		badExit( $subName, "Not able to remove temporary song file & batch files for song file: '" . $songFile . "'" );
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
		-text							=> 'Create XML',
		-font							=> TK_FNT_B,
		-state						=> 'normal',
		-bg								=> TK_COLOR_BG,
		-fg								=> TK_COLOR_FG,
		-activebackground => TK_COLOR_ABG
	);

	$M->{'window'}->update();
}

#----------------------------------------------------------------------------------------------------------
# program exits
sub tkExit
#----------------------------------------------------------------------------------------------------------
{
	#call to save current file/directory selection
	saveLastVal();

	#close log file
	endLog();

	$M->{'window'}->destroy;
	exit( 0 );
}

#----------------------------------------------------------------------------------------------------------
#save current file/directory selection for next use
sub saveLastVal
#----------------------------------------------------------------------------------------------------------
{
	my ( $dirOS_Err, $dirSysErr, $lastFH );

	my $lastValDir = $ENV{APPDATA} . $FS . $progName;
	if ( ! testL ( 'd', $lastValDir ) ) {
		mkdirL ( $lastValDir );
		$dirSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		$dirOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
	}
	if ( ! testL ( 'd', $lastValDir ) ) {
		warning( undef, "Not able to create 'lastValue.cfg' directory: '" . $lastValDir . "', returned:\n" . $dirSysErr . "\nand:\n" . $dirOS_Err );
	} else {
		my $lastFile = $lastValDir . $FS . 'lastValue.cfg';
		openL ( \$lastFH, '>:encoding(UTF-8)', $lastFile );
		$dirSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		$dirOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		if ( ! testL ( 'e', $lastFile ) ) {
			warning( undef, "Not able to open last value file: '" . $lastFile . "', returned:\n" . $dirSysErr . "\nand:\n" . $dirOS_Err );
		} else {
			my $lastValFH = select $lastFH; $| = 1; select $lastValFH;
			if ( $filePath && $dirName ) {
				print $lastFH $filePath . "\n" . $dirName;
			} elsif ( $filePath ) {
				print $lastFH $filePath;
			} elsif ( $dirName ) {
				print $lastFH "\n" . $dirName;
			}
			close( $lastFH );
		}
	}
}

#----------------------------------------------------------------------------------------------------------
#read last file/directory selection for current use
sub readLastVal
#----------------------------------------------------------------------------------------------------------
{
	my @lastVal;

	my $lastValDir = $ENV{APPDATA} . $FS . $progName;
	my $lastFile = $lastValDir . $FS . 'lastValue.cfg';
	#only read if value not passed
	if ( ( testL ( 's', $lastFile ) ) && ( ! $ARGV[0] ) ) {
		my $lastFH;
		openL ( \$lastFH, '<:encoding(UTF-8)', $lastFile );
		my $dirSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
		my $dirOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
		if ( ! testL ( 's', $lastFile ) ) {
			warning( undef, "Not able to open last value config file: '" . $lastFile . "', returned:\n" . $dirSysErr . "\nand:\n" . $dirOS_Err );
		} else {
			@lastVal = <$lastFH>;
			close( $lastFH );
			chomp( @lastVal );
			$filePath = $lastVal[0];
			$dirName = $lastVal[1];
			if ( $lastVal[0] ) {
				( $fileName, $dirName ) = fileparse( abspathL ( $filePath ) );
				#value returned in 1st line of lastValue.cfg has zero-width character(s) at end of value - rebuild
				$filePath = $dirName . $fileName;
			}
		}
	}
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
		openL ( \$funcLogFH, '>:encoding(UTF-8)', $log );
		if ( ! fileno( $funcLogFH ) ) {
			my $funcSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $funcOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			badExit( $funcName, "Not able to create log file: '" . $log . "', returned:\n" . $funcSysErr . "\nand:\n" . $funcOS_Err );
		} else {
			#redirect STDERR to log file
			open( STDERR, '>>:encoding(UTF-8)', $log ) or warning( undef, "Not able to redirect STDERR" );
			my $oldfh = select $funcLogFH; $| = 1; select $oldfh;
		}

		toLog( $funcName, "$Sep\nFunction: $funcName\n\tDate: $timeSt\n$Sep" );
	} else {
    if ( testL ( 'd', $dirName ) ) {
	    $log = "$dirName$progName.log";
	  } else {
	  	my $dir = getcwdL();
	    $log = "$dir$FS$progName.log";
	  }
		openL ( \$logFH, '>:encoding(UTF-8)', $log );
		if ( ! fileno( $logFH ) ) {
			my $logSysErr = decode( $Config{enc_to_system} || 'UTF-8', $! );
			my $logOS_Err = decode( $Config{enc_to_system} || 'UTF-8', $^E );
			badExit( undef, "Not able to create log file: '" . $log . "', returned:\n" . $logSysErr . "\nand:\n" . $logOS_Err );
		} else {
			#redirect STDERR to log file
			open( STDERR, '>>:encoding(UTF-8)', $log ) or warning( undef, "Not able to redirect STDERR" );
			my $oldfh = select $logFH; $| = 1; select $oldfh;
		}

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
