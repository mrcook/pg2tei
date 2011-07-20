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
use strict;
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Find;
use File::Spec;
use File::Copy;
use constant DS => '/';   ## Default Directory Separator

use vars '$line';

##################################
## Get correct DRIVES and PATHS ##
##################################
my $current_drive = DS . 'media' . DS . 'Development';
my $books_folder  = $current_drive . DS . 'BOOK-Files' . DS . '04-TEI' . DS;  ## Default Books Path

# PATH to pg2tei.pl Perl script
my $pg2tei_script = $current_drive . DS . 'project-code' . DS . 'epubbooks-pg2tei' . DS . 'pg2tei.pl';

######################################
## Search and execute all TXT files ##
######################################
find (\&eachTEI, $books_folder);

sub eachTEI {
  return unless $_=~ /\.txt$/;    ## Skip non-TXT files
  my $file           = $_;
  my $filename       = $file;
  $filename       =~ s|^(.+?)\.txt$|$1|;
  my $orig_filename  = $filename;         # Used for the copying of the .txt file
  $filename       =~ s|^(.+?)-[80]$|$1|;  # Remove any UTF-8 info in the filename (3781-8.txt)

  my $bookspath      = $File::Find::name;
  $bookspath      =~ s|/(.+)+/$file|/$1|;
  my $tei_path_file  = $books_folder . $filename . DS . 'tei' . DS . $filename . '.tei';

  ## create default folder structure (/##/tei/) for each book
  mkdir($books_folder . $filename)  || print "\nCan't create $filename folder: $!\n";
  mkdir($books_folder . $filename . DS . 'pg-orig', 0777)  || print "\nCan't create PG_ORIG folder: $!\n";
  mkdir($books_folder . $filename . DS . 'tei',     0777)  || print "\nCan't create TEI folder: $!\n";

  ## Make a backup copy of the .txt file in "pg-orig".
  copy($file, $books_folder . $filename . DS . 'pg-orig' . DS . $orig_filename . '.txt') or die "Failed to copy file: $!\n";


  # Check that the file will open correctly as UTF-8
  my $utf_check = 0;
  open(UTFCHECK, "<", $file) || die('Could not open file!');
    my @raw_data = <UTFCHECK>;
  close(UTFCHECK);
  foreach $line (@raw_data) {
    if ($line =~ s/Character set encoding: (.*?)\s*/$1/i) {
      if ($line =~ m/u(tf-?8|nicode)/i) {
        $utf_check = 1;
      }
      last;
    }
  }
  my $pg2tei = '';
  ## Now run the pg2tei.pl script using `backticks` to get file into variable.
  if ($utf_check == 0) {
    $pg2tei = `perl -w $pg2tei_script $books_folder $file`;
  } else {
    $pg2tei = `perl -w $pg2tei_script $books_folder $file -utf`;
  }

  #######################################
  ## Now let's do some post-processing ##
  #######################################
  my $tmp_count = 0; # setup our default counter

  # Remove extra quote or epigraph tags
  $pg2tei =~ s|</quote>\s+<quote>||g;
  $pg2tei =~ s|</epigraph>\s+<epigraph>||g;


  ### Add <lg rend="font-style(italic)"> where needed.
  while ($pg2tei =~ s|<lg>\s+<l([^>]+)?>_([^_]+)</l>\s+((?:  <l>[^_]+</l>\n)*)\s+<l([^>]+)?>([^_]+)_</l>\s+</lg>|<lg rend="font-style(italic)">\n  <l$1>$2</l>\n$3  <l$4>$5</l>\n </lg>|) {}

  ### If there are any multi-line emphasis (but not every line in the <lg>)
  ### then we can now SAFELY swap out and close off the rest of the _ (underscores)
  $pg2tei =~ s|<l>_([^_]+)</l>|<l><emph>$1</emph></l>|g;
  $pg2tei =~ s|<l>(.+)_</l>|<l><emph>$1</emph></l>|g;

  # Move the PREFACE to the front matter.
  my @preface_text; $tmp_count = 0;
  while ($pg2tei =~ s!<div type="chapter">\s+(<head>(?:<emph>)?(?:THE )?(?:EDITOR&#8217;S )?(PREFACE|PROLOGUE|POSTSCRIPT)(.*?)</head>\n\n\n(.*?)\n\n)</div>!!is) {
    my $tmp_preface = $1;
    my $tmp_type = lc($2);
    $tmp_preface =~ s|</head>\n\n\n|</head>\n\n|;
    $tmp_preface =~ s|\n|\n    |g;
    $tmp_preface =~ s|\n +\n|\n\n|g;
    $preface_text[$tmp_count] = "  <div type=\"" . $tmp_type . "\">\n    $tmp_preface<signed></signed>\n  </div>\n\n";
    $tmp_count++;
  }
  if ($tmp_count > 0) {
    $pg2tei =~ s| *<div type="preface">\n *<head>Preface</head>\n *<p></p>\n *<signed></signed>\n *</div> *|@preface_text|;
    $pg2tei =~ s|</div> *<div type="preface">|</div>\n\n  <div type="preface">|g;
  }

  # Mark-up the "Introduction" div as <div type="introduction">
  $pg2tei =~ s|<div type="chapter">\n\n(<head>(?:<emph>)?(?:THE )?INTRODUCTION(.*?)</head>\n)\n+|  <div type=\"introduction\">\n\n    $1\n    |is;

  # In rare cases, a <milestone> is given where it shouldn't
  $pg2tei =~ s|(?=[^\n])<milestone unit="tb" />(?=[^\n])| * * * |g;

  # Can we somehow move these checks into the main loop above?
  $pg2tei =~ s|<p><quote>|<quote>|g;
  $pg2tei =~ s|</quote>\s*</p>|</quote>|g;


  # In rare cases, a <note place="foot"> is given where it should be three stars; * * *
  $pg2tei =~ s|(<note place="foot">\n\n\[PLACE FOOTNOTE HERE\] -- \*\n\n</note> ){3,}|* * * |g;

  ##-------------------------------------------------------------##
  ## PROCESS FOOTNOTES -- MUST HAVE A CLOSING SQUARE BRACKET "]" ##
  ## Only works with numbered/lettered (1,2,A,B,etc.) footnotes. ##
  ##-------------------------------------------------------------##
  my $process_footnotes = 1; # Careful - will not catch the "full" note unless there is a closing "]".
  my $place_foot_count = 0; my $note_foot_count = 0;
  while ($pg2tei =~ /\[PLACE FOOTNOTE HERE\]/g)  { $place_foot_count++; }
  while ($pg2tei =~ /\[Footnote (?:[\d\w*+]+)/g) { $note_foot_count++;  }
  print "\nFOOTNOTE COUNT: [$place_foot_count] | <$note_foot_count>\n";

  if ($place_foot_count != $note_foot_count) {
    $process_footnotes = 0;
  }

  if ($process_footnotes) {
    my @footnotes;
    while ($pg2tei =~ s!<p>\[Footnote ([\d\w*+]+):\s*(?:</p>)?\s*(.*?)(?:<p>)?\](</p>|</quote>)\n\n!!s) {
      push @footnotes, [$1, $2];
    }
    foreach my $footnotes (@footnotes) {
      $pg2tei =~ s|\[PLACE FOOTNOTE HERE\] -- [\d\w*+]+\s|<p>$footnotes->[1]</p>\n|;
    }
  }
  # Now we've processed most footnotes let's check for "inline" footnotes.
  # while ($pg2tei =~ s|[^\n]+\[Footnote(?: [\d\w*+]+)?:\s+([^\]]+)\]|<note place="foot">\n\n<p>$1</p>\n\n</note>|s) {}
  $pg2tei =~ s|(?=[^\n]+)\[Footnote(?: [\d\w*+]+)?:\s+([^\]]+)\]|<note place="foot">\n\n<p>$1</p>\n\n</note>|gs;


  # MUST BE DONE HERE -- After Footnote Stuff
  # In some footnotes we still have a <p><quote> which needs removing
  while ($pg2tei =~ s!<p><(?:quote|epigraph)>!<quote>!s) {}
  while ($pg2tei =~ s!</(?:quote|epigraph)>\n\n+</p>!</quote>!s) {}


  ### -------------------------------------- ###
  ### Try to fix the CHAPTER/SECTION issues. ###
  ### -------------------------------------- ###
  my $normal_chapter_exists = 0;
  if ($pg2tei =~ m|<div type="chapter">\n\n<head>(?:.*?)CHAPTER(?:.*?)</head>|is) {
    $pg2tei =~ s|<div type="chapter">(\n\n<head>(Section )?\d+</head>)|<div type="section">$1|g;
  }

  # Mark-up sections when finding "section sign" (§)
  # Followed by no-breaking or normal space
  $pg2tei =~ s/<div type="chapter">\n\n<head>\x{C2}\x{A7}(?:\x{C2}\x{A0}| )?(\d+)\.?<\/head>/<div type="section">\n\n<head>$1<\/head>/g;


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
