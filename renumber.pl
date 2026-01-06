#!/usr/bin/perl -w

#********************************************************************************************************
#
#	File: renumber.pl
#	Desc: Renumbers KEY values for XML nodes
#
#	Author: Richard Davis
#	  	rich@richandsteph.com
#
#********************************************************************************************************
# version 1.0 -  28 Feb 2024	RAD	initial creation
#         1.1 -  23 Mar 2025  RAD changed header/closing info
#         1.2 -  21 Apr 2025  RAD removed logic for no change to node number / changed to handle Unicode
#         1.3 -  16 May 2025  RAD changed to handle all unicode characters in process
#         1.4 -   3 Jun 2025  RAD added specified unicode handling of open files / added close to file 
#                                 handles
#         1.5 -   5 Jan 2026  RAD removed unneeded unicode pragmas / added '$program_test' as possible 
#                                 folder
#         1.6 -   6 Jan 2026  RAD added processing of each attribute of 'song' children, when present
#********************************************************************************************************

my $Version = "1.6";

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
use XML::Writer;

my $FS = '\\';
my $status = 1;

#start logging
my $logFH;
my $fileName = fileparse( $0 );
$fileName =~ s#\.\w\w\w?$##;
my $logFile = "$fileName.log";
startLog( $logFile );

#get list of files from current directory
my @workDir = getcwdL();
$workDir[0] =~ s#[\\\/]#$FS#g;
my @fileLst;
find( \&wanted, @workDir );

#loop through each XML file in directory
foreach my $xmlFile ( @fileLst ) {
	toLog( "...Processing XML File: '$xmlFile'\n\n" );

	#load XML data
	my $xmlInFH;
	openL( \$xmlInFH, '<:encoding(UTF-8)', $xmlFile ) or badExit( "Not able to open XML file: '$xmlFile' for input" );
		binmode( $xmlInFH );
		my $dom = XML::LibXML->load_xml( IO => $xmlInFH );
		badExit( "\n\nCouldn't load XML file: $xmlFile" ) unless ( $dom );
	close( $xmlInFH );

	#create XML writer object, so can output empty XML elements without collapsing
	my $writer = XML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1, ENCODING => 'utf-8' );
	badExit( "Not able to create new XML::Writer object" ) if ( ! $writer );
	#write XML Declaration
	$writer->xmlDecl( "UTF-8" ) or badExit( "Not able to write out XML Declaration" );
	$writer->comment( "*IMPORTANT: Only 1 attribute/value pair is allowed per each child node of <song>" );
	
	#cycle through number nodes
	my $nodeCnt = 0;
	#set date in <playlist> attribute
	my $playlistNode = $dom->findnodes( '/playlist' );
	my $date = localtime( time() );
	toLog( "\tSetting current date/time in <playlist> node\n" );
	#get playlist @name for writing out
	my $playlistName = $dom->findvalue( '/playlist/@name' );
	$writer->startTag( "playlist", name => $playlistName, date => $date );

	foreach my $songNode ( $dom->findnodes( '//song' ) ) {
		#renumber node textual content
		$nodeCnt++;

		#get @number value and compare to counter, then write XML 'song' start tag
		my $numberVal = $songNode->findvalue( './@number' );
		if ( $numberVal !~ m#^$nodeCnt$# ) {
			#change @number to new $nodeCnt
			toLog( "\tNode content changed from: $numberVal to $nodeCnt\n" );
			#write out XML 'song' element
			$writer->startTag( "song", number => $nodeCnt );
		} else {
			#write out XML 'song' element
			$writer->startTag( "song", number => $numberVal );
		}

		#search empty elements and add empty node to avoid collapsed tag output
		foreach my $subNode ( $songNode->findnodes( '*' ) ) {
			my $nodeName = $subNode->nodeName;
			#determine attributes for tag, can only process 1 attribute=value per $subNode
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
	$writer->end() or badExit( "Not able to end XML document" );

	#write out renumbered XML playlist file
	my $xmlOutFH;
	openL( \$xmlOutFH, '>:encoding(UTF-8)', $xmlFile ) or badExit( "Not able to create '" . $xmlFile . "'" );
	my $newfh = select $xmlOutFH; $| = 1; select $newfh;
	print $xmlOutFH $writer or badExit( "Not able to write out renumbered XML to '$xmlFile'" );
	close( $xmlOutFH );
	toLog( "\n...Finished renumbering XML file: '$xmlFile'\n\n\n" );

	#set error status
	$status = 0;
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
	my $currDir = getcwdL() or badExit( "Not able to get current directory with 'getcwdL()'" );
	#skip directories that start with $
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
	toLog( "$Sep\n$time  $stat$ver_info\n$Sep\n\n" );
	close $logFH;
}
