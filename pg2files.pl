#!/usr/bin/perl
#
# Any redistributions of files must retain the copyright notice below.
#
# @author     Michael Cook | ePub Books (http://www.epubbooks.com)
# @copyright  Copyright (c)2007-2009 Michael Cook
# @package    pg2files Batch Script
# @created    (pg2tei v 0.1)
# @version    $Id$
#

require 5.004;
use strict;

## Default Directory Separator
use constant DS => '/';

## Setup Variables
my ($booksdrive, $appsdrive, $booksfolder, $xsltpath, $bookspath,
    $appspath, $saxonpath, $filename, $filenoext, $fullpath);

## Default Drives
$booksdrive = 'H:';
$appsdrive = 'H:';

## Default Paths; Books, XSLT scripts, Apps, Saxon, etc.
$booksfolder = DS . 'BOOK-Files' . DS . '04-TEI';
$xsltpath = 'epbProject' . DS . 'epb-tei2epub' . DS . 'xsl';

$appspath = '_apps';
$saxonpath = 'saxon';
## Perl and Book paths
my $perl_drive = "/xampp/perl/bin/perl.exe";    # For U3 drive use; /xampp/perl/bin/perl.exe
my $book_drive = "/BOOK-Files/";

my $perl_bin = "/xampp/perl/bin/perl.exe";    # For U3 drive use; /xampp/perl/bin/perl.exe
my $book_dir = "/BOOK-Files/";

# Write the BAT file
open (FILEOUT, "> pg2tei.bat") or die "Couldn't open $book_dir for writing: $!";

# Scan BASE dir and process all TXT files
opendir(BIN, $book_dir) or die "Can't open $book_dir: $!";
while( defined (my $txt_filename = readdir BIN) ) {
  next unless ($txt_filename =~ /\.txt/);

  my $filename = $txt_filename;
  $filename =~ s|(.*?)\.txt|$1|;
  my $tei_filename = $book_dir . $filename . ".tei";
  $txt_filename = $book_dir . $txt_filename;
  
  print FILEOUT $perl_bin . " -w " . "pg2tei.pl " . $txt_filename . " > " . $tei_filename . "\n";

}
closedir(BIN);

close FILEOUT;

############################
# RUN the pg2tei.bat file. #
############################
system "pg2tei.bat";
