#!/usr/bin/perl -w

#**********************************************************************************************************
# File: Template_Tk.pl
# Desc: Perl script template that builds a Tk window with 2 function buttons and an 'Exit' button
#       - Includes logging and window prompt functions
#       - Includes a search box for a directory or file, but populates that search box if an argument is passed to Perl script
#
#       **directory currently assumed, if passing file check functions for use of $dirName THROUGHOUT and modify with $fileName
#
#	Author: Richard Davis
#	  	rich@richandsteph.com
#
#**********************************************************************************************************
# version 1.0  -  30 Jan 2026  RAD  initial creation
#
#
#   TO-DO:
#         1) none
#
#**********************************************************************************************************

my $Version = "1.0";

use strict;
use warnings;
use utf8::all;
use feature 'unicode_strings';
use open ':std', IO => ':raw :encoding(UTF-8)';

use Data::Dumper qw( Dumper );
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
my $progNm = progNm();
my ( $dirName, $fileName, $log, $stat );

#process variables
$dirName = '';
$fileName = '';
if ( $ARGV[0] ) {
	$fileName = $ARGV[0];
	( undef, $dirName ) = fileparse( abspathL ( $fileName ) );
}
#directory separator default for Windows command line
my $FS = '\\';
$fileName =~ s#[\/\\]#$FS#g;

#create initial window and pass to tk caller
my $M->{'window'} = MainWindow->new();
tkMainWindow();
MainLoop;

#-------------------------------------------------------------
# read directory and build a list of XML files
sub getFiles
#-------------------------------------------------------------
{
	my ( @fileFolder, @files );

	updStatus( undef, 'Building list of files...' );

	opendir DIR, $dirName or badExit( "Could not open directory\n looking in <$dirName>" );
		@fileFolder = readdir DIR;
	closedir DIR;
	@files = grep m/\.xml$/i, @fileFolder;
	unless ( scalar( @files ) ) {
		badExit( "No files were found in directory\n looking in <$dirName>" );
	}
	
	#change to working directory
	chdirL( $fileFolder[0] );

	return( @files );
}

#-------------------------------------------------------------
# run process on all files passed in array
sub mainProcess
#-------------------------------------------------------------
{
	my ( @files ) = @_;

	#loop through each file
	foreach ( @files ) {
		updStatus( undef, "Processing...$_" );
		toLog( "\nBegin Processing...$_\n" );
#-x-		$fileName = "$dirName$FS$_";
		my $command;

		toLog( "\n\tRunning $command\n\n" );
		updStatus( "Starting $progNm process", undef );

		my $status = 0;

		#if encountered warnings or errors
		if ( $status == 2 ) {
			badExit( "Process failed\n\tPlease verify log at $log" );
		} elsif ( $status == 1 ) {
			my $ans = promptUser( 'warning', "Process generated Warnings,\n\tverify log at <$log>,\n do you want to continue?", 'Yes', 'No' );
			if ( $ans =~ m#No# ) {
				badExit( "User chose to stop process,\n Warnings generated in\n <$log>" );
			}
			toLog( "\n**WARNING: Process generated Warnings,\n    verify log at <$log>\n\n" );
		}

		toLog( "\nFinished Processing\n\n" );
	}
}

#-------------------------------------------------------------
sub startLog
#-------------------------------------------------------------
{
	my $now = dateTime();
	my $timeSt = $now->{'date'} . " at " . $now->{'time'};
	$log = "$dirName$FS$progNm.log";

	open LOG, ">$log" or badExit( "Not able to create log file\n creating in <$log>" );
	#redirect STDERR to log file
	open STDERR, ">>$log";
	my $oldfh = select LOG; $| = 1; select $oldfh;
	toLog( "$SEP\nTool: $progNm\n\tVersion: $Version\n\n\tDate: $timeSt\n$Sep" );
}

#-------------------------------------------------------------
#write to log file
sub toLog
#-------------------------------------------------------------
{
	my ( $msg ) = @_;

	if ( fileno LOG ) {
		print LOG $msg;
	} else {
		#log file is not open, write to error window
		my ( $package, $file, $line, $subname ) = caller( 1 );
		$subname =~ s#main::##;
		unless ( $subname =~ m#badExit#i ) {
			badExit( "$msg" );
		}
	}
}

#-------------------------------------------------------------
sub endLog
#-------------------------------------------------------------
{
	if ( fileno LOG ) {
		toLog( "$progNm Process Completed\n$SEP\n\n" );
	}
	close LOG;
}

#-------------------------------------------------------------
sub tkMainWindow
#-------------------------------------------------------------
{
	#main window
	$M->{'window'}->configure( -bg=>TK_COLOR_BG, -fg=>TK_COLOR_FG, -title=>"$progNm..." );
	
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
		-text=>"$progNm Tool"
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
	#   change the -textvariable value to /$fileName for files
	#   change the -command value to '[/&tkGetFile, $fileName]' for files
	$choose->Label(
		-text=>'File:',
		-font=>TK_FNT_BIGB,
		-bg=>TK_COLOR_BG,
		-fg=>TK_COLOR_FG
	)->pack( -side=>'left' );
	my $entry = $choose->Entry(
		-textvariable=>\$fileName,
		-width=>'30',
		-bg=>TK_COLOR_FIELD,
		-fg=>TK_COLOR_FG
	)->pack( -side=>'left' );
	$entry->xview( 'end' );
	$M->{'select'} = $choose->Button(
		-text => "...",
		-command => [ \&tkGetFile, $fileName ],
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
	if ( $dirName ) {
		$M->{'func1'}->focus();
	} else {
		$M->{'select'}->focus();
	}
}

#-------------------------------------------------------------
#update status in window, 1st arg is current status and 2nd arg is current process
sub updStatus
#-------------------------------------------------------------
{
	if ( $_[0] ) { $stat = $_[0] };
	if ( $_[1] ) { $proc = $_[1] };

	$M->{'window'}->update();
}

#-------------------------------------------------------------
#creates prompt window
#  -returns user's response (name of button)
#  -if 1st arg specified as 'warning' or 'error', will display that image and include in window title
#  -3rd arg, and so forth, create buttons
#  -3rd arg button has default focus
sub promptUser
#-------------------------------------------------------------
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
	$title = "$progNm...$title";

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

#-------------------------------------------------------------
#user chooses directory
sub tkGetDir
#-------------------------------------------------------------
{
	my ( $filePath ) = @_;

	$filePath = $M->{'window'}->chooseDirectory(
		-initialdir=>$filePath,
		-title=>'Choose Directory...'
	);

	if ( testL( 'e', $filePath ) ) {
		$dirName = $filePath;
	}
}

#-------------------------------------------------------------
#user chooses file
sub tkGetFile
#-------------------------------------------------------------
{
	my ( $filePath ) = @_;
	my ( $dir, $file );

	if ( testL( 'e', $filePath ) ) {
		( $file, $dir ) = fileparse( abspathL ( $filePath ) );
	}

	$filePath = $M->{'window'}->getOpenFile(
		-initialdir=>$dir,
		-initialfile=>$file,
		-title=>'Choose File...'
	);

	if ( testL( 'e', $filePath ) ) {
		$fileName = $filePath;
	}
}

#-------------------------------------------------------------
#first function
sub tkStart1
#-------------------------------------------------------------
{
	#must specify directory
	unless ( $fileName )
	{
		my $ans = promptUser( 'warning', "No file selected,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( "User chose to stop process,\n no file selected or passed" );
		}
		$M->{'select'}->focus();
		return;
	}

	#change buttons to indicate process started
	$M->{'func1'}->configure(
		-text=>'Running...',
		-state=>'disabled',
		-fg=>TK_COLOR_GREYBUT,
		-bg=>TK_COLOR_FIELD,
		-activebackground=>TK_COLOR_FIELD
	);
	$M->{'func2'}->configure(
		-text=>'Function 2',
		-font=>TK_FNT_BI,
		-state=>'disabled',
		-fg=>TK_COLOR_GREYBUT,
		-bg=>TK_COLOR_BG,
		-activebackground=>TK_COLOR_BG,
		-disabledforeground=>TK_COLOR_GREYBUT
	);
	$M->{'exit'}->focus();

	#starting log process
	startLog();
	
	#get list of files and change to directory, if $fileName not passed in perl arg
	my @files;
	if ( testL( 'e', $fileName ) ) {
    push( @files, $fileName );
  } else {
		@files = getFiles();
	}
	#loop through each file in directory
	mainProcess( @files );

	#process ended
	my $folderNm;
	( $folderNm ) = fileparse( abspathL ( $dirName ) );
	updStatus( "Finished processing \"" . $folderNm . "\"" );
	tkEnd();
}

#-------------------------------------------------------------
#second function
sub tkStart2
#-------------------------------------------------------------
{
	#must specify directory
	unless ( $fileName )
	{
		my $ans = promptUser( 'warning', "No file selected,\n do you want to continue?", 'Yes', 'No' );
		if ( $ans =~ m#No# ) {
			badExit( "User chose to stop process,\n no file selected or passed" );
		}
		$M->{'select'}->focus();

		return;
	}

	#change buttons to indicate process started
	$M->{'func1'}->configure(
		-text=>'Function 1',
		-font=>TK_FNT_BI,
		-state=>'disabled',
		-fg=>TK_COLOR_GREYBUT,
		-bg=>TK_COLOR_BG,
		-activebackground=>TK_COLOR_BG,
		-disabledforeground=>TK_COLOR_GREYBUT
	);
	$M->{'func2'}->configure(
		-text=>'Running...',
		-state=>'disabled',
		-font=>TK_FNT_B,
		-fg=>TK_COLOR_GREYBUT,
		-bg=>TK_COLOR_FIELD,
		-activebackground=>TK_COLOR_FIELD
	);
	$M->{'exit'}->focus();

	#starting log process
	startLog();
	
	#get list of files and change to directory, if $fileName not passed in perl arg
	my @files;
	if ( testL( 'e', $fileName ) ) {
    push( @files, $fileName );
  } else {
		@files = getFiles();
	}
	#loop through each file in directory
	mainProcess( @files );

	#process ended
	my $folderNm;
	( $folderNm ) = fileparse( abspathL ( $dirName ) );
	updStatus( "Finished processing \"" . $folderNm . "\"" );
	tkEnd();
}

#-------------------------------------------------------------
# function 1 or function 2 ends successfully - log closed and window refreshed for restart
sub tkEnd
#-------------------------------------------------------------
{
	#close log file
	endLog();
	undef $log;

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

#-------------------------------------------------------------
# program exits
sub tkExit
#-------------------------------------------------------------
{
	#close log file
	endLog();

	$M->{'window'}->destroy;
	exit( 0 );
}

#-------------------------------------------------------------
sub dateTime
#-------------------------------------------------------------
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
	}
	$yr = 1900 + $yr;

	#set available forms of date & time
	$now->{'date'} = "$mon $day, $yr";
	$now->{'time'} = "$hr:$min $tod";
	
	return( $now );		
}

#-------------------------------------------------------------
#return the name of the program currently running
sub progNm
#-------------------------------------------------------------
{
	my $prog;

	#running under PerlApp, so get name of program
	if ( defined $PerlApp::VERSION ) { $prog = PerlApp::exe(); }
	# Not running PerlAppified, so file should already exist
	else { $prog = fileparse( $0 ); }

	$prog =~ s#\..*$##;
	return( $prog );
}

#-------------------------------------------------------------
#error in process, write out error to log and/or window and exit
sub badExit
#-------------------------------------------------------------
{
	my ( $error ) = @_;

	#store any returned system error info
	if ( $! or $@ ) {
	  $error .= "\n\n failed with following error message: $!$@";
	}
	updStatus( undef, 'ERROR...' );

	if ( fileno LOG ) {
		toLog( " **ERROR: $error\n" );
	}

	promptUser( 'error', $error );

	#close log if open
	if ( fileno LOG ) {
		endLog();
	}

	#close window
	$M->{'window'}->destroy;

	#return exception code
	exit 255;
}
