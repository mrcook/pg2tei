#!/usr/bin/perl
#
# Any redistributions of files must retain the copyright notice below.
#
# @author     Michael Cook | epubBooks (http://www.epubbooks.com)
# @copyright  Copyright (c)2007-2009 Michael Cook
# @package    pg2tei v0.20 - Project Gutenberg eText to TEI converter
# @created    May 2007
# @version    $Id$
#
# Based on The Gnutenberg Press - PGText to TEI converter by
# Marcello Perathoner (Copyright 2003).
#
# Starting 2007-05-09, many additions and fixes have been made by Michael Cook.
#

require 5.004;
use strict;

use Data::UUID;
use Data::Dumper;
use Getopt::Long;
use locale;
use POSIX qw(strftime);
use POSIX qw(locale_h);
use Text::Wrap;            # Only needed when re-wrapping text in <epigraph>


################################################################################
####                  CHECK FOR UTF-8 SOURCE AND SET OUTPUT                 ####
################################################################################
use utf8;
#use open IN => ':encoding(utf8)';         # NEEDED for UTF-8 Source documents.
binmode STDOUT, ':utf8';

################################################################################
####                       Set some specific parameters                      ###
################################################################################

my  $is_verse           = 0;    # Work is a poem? Some hints as to what is being converted.

my  $process_epigraph   = 1;    # Disable if book is mostly Poems

my  $cnt_chapter_sep    = "3,"; # chapters are separated by 3 empty lines
my  $cnt_head_sep       = "2";
my  $cnt_paragraph_sep  = "1";

my  $avg_line_length    = 0;
my  $max_line_length    = 0;
# $Text::Wrap::columns    = 78;

# regexps how to catch quotes (filled in later)
my  ($quotes1, $quotes1pre, $quotes2);

my  $override_quotes    = '';

my  $help               = 0;

# All date arrays hold;
#    [0] = date found in TXT (March 23, 2001)
#    [1] = date formatted as YYYY-MM-DD
my  @current_date;
$current_date[1]   = strftime ("%Y-%m-%d", localtime ());
$current_date[0]   = strftime ("%d %B %Y", localtime ());

#my  $locale = "en";
#setlocale (LC_CTYPE, $locale);
#$locale = setlocale (LC_CTYPE);

my $uuid =  uuid_gen(); # Create a UUID

my  $title              = '';
my  $sub_title          = '';
my  $authors            = '';
my  $editor             = '';
my  $editors            = '';

my  $illustrators       = '';
my  $illustrated_by_tag = 'Illustrated by';
my  $translators        = '';
my  $translated_by_tag  = '';
my  $published_place    = '';
my  $publisher          = '';
my  $dates_sorted       = '';

my  $language           = '';
my  $language_code      = '';
my  $encoding           = 'iso-8859-1';

my  $series_title       = '****';
my  $series_volume      = '**';

my  @release_date;
my  @posted_date;
my  @last_updated;
my  @first_updated;
my  @first_posted;
my  @published_date     = '';
my  $revision_last_updated = 0; # Needed for <revisionDesc>

my  $filename           = '';
my  $gutenberg_num      = '';
my  $edition            = '';
my  $pg_edition         = '';

my  $scanned_by         = '';
my  $created_by         = '';
my  $updated_by         = '';

my  $transcriber_notes  = '';
my  $transcriber_errors = '';
my  $redactors_notes    = '';

my  $rend               = '';

my  $footnote_exists    = 0;
my  $is_book            = 0;
my  $is_book_div        = 0;

use vars '$lang_gb_check';
use vars '$front_matter_block';
use vars '@illustrators';
use vars '$single_open_quotes_exist';
use vars '$is_heading';
use vars '$is_subheading';
use vars '$is_first_para';

my  @translators        = ();
my  @editors            = ();
my  @authors            = ();

my %languages = (
  "de"     => "German",
  "el"     => "Greek",
  "en-gb"  => "British",
  "en-us"  => "American",
  "en"     => "English",
  "es"     => "Spanish",
  "fr"     => "French",
  "it"     => "Italian",
  "la"     => "Latin",
  "nl"     => "Dutch",
  "pl"     => "Polish",
  "pt"     => "Portuguese",
);

GetOptions (
  "quotes=s"    => \$override_quotes,
  "chapter=i"   => \$cnt_chapter_sep,
  "head=i"      => \$cnt_head_sep,
  "paragraph=i" => \$cnt_paragraph_sep,
  "verse!"      => \$is_verse,
#  "locale=s"    => \$locale,
  "help|h|?!"   => \$help,
);


################################################################################
####                 How to catch Chapters, Paragraphs, etc.                ####
################################################################################

# regex's get applied in this order:
# chapter1           <div>
#    head1           <head>
#       paragraph1   <head type="sub">
#    epigraph1       <epigraph>
#    paragraph1      <p>
# chapter1 gets applied on body. The result of the match(es)
# gets fed first into head1 and then into epigraph1 and paragraph1,
# the result of head1 gets fed into paragraph1

my $tmp = "(.*?)\n{$cnt_chapter_sep}\n+";

my $chapter1   = qr/$tmp/s;

$tmp = "(.*?)\n{$cnt_head_sep}\n+";
my $head1      = qr/$tmp/s;

$tmp = "(.*?)\n{$cnt_paragraph_sep}\n+";
my $paragraph1 = qr/$tmp/s;

# Removed for the moment -- not sure if I want to capture these
#my $epigraph1  = qr/^(?&#8212;)(.*?)\n\s*&#8212;(.+)\n\n+/s; # match epigraph and citation
my $epigraph1  = qr/^(?=\n\s*&#8212;)(.*?)\n\n+/s; # match epigraph and citation - Keep on eye onthis (2010-02-28)

undef $/;  # slurp it all, mem is cheap

################################################################################
####                           THE CORE PARSING                             ####
################################################################################

while (<>) {
  s|\r||g;       # cure M$-DOS files
  s|\t| |g;      # replace tabs
  s| +\n|\n|g;   # remove spaces at end of line

  # substitute & for &amp;
  s|&(?= )|&amp;|g;


  ####--------------------------------------------------####
  #### Quick check to see if the doc is British English ####
  ####--------------------------------------------------####
  my $uk_count = 0;
  my $us_count = 0;
  my $word = '';
  foreach $word (split(/[^a-zA-Z]+/, $_)) {
    if ($word =~ /(colour|flavour|favour|savour|honour|defence|ageing|jewellery)/i) {
      $uk_count++;
    }
    if ($word =~ /(color|flavor|favor|savor|honor|defense|aging|jewelry)/i) {
      $us_count++;
    }
  }
  if ($uk_count > $us_count) { $lang_gb_check = 1; } else { $lang_gb_check = 0; }

  ####--------------------------------------####
  #### Grab PG header and output TEI header ####
  ####--------------------------------------####
  
  # First check for PREFACE, INTRODUCTION, etc.
  if (s/^(.*?)(?=\n\n\n[_ ]*(PREFACE|INTRODUCTION|AUTHOR'S NOTE|BIOGRAPHY|FOREWORD).*?\n)/output_header($1)/egis) {
    print "Found PREFACE/INTRO/etc. start.\n\n";
  # Now check for CHAPTERS, VOLUMES, etc.
  } elsif (s/^(.*?)(?=\n\n\n[_ ]*(CHAPTER|PART|BOOK|VOLUME|SECTION) (1[^\d]|:upper:O:upper:N:upper:E|I[^( ?:lower:\w)]|(THE )?FIRST)(.*?)\n)/output_header($1)/egis) {
    print "Found BOOK/CHAPTER/etc. start.\n\n";
  # No chapter name? Just look for an actual "1" or "I" or "ONE"
  } elsif (s/^(.*?)(?=\n\n\n[_ ]*(1[^\d]|:upper:O:upper:N:upper:E|I[^( ?:lower:\w)])\.?\n)(.*?)/output_header($1)/egis) {
    print "Found NUMBERS ONLY start.\n\n";
    #output_header($1);
  } else {
    print "**************************************\n";
    print "**** ERROR! No FRONT MATTER Found ****\n";
    print "**************************************\n";
    print "\n\n";
    print "We are unable to detect the end of the fron matter section.\n";
    print "This is usually done by finding, for example, \"Chapter\" or \"Preface\" sections.\n";
    print "The best fix is to manually add a \"CHAPTER 1\" with at least 3 blank\n\n";
    print "lines surround it and then running the txt through the script again.\n\n";
    print "**************************************\n";
    print "\n\n";
  }

  # Process the body
  if (! s/^(.*?)[\* ]*((This is )?(The )?End of (Th(e|is) )?Project Gutenberg [eE](book|text)).*?\n/output_body($front_matter_block .= $1)/egis) {
    # output_body ($front_matter_block .= $_);
  }

  # output tei footer
  output_footer ();
}

####                           END CORE PARSING                             ####
################################################################################


################################################################################
####                          START OF FUNCTIONS                            ####
################################################################################

sub output_line {     # Output <l>'s.
  my $line = shift;
  my $min_indent = shift;

  $line =~ m/\S/g; # What does this do?
  my $indent = (pos ($line) - $min_indent - 1);
  $line =~ s/^\s+//;

  if (length ($line)) {
    $indent = 6 if $indent >= 7;
    $indent = 4 if $indent == 5;
    $indent = 2 if $indent == 3;
    $indent = 0 if $indent == 1;
    
    my $line_indent = '';
    $line_indent = ' rend="margin-left(' . $indent . ')"' if $indent > 0;

    #### Remove quotes for now as they create more havoc than good!!!!
    # $line = process_quotes_1 ($line);
    # $line = fix_unbalanced_quotes_line ($line);

    # Fix some double <q> tags
    # $line =~ s|</q></q>|</q>|g;
    # $line =~ s|<q></q>|</q>|g;
    # $line =~ s|<q><q>|<q>|g;

    $line = post_process ($line);
    print "  <l$line_indent>$line</l>\n";
  }
  return '';
}


sub output_para {
  my $p = shift;
  $p .= "\n";

  #print "IS FIRST: $is_first_para\n";

  # We need to check for "[Footnote" entries to stop them being caught as a <lg>
  my $is_foonote_entry = '';
  if ($p =~ /^[\n|\s]+\[Footnote/) {
    $is_foonote_entry = 1;
  }

  my $o = study_paragraph ($p);

  if (($is_verse || is_para_verse($o)) && $p ne "<milestone>\n" && !$is_foonote_entry) {
    # $p = process_quotes_1 ($p); # Not sure if this should be enabled...probably not.
    # $p = post_process ($p);     # Not sure if this should be enabled...probably not.
    if ($is_first_para == 0) {
      print "<quote>\n <lg>\n";
    } else {
      print "<epigraph>\n <lg>\n";
    }
    while (length ($p)) {
      if ($p =~ s/^(.*?)\s*\n//o) {
        output_line ($1, $o->{'min_indent'});
      }
    }
    if ($is_first_para == 0) {
    print " </lg>\n</quote>\n\n";
    } else {
    print " </lg>\n</epigraph>\n\n\n";
    }
  } else { # paragraph is prose
    # join end-of-line hyphenated words
    $p =~ s/([^- ])- ?\n([^ ]+) /$1-$2\n/g;

    $p = process_quotes_1 ($p);
    $p = post_process ($p);

    $rend = ''; # $rend must be reset each time.
    $rend = ' rend="text-align(center)"' if (is_para_centered ($o));
    $rend = ' rend="text-align(right)"'  if (is_para_right ($o));

    if ($p =~ m/^<(figure|milestone|div|pb)/) {
    } elsif ($p =~ m/^\[Footnote/) {
      $p = "<p$rend>$p</p>";
    } else {
      $p = "<p$rend>$p</p>";
      $is_first_para = 0; # Now that we've confirmed the opening para is not an epigraph...
    }

    # print wrap ('', '', $p); # We are not going to perform any re-wrapping
    print $p;  # No WRAP

    print "\n\n";
  }

  return '';
}


sub output_stage {
  my $stage = shift;
  $stage =~ s/[ \t\n]+/ /g;
  print "<stage>$stage</stage>\n\n";
  return '';
}


sub output_head {
  my $head = shift;
  $head .= "\n" x 10;
  $head =~ s/$paragraph1//;

  my $head_tmp = '';
  $head_tmp = process_quotes_1 ($1);
  $head_tmp = post_process ($head_tmp);

  $head_tmp =~ s/^\s+//; # Strip out leading whitespace

  if ($head_tmp =~ /^<(figure|milestone)/) { # stop <figure> and others getting caught
    print $head_tmp . "\n\n";
  } else {
    $is_heading = 1; # This is going to allow us to know if we have a sub <div> (book/chapter/section).

    # Split up any "Chapter I. Some title." headings with sub-headings. Keep an eye on this.(2009-12-29)
    $head_tmp =~ s/^((CHAPTER|PART|BOOK|VOLUME|SECTION) (.*?)\.) *(.+(\n.+)*)$/$1<\/head>\n\n<head type="sub">$4/is;
    # If a chapter/book has a 'dash' then it's probably not meant to be split into heading/subheading.
    $head_tmp =~ s/<\/head>\n\n<head type="sub">&#8212;/&#8212;/is; # There must be a better way to do this!
    print "<head>" . $head_tmp . "</head>\n\n";
  }

  while ($head =~ s/$paragraph1//) {
    my $subhead = post_process ($1);

    $subhead =~ s|^\"(.*?)\"$|<q>$1</q>|; # Rough fix of Quotes
    $subhead =~ s|^\s||gm;                # Strip out leading whitespace

    if ($subhead =~ /^<(figure|milestone)/) { # stop <figure> and others getting caught
      print $subhead . "\n\n";
    } else {
     print "<head type=\"sub\">$subhead</head>\n\n";
   }
  }
  print "\n";
  return '';
}


####------------------------------------------####
#### quotes involve pretty much guesswork and ####
#### we will probably get some quotes wrong.  ####
####------------------------------------------####
sub process_quotes_2 {
  my $c = shift;
  if ($c =~ m|$quotes2|) {
    while ($c =~ s|$quotes2|"<q>" . process_quotes_1 ($1) . "</q>"|es) {};
  }
  return $c;
}


sub process_quotes_1 {
  my $c = shift;

  if ($c =~ m/$quotes1/g) {
    while ($c =~ s|$quotes1|"<q>" . process_quotes_2 ($1) . "</q>"|es) {};
    }
  if ($c =~ m/$quotes1pre/g) {
    while ($c =~ s|$quotes1pre|"<qpre>" . process_quotes_2 ($1) . "</q>"|es) {};
  }

  # attract user's attention to these remaining quotes
  # $c =~ s|([\"«»\x84])|<fixme>$1</fixme>|g;
  #### @Mike - just convert to <q> and deal with it in XSLT ####
  $c =~ s|(["«»\x84])|<q>|g;

  $c = do_fixes ($c);

  return $c;
}


####----------------------------------------####
#### try to fix unbalanced quotes in verses ####
####----------------------------------------####
sub fix_unbalanced_quotes_line {
  my $line = shift;
  my $balance = 0;

  my $tmp = $line;
  $balance += ($tmp =~ s|<q>||g);
  $balance -= ($tmp =~ s|</q>||g);

  if ($balance != 0) {
    while (($line =~ s|<q>([^<]*)</q>|§q§$1§/q§|g) > 0) {};

    while ($balance > 0) {
      $line =~ s|<q>(.*)|<qpre>$1</q>|;
      $balance--;
    }
    while ($balance < 0) {
      $line = "<qpost>" . $line;
      $balance++;
    }
    $line =~ s|§(/?q)§|<$1>|g;
  }
  $line = do_fixes ($line);

  return $line;
}


#### try to fix various quotes ####
sub do_fixes {
  my $fix = shift;
  $fix =~ s| </q>|</q>|g; # Tidy up </q> tags with space before.
  return $fix;
}


sub output_epigraph {
  my $epigraph = shift;
  my $citation = shift;

  print "<epigraph>\n";

  $epigraph = process_quotes_1 ($epigraph);
  $citation = process_quotes_1 ($citation);
  $citation = process_quotes_1 ($citation);
  $epigraph = post_process ($epigraph);
  $citation = post_process ($citation);

  $epigraph =~ s|\s+| |g;
  $epigraph = "  <p>$epigraph</p>";

  print wrap ('', '     ', $epigraph);
  #print $epigraph;  # No WRAP
  print "\n";

  $citation =~ s|&#160;&#8212;|&#8213;|g;

  print "  <p rend=\"text-align(right)\">$citation</p>\n";

  print "</epigraph>\n\n\n";

  return '';
}


sub output_chapter {
  my $chapter = shift;
  my $part_number;
  $is_first_para = $process_epigraph;
  
  $chapter .= "\n" x 10;

  if ($chapter =~ /^ *(BOOK|PART|VOLUME) (ONE|1|I(?:[^\d:upper:I:upper:V:upper:X])|(THE )?FIRST)/i) {
    print "\n\n" . '<div type="' . lc($1) . '" n="1">' . "\n\n";
    $is_book = 1;
    $is_book_div = 1;
  } elsif ($chapter =~ /^ *(BOOK|PART|VOLUME) +(THE )?(.*?)(&#821[123];|[:\.\s]+)(.*?)\n/i) {
    print "</div>\n\n";
    if (!$is_heading) { print "\n"; }

    # Grab the Part/Book number
    $part_number = encode_numbers($3);
    if (!$part_number) { $part_number = "xx"; }
      
    print "\n" . '<div type="' . lc($1) . '" n="' . $part_number . '">' . "\n\n";
    $is_book = 1;
    $is_book_div = 1;
  } else {
    $is_book_div = 0;
    if (!$is_heading) { print "\n"; }
    print "\n" . '<div type="chapter">' . "\n\n";
  }
  $chapter =~ s/$head1/output_head ($1)/es;

  # Marcello's Original
  #while ($chapter =~ s/$epigraph1/output_epigraph ($1, $2)/es) {};
  if ($is_first_para == 1) {
    $chapter =~ s/$epigraph1/output_epigraph($1, $2)/es;
  }

  if (not $chapter =~ m/\n\w/g) { # If all lines are indented this chapter must only be a poem (I hope!!)
    $is_first_para = 0;
  }

  if ($chapter =~ s/$paragraph1/output_para($1)/egs) {
    $is_heading = 0;
  }

  if (!$is_heading) {
    print "</div>\n\n";
  }

  return '';
}


sub output_body {
  my $body = shift;
  $body =~ s/^\s*//;
  
  # Let's clean up those <milestone> and footnote[*] tags
  $body = pre_process($body);
  
  guess_quoting_convention (\$body); # save mem, pass a ref
  ($avg_line_length, $max_line_length) = compute_line_length (\$body);

  print ("AVG Line Length: $avg_line_length\n");
  print ("MAX Line Length: $max_line_length\n");

  $body .= "\n{$cnt_chapter_sep}\n";

  # This is Marcello's line, we should be able to change this now with a later Perl.
  # while ($body =~ s/$chapter1/output_chapter ($1)/es) {}; # egs doesn't work in 5.6.1
  $body =~ s/$chapter1/output_chapter ($1)/egs; # (2009-12-25)

  return '';
}


####-------------------------------------------------####
#### Scan the PG header for useful info. The problem ####
#### here is that there are a gazillion different    ####
#### <soCalled>standard headers</soCalled>           ####
####-------------------------------------------------####
sub output_header () {
  my $h = shift;

  # Grab the front matter from this header for printing to output .tei
  if ($h =~ /\n\*\*\* ?START OF TH(E|IS) PROJECT.*?\n(.*?)$/is) {
    $front_matter_block = $2 . "\n\n";
  } elsif ($h =~ /\n\*END[\* ]+THE SMALL PRINT.*?\n(.*?)$/is) {
    $front_matter_block = $1 . "\n\n";
  } elsif ($h =~ /\n[* ]+The Project Gutenberg [eE](book|text) of .+[* ]+\n(.*?)$/is) {
    $front_matter_block = $2 . "\n\n";
  }

  ####------------------------------------------------####
  #### Grab easy data when it is assigned with a tag  ####
  #### (most PG texts now have some/all of this info) ####
  ####------------------------------------------------####
  if ($h =~ /\nTitle: *(.+)\n/i)                  { $title = $1; }
  if ($h =~ /\nTitle:.+\n  +(.+)\n/i)             { $sub_title = $1; } else { $sub_title = ''; }
  if ($h =~ /\nAuthors?: *(.+)\n/i)               { $authors = $1; }
  if ($h =~ /\nEditors?: *(.+)\n/i)               { $editor = $1; }
  if ($h =~ /\nIllustrat(ors?|ions( by)?): *(.+)\n/i) { $illustrators = change_case($3); }
  if ($h =~ /\nTranslat(ors?|ion( by)?): *(.+)\n/i)   { $translators  = change_case($3); }
  if ($h =~ /\nEdition: *(\d+)\n/i)               { $edition = $1; }
  if ($h =~ /\nPublished: *(\d+)\n/i)             { $published_date[0] = $1; }
  if ($h =~ /\nLanguage: *(.+)\n/i)               { $language = $1; }
  if ($h =~ /\nCharacter set encoding: *(.+)\n/i) { $encoding = lc($1); }

  # PG eBook number
  if ($h =~ /\[E(Book|Text) #(\d+)\]\s+/i)        { $gutenberg_num = $2; }

  # The Series information is sometimes added manually by myself.
  # Better to do this in the source than in the manual post-processing.
  if ($h =~ /\nSeries Name: +(.+)\n/i)                 { $series_title  = $1; }
  if ($h =~ /\nSeries Volume: +(\d+)\n/i)         { $series_volume = $1; }


  # There are four different dates possible in any PG text;
  #   * (Official) Release Date (Some early books include the EBook No.)
  #   * First Posted
  #   * Posting Date ('Almost' always includes the EBook No.)
  #   * Last Updated

  # RELEASE DATE: A strange one as in the old days PG would set themselves 
  # an 'intended' date for release (why on earth did they do this!) However, 
  # books were often released before this actual date.
  # WARNING! On a few very early books this is also be the 'true' 
  # release date!

  # FIRST POSTED: When this is given it is almost always going to be the 
  # date the file was actually released. This is probably only when 
  # no 'Posting Date' is given - see below.

  # POSTING DATE: When no 'First Posted' date is given then this is usually 
  # the date when the book is actually released. Otherise, this could be 
  # the 'Last Updated' date; usually a more recent date than if an actual 
  # 'Last Updated' date exists.

  # LAST UPDATED: This is the date the book was last updated. Sometimes - maybe 
  # always - the 'Posted Date' is a newer date than this -- Need confirming.

  # Welcome to the world of PG!

  # OFFICIAL RELEASE DATE (Sometimes includes the EBook No.)
  if ($h =~ /\n(Official|Original)? ?Release Date: *(.*?)( +\[E(Book|Text) +#(\d+)\])?\n/i) {
    $release_date[0] = $2;
    $release_date[1] = process_dates($2);
  }
  # FIRST POSTED
  if ($h =~ /\nFirst Posted: *(.+)\n/i)           {
    $first_posted[0] = $1;
    $first_posted[1] = process_dates($1);
  }
  # POSTING DATE (Usually includes the EBook No.)
  if ($h =~ /\nPosting Date: *(.*?)( +\[E(Book|Text) +#(\d+)\])?\n/i) {
    $posted_date[0]  = $1;
    $posted_date[1]  = process_dates($1);
  }
  # LAST UPDATED
  if ($h =~ /\nLast Updated?: *(.+)\n/i)          {
    $last_updated[0] = $1;
    $last_updated[1] = process_dates($1);
  }

  ####------------------------------------------------------------------####
  #### Not all books have the above information easily available.       ####
  #### Now let's do some extra checks when this information is empty.   ####
  ####------------------------------------------------------------------####
  #### We're also going to check for other information like transcriber ####
  #### notes and produced by and also do a little post-processing       ####
  ####------------------------------------------------------------------####

  # Find both TITLE and AUTHOR from the file header tag.
  # I HAVE REMOVED the \n from the start of these two strings -- Keep an eye on this (2009-11-xx).
  if (!$title or !$authors) {
   if ($h =~ /^\** *The Project Gutenberg Etext of (.*?),? by (.*?)\** *\n/) {
      if (!$title)  { $title = $1;  }
      if (!$authors) { $authors = change_case($2); }
    } elsif ($h =~ /^\** *The Project Gutenberg Etext of (.*?)\** *\n/) {
      if (!$title)  { $title = $1;  }
    }
  }
  # If still no AUTHOR found -- these are a bit random but can often work
  if (!$authors && $title) {
    if ($h =~ /\n$title\n+by (.*?)\n/i) { $authors = change_case($1); }
  } elsif (!$authors) {
    if ($h =~ /\n *by (.*?)\n/i) { $authors = change_case($1); }
  }
  @authors = process_names($authors);

  if ($editor) {
    @editors = process_names($editor);
  }

  # If no POSTING DATE
  if (!$posted_date[0]) {
    if ($h =~ /\[(The actual date )?This file (was )?first posted (on|=) (.+)\]\n/i) {
      $posted_date[0] = $4;
      $posted_date[1] = process_dates($4);
    }
  }    
  # If no LAST UPDATED
  if (!$last_updated[0]) {
    if ($h =~ /\[(Date|This file was|Most) (last|recently) updated( on|:)? (.+)\]/i) {
      $last_updated[0] = $4;
      $last_updated[1] = process_dates($4);
    }
  }
  
  # If no TRANSLATORS
  if ($h =~ /[\n ]*(Translated (from.*)??by)\s+(.+)\.?/i) {
    $translated_by_tag = $1;
    if (!$translators) {
      $translators = change_case($3);
    }
  }
  if ($translators) {
    @translators = process_names($translators);
  }

  # If no EDITION (We do an additional check against releases further down.)
  if (!$edition) {
    $filename = "$ARGV"; # Perhaps the filename has it (not many PG books still use the old filename system)
    if ($filename =~ /^(\w{4,5})((10|11|12)\w?)\..+$/i) {
      $edition  = $3;
    } else { 
      $edition = '1'; # Still no EDITION so default to 1
    }
  }
  # PG EDITION is used in the <revisionDesc> section.
  $pg_edition = $edition;
  # Change EDITION when 10, 11 or 12 to equal 1, 2 or 3
  if ($edition =~ /^1\d$/) { $edition = $edition - 9; }

  # Assign English as a default and check for UK or US English.
  if (!$language) { $language = 'English'; }
  if ($language eq 'English' and $lang_gb_check == 1) { $language = 'British'; }
  $language_code = encode_lang($language);

  # Check for encoding variations and assign the default 'is-8859-1'
#  if ($encoding =~ /ascii|(iso ?)?latin-1|iso-646-us( \(us-ascii\))?|iso 8859_1|us-ascii/) {
#    $encoding = 'iso-8859-1';
#  }
#  $encoding = 'utf-8';  # We're going to force UTF-8 on all documents #

  ####--------------------------------------------------####
  #### Let's find out who created and updated this book ####
  ####--------------------------------------------------####
  # Who SCANNED/PROOFED the original text?
  if ($h =~ /[\n ]+([e-]*text Scanned|Scanned and proof(ed| ?read)) by:? +(.+)\n/i) {
    $scanned_by = $3;
  } elsif ($h =~ /[\n ]+Transcribed from the (\d\d\d\d)( edition( of)?)? (.+)( edition)? by:? +(.+)\n\n/is) {
    $scanned_by = $6;
  } elsif ($h =~ /proof(ed| ?read) by:? +(.+)[,. ]*\n/i) {
    $scanned_by = $2;
  }
  # Who first PRODUCED this text for Project Gutenberg?
  $h =~ s/\n\*+.+Prepared By (?:Hundreds|Thousands) of Volunteers(?:!| and Donations)?\*+\n//i; #Remove this stupid thing.
  if ($h =~ /[\n ]+(This [e-]*Text (was )?(first ))?(Produced|Prepared|Created) by +(.*?)\n\n/is) {
    $created_by = $5;
    $created_by =~ s/\n/ /g;
    $created_by =~ s/(\.| at)$//;
  }
  # Who UPDATED this version?
  if ($h =~ /[\n ]+(This )?updated ([e-]*Text|edition) (was )?(Produced|Prepared|Created) by +(.*?)\n(.*?)\n/i) {
    $updated_by = $5;
    if ($6) {
      $updated_by = $updated_by . " " . $6;
    }
  }
  # If no creator is found let's see what we can do about it.
  # We need at least either scanned_by or created_by
  if (!$created_by) {
    if (!$scanned_by) {
      $created_by = "Project Gutenberg";
    }
  }
  # Let's remove any http://www.pgdp.net from the producers
  $scanned_by =~ s|( at)? ?http://www\.pgdp\.net/?||i;
  $created_by =~ s|( at)? ?http://www\.pgdp\.net/?||i;
  # We don't need to know who made the HTML version in this file.
  $scanned_by =~ s|\.? +HTML version by .*?\.? *$||i;
  $created_by =~ s|\.? +HTML version by .*?\.? *$||i;


  ####-----------------------------------------------####
  #### Getting the PUBLISHER, PUBLISHED DATE and the ####
  #### PUBLISHED PLACE is not always very accurate.  ####
  ####-----------------------------------------------####
  # Very useful if this 'Transcribed' line exists.
  if ($h =~ /[\n ]+Transcribed from the (\d\d\d\d)( edition( of)?)? (.*?)( edition)? by(.+)\n\n/is) {
    $publisher = $4;
    if (!$published_date[0]) { $published_date[0] = $1; }
  }
  # If still no PUBLISHED DATE
  if (!$published_date[0]) {
    if ($h =~ /\n[\s_]*Copyright(ed)?[,\s]*(\d\d\d\d)/i) {
      $published_date[0] = $2;
    } elsif ($h =~ /\n *([0-9]{4})\n/i) {
      $published_date[0] = $1;
    } elsif ($h =~ /[\[\(]([0-9]{4})[\]\)]/i) {
      $published_date[0] = $1;
    }
  }
  if ($published_date[0]) {
    $published_date[1] = process_dates ($published_date[0]);
  } else {
    $published_date[1] = '';
  }

  # If still no PUBLISHER
  if (!$publisher) {
    if ($h =~ /\s+_?(.*?)\b(Publisher|Press|Company|Co\.)\b(.*?)_?\s+/i) {
      $publisher = change_case($1 . $2 . $3);
    }
  }
  # Get the PUBLISHED PLACE --- Very hit 'n miss!!
  if ($h =~ /\n *((New York|London|Cambridge|Boston|Chicago).*?)_?\n/i) {
    $published_place = change_case($1);
  }

  # REDACTOR'S NOTES
  if ($h =~ / *\[Redactor'?s? Note[s:\n ]*(.*?)\]/is) {
    $redactors_notes = $1;
  } elsif ($h =~ /Redactor\'s Note[s:\n ]*(.*?)\n\n\n/is) {
    $redactors_notes = $1;
  }
  if ($redactors_notes) {
    $redactors_notes .= "\n";  
    $redactors_notes =~ s|\n|\n        |gis;   # Indent the text
    $redactors_notes =~ s|\n\s+\n|\n\n|gis;    # Clear empty lines
  }

  # TRANSCRIBERS NOTES -- If not then check Footer_Block AND Body_Block
  if ($h =~ / *\[Transcriber'?s? Note[s:\n ]+(.*?)\]/is) {
    $transcriber_notes = "\n" . $1;
  } elsif ($h =~ /Transcriber\'?s? Note[s:\n ]+(.*?)\n\n\n/is) {
    $transcriber_notes = "\n" . $1;
  }
  # Note: Few but there are some, possibly Errata stuff so add to $transcribers_errata
  if ($h =~ /^ *\[Notes?: (.*?)\]/is) {
    $transcriber_notes .= $1;
  } elsif ($h =~ /^Notes?: (.*?)\n\n\n/is) {
    $transcriber_notes .= $1;
  }
  if ($transcriber_notes) {
    $transcriber_notes =~ s|\n|\n        |gis;  # Indent the text
    $transcriber_notes =~ s|\n *\n|\n\n|gis;    # Clear empty lines
    $transcriber_notes .= "\n      ";
  }

  # ILLUSTRATED BY ...
  if (/\n\n(((.*?)\n)?(.*?)(Illustrat(ions?|ed|er))( in colou?r)? by)\s*(.*?)\n\n/i) {
    if ($1) {
      $illustrated_by_tag = $1;
      $illustrated_by_tag =~ s|_||g;
      $illustrated_by_tag =~ s|\n| |g;
      $illustrated_by_tag = change_case($illustrated_by_tag);
    }
    if (!$illustrators) {
      $illustrators = change_case($8);
      $illustrators =~ s/_//;
    }
  }
  if ($illustrators) { 
    @illustrators = process_names($illustrators);
  } else {
    $illustrated_by_tag = '';
  }

  ####--------------------------------------------------------------####
  #### SAFE Option for Dates is to create an array and sort them.   ####
  #### This is because PG often mixes up Posted/Released dates.     ####
  #### This will then give a proper date sequence; even if it's not ####
  #### 100% as PG intended -- how much manual work do you want! :)  ####
  ####--------------------------------------------------------------####
  my @book_dates   = ();
  my @dates_sorted = ();
  if ($release_date[0]) { push(@book_dates, [$release_date[1], $release_date[0]]); }
  if ($first_posted[0]) { push(@book_dates, [$first_posted[1], $first_posted[0]]); }
  if ($posted_date[0])  { push(@book_dates, [$posted_date[1],  $posted_date[0]]);  }
  if ($last_updated[0]) { push(@book_dates, [$last_updated[1], $last_updated[0]]); }

  # Sort into Date ASC order
  @dates_sorted = sort {$a->[0] cmp $b->[0]} @book_dates;

  # Set the real RELEASE DATE
  $release_date[0] = $dates_sorted[0]->[1];
  $release_date[1] = $dates_sorted[0]->[0];
  # Set the real LAST UPDATED
  $last_updated[0] = $dates_sorted[$#dates_sorted]->[1];
  $last_updated[1] = $dates_sorted[$#dates_sorted]->[0];

  # if there's more than one date entry then there is a last updated.
  if ($#dates_sorted > 0) { $revision_last_updated = 1; }

  # Now let's 'shift' the first RELEASED DATE from the array.
  # This will leave us with only updates for the <revisionDesc> info.
  shift(@dates_sorted);


  # How many releases/updates have there been? 
  # Checking here so we can assign a new (and proper?) value to $edition.
  if ($edition < @dates_sorted + 1) {
    $edition = @dates_sorted + 1; # Add the original release back on.
  }

  ####-------------------------------------------------------####
  #### Now we prepare the header tags <author> and <editor>  ####
  #### We're doing this here to make the PRINT code cleaner. ####
  ####-------------------------------------------------------####
  my $tmp_count = 0;
  my @authors_list = (); $tmp_count = 0;
  foreach $authors (@authors) {
    if ($authors->[2]) {
      $authors_list[$tmp_count] = "<author><name reg=\"$authors->[2], $authors->[0]\">$authors->[1] $authors->[2]</name></author>\n";
    } else {
      $authors_list[$tmp_count] = "<author><name reg=\"$authors->[0]\">$authors->[0]</name></author>\n";
    }
    $tmp_count++;
  }

  my @illustrators_list = (); $tmp_count = 0;
  foreach $illustrators (@illustrators) {
    if ($illustrators->[2]) {
      $illustrators_list[$tmp_count] = "<editor role=\"illustrator\"><name reg=\"$illustrators->[2], $illustrators->[0]\">$illustrators->[1] $illustrators->[2]</name></editor>\n";
    } else {
      $illustrators_list[$tmp_count] = "<editor role=\"illustrator\"><name reg=\"$illustrators->[0]\">$illustrators->[0]</name></editor>\n";
    }
    $tmp_count++;
  }

  my @translators_list = (); $tmp_count = 0;
  foreach $translators  (@translators) {
    if ($translators->[2]) {
      $translators_list[$tmp_count] = "<editor role=\"translator\"><name reg=\"$translators->[2], $translators->[0]\">$translators->[1] $translators->[2]</name></editor>\n";
    } else {
      $translators_list[$tmp_count] = "<editor role=\"translator\"><name reg=\"$translators->[0]\">$translators->[0]</name></editor>\n";
    }
    $tmp_count++;
  }

  my @editors_list = (); $tmp_count = 0;
  foreach $editors (@editors) {
    if ($editors->[2]) {
      $editors_list[$tmp_count] = "<editor role=\"editor\"><name reg=\"$editors->[2], $editors->[0]\">$editors->[1] $editors->[2]</name></editor>\n";
    } else {
      $editors_list[$tmp_count] = "<editor role=\"editor\"><name reg=\"$editors->[0]\">$editors->[0]</name></editor>\n";
    }
    $tmp_count++;
  }

  # Now to prepare the UPDATED DATES for the file.
  my @file_updates_list = (); my $last_updated_by; $tmp_count = 0;
  foreach $dates_sorted (reverse(@dates_sorted)) {
    if ($tmp_count == $#dates_sorted and $updated_by) { # Is there a last updated person?
      $last_updated_by = $updated_by;
    } else {
      $last_updated_by = 'Unknown';
    }
    $file_updates_list[$tmp_count] = "    <change when=\"$dates_sorted->[0]\" who=\"$last_updated_by\">\n" . 
                                     "      Project Gutenberg Update Release.\n" . 
                                     "    </change>\n";

    $tmp_count++;
  }

  ####-------------------------------####
  #### Time to print the <teiHeader> ####
  ####-------------------------------####
  print <<HERE;
<?xml version="1.0" encoding="utf-8"?>

<TEI>
<teiHeader>
  <fileDesc>
    <titleStmt>
      <title>$title</title>
HERE
if ($sub_title) {
print <<HERE;
      <title type="sub">$sub_title</title>
HERE
}
foreach (@authors_list) {
  print "      " . $_;          # <author><name reg=""></name></author>
}
foreach (@illustrators_list) {
  print "      " . $_;          # <editor role="illustrator"><name reg=""></name></editor>
}
foreach (@translators_list) {
  print "      " . $_;          # <editor role="translator"><name reg=""></name></editor>
}
foreach (@editors_list) {
  print "      " . $_;          # <editor role="editor"><name reg=""></name></editor>
}
print <<HERE;
    </titleStmt>
    <editionStmt>
      <edition n="$edition">Edition $edition, <date when="$last_updated[1]">$last_updated[0]</date></edition>
      <respStmt>
        <resp>Original e-Text edition prepared by</resp>
        <name>$created_by</name>
      </respStmt>
    </editionStmt>
    <publicationStmt>
      <publisher>Project Gutenberg</publisher>
      <pubPlace><xref url="http://www.gutenberg.org">www.gutenberg.org</xref></pubPlace>
      <address>
        <addrLine>809 North 1500 West,</addrLine>
        <addrLine>Salt Lake City,</addrLine>
        <addrLine>UT 84116</addrLine>
        <addrLine>United States</addrLine>
      </address>
      <date when="$release_date[1]">$release_date[0]</date>
      <idno type="gutenberg-no">$gutenberg_num</idno>
      <idno type="UUID">$uuid</idno>
      <availability>
        <p>This eBook is for the use of anyone anywhere at no cost and with
           almost no restrictions whatsoever. You may copy it, give it away or
           re-use it under the terms of the Project Gutenberg License included
           online at <xref url="http://www.gutenberg.org/license">www.gutenberg.org/license</xref>
        </p>
      </availability>
    </publicationStmt>
    <seriesStmt>
      <title level="s">$series_title</title>
      <idno type="vol">$series_volume</idno>
    </seriesStmt>
    <notesStmt>
      <note resp="redactor">$redactors_notes</note>
      <note type="transcriber">$transcriber_notes</note>
    </notesStmt>
    <sourceDesc>
      <biblStruct>
        <monogr>
          <title>$title</title>
HERE
if ($sub_title) {
  print <<HERE;
          <title type="sub">$sub_title</title>
HERE
}
foreach (@authors_list) {
  print "          " . $_;      # <author><name reg=""></name></author>
}
foreach (@illustrators_list) {
  print "          " . $_;      # <editor role="illustrator"><name reg=""></name></editor>
}
foreach (@translators_list) {
  print "          " . $_;          # <editor role="translator"><name reg=""></name></editor>
}
foreach (@editors_list) {
  print "          " . $_;      # <editor role="editor"><name reg=""></name></editor>
}
print <<HERE;
          <imprint>
            <pubPlace>$published_place</pubPlace>
            <publisher>$publisher</publisher>
            <date when="$published_date[1]">$published_date[0]</date>
          </imprint>
        </monogr>
      </biblStruct>
    </sourceDesc>
  </fileDesc>
  <encodingDesc>
    <samplingDecl>
      <p>Editorial notes from the source may not have been reproduced.</p>
      <p>Blank lines and multiple blank spaces, including paragraph indents, have not been preserved.</p>
    </samplingDecl>
    <editorialDecl>
HERE
if ($transcriber_errors) {
  print <<HERE;
      <correction status="high" method="silent">
        <p>$transcriber_errors</p>
      </correction>
HERE
}
print <<HERE;
      <normalization></normalization>
      <quotation marks="all" form="std">
        <p>Not all double quotation marks have been rendered with q tags.</p>
      </quotation>
      <hyphenation eol="none">
        <p>Hyphenated words that appear at the end of the line may have been reformed.</p>
      </hyphenation>
      <stdVals>
        <p>Standard date values in the header are recorded in the attribute "when=" and are given in ISO form yyyy-mm-dd.</p>
      </stdVals>
      <interpretation>
        <p>Italics are recorded without interpretation.</p>
      </interpretation>
    </editorialDecl>
    <classDecl>
      <taxonomy id="lc">
        <bibl>Library of Congress Classification</bibl>
      </taxonomy>
    </classDecl>
  </encodingDesc>
  <profileDesc>
    <creation>
      <date when="$current_date[1]">$current_date[0]</date>
    </creation>
      <langUsage>
        <language id="$language_code">$language</language>
      </langUsage>
    <textClass>
      <keywords scheme="lc">
        <list>
          <item></item>
        </list>
      </keywords>
      <classCode scheme="lc"><!-- LoC Class (PR, PQ, ...) --></classCode>
    </textClass>
  </profileDesc>
  <revisionDesc>
    <change when="$current_date[1]" who="Cook, Michael">
      Conversion of TXT document to TEI P5 by <name>Michael Cook</name>.
HERE
if ($encoding ne 'utf-8') {
  my $enc_tmp = uc($encoding);
  print <<HERE;
      Source file encoding: $enc_tmp.
      TEI encoded as UTF-8.
HERE
}
print <<HERE;
    </change>
HERE
foreach (@file_updates_list) {
  print $_;      # <change when="1900-01-01" who="Unknown">Details</change>
}
  print <<HERE;
  </revisionDesc>
</teiHeader>

<text>

<front>

  <titlePage>
    <docTitle>
      <titlePart type="main">$title</titlePart>
HERE
if ($sub_title) {
  print <<HERE;
      <titlePart type="sub">$sub_title</titlePart>
HERE
}
print <<HERE;
    </docTitle>
HERE
foreach my $author_name (@authors) {
  if ($author_name->[2]) {
    print <<HERE;
    <docAuthor>$author_name->[1] $author_name->[2]</docAuthor>
HERE
  } else {
    print <<HERE;
    <docAuthor>$author_name->[0]</docAuthor>
HERE
  }
}
if ($editor) {
  print <<HERE;
    <byline>Edited by <name>$editor</name></byline>
HERE
}
if ($illustrators) {
  print <<HERE;
    <byline>$illustrated_by_tag <name>$illustrators</name></byline>
HERE
}
if ($translators) {
  print <<HERE;
    <byline>$translated_by_tag <name>$translators</name></byline>
HERE
}
print <<HERE;
    <docEdition></docEdition>
    <docImprint>
      <pubPlace>$published_place</pubPlace>
      <publisher>$publisher</publisher>
      <docDate>$published_date[0]</docDate>
    </docImprint>
  </titlePage>

  <div type="dedication">
    <p></p>
  </div>

  <div type="contents">
    <head>Table of Contents</head>
    <divGen type="toc"/>
  </div>

  <div type="preface">
    <head>Preface</head>
    <p></p>
    <signed></signed>
  </div>

</front>

<body>

HERE

  return '';
}


sub output_footer {
  if ($is_book == 1) {
    print <<HERE;
</div>

HERE
  }
  print <<HERE;
</body>

<back>

HERE
  if ($footnote_exists == 1) {
    print <<HERE;
  <div type="footnotes">
    <head>Footnotes</head>
    <divGen type="footnotes"/>
  </div>

HERE
  }
  print <<HERE;
</back>

</text>

</TEI>

HERE

  return '';
}


####---------------------------------------####
#### Various cosmetic tweaks before output ####
####---------------------------------------####
sub pre_process {
  my $c = shift;

  #### Needs to be here otherwise all <tags> will be broken!
  $c =~ s|<|&lt;|g;
  $c =~ s|>|&gt;|g;

  ###----------------------------------------------------------------------###
  ### If English open quotes ‘ don't exist replace apostrophes with Entity ###
  ### This bit is a real ultra-safe way of checking                        ###
  ###----------------------------------------------------------------------###
  # x60 = ` | x91 = ‘ | x2018 = ‘ | x201A = ‚
  # Check for any opening quotes; including ' for full saftey
  if ($c =~ /[\x{2018}\x{201A}\x{60}\x{91}\x{27}]/) {
    $single_open_quotes_exist = 1;
  }
  # If not open quotes replace all single closing quotes with Entity
  if ($single_open_quotes_exist == 0) {
    # x92 = ’ | x2019 = ’
    $c =~ s|[\x{2019}\x{92}]|&#8217;|g;
  }

  # Add <b> tags; changing = and <b> to <hi>
  $c =~ s|<b>|<hi>|g;
  $c =~ s|</b>|</hi>|g;
  #$c =~ s|=([^=]+)=|<hi>$1</hi>|gis;


  ###################################
  ### PAGES NUMBERS or FOOTNOTES? ###
  ###################################
  $c =~ s|\{(\d+)\}|<pb n=$1>|g;  # Comment out if a eText uses {curly brackets} as footnotes.  
  
  ### <milestone>, <pb n=$1 /> and <footnote> are replaced with full tags in the "post_process" sub
  
  #### Replace <milestone> events
  # substitute * * * * * for <milestone> BEFORE footnotes
  # <milestone> will be replaced later, on line: ~1250
  $c =~ s|( +\*){3,}|\n<milestone>|g;

  #### Some pre-processing for the Footnotes.
  $c =~ s|[\{\<\[]l[\}\>\]]|[1]|g;            # fix stupid [l] mistake. Number 1 not letter l.

  ## Some footnotes are marked up with <>, {} or () so change to []
  my $note_exists = 0;
  if ( $c =~ m/\[(\d+|\*+|\w)\]/ ) { $note_exists = 1; }
  ## If footnotes are detected with the above, then we don't need to process these do we.
  if ($note_exists == 0) {
    ################### i should not need to escape these character class entries \* \+ ########################
    if ( $c =~ s|\<([\d\*\+]+)\>|[$1]|g ) {
      $note_exists = 1;
    } elsif ( $c =~ s|\{([\d\*\+]+)\}|[$1]|g ) {
      $note_exists = 1;
    }
   # In some rare cases there are mixed letter/number notes using {1a} styling
    if ($note_exists == 0) {
      $c =~ s|\{(\d+[a-z]+)\}|[$1]|g;
    }
    
   ### Often (1), (2), etc are NOT used as footnotes. Uncomment if needed.
   # Change (1) only if other brackets NOT detected -- extra bit of safety in case (1) is used for another reason.
#    if ($note_exists == 0) {
#      $c =~ s/\((\d\d?|\*+|\++)\)/[$1]/g;
#    }
  }

  $c =~ s|(\((\*+)\))|[$2]|g;             # Change (*) footnotes to *
  $c =~ s|(?=[^\[])(\*+)(?=[^\]])|[$1]|g; # Change * footnotes to [*]

  ## Check for * footnotes and fix up
  $c =~ s|(\n\s+)\[\*\*\*\] |$1\[Footnote 3: |g;         # If a footnote uses [* ...] then replace (footnote 3)
  $c =~ s|(\n\s+)\[(\*\*\|\+)\] |$1\[Footnote 2: |g;     # If a footnote uses [* ...] then replace (footnote 2)
  $c =~ s|(\n\s+)\[\*\] |$1\[Footnote 1: |g;             # If a footnote uses [* ...] then replace (footnote 1)

  ## Check for [1], [1a] style footnotes and fix up
  $c =~ s|(\n\s+)\[(\d+)\] |$1\[Footnote $2: |g;         # If a footnote uses [1 ...] then replace (footnote 1)
  $c =~ s|(\n\s+)\[(\d+[a-z]+)\] |$1\[Footnote $2: |g;   # If a footnote uses [1a ...] then replace (footnote 1a)

  # FOOTNOTES: Semi-auto process on footnotes.    
  if ($c =~ s/\[(\d+|\*+|\w)\]/<footnote=$1>/g) {
    $footnote_exists = 1;
  }  elsif ($c =~ s/\[(\d+[a-z]+)\]/<footnote=$1>/g) {
    $footnote_exists = 1;
  }

  ####------------------------------------####
  #### Do some other basic pre-processing ####
  ####------------------------------------####

  #substitute hellip for ...
  $c =~ s| *\.{3,}|&#8230;|g;
  $c =~ s| *(\. ){3,}|&#8230;|g;
  $c =~ s|&#8230; ?\.|&#8230;|g;          # Fix '&#8230; .'
  ############################### DO I NEED TO ESCAPE THESE CHARACTER CLASSES?? ###################################
  $c =~ s|&#8230; ?([\!\?])|&#8230;$1|g;  # Fix '&#8230; ! or ?'

  #substitute °, @ OR #o (lowercase O) for &#176;
  $c =~ s|(°\|@)|&#176;|g;
  $c =~ s|(\d{1,3})o|$1&#176;|g;

  # Reserved characters; these characters will give TeX trouble if left in
  $c =~ s|\\|&#92;|g;
  # $c =~ s|\{|&#123;|g;
  # $c =~ s|\}|&#125;|g;

  # substitute ___ 10+ to <milestone/>
  $c =~ s|_{10,}|milestone>|g;
  # substitute ------ 15+ for <milestone>
  $c =~ s|-{15,}|<milestone>|g;

  # substitute ----, --, -
  $c =~ s|----|&#8213;|g;
  $c =~ s|--|&#8212;|g;
  $c =~ s|—|&#8212;|g;

  return $c;
}


sub post_process {
  my $c = shift;
  
  #UNICODE Quote Replacement: Smart DOUBLE Quotes.
  # x84 = „ | x93 = “ | x94 = ”
  # x201C = “ (English Open)
  # x201D = ” (English Closed)
  # x201F = ‟ (???)
  # x201E = „ (German Open)
  $c =~ s|[\x{201C}\x{201E}\x{201F}\x{84}\x{93}]|<q>|g;
  $c =~ s|[\x{201D}\x{94}]|</q>|g;

  # Double Prime - What should I do with these...will they even exist?
  # x2033 = ″ | x2036 = ‶ (reverse double prime)
  #  $c =~ s|\x{2033}|</q>|g;
  #  $c =~ s|\x{2036}|<q>|g;

  #UNICODE Quote Replacement: APOSTROPHE.
  $c =~ s|\b[\x{2019}\x{92}\x{27}]\b|&#8217;|g;

  #UNICODE Apostrophe Replacement: SINGLE HIGH-REVERSED-9
  # x201B = ‛
  #     U+201B (HTML: &#8219;) – single high-reversed-9, or single reversed comma, quotation mark.
  #     This is sometimes used to show dropped characters at the end of words, 
  #     such as goin‛ instead of using goin‘, goin’, goin`, or goin' (see wikipedia)
  $c =~ s|\x{201B}|&#8219;|g;
  # Perhaps create a sub() with a word list for changing these dropped characters?
  
  #UNICODE Quote Replacement: Smart SINGLE Quotes.
  # x60 = ` | x91 = ‘ | x92 = ’
  # x2018 = ‘
  # x2019 = ’
  # x201A = ‚ (Low single curved quote, left - looks like a comma)
  # $c =~ s|[\x{2018}\x{201A}\x{60}\x{91}]|\x{2018}|g;
  # $c =~ s|[\x{2019}\x{92}]|\x{2019}|g;

  # Single Prime - What should I do with these...will they even exist?
  # x2033 = ’ | x2036 = ‵ (reverse double prime)
  #  $c =~ s|\x{2032}|’|g;
  #  $c =~ s|\x{2035}|‘|g;

  # Try to remove any silly BOX formating. +----+, | (...text...) |  stuff!
  $c =~ s|\+-+\+|\n|g;
  $c =~ s/ *\|(.+)\| *\n/$1\n/g;

  ####-------------------####
  #### Text Highlighting ####
  ####-------------------####

  # Add <emph> tags; changing _ and <i> to <emph>
  $c =~ s|<i>|<emph>|g;
  $c =~ s|</i>|</emph>|g;
  $c =~ s|_(.*?)_|<emph>$1</emph>|gis;
  $c =~ s|<emph></emph>|__|g;           # empty tags - perhaps these are meant to be underscores?

  ####-----------------------####
  #### Typografical Entities ####
  ####-----------------------####

  # Ignore hyphenated words and just replace all hyphens (-) with &#8211;
  $c =~ s|-|&#8211;|g;

  # move dashes
  $c =~ s|&#8212; </q>([^ ])|&#8212;</q> $1|g;
  $c =~ s|&#8212; </q>|&#8212;</q>|g;
  $c =~ s|([^ ])<q> &#8212;|$1 <q>&#8212;|g;

  # SUPERSCRIPT
  $c =~ s|(\^)([^ ]+)|<sup>$2</sup>|g;
  $c =~ s|([IVX]+)(er)(?=[^\w])|$1<sup>$2</sup>|g;
  # SUBSCRIPT (Only works for H_2O formula.)
  $c =~ s|(\w)_([0-9])|$1<sub>$2</sub>|g;
  $c =~ s|H2O|H<sub>2</sub>O|g; # In case no underscore has been added.

  # insert a non-breaking space after Mr. Ms. Mrs., etc.
  $c =~ s|(?<=\s)(Ms\.?)[ \n]+([[:upper:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(Mrs?\.?)[ \n]+([[:upper:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(Mme\.?)[ \n]+([[:upper:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(Dr\.?)[ \n]+([[:upper:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(St\.?)[ \n]+([[:upper:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(No\.?)[ \n]+([[:digit:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(Rev\.?)[ \n]+([[:upper:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(Sgt\.?)[ \n]+([[:upper:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(Capt\.?)[ \n]+([[:upper:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(Gen\.?)[ \n]+([[:upper:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(M\.)[ \n]+([[:upper:]])|$1&#160;$2|g;
  $c =~ s|(?<=\s)(Ew\.)[ \n]+([[:upper:]])|$1&#160;$2|g;

  ####-------------------####
  #### Various Cosmetics ####
  ####-------------------####

  # strip multiple spaces
  $c =~ s|[ \t]+| |g;

  # strip spaces before new line/end of text
  $c =~ s| *\n|\n|g;
  $c =~ s|\s*$||g;   # This line was origianlly in output_para() after post_process()

  # strip leading spaces
  $c =~ s|^ +||;

  # Don't worry about Marcellos stuff here
  # $c =~ s|<qpre>|<q rend=\"post: none\">|g;
  # $c =~ s|<qpost>|<q rend=\"pre: none\">|g;
  $c =~ s|<qpre>|<q>|g;
  $c =~ s|<qpost>|<q>|g;

  # [BLANK PAGE]
  $c =~ s|\[Blank Page\]|<div type="blankpage"></div>|g;

  # ILLUSTRATIONS ...
  # Original formula....keep!
  # $c =~ s| *\[Illustration:? ?([^\]\\]*)(\\.[^\]\\]*)*\]|<figure url="images/">\n <head>$1</head>\n <figDesc>Illustration</figDesc>\n</figure>|gi;
  if ($c =~ s| *\[Illustration:? ?([^\]\\]*)(\\.[^\]\\]*)*\]|<figure url="images/">\n   <figDesc>$1</figDesc>\n</figure>|gi) {
    # my $tmp = change_case($1);
    my $tmp = $1;
    # $tmp =~ s|[\r\n]+| |g;
    $tmp =~ s|\n+| |g;
    $c =~ s|(.*?)<figDesc>(.*?)</figDesc>(.*?)|$1<figDesc>$tmp</figDesc>$3|s;
  }
  $c =~ s|(.*?)<figDesc></figDesc>(.*?)|$1<figDesc>Illustration</figDesc>$2|; # Replace empty <figDesc>'s with an Illustration description

  $c =~ s|<head> ?(.*?) ?</head>|<head>$1</head>|g; # Strip the leading white space - Find a better way!!
  $c =~ s|<head>\"|<head><q>|g;     # apply more quotes
  $c =~ s|\"</head>|</q></head>|g;  # apply more quotes

  # substitute <pb n=179> to include the "quotes"; <pb n="179" />
  $c =~ s|<pb n=(\d+)>|<pb n="$1" />|g;

  # substitute <milestone> to include the unit="tb" attribute.
  $c =~ s|<milestone>|<milestone unit="tb" />|g;

  # substitute <footnote> to include full tag
  if ($c =~ s|<footnote=(.*?)>|<note place="foot">\n\n[PLACE FOOTNOTE HERE] -- $1\n\n</note>|g) {
    $footnote_exists = 1;
  }

  ####-------------------------####
  #### DO SOME FINAL FIXING UP ####
  ####-------------------------####

  $c =~ s|</figure></q></q>|</figure>|g;  # quotes after </figure>
  $c =~ s/([NMQ])dash/$1dash/g;           # Fix &#8211; caps

  $c =~ s|&c\.|&amp;c.|g;                 # Some old books use "&c." mark-up "&amp;" (this means "etc.")

  # Change 'Named Entity' characters to 'Numbered Entity' codes.
  # For use with TEI DTD and XSLT.
  #  $c =~ s|&nbsp;|&#160;|g;
  #  $c =~ s|&ndash;|&#8211;|g;
  #  $c =~ s|&mdash;|&#8212;|g;
  #  $c =~ s|&qdash;|&#8213;|g;
  #  $c =~ s|&hellip;|&#8230;|g;
  #  $c =~ s|&deg;|&#176;|g;

  return $c;
}


sub encode_lang {
  my $lang = shift;

  if ($lang eq "English") {
    $lang = "American";
  }
  while (my ($key, $value) = each (%languages)) {
    if ($value eq $lang) {
      return $key;
    }
  }
  return $lang;
}


sub process_dates {
  my ($year, $month, $day) = (0, 0, 0);
  my $tmp_month = 0;
  my $wdate = shift;

  return if $wdate eq '';
  
  # Look for: 1990-12-23
  if ($wdate =~ m|^(\d{4})-([01]?[0-9])-([0123]?[0-9])$|) {
    ($year, $month, $day) = ($1, $2, $3);
    $tmp_month = $month;

  # Look for: January 22, 2002
  } elsif ($wdate =~ m|^(\w+)\s+([0123]?[0-9]),?\s+(\d{2,4})$|) {
    ($year, $month, $day) = ($3, $1, $2);
  
  # Look for: 9/19/01 or 9-19-2002
  } elsif ($wdate =~ m|^(\d{1,2})[/-]([0123]?[0-9])[/-](\d{2,4})$|) {
    ($year, $month, $day) = ($3, $1, $2);
    $tmp_month = $month;

  # Look for: January, 2002 or January 2002
  } elsif ($wdate =~ m|^(\w+),?\s+(\d{2,4})$|) {
    ($year, $month, $day) = ($2, $1, 0);

  # Look for English format: 21st January, 2002
  } elsif ($wdate =~ m/^([123]?[0-9])(st|nd|rd|th)\s+(\w+),?\s+(\d{2,4})$/) {
    ($year, $month, $day) = ($4, $3, $1);
  }

  # ERROR Checking - Maybe we don't have a full date!
  if ($year == 0) { $year = $wdate; }

  $month = encode_month ($month);

  if ($month == 0)     { if ($tmp_month eq 0) { $month = "***"; } else { $month = $tmp_month; } }
  if ($year < 7)       { $year += 2000; } elsif ($year < 70) { $year += 1900; }
  if ($day)            { return sprintf ("%04d-%02d-%02d", $year, $month, $day); }
  if ($month ne "***") { return sprintf ("%04d-%02d", $year, $month); }
  return sprintf ("%04d", $year);
}


sub encode_month {
  my $wmonth = shift;

  # fix shorter months
  my %short_months = (
     1     => "Jan",
     2     => "Feb",
     3     => "Mar",
     4     => "Apr",
     5     => "May",
     6     => "Jun",
     7     => "Jul",
     8     => "Aug",
     9     => "Sep",
    10     => "Oct",
    11     => "Nov",
    12     => "Dec"
  );
  my %months = (
     1     => "January",
     2     => "February",
     3     => "March",
     4     => "April",
     5     => "May",
     6     => "June",
     7     => "July",
     8     => "August",
     9     => "September",
    10     => "October",
    11     => "November",
    12     => "December"
  );

  while (my ($key, $value) = each(%months)) {
    if ($value eq $wmonth) {
      return $key;
    }
  }
  while (my ($key, $value) = each(%short_months)) {
    if ($value eq $wmonth) {
      return $key;
    }
  }
  return 0;
}


sub encode_numbers {
  my $tmp_num = shift;

  $tmp_num = uc($tmp_num); # removes anys case sensitivity.
  
  # fix numbers
  my %numbers = (
     1     => "ONE",
     2     => "TWO",
     3     => "THREE",
     4     => "FOUR",
     5     => "FIVE",
     6     => "SIX",
     7     => "SEVEN",
     8     => "EIGHT",
     9     => "NINE",
    10     => "TEN",
    11     => "ELEVEN",
    12     => "TWELVE",
    13     => "THIRTEEN",
    14     => "FOURTEEN",
    15     => "FIFTHTEEN",
    16     => "SIXTEEN",
    17     => "SEVENTEEN",
    18     => "EIGHTEEN",
    19     => "NINETEEN",
    20     => "TWENTY",
  );
  my %roman_numbers = (
     1     => "I",
     2     => "II",
     3     => "III",
     4     => "IV",
     5     => "V",
     6     => "VI",
     7     => "VII",
     8     => "VIII",
     9     => "IX",
    10     => "X",
    11     => "XI",
    12     => "XII",
    13     => "XIII",
    14     => "XIV",
    15     => "XV",
    16     => "XVI",
    17     => "XVII",
    18     => "XVIII",
    19     => "IX",
    20     => "XX",
  );
  my %ordinal_numbers = (
     1     => "FIRST",
     2     => "SECOND",
     3     => "THIRD",
     4     => "FOURTH",
     5     => "FIFTH",
     6     => "SIXTH",
     7     => "SEVENTH",
     8     => "EIGHTH",
     9     => "NINTH",
    10     => "TENTH",
    11     => "ELEVENTH",
    12     => "TWELFTH",
    13     => "THIRTEENTH",
    14     => "FOURTEENTH",
    15     => "FIFTEENTH",
    16     => "SIXTEENTH",
    17     => "SEVENTEENTH",
    18     => "EIGHTEENTH",
    19     => "NINETEENTH",
    20     => "TWENTIETH",
  );

  while (my ($key, $value) = each(%numbers)) {
    if ($value eq $tmp_num) {
      return $key;
    }
  }
  while (my ($key, $value) = each(%roman_numbers)) {
    if ($value eq $tmp_num) {
      return $key;
    }
  }
  while (my ($key, $value) = each(%ordinal_numbers)) {
    if ($value eq $tmp_num) {
    return $key;
    }
  }

  return $tmp_num;
}


sub process_names {
  my $names_string = shift;
  my @names = ();

  # Tidy things up
  $names_string =~ s/\(/[/;                 # Change () brackets to [] brackets
  $names_string =~ s/\)/]/;                 # Change () brackets to [] brackets
  $names_string =~ s/ +(&amp;|and|&) +/+/;  # Replace '&amp;' to '+' for the split
  $names_string =~ s/^ *(.*?) *$/$1/;       # Strip any end spaces

  my @names_list = split(/\+/, $names_string);

  my $count = 0;
  foreach my $name (@names_list) {
    if ($name =~ /^(.*?) +([-\w]+)$/i) {
      my $orig_firstname = $1; # Keep the original first name for <front> data
      my $firstname = $1;
      my $lastname = $2;
      ## Some authors use initials, so assign proper name also
      if ($lastname eq 'Baum'       and $firstname =~ /L\. ?Frank/)  { $firstname = 'Lyman Frank'; }
      if ($lastname eq 'Fitzgerald' and $firstname =~ /F\. ?Scott/)  { $firstname = 'Francis Scott'; }
      if ($lastname eq 'Montgomery' and $firstname =~ /L\. ?M./)     { $firstname = 'Lucy Maud'; }
      if ($lastname eq 'Nesbit'     and $firstname =~ /E\./)         { $firstname = 'Edith'; }
      if ($lastname eq 'Smith'      and $firstname =~ /E\. ?E./)     { $firstname = 'Edward Elmer'; }
      if ($lastname eq 'Smith'      and $firstname =~ /["']Doc["']/) { $firstname = 'Edward Elmer'; }
      if ($lastname eq 'Wells'      and $firstname =~ /H\. ?G./)     { $firstname = 'Herbert George'; }
      if ($lastname eq 'Wodehouse'  and $firstname =~ /P\. ?G./)     { $firstname = 'Pelham Grenville'; }
      $names[$count] = ([$firstname, $orig_firstname, $lastname]);
    } elsif ($name =~ m/^Anon/i) {
      $names[$count] = (['Anonymous']);    
    } else {
      $names[$count] = ([$name]);    
    }
    $count++;
  }
  if (!@names) {
    $names[0] = (['Anonymous']);
  }

  return @names;
}


sub list_languages {
  my $langlist = '';
  foreach my $key (sort (keys %languages)) {
    $langlist .= "      <language id=\"$key\">$languages{$key}</language>\n";
  }
  return $langlist;
}

sub guess_quoting_convention {
  # study the text and decide which quoting convention is used
  my $openquote1  = '';
  my $closequote1 = '';
  my $openquote2  = '';
  my $closequote2 = '';

  if ( length($override_quotes) ) {
    $openquote1  = substr ($override_quotes, 0, 1);
    $openquote2  = substr ($override_quotes, 1, 1);
    $closequote2 = substr ($override_quotes, 2, 1);
    $closequote1 = substr ($override_quotes, 3, 1);
    } else {
    my $body = shift;
    $body = $$body;

    #  my $count_84 = ($body =~ tr/\x84/\x84/); # win-1252 („) opening double quote
    my $count_22 = ($body =~ tr/\x22/\x22/); # " ascii double quote
    #  my $count_27 = ($body =~ tr/\x27/\x27/); # ' ascii single quote
    my $count_60 = ($body =~ tr/\x60/\x60/); # ` ascii single opening quote (grave accent)
    my $count_b4 = ($body =~ tr/\xb4/\xb4/); # ´ ascii single closing quote (acute accent)
    my $count_ab = ($body =~ tr/\xab/\xab/); # « left guillemet
    my $count_bb = ($body =~ tr/\xbb/\xbb/); # » right guillemet

    #  my $single_quotes = $count_27 + $count_60 + $count_b4;
    my $single_quotes = $count_60 + $count_b4;
    #  my $double_quotes = $count_22 + $count_84;
    my $double_quotes = $count_22;
    my $guillemets    = $count_ab + $count_bb;

    my $french_quotes   = ($guillemets > $single_quotes + $double_quotes);
    my $american_quotes = ($double_quotes > $single_quotes);

    if ($french_quotes) {
      $openquote1  = "\xab";
      $closequote1 = "\xbb";
      $openquote2  = "<";
      $closequote2 = ">";
    } elsif ($american_quotes) {
      # $openquote1 = $count_84 ? "\x84" : "\x22";
      $openquote1  = "\x22";
      $closequote1 = "\x22";
      # $openquote2  = $count_60 ? "\x60" : "\x27";
      $openquote2  = "\x60";
      # $closequote2 = "\x27";
      $closequote2 = "\xb4";
      #  } else { # british quotes
      #      $openquote1  = $count_60 ? "\x60" : "\x27";
      #      $closequote1 = "\x27";
      #      $openquote2  = $count_84 ? "\x84" : "\x22";
      #      $closequote2 = "\x22";
    }
    print ("\nguessed quotes: $openquote1 $closequote1 and $openquote2 $closequote2\n");
  }
  # how to catch quoted material
  # on nesting level1 and level2
  # pre is for paragraphs without closing quote
  # \B matches non-(word boundary), ^ and $ are considered non-words

  # Marcello only checked quote when followed by limited characters :alpha: _ $ etc.
  # $quotes1    = qr/\B$openquote1(?=[[:alpha:]_\$$openquote2])(.*?)$closequote1\B/s;
  # $quotes1pre = qr/\B$openquote1(?=[[:alpha:]_\$$openquote2])(.*?)$/s;
  # $quotes2    = qr/\B$openquote2(?=[[:alpha:]])(.*?)$closequote2\B/s;
  $quotes1    = qr/\B$openquote1(.*?)$closequote1\B/s;
  $quotes1pre = qr/\B$openquote1(.*?)$/s;
  $quotes2    = qr/\B$openquote2(.*?)$closequote2\B/s;
}


sub study_paragraph {
  # learn interesting stuff about this paragraph

  my @lines = split (/\n/, shift);
  my $o = { };

  my $cnt_lines  = scalar (@lines);
  my $min_len    = 10000; # Not sure why Marcello included this variable
  my $max_len    = 0;     # Not sure why Marcello included this variable
  my $sum_len    = 0;
  my $min_indent = 10000;
  my $max_indent = 0;
  my $cnt_indent = 0;
  my $sum_indent = 0;
  my $cnt_caps   = 0;
  my $cnt_short  = 0;
  my $cnt_center = 0;

  # Compute % of max line length (currently: 84%)
  my $threshhold = int ($max_line_length * 80 / 100);

  for (@lines) {
    # On rare occassions a <milestone> is included in a <lg>
    # need to skip this line as it messes up the checks
    if (m/<milestone>/) {
      $cnt_lines -= 1;
      next;
    }
    # min, max, avg line length
    my $len = length ($_);

    $min_len = $len if ($len < $min_len);
    $max_len = $len if ($len > $min_len);
    $sum_len += $len;

    # count indented lines
    # min and max indentation
    m/^(\s*)/;
    my $indent = length ($1);
    $max_indent = $indent if ($indent > $max_indent);
    $min_indent = $indent if ($indent < $min_indent);
    $cnt_indent++ if ($indent);
    $sum_indent += $len;

    # count lines beginning with capital; ignoring punctuations and spaces.
    $cnt_caps++ if (m/^([^a-zA-Z]*)[A-Z]/);

    # count lines shorter than xx% (set above) max text line length
    $cnt_short++ if ($len < $threshhold);

    my $right_indent = $max_line_length - $len;

    # count centered lines
    if ($indent > 0) {
      if (($right_indent / $indent) < 2) {
        $cnt_center++;
      }
    }
  }

  $cnt_lines = 1 if ($cnt_lines == 0);

  $o = {
    'cnt_lines'  => $cnt_lines,
    'min_len'    => $min_len,
    'max_len'    => $max_len,
    'sum_len'    => $sum_len,
    'avg_len'    => $sum_len / $cnt_lines,

    'cnt_indent' => $cnt_indent,
    'min_indent' => $min_indent,
    'max_indent' => $max_indent,
    'sum_indent' => $sum_indent,
    'avg_indent' => $sum_indent / $cnt_lines,

    'cnt_short'  => $cnt_short,
    'cnt_long'   => $cnt_lines - $cnt_short,
    'cnt_caps'   => $cnt_caps,
    'cnt_left'   => $cnt_lines - $cnt_indent,
    'cnt_center' => $cnt_center,
  };

  return $o;
}


sub is_para_verse {
  # decide if paragraph is a verse
  # param is result from study_paragraph
  my $o = shift;
  
  # If only one line and no indent then we don't know if it is a <l>
  return 0 if $o->{'cnt_lines'} < 2 && $o->{'min_indent'} == 0;

  ######################################
  # are all lines indented ?
  # return 0 if $o->{'min_indent'} == 0; # Marcello's Original

  ## Here we check for the number of indented lines instead of min_indent
  if ($o->{'cnt_indent'} < 2 && $o->{'min_indent'} == 0) {
    if ($o->{'cnt_long'} > 0) {
      return 0;
    }
  }

  ############################################
  # do all lines begin with capital letters ?
  #
  # first check for more than one line
  if ($o->{'cnt_lines'} > 1) {
    # Not all caps?
    return 0 if $o->{'cnt_caps'} < $o->{'cnt_lines'};

    # NEW! 2009-12-03
    # All Caps and no indent
    return 0 if $o->{'cnt_caps'} == $o->{'cnt_lines'} && $o->{'max_indent'} == 0;

    ##### Is this line still needed with the line above? -- Only if the line above doesn't work! ####
    # Extra check as some two-liners both contain Capitals at the start.
    # return 0 if $o->{'cnt_lines'} == 2 && $o->{'max_indent'} == 0;
  }

  # are all lines shorter than average ?
  return 0 if $o->{'cnt_long'} > 0 && $o->{'max_indent'} == 0;

  # all tests passed, this is verse
  return 1;
}


sub is_para_centered {
  my $o = shift;
  return $o->{'cnt_center'} == $o->{'cnt_lines'};
}


sub is_para_right {
  my $o = shift;

  # one-liner, cannot tell
  return 0 if $o->{'cnt_lines'}  < 2;

  return 0 if $o->{'min_indent'} == $o->{'max_indent'};
  return 0 if $o->{'min_len'}    != $o->{'max_len'};
  return 1;
}


sub is_para_justified {
  my $o = shift;

  # one-liner, cannot tell
  return 0 if $o->{'cnt_lines'}  < 2;

  return 0 if $o->{'min_indent'} != $o->{'max_indent'};
  return 0 if $o->{'min_len'}    != $o->{'max_len'};
  return 1;
}


sub compute_line_length {
  # computes average and max line length of this text
  my $body = shift;

  my @lines = split (/\n/, $$body);
  my $lines   = 0;
  my $sum_len = 0;
  my $max_len = 0;
  for (@lines) {
    my $len = length ($_);
    if (!/^$/) {
      $lines++;
      $sum_len += $len;
    }
    $max_len = $len if ($len > $max_len);
  }

  return ($sum_len / $lines, $max_len);
}


sub change_case {
  my $case = shift;

  $case = lc($case);
  $case =~ s|(?<![a-z])([a-z])|\u$1|g;
  $case =~ s|\bAnd\b|and|g;
  $case =~ s|\bOf\b|of|g;
  $case =~ s|\bBy\b|by|g;
  $case =~ s|<(/)?(.*?)>|<$1\l$2>|g;
  $case =~ s|([NMQ])dash|$1dash|g;      # Fix &#8211; caps
  $case =~ s|&Amp;|&amp;|g;             # &Amp;
  $case =~ s|(.*?)\'S|$1's|g;           # change 'S to 's

  return $case;
}


sub lower_case {
  my $case = shift;

  $case =~ s/(.*?)/\l$1/g;

  return $case;
}


sub uuid_gen {
  my $ug = new Data::UUID;
  my $uuid = $ug->create_str();

  # this creates a new UUID in string form, based on the standard namespace
  # UUID NameSpace_URL and name "www.mycompany.com"

  ## NOTE: This does not create a random number each time...it is always the same
  # my $uuid = $ug->create_from_name_str(NameSpace_URL, "www.epubbooks.com");

  return $uuid;
}

if ($help) {
    usage (); exit;
}


sub usage {
  print <<HERE;

PGText to TEI converter

usage: gut2tei.pl [options] pgtextfile > teifile

--quotes="[()]"    quoting convention used (default: automatic detection)
                   [] = outer quotes, () = inner quotes
       eg. --quotes="\\\"''\\\''
--chapter=n        empty lines before chapter        (default: $cnt_chapter_sep)
--head=n           empty lines after chapter heading (default: $cnt_head_sep)
--paragraph=n      empty lines before paragraph      (default: $cnt_paragraph_sep)
--drama            text is drama   (default: prose)
--verse            text is verse   (default: prose)
--help             display this screen

HERE
# --locale           use this locale (default: $locale)
}

# Local Variables:
# mode:perl
# coding:utf8-unix
# End:
