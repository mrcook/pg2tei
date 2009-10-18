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
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Find;
use File::Spec;
use File::Copy;
use constant DS => '/';   ## Default Directory Separator

use vars '$line';

## Default BOOK Drive/Path ##
$booksfolder    = DS . 'BOOK-Files' . DS . '04-TEI' . DS;  ## Default Books Path
## Get current drive
$cur_dir        = File::Spec->curdir();
$cur_dir        = File::Spec->rel2abs unless ( File::Spec->file_name_is_absolute($cur_dir) );
$cur_drive      = (File::Spec->splitpath($cur_dir))[0];
## pg2tei Perl script path
$pg2tei_script  = $cur_drive . DS . 'epbProject' . DS . 'epb-pg2tei' . DS . 'pg2tei.pl';

######################################
## Search and execute all TXT files ##
######################################
find (\&eachTEI, $cur_drive . $booksfolder);

sub eachTEI {
  return unless $_=~ /\.txt$/;    ## Skip non-TXT files
  $file           = $_;
  $filename       = $file;
  $filename       =~ s|^(.*?)\.txt$|$1|;

  $bookspath      = $File::Find::name;
  $bookspath      =~ s|/(.*?)/$file|/$1|;
  $tei_path_file  = $booksfolder . $filename . DS . 'tei' . DS . $filename . '.tei';

  ## create default folder structure (/##/tei/) for each book
  mkdir($booksfolder . $filename . DS,             0777)  || print "\nCan't create $filename folder: $!\n";
  mkdir($booksfolder . $filename . DS . 'pg-orig', 0777)  || print "\nCan't create PG_ORIG folder: $!\n";
  mkdir($booksfolder . $filename . DS . 'tei',     0777)  || print "\nCan't create TEI folder: $!\n";

  ## Make a backup copy of the .txt file in "pg-orig".
  copy($file, $booksfolder . $filename . DS . 'pg-orig' . DS . $filename . '.txt') or die "Failed to copy file: $!\n";

  ## Now run the pg2tei.pl script using `backticks` to get file into variable.
  $pg2tei = `perl -w $pg2tei_script $booksfolder $file`;


  #######################################
  ## Now let's do some post-processing ##
  #######################################

  # Remove those extra quote tags
  $pg2tei =~ s|</quote>\n\n<quote>||g;


  #############################
  ## Write out to a TEI file ##
  #############################
  open (OUT,  ">", $tei_path_file) or die "Could not open file\n";
    print OUT $pg2tei;
  close(OUT);

}
