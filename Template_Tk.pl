#!/usr/bin/perl -w

#**********************************************************************************************************
# File: Template_Tk.pl
# Desc: Perl script template that builds a Tk window with 2 function buttons and an 'Exit' button
#       - Includes logging (global & per function) and window prompt functions
#       - Includes a search box for a directory or file, populates search box if an argument is passed to 
#         Perl script
#
# Usage:  perl C:\git_playlist\Template_Tk.pl [PLAYLIST_XML_FILE](optional)
#
#	Author: Richard Davis
#         rich@richandsteph.com
#
#**********************************************************************************************************
#
# Version 1.0  -  31 Jan 2026  RAD  initial creation
#         2.0  -  15 Feb 2026  RAD  updated to use current standards in 'playlist_utilities.pl'
#
#
#   TO-DO:
#         1) none
#
#**********************************************************************************************************

my $Version = "2.0";

use strict;
use warnings;
use utf8::all;
use feature 'unicode_strings';
use open ':std', IO => ':raw :encoding(UTF-8)';

use Config;
use Data::Dumper qw( Dumper );
use File::Basename qw( fileparse );
use Tk;
use Tk::DialogBox;
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
use constant TK_FNT_BIGGER		=> "-*-lucida-bold-r-normal-*-18-*";
use constant TK_FNT_BIGB		=> "-*-lucida-bold-r-normal-*-14-*";
use constant TK_FNT_BIG			=> "-*-lucida-medium-r-normal-*-14-*";
use constant TK_FNT_BI			=> "-*-lucida-bold-i-normal-*-12-*";
use constant TK_FNT_B			=> "-*-lucida-bold-r-normal-*-12-*";
use constant TK_FNT_I			=> "-*-lucida-medium-i-normal-*-12-*";

umask 000;

#set error/warning status
my $warnCnt = 0;

#global variables
my $Sep = "-" x 110;
my $SEP = "=" x 110;
my $proc = 'Waiting on command...';
my $progName = progNm();
#instantiate warning hash
my %warn;
my ( $dirPath, $fileName, $fileFQN, $log, $stat );
#log file handles for function log vs. global log
my ( $funcLogFH, $logFH );
my $FS = '\\';

#process variables
if ( $ARGV[0] ) {
	$fileFQN = $ARGV[0];
	#directory separator default for Windows command line
	$fileFQN =~ s#[\/\\]#$FS#g;
	( $fileName, $dirPath ) = fileparse( abspathL ( $fileFQN ) );
	if ( ! testL ( 'd', $dirPath ) ) {
		$dirPath = getcwdL();
	}
	$fileFQN = "$dirPath$fileName";
}

#create initial window and pass to tk caller, start overall logging
startLog();
my $M->{'window'} = MainWindow->new();
tkMainWindow();
MainLoop;

#----------------------------------------------------------------------------------------------------------
# read directory and build a list of XML files
sub getFiles
#----------------------------------------------------------------------------------------------------------
{
	my ( @fileFolder, @files );

	updStatus( undef, 'Building list of files...' );

	opendir DIR, $dirPath or badExit( undef, "Could not open directory\n looking in <$dirPath>" );
		@fileFolder = readdir DIR;
	closedir DIR;
	@files = grep m/\.xml$/i, @fileFolder;
	unless ( scalar( @files ) ) {
		badExit( undef, "No files were found in directory\n looking in <$dirPath>" );
	}
	
	#change to working directory
	chdirL( $fileFolder[0] );

	return( @files );
}

#----------------------------------------------------------------------------------------------------------
# run process on all files passed in array
sub mainProcess
#----------------------------------------------------------------------------------------------------------
{
	my ( @files ) = @_;

	#determine if called by tkStart1 or tkStart2
	my ( $package, $file, $line, $subname ) = caller( 1 );
	$subname =~ s#main::##i;
	my $funcName;
	if ( $subname =~ m#^tkStart1$#i ) {
		$funcName = 'Function1';
	} elsif ( $subname =~ m#^tkStart2$#i ) {
		$funcName = 'Function2';
	} else {
		undef $funcName;
	}

	#loop through each file
	foreach ( @files ) {
		updStatus( undef, "Processing...$_" );
		toLog( $funcName, "\nBegin Processing...$_\n" );
		my $command;

		toLog( $funcName, "\n\tRunning $command\n\n" );
		updStatus( "Starting $progName process", undef );

		my $status = 0;

		#if encountered warnings or errors
		if ( $status == 2 ) {
			badExit( $funcName, "Process failed\n\tPlease verify log at $log" );
		} elsif ( $status == 1 ) {
			my $ans = promptUser( 'warning', "Process generated Warnings,\n\tverify log at <$log>,\n do you want to continue?", 'Yes', 'No' );
			if ( $ans =~ m#No# ) {
				badExit( $funcName, "User chose to stop process,\n Warnings generated in\n <$log>" );
			}
			toLog( $funcName, "\n**WARNING: Process generated Warnings,\n    verify log at <$log>\n\n" );
		}

		toLog( $funcName, "\nFinished Processing\n\n" );
	}
}

#----------------------------------------------------------------------------------------------------------
#start logging to file, if no arg then set as main program log otherwise set to passed arg function name
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

#----------------------------------------------------------------------------------------------------------
# draw main GUI window
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
	#   change the -textvariable value to \$fileFQN for files
	#   change the -command value to '[\&tkGetFile, $fileFQN]' for files
	$choose->Label(
		-text=>'File:',
		-font=>TK_FNT_BIGB,
		-bg=>TK_COLOR_BG,
		-fg=>TK_COLOR_FG
	)->pack( -side=>'left' );
	my $entry = $choose->Entry(
		-textvariable=>\$fileFQN,
		-width=>'30',
		-bg=>TK_COLOR_FIELD,
		-fg=>TK_COLOR_FG
	)->pack( -side=>'left' );
	$entry->xview( 'end' );
	$M->{'select'} = $choose->Button(
		-text => "...",
		-command => [ \&tkGetFile, $fileFQN ],
		-bg => TK_COLOR_BG,
		-fg => TK_COLOR_FG,
		-activebackground=>TK_COLOR_ABG,
		-width => 3
	)->pack( -side=>'left', -padx=>'2', -pady=>'8' );

	#status frame
	my $statframe = $status->Frame( -relief=>'sunken', -borderwidth=>'2', -bg=>TK_COLOR_FIELD )->pack( -padx=>'4', -fill=>'x' );
	$M->{'progress'}= $statframe->Label( -bg=>TK_COLOR_FIELD, -textvariable=>\$stat )->pack( -side=>'left', -fill=>'x' );

	#buttons frame
	$M->{'func1'} = $buttons->Button(
		-text=>'Function 1',
		-font=>TK_FNT_B,
		-command=>\&tkStart1,
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
	if ( $dirPath ) {
		$M->{'func1'}->focus();
	} else {
		$M->{'select'}->focus();
	}
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
#creates prompt window
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
		if ( $type =~ m#( error|warning )#i ) {
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
#first function
sub tkStart1
#----------------------------------------------------------------------------------------------------------
{
	#must specify directory
	unless ( $fileName )
	{
		my $ans = promptUser( 'warning', "No file selected,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( 'Function1', "User chose to stop process,\n no file selected or passed" );
		}
		$M->{'select'}->focus();
		return;
	}

	#change buttons to indicate process started
	$M->{'func1'}->configure(
		-text=>'Running...',
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
	startLog( 'Function1' );
	
	#get list of files and change to directory, if $fileFQN not passed in perl arg
	my @files;
	if ( testL ( 'e', $fileFQN ) ) {
    push( @files, $fileFQN );
  } else {
		@files = getFiles();
	}
	#loop through each file in directory
	mainProcess( @files );

	#process ended
	my $folderNm;
	( $folderNm ) = fileparse( abspathL ( $dirPath ) );
	updStatus( "Finished processing \"" . $folderNm . "\"" );
	tkEnd( 'Function1' );
}

#----------------------------------------------------------------------------------------------------------
#second function
sub tkStart2
#----------------------------------------------------------------------------------------------------------
{
	#must specify directory
	unless ( $fileName )
	{
		my $ans = promptUser( 'warning', "No file selected,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( 'Function2', "User chose to stop process,\n no file selected or passed" );
		}
		$M->{'select'}->focus();

		return;
	}

	#change buttons to indicate process started
	$M->{'func1'}->configure(
		-text=>'Function1',
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
	
	#get list of files and change to directory, if $fileFQN not passed in perl arg
	my @files;
	if ( testL ( 'e', $fileFQN ) ) {
    push( @files, $fileFQN );
  } else {
		@files = getFiles();
	}
	#loop through each file in directory
	mainProcess( @files );

	#process ended
	my $folderNm;
	( $folderNm ) = fileparse( abspathL ( $dirPath ) );
	updStatus( "Finished processing \"" . $folderNm . "\"" );
	tkEnd( 'Function2' );
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
  $log = "$dirPath$FS$progName.log";

	#focus on exit button and reset status
	$proc = 'Waiting on command...';
	$M->{'exit'}->focus();

	#reset buttons
	$M->{'func1'}->configure(
		-text=>'Function 1',
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
# GUI program exit & write out selections from GUI for next run use
sub tkExit
#----------------------------------------------------------------------------------------------------------
{
	#close log file
	endLog( undef );

	$M->{'window'}->destroy;
	exit( 0 );
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
sub progNm
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
