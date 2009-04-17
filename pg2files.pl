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
use File::Spec;
use File::Copy;

use constant DS => '/';   ## Default Directory Separator

my $booksdrive = 'V:';                                     ## Default Books Drive
my $booksfolder = DS . 'BOOK-Files' . DS . '04-TEI' . DS;  ## Default Books Path

## Get current drive
my $cur_dir = File::Spec->curdir();
   $cur_dir = File::Spec->rel2abs unless ( File::Spec->file_name_is_absolute($cur_dir) );
my $cur_drive = (File::Spec->splitpath($cur_dir))[0];

## Perl and Book paths
my $perl_bin = $cur_drive . DS . "xampp" . DS . "perl" . DS . "bin" . DS . "perl.exe";
my $pg2tei_path = $cur_drive . DS . "epbProject" . DS . "epb-pg2tei" . DS;

# Write the BAT file
open (FILEOUT, "> " . $pg2tei_path . DS . "pg2tei.bat") or die "Couldn't open $pg2tei_path for writing: $!";

# Scan BASE dir and process all TXT files
opendir(BIN, $booksfolder) or die "Can't open $booksfolder: $!";

while( defined (my $txt_filename = readdir BIN) ) {
  next unless ($txt_filename =~ /\.txt/);

  my $filename = $txt_filename;
     $filename =~ s|(.*?)\.txt|$1|;
  my $tei_filename = $booksfolder . $filename . DS . "tei" . DS . $filename . ".tei";
     $txt_filename = $booksfolder . $txt_filename;
 
  print FILEOUT $perl_bin . " -w " . $pg2tei_path . "pg2tei.pl " . $txt_filename . " > " . $tei_filename . "\n";

  ## create default "/##/tei/" folder structure for each book *saves a few seconds manual work* :)
  mkdir($booksfolder . $filename . DS, 0777) || print "\nCan't create folder: $!";          
  mkdir($booksfolder . $filename . DS . "pg-orig", 0777) || print "\nCan't create folder: $!";
  mkdir($booksfolder . $filename . DS . "tei", 0777) || print "\nCan't create folder: $!";

  ## Make a copy of the old .txt file in the "pg-orig" folder as backup.
  copy($txt_filename, $booksfolder . $filename . DS . "pg-orig" . DS . $filename . ".txt") or die "copy failed: $!";
  
}
closedir(BIN);
close FILEOUT;

############################
# RUN the pg2tei.bat file. #
############################
system "$pg2tei_path/pg2tei.bat";

