#!/usr/bin/perl -w

#********************************************************************************************************
#
#	File: make_m3u.pl
#	Desc: creates playlist .m3u file from XML input
#
#	Author: Richard Davis
#	  	rich@richandsteph.com
#
#********************************************************************************************************
# version 1.0 -  28 Feb 2024	RAD	initial creation
#         1.1 -  23 Mar 2025  RAD removed counter from m3u entry (not needed), changed header/closing 
#                                 info
#         1.2 -  26 Mar 2025  RAD added quotes around artist in log
#         1.3 -  21 Apr 2025  RAD changed logic for iterating over song data to use hashes
#         1.4 -  16 May 2025  RAD changed to handle all unicode character issues
#         1.5 -  22 Dec 2025  RAD added specified unicode file handling for 'openL'
#         1.6 -  28 Dec 2025  RAD swapped artist - title output to match iTunes export
#         1.7 -   6 Jan 2026  RAD removed unneeded Unicode pragmas / added '$' testing directory for 
#                                 scouring /added output of statuses to console / added output of "." 
#                                 to command shell to show progress when crawling directories
#         1.8 -   6 Jan 2026  RAD added output of $title, $seconds, $artist when fails to populate
#         1.9 -  19 Jan 2026  RAD removed sorting function for .m3u items (not very reliable, w/o 
#                                 multiple sorts)
#        1.10 -  20 Jan 2026  RAD corrected add to $m3uData of each song file / removed previous 
#                                 commented out lines
#
#
#   TO-DO:
#         1) none
#
#********************************************************************************************************

my $Version = "1.10";

use strict;
use warnings;
use utf8::all;
use feature 'unicode_strings';
use open ':std', IO => ':raw :encoding(UTF-8)';

use Carp qw( croak carp );
use Data::Dumper;
use File::Basename qw( fileparse );
use File::Find::utf8 qw( find );
use Win32::LongPath qw( abspathL getcwdL openL );
use XML::LibXML;

my $FS = '\\';
my $status = 1;

#start logging
my $logFH;
my $logFile = 'make_m3u.log';
$logFile =~ s#[\\/]#$FS#g;
startLog( $logFile );

#get list of files from current directory
my @workDir = getcwdL();
$workDir[0] =~ s#[\\\/]#$FS#g;
#-x-my @fileLst = listDir( $workDir );
my @fileLst;
find( \&wanted, @workDir );

#loop through each XML file in directory
foreach my $xmlFile ( @fileLst ) {
	toLog( "...Processing XML file: '$xmlFile'\n\n" );
	#echo status to console
	binmode( STDOUT, ":encoding(UTF-8)" );
	print "\n   Processing '$xmlFile'\n";


	#load XML data
	my $xmlFH;
	openL( \$xmlFH, '<:encoding(UTF-8)', $xmlFile ) or badExit( "Not able to open XML file for reading: '" . $xmlFile . "'" );
		binmode $xmlFH;
		my $dom = XML::LibXML->load_xml( IO => $xmlFH );
		badExit( "\n\nCouldn't load XML file: $xmlFile" ) unless ($dom);
	
	#create M3U playlist header
	my $m3uData = "#EXTM3U\n#EXTENC: UTF-8\n#PLAYLIST:";
	my $m3uFileName;
	if ( $dom->findnodes( '/playlist/@name' ) ) {
		$m3uFileName = $dom->findnodes( '/playlist/@name' );
	} else {
		( $m3uFileName ) = fileparse( abspathL( $xmlFile ) );
		$m3uFileName =~ s#\.\w\w\w?$##;
	}
	$m3uData .= "$m3uFileName\n";
	my $date = localtime( time() );
	toLog( "Setting date/time for playlist\n" );
	$m3uData .= '#EXTINF:DATE - ' . $date . "\n";

	#create hashes of sorted data for output / title, artist, & song number for logging
	my %m3uItem;
	my %m3uTitle;
	my %m3uArtist;
	my %m3uNum;
	#parse out data for .m3u entry
	foreach my $songNode ( $dom->findnodes( '//song' ) ) {
		my ( $seconds, $title, $artist, $path );
		$seconds = ( $songNode->findvalue( 'duration' ) );
		$title = ( $songNode->findvalue( 'title' ) );
		$artist = ( $songNode->findvalue( 'artist' ) );
		$path = ( $songNode->findvalue( 'path' ) );
		$m3uNum{$path} = ( $songNode->findvalue( './@number' ) );
		
		#exit if no .m3u data found
		badExit( "No .m3u entry made, current entry path: '" . $path . "', title: '" . $title . "', artist: '" . $artist . "', seconds: '" . $seconds . "'" ) unless ( $seconds && $title && $artist && $path );
		#add to m3u hash keyed by path
		$m3uItem{$path} = '#EXTINF:' . $seconds . ',' . $title . ' - ' . $artist . "\n" . $path . "\n";
		$m3uTitle{$path} = $title;
		$m3uArtist{$path} = $artist;

		#add song to compiled data
		$m3uData .= $m3uItem{$path};
		toLog( "Writing \"$m3uTitle{$path}\" by \"$m3uArtist{$path}\" from number $m3uNum{$path} to .m3u file\n" );
	}

	#write out new .m3u playlist file
	my $m3uFH;
	my $m3uFile = $xmlFile;
	$m3uFile = $m3uFileName . '.m3u';
	openL ( \$m3uFH, '>:encoding(UTF-8)', $m3uFile ) or badExit( "Not able to create '$m3uFile'" );
		my $oldfh = select $m3uFH; $| = 1; select $oldfh;
		print $m3uFH $m3uData;
	close $m3uFH;
	toLog( "\n...Created playlist file: '$m3uFile'\n" );
	
	#set error status
	$status = 0;
}

#echo status to console
if ( ! $status ) {
	print "\n...Finished Processing Successfully\n\n";
}
#end log file
endLog( $status );
exit;

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

#create file list from directory, check if song file, and verify not choosing files in root directory
sub wanted {
	#send notice of folder processing to console
	print ".";
	my $currDir = getcwdL() or badExit( "Not able to get current directory with 'getcwdL()'" );
	#skip directories that start with $, unless test directory
	return if ( $currDir =~ m#[\\\/]\$(?!program_test)# );
	$currDir =~ s#[\\\/]#$FS#g;
	my $currFile = abspathL( $_ );
	badExit( "Not able to get abspathL() for current file" ) if ( ! $currFile );
	#only process xml files
	if ( $currFile =~ m#\.xml$#i ) {
		$currFile =~ s#[\\\/]#$FS#g;
		#replace erroneous non-Unicode characters
		$currFile = charReplace( $currFile );
		push @fileLst, $currFile;
	} else {
		return;
	}
	return;
}

#failed execution process
sub badExit {
	my ( $msg ) = @_;
	croak( "\n**ERROR: $msg,\n   $!,\n   $?,\n   $@,\n   $^E\n\n" );
	endLog( 1 );
	exit 255;
}

#starting log process
sub startLog {
	my ( $log ) = @_;
	my $time = localtime( time() );
	my $ver_info = "  Running: '$0', Version:$Version";
	my $Sep = "-" x 120;

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
	my $Sep = "-" x 120;

	if ( $stat ) {
		$stat = 'Failed';
	} else {
		$stat = 'Completed';
	}
	toLog( "$Sep\n$time  $stat$ver_info\n$Sep\n\n" );
	close $logFH;
}
