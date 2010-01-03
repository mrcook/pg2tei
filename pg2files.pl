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

##################################
## Get correct DRIVES and PATHS ##
##################################
$current_dir        = File::Spec->curdir();
$current_dir        = File::Spec->rel2abs unless ( File::Spec->file_name_is_absolute($current_dir) );
$current_drive      = (File::Spec->splitpath($current_dir))[0];

# PATH to the TEI book files
$books_folder    = DS . 'BOOK-Files' . DS . '04-TEI' . DS;  ## Default Books Path

# PATH to pg2tei.pl Perl script
$pg2tei_script  = $current_drive . DS . 'epbProject' . DS . 'epb-pg2tei' . DS . 'pg2tei.pl';

######################################
## Search and execute all TXT files ##
######################################
find (\&eachTEI, $current_drive . $books_folder);

sub eachTEI {
  return unless $_=~ /\.txt$/;    ## Skip non-TXT files
  $file           = $_;
  $filename       = $file;
  $filename       =~ s|^(.*?)\.txt$|$1|;
  $orig_filename  = $filename;         # Used for the copying of the .txt file
  $filename       =~ s|^(.*?)-[80]$|$1|;  # Remove any UTF-8 info in the filename (3781-8.txt)

  $bookspath      = $File::Find::name;
  $bookspath      =~ s|/(.*?)/$file|/$1|;
  $tei_path_file  = $books_folder . $filename . DS . 'tei' . DS . $filename . '.tei';

  ## create default folder structure (/##/tei/) for each book
  mkdir($books_folder . $filename . DS,             0777)  || print "\nCan't create $filename folder: $!\n";
  mkdir($books_folder . $filename . DS . 'pg-orig', 0777)  || print "\nCan't create PG_ORIG folder: $!\n";
  mkdir($books_folder . $filename . DS . 'tei',     0777)  || print "\nCan't create TEI folder: $!\n";

  ## Make a backup copy of the .txt file in "pg-orig".
  copy($file, $books_folder . $filename . DS . 'pg-orig' . DS . $orig_filename . '.txt') or die "Failed to copy file: $!\n";

  ## Now run the pg2tei.pl script using `backticks` to get file into variable.
  $pg2tei = `perl -w $pg2tei_script $books_folder $file`;


  #######################################
  ## Now let's do some post-processing ##
  #######################################

  # Remove those extra quote tags
  $pg2tei =~ s|</quote>\n\n<quote>||g;

  # Move the PREFACE to the front matter.
  my @preface_text; my $tmp_count = 0;
  while ($pg2tei =~ s|<div type="chapter">\n\n *(<head>PREFACE(.*?)</head>\n\n\n(.*?)\n\n)</div>||s) {
    $preface_text[$tmp_count] = "  <div type=\"preface\">\n    $1    <signed></signed>\n  </div>";
    $tmp_count++;
  }
  if ($tmp_count > 0) {
    $pg2tei =~ s| *<div type="preface">\n *<head>Preface</head>\n *<p></p>\n *<signed></signed>\n *</div> *|@preface_text|;
    $pg2tei =~ s|</div> *<div type="preface">|</div>\n\n  <div type="preface">|g;
  }

  # In rare cases, a <milestone> is given where it shouldn't
  $pg2tei =~ s|(?=[^\n])<milestone unit="tb" />(?=[^\n])| * * * |g;


  #############################
  ## Write out to a TEI file ##
  #############################
  if (unlink($tei_path_file) == 1) {
    print "\n\n--- Old file has been deleted ---\n\n";
  }
  open (OUT,  ">", $tei_path_file) or die "Could not open file\n";
    print OUT $pg2tei;
  close(OUT);

}
