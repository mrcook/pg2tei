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
use Getopt::Long;
use Getopt::Long;
use POSIX qw(strftime);
use POSIX qw(locale_h);
use Text::Wrap;
use Data::UUID;
use Data::Dumper;

use utf8;
#use open IN => ":encoding(utf8)", OUT => ":utf8";
#use open qw/:std :encoding(utf8)/;

use vars '$front_matter_block';
use vars '@illutrators';

use locale;
my $locale = "en";

$Text::Wrap::columns = 78;
my $help   = 0;

# some parameters

my $cnt_chapter_sep   = "3,"; # chapters are separated by 3 empty lines
my $cnt_head_sep      = "2";
my $cnt_paragraph_sep = "1";

# some hints as to what is being converted
my $is_verse = 0;             # work is a poem

# regexps how to catch quotes (filled in later)
my ($quotes1, $quotes1pre, $quotes2);

my $avg_line_length = 0;
my $max_line_length = 0;


################################################################################

my $date_string     = "<date value=\"" . strftime ("%Y-%m", localtime ()) . "\">" . strftime ("%B %Y", localtime ()) . "</date>";
my $dcurdate        = strftime ("%Y-%m-%d", localtime ());
my $current_date    = strftime ("%d %B %Y", localtime ());

my  $producer       = '*** unknown';
my  $title          = '';
my  $sub_title      = '';
my  $author_string  = '';
my  $editor         = '';
my  $illustrated_text = 'Illustrated by';
my  $illustrated_by = '';
my  $translated     = '';
my  $translated_by  = '';
my  $publishedplace = '';
my  $publisher      = '';
my  $publishdate    = '';

my  $language       = '***';
my  $language_code  = '';
my  $charset        = '***';

my  $posteddate       = '';
my  $releasedate      = '';
my  $lastupdated      = '';
my  $posteddate_iso   = '';
my  $releasedate_iso  = '';
my  $lastupdated_iso  = '';
my  $revision_lastupdated = ''; # Needed for <revisionDesc>
my  $firstupdated     = '';
my  $firstupdated_iso = '';

my  $filename       = '';
my  $gutenberg_num  = '';
my  $edition        = '';

my  $prod_first_by      = 'unknown';
my  $produced_by        = 'unknown';
my  $produced_update_by = 'unknown';

my  $transcriber_notes  = '';
my  $transcriber_errors = '';
my  $redactors_notes    = '';

my  $footnote_exists    = 0;

my  $is_book            = 0;
my  $is_book_div        = 0;

my %languages = (
  "de"	   => "German",
  "el"	   => "Greek",
  "en-gb"  => "British",
  "en-us"  => "American",
  "en"	   => "English",
  "es"	   => "Spanish",
  "fr"	   => "French",
  "it"	   => "Italian",
  "la"	   => "Latin",
  "nl"	   => "Dutch",
  "pl"	   => "Polish",
  "pt"     => "Portuguese",
);

my $override_quotes = '';
GetOptions (
  "quotes=s"    => \$override_quotes,
	"chapter=i"   => \$cnt_chapter_sep,
	"head=i"      => \$cnt_head_sep,
	"paragraph=i" => \$cnt_paragraph_sep,
	"verse!"      => \$is_verse,
	"locale=s"    => \$locale,
	"help|h|?!"   => \$help,
);

if ($help) {
    usage (); exit;
}

setlocale (LC_CTYPE, $locale);
$locale = setlocale (LC_CTYPE);
#print "NEW locale: $locale\n";

# how to catch chapters and paragraphs etc.
# regexes get applied in this order:
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

#my $epigraph1  = qr/^(.*?)\n\n\s*--([^\n]*?)\n\n+/s; # match epigraph and citation

undef $/;  # slurp it all, mem is cheap

while (<>) {
    s|\r||g;         # cure M$-DOS files
    s|\t| |g;        # replace tabs
    s|[ \t]+\n|\n|g; # remove spaces at end of line

    # Do a quick check on the language to see if it is British English
    if (m/(colour|flavour|favour|savour|honour|defence|ageing|jewellery)/i) {
      $language = "British";
    }

    # process gutenberg header and output tei header
# A simpler rule for certain books
#  if (s/^(.*?)(?=\n\n[_ ]*((CHAPTER|PART|BOOK|VOLUME) )?(1[^\d]|:upper:O:upper:N:upper:E)(.*?)\n)/output_header ($1)/egis) {

# This one Checks for a PREFAC/INTRO's/etc and then checks for Chapters, etc. including "The First" type stuff
  if (s/^(.*?)(?=\n\n[_ ]*(PREFACE|INTRODUCTION|AUTHOR\'S NOTE|((CHAPTER|PART|BOOK|VOLUME) )?(((\w+) )?[1[^\d\.]|:upper:O:upper:N:upper:E|I[^( ?:lower:\w)]))(.*?)\n)/output_header($1)/egis) {

# this one works - for the most part!!
#  if (s/^(.*?)(?=\n\n[_ ]*((CHAPTER|PART|BOOK|VOLUME) )?(1[^\d\.]|:upper:O:upper:N:upper:E|I)(.*?)\n)/output_header ($1)/egis) {

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


# process body
  if (! s/^(.*?)[\* ]*((This is )?(The )?End of (Th(e|is) )?Project Gutenberg [e|E](book|text))/output_body ($front_matter_block .= $1)/egis) {
#    output_body ($front_matter_block .= $_);
  }

# output tei footer
    output_footer ();
}

### end of main () #############################################################

sub output_line {
  my $line = shift;
  my $min_indent = shift;

  $line =~ m/\S/g;
##  my $indent = "&nbsp;" x (pos ($line) - $min_indent - 1); ## OLD spacinging
  my $indent = (pos ($line) - $min_indent - 1);
  $line =~ s/^\s*//;

  if (length ($line)) {

    $indent = 6 if $indent >= 7;
    $indent = 4 if $indent == 5;
    $indent = 2 if $indent == 3;
    $indent = 0 if $indent == 1;
    
    my $line_indent = '';
    $line_indent = ' rend="margin-left(' . $indent . ')"' if $indent > 0;


#### Remove quotes for now as they create more havoc than good!!!!
#    $line = process_quotes_1 ($line);
#    $line = fix_unbalanced_quotes_line ($line);

    $line = post_process ($line);
    $line = process_footnotes ($line);

    if ( $line =~ m/\[(\d+|\*)\]/ ) { # Check for footnotes
      print "<p>$line</p>\n";
    } else {
      # Fix some double <q> tags
      $line =~ s|</q></q>|</q>|g;
      $line =~ s|<q></q>|</q>|g;
      $line =~ s|<q><q>|<q>|g;
      print "  <l$line_indent>$line</l>\n";
    }

  }
  return '';
}

sub output_para {
  my $p = shift;
  $p .= "\n";
  
  my $o = study_paragraph ($p);
  
  # substitute * * * * * for <milestone> BEFORE footnotes
  # Replace <milestone> later, on line: ~1250
  $p =~ s|^( *\*){3,}|<milestone>|g;

  if (($is_verse || is_para_verse($o)) && $p ne "<milestone>\n") {
    # $p = process_quotes_1 ($p); ## Not sure if this should be enabled...probably not.
    # $p = post_process ($p);     ## Not sure if this should be enabled...probably not.

    print "<quote>\n <lg>\n";
    while (length ($p)) {
      if ($p =~ s/^(.*?)\s*\n//o) {
        output_line ($1, $o->{'min_indent'});
      }
    }
    print " </lg>\n</quote>\n\n";
  } else {
    # paragraph is prose
    # join end-of-line hyphenated words
#   $p =~ s|[^-]-[ \t\n]+|-|g; # Marcello's Line
    $p =~ s|([^- ])- ?\n([^ ]+) |$1-$2\n|g;

    $p = process_quotes_1 ($p);
    $p = post_process ($p);

#    $p =~ s/\s+/ /g; # This strips out the original newlines - Marcello's Line
    $p =~ s/ +/ /g; # Change Marcello's to just strip out multiple spaces
    $p =~ s/\s*$//g;

    my $rend = '';
    $rend = ' rend="text-align(center)"' if (is_para_centered ($o));
    $rend = ' rend="text-align(right)"'  if (is_para_right ($o));

    $p =~ s|^ (.*?)|$1|;  # remove any leading spaces

    if ($p =~ m|^<(figure\|milestone\|div)|) {
    } else {
      $p = "<p$rend>$p</p>";
    }

    $p = process_footnotes ($p);

#### ------------ ---------------------- ------------ ####
####    DO SOME LAST MINUTE FIXING UP BEFORE OUTPUT   ####
#### Not the best way but it works....so I'm happy :) ####
#### ------------ ---------------------- ------------ ####

    #Opening and closing quotes?
#    $p =~ s|</quote>\r\n\r\n<quote>|\r\n\r\n|g;
    $p =~ s|</quote>\n\n<quote>|\n\n|g;

    $p =~ s|&hellip; ?\.|&hellip;|g; # Fix '&hellip; .'
    $p =~ s|&hellip; ?([\!\?])|&hellip;$1|g; # Fix '&hellip; ! or ?'

    $p =~ s|</figure></q></q>|</figure>|g; # quotes after </figure>

    $p =~ s|<emph></emph>|__|g; # empty tags - perhaps these are meant to be underscores?

    $p =~ s/([NMQ])dash/$1dash/g; # Fix &ndash; caps

    # Change 'Named Entity' characters to 'Numbered Entity' codes.
    # For use with TEI DTD and XSLT.
    $p =~ s|&nbsp;|&#160;|g;
    $p =~ s|&ndash;|&#8211;|g;
    $p =~ s|&#8212;|&#8212;|g;
    $p =~ s|&qdash;|&#8213;|g;
    $p =~ s|&hellip;|&#8230;|g;
    $p =~ s|&deg;|&#176;|g;

    print $p;  # No WRAP
#   print wrap ("", "", $p);  # WRAP - Marcello's Line

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
  $head_tmp = process_footnotes ($head_tmp);

  $head_tmp =~ s/^\s//; # Strip out leading whitespace

  if ($head_tmp =~ m/^<(figure|milestone)/) { # stop <figure> and others getting caught
    print $head_tmp . "\n\n";
  } else {
    print "<head>" . $head_tmp . "</head>\n\n";
  }

  while ($head =~ s/$paragraph1//) {
    my $subhead = post_process ($1);

    $subhead =~ s|^\"(.*?)\"$|<q>$1</q>|; # Rough fix of Quotes

    $subhead =~ s/^\s//gm; # Strip out leading whitespace

    if ($subhead =~ m/^<(figure|milestone)/) { # stop <figure> and others getting caught
      print $subhead . "\n\n";
    } else {
     print "<head type=\"sub\">$subhead</head>\n\n";
   }
  }
  print ("\n");
  return '';
}

# quotes involve pretty much guesswork and probably
# we will get some quotes wrong

sub process_quotes_2 {
  my $c = shift;

  if ($c =~ m/$quotes2/) {
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
  #$c =~ s|([\"«»\x84])|<fixme>$1</fixme>|g;
  #### just convert to <q> and hope XSL catches it
  $c =~ s|([\"«»\x84])|<q>|g;

  $c = do_fixes ($c);

  return $c;
}

sub fix_unbalanced_quotes_line {
  # tries to fix unbalanced quotes in verse lines
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

sub do_fixes {

  # tries to fix various quotes
  my $fix = shift;

  $fix =~ s| </q>|</q>|g; # Tidy up </q> tags with space before.

  return $fix;
}

sub output_epigraph {
  my $epigraph = shift;
  my $citation = shift;

  print "<epigraph>\n\n";

  $epigraph = process_quotes_1 ($epigraph);
  $citation = process_quotes_1 ($citation);
  $epigraph = post_process ($epigraph);
  $citation = post_process ($citation);

  $epigraph =~ s/\s+/ /g;
  $epigraph = "<p>$epigraph</p>";

  print wrap ("", "", $epigraph);
  print "\n\n";

  $citation =~ s/&nbsp;&#8212;/&qdash;/g;

  print "<p rend=\"text-align(right)\">$citation</p>\n\n";

  print "</epigraph>\n\n\n";
  return '';
}

sub output_chapter {
  my $chapter = shift;

  my $part_number = "";
  $chapter .= "\n" x 10;

  if ($chapter =~ m/^(BOOK|PART|VOLUME) (ONE|1|I|.*?first)(?=[^\dIVX])(.*?)/i) {
    print "\n\n<div type=\"" . lower_case($1) . "\" n=\"1\">\n\n";
    $is_book = 1;
    $is_book_div = 1;
  } elsif ($chapter =~ m/^(BOOK|PART|VOLUME) +(THE )?(.*?)([\. -]+(.*?)\n|\n)/i) {
    print "</div>\n\n";
    print "</div>\n\n\n";
    #   Grab the Part/Book number
    $part_number = encode_numbers($3);
    if (!$part_number) { $part_number = "xx"; }
      
    print "<div type=\"" . lower_case($1) . "\" n=\"" . $part_number . "\">\n\n";
    $is_book = 1;
    $is_book_div = 1;
  } else {
    if ($is_book_div != 1) {
      print "</div>\n\n\n";
    } else {
      $is_book_div = 0;
    }
    print "<div type=\"chapter\">\n\n";
  }

  $chapter =~ s|$head1|output_head ($1)|es;

# while ($chapter =~ s|$epigraph1|output_epigraph ($1, $2)|es) {};
  while ($chapter =~ s|$paragraph1|output_para ($1)|es) {};

  return '';
}

sub output_body {
  my $body = shift;
  $body =~ s/^\s*//;

  guess_quoting_convention (\$body); # save mem, pass a ref
  ($avg_line_length, $max_line_length) = compute_line_length (\$body);

  print ("AVG Line Length: $avg_line_length\n");
  print ("MAX Line Length: $max_line_length\n");

  $body .= "\n{$cnt_chapter_sep}\n";

  while ($body =~ s|$chapter1|output_chapter ($1)|es) {}; # egs doesn't work in 5.6.1

  return '';
}

sub output_header () {
  # scan the gutenberg header for useful info
  # the problem here is that there are a gazillion different
  # <soCalled>standard headers</soCalled>
  my $h = shift;

  # Grab the front matter from this header for printing.
  if ($h =~ m/^(.*?)\*\*\* ?START OF TH(E|IS) PROJECT.*?\n(.*?)$/gis) {
    $front_matter_block = $3;
  } elsif ($h =~ m/^(.*?)\*END[\* ]+THE SMALL PRINT.*?\n(.*?)$/gis) {
    $front_matter_block = $2;
  }

  for ($h) {

    # Try to grab the sub title too!
    if (/Title: *(.*?)\n  +(.*?)\n/) {
      $title = $1; $sub_title = $2;
    } elsif (/Title: *(.*?)\n/) {
      $title = $1; $sub_title = "";
    }
    
    if (/\nAuthors?: *(.*?)\n/)               { $author_string = $1; }
    if (/\nEditors?: *(.*?)\n/)               { $editor = $1; }
    if (/\nIllustrat(or|ions): *(.*?)\n/)     { $illustrated_by = change_case($2); }
    if (/\nEdition: *(.*?)\n/)                { $edition = $1; }
    if (/\nCharacter set encoding: *(.*?)\n/) { $charset = $1; }
    if (/\nLanguage: *(.*?)\n/)               {
      if ($1 ne "English" && $language ne "British") {
        $language = $1;
      }
    }
    if ($language eq "***")      { $language = "English"; }
    $language_code = encode_lang ($language);

    ############################################################################
    # Find the Posting/Release/Updated Dates
    # Release Date is usually old than the Posting Date (But not always)
    # Posting Date usually contains the EBook #

    # OFFICIAL RELEASE DATE - Usually NO EBook #.
    if (/\n((Official|Original) )?Release Date: *(.*?)\n/i) { $releasedate = $3; }
    # POSTING DATE - This usually includes the EBook #.
    if (/\nPosting Date: *(.*?)\n/)       { $posteddate  = $1; }
      # If no Posting Date try this.
    if (!$posteddate ) {
      if (/\[(The actual date )?This file (was )?first posted (on|=) (.*?)\]\n/i) {
        $posteddate  = $4;
      }
    }
    # LAST UPDATED
    if (/\nLast Updated?: *(.*?)\n/i)       { $lastupdated = $1; }
      # If no Last Update try this.
    if (!$lastupdated) {
      if (/\[(Date|This file was|Most) (last|recently) updated( on|:)? (.*?)\]/i) {
        $lastupdated = $4;
      }
    }

    # Grab the PG ETEXT NUMBER
    my $etext_regex = "";
      # Get eBook Number from Posting/Release Date
    if ($posteddate =~ /^(.*?)( +\[e(book|text) +\#(\d+)\])$/i) {
      $posteddate = $1;
      $gutenberg_num = $4;
    }
      # Sometimes the eBook number is on Release Date
    if (!$gutenberg_num) {
      if ($releasedate =~ /^(.*?)( +\[e(book|text) +\#(\d+)\])$/i) {
        $releasedate = $1;
        $gutenberg_num = $4;
      } 
    }
    # PROCESS and get the ISO DATES
    $releasedate_iso = process_dates ($releasedate) if ($releasedate);
    $posteddate_iso  = process_dates ($posteddate)  if ($posteddate);
    $lastupdated_iso = process_dates ($lastupdated) if ($lastupdated);

    # SAFE Option for Dates is to create an array and sort them.
    # This is because PG often mixes up Posted/Released dates, etc.
    # This will then give the proper date sequence.
    my @book_dates   = ();
    my @dates_sorted = ();
    if ($releasedate) { push(@book_dates, [$releasedate_iso, $releasedate]); }
    if ($posteddate)  { push(@book_dates, [$posteddate_iso,  $posteddate]);  }
    if ($lastupdated) { push(@book_dates, [$lastupdated_iso, $lastupdated]); }
    # Sort into Date ASC order
    @dates_sorted = sort {$a->[0] <=> $b->[0]} @book_dates;
    # Set RELEASE DATE
    $releasedate     = $dates_sorted[0]->[1];
    $releasedate_iso = $dates_sorted[0]->[0];
    # Set FIRST UPDATED
    # If there is a 3rd date there is a FIRST RELEASED DATE
    if ($dates_sorted[2]->[0]) {
      $firstupdated     = $dates_sorted[1]->[1];
      $firstupdated_iso = $dates_sorted[1]->[0];
    } else {                                # Otherewise, there is not middle date.
      $firstupdated     = '';
      $firstupdated_iso = '';
    }
    # Set LAST UPDATED
    if ($dates_sorted[2]->[0]) {            # Are there 3 dates?
      $revision_lastupdated = 1;
      $lastupdated     = $dates_sorted[2]->[1];
      $lastupdated_iso = $dates_sorted[2]->[0];
    } elsif ($dates_sorted[1]->[0]) {       # Not 3 dates? How about 2?
      $revision_lastupdated = 1;
      $lastupdated     = $dates_sorted[1]->[1];
      $lastupdated_iso = $dates_sorted[1]->[0];
    } else {                                # Set to SAME AS RELEASE DATE (Needed for <edition> date info.)
      $lastupdated     = $dates_sorted[0]->[1];
      $lastupdated_iso = $dates_sorted[0]->[0];
    }


    # If not set try to grab title, author, etc.
    # I HAVE REMOVED the \n from the start of these two string -- Keep an eye on this.
    if (/\** *The Project Gutenberg Etext of (.*?),? by (.*?)\** *\n/) {
      if (!$title)  { $title = $1;  }
      if (!$author_string) { $author_string = change_case($2); }
    } elsif (/\** *The Project Gutenberg Etext of (.*?)\** *\n/) {
      if (!$title)  { $title = $1;  }
    }

    # Author still not aquired...this is a bit random but can often work
    if (!$author_string && $title) {
      if (/\n$title\n+by (.*?)\n/i) { $author_string = change_case($1); }
    } elsif (!$author_string) {
      if ($front_matter_block =~ m/\n *by (.*?)\n/i) { $author_string = change_case($1); }
    }
    # Sometimes Author get assigned wierd info...fix it
    if ($author_string =~ m/Project Gutenberg/i) { $author_string = "Anonymous"; }

    if (/This etext was produced by (.*?)[\.,]?\n/) {
      $produced_by = $1;
    }

    # Translated from ...
    if (/[\n ]*(Translated (from.*)?by)[\s\t\r\n]+(.+)/i) {
      $translated = $1;
      $translated_by = $3;
    } elsif ($front_matter_block =~ s/[\n ]*(Translated (from.*)?by) (.+)//i) {
      $translated = $1;
      $translated_by = $3;
    }
  }

  my $languages = list_languages ($language_code);

  my @editors = ();
  if ($editor) {
    @editors = process_names ($editor);
  }


  my @authors = process_names ($author_string);
  $author_string =~ s/&/&amp;/; # Now we have used the string let's fix  the &'s

  if (!$filename) {
    $filename = "$ARGV";
    if ($filename =~ s/(\w{4,5})((10|11)\w?)(\..*)$//) {
      $filename = $1;
      if (!$edition) {$edition  = $2; }
    }
  }

### If $edition still equals nothing then assign default: 1
  if (!$edition) {
    $edition = '1';
    # Increase to next version if file has been updated
    if ($releasedate_iso ne $lastupdated_iso) { $edition = '2'; }
  }

### If $edition equals PG 10 or 11 change to 1 and 2 respectively.
  my $pg_edition = $edition; # Keep the original PG edition number if it exists.
  if ( $edition == 10 ) { $edition = '1'; }
  if ( $edition == 11 ) { $edition = '2'; }
  if ( $edition == 12 ) { $edition = '3'; }


################################################################################
###                       Now process FRONT MATTER                           ###
################################################################################

  for ($front_matter_block) {

    # Who first produced this text for Project Gutenberg?
    if (s/[\n ]+(This [e-]*Text (was )?(first ))?(Produced|Prepared|Created) by +(.*?)\n(.*?)\n//i) {
      $prod_first_by = $5;
      if ($6) {
        $prod_first_by = $prod_first_by . " " . $6;
      }
    }

    # Who first produced the UPDATED version?
    if (s/[\n ]+(This )?updated ([e-]*Text|edition) (was )?(Produced|Prepared|Created) by +(.*?)\n(.*?)\n//i) {
      $produced_update_by = $5;
      if ($6) {
        $produced_update_by = $produced_update_by . " " . $6;
      }
    }

    # Who Scanned/Proofed the original text?
    if (/[\n ]+([e-]*text Scanned|Scanned and proof(ed| ?read)|Transcribed from the.*?) by:? +(.*?)\n/i) {
      $produced_by = $3;
    } elsif (/proof(ed| ?read) by:? +(.*?)\n/i) {
      $produced_by = $2;
    }
    $produced_by =~ s/^(.*?)[, ]$/$1/;  # Clean up any end spaces or commas

    if ($produced_by eq "unknown") {
      $produced_by = $prod_first_by;
    } elsif ($prod_first_by eq "unknown") {
      $prod_first_by = $produced_by;
    }

    if ($prod_first_by eq "unknown") {
      $prod_first_by = "Project Gutenberg";
    }
    $prod_first_by =~ s/\.$//;


    # Get the published date
    if (m/\n *([0-9]{4})\n/i) {
      $publishdate = $1;
    } elsif (m/[\[\(]([0-9]{4})[\]\)]/i) {
      $publishdate = $1;
    } elsif (m/\n[\s_]*Copyright(ed)?[,\s]*([0-9]{4})/i) {
      $publishdate = $2;
    }
    # Get the published place
    if (m/^ *((New York|London|Cambridge|Boston).*?)_?\n/i) {
      $publishedplace = change_case($1);
    }
    # Get the publisher
    if (m/[\n_ ]*(.*?)(Publish|Company|Co\.)(.*?){,20}_?\n/i) {
      $publisher = change_case($1 . $2 . $3);
      $publisher =~ s|&|&amp;|; # Convert ampersand
    }

    # REDACTOR'S NOTES
    if (s/ *\[Redactor\'?s? Note[s:\n ]*(.*?)\]//is) {
      $redactors_notes = $1;
    } elsif (s/Redactor\'s Note[s:\n ]*(.*?)\n\n\n//is) {
      $redactors_notes = $1;
    }

    if ($redactors_notes) {
      $redactors_notes = "\n" . $redactors_notes;
    }
    $redactors_notes =~ s/\n/\n        /gis;      # Indent the text
    $redactors_notes =~ s/\n\s+\n/\n\n/gis;  # Clear empty lines

    # TRANSCRIBERS NOTES -- If not then check Footer_Block AND Body_Block
    if (s/ *\[Transcriber\'?s? Note[s:\n ]+(.*?)\]//is) {
      $transcriber_notes = $1;
    } elsif (s/Transcriber\'?s? Note[s:\n ]+(.*?)\n\n\n//is) {
      $transcriber_notes = $1;
    }

    # Note: Few but there are some, possibly Errata stuff so add to $transcribers_errata
    if (s/^ *\[Notes?: (.*?)\]//is) {
      $transcriber_notes .= $1;
    } elsif (s/^Notes?: (.*?)\n\n\n//is) {
      $transcriber_notes = $1;
    }

    if ($transcriber_notes) {
      $transcriber_notes = "\n" . $transcriber_notes;
    }
    $transcriber_notes =~ s/\n/\n        /gis;      # Indent the text
    $transcriber_notes =~ s/\n\s+\n/\n\n/gis;  # Clear empty lines


    # ILLUSTRATED BY ...
    if (/\n_?((With )?(full )?(colou?r )?(Illustrat(ions?|ed|er|or))( in colou?r)?( by|:)?)[ \n]?(.*?)[\._]*$/i) {
      if ($1) {
        $illustrated_text = change_case($1);
      }
      if (!$illustrated_by) {
        $illustrated_by = change_case($9);
        $illustrated_by =~ s/_$//;
      }
    }

    if ($illustrated_by) { 
      @illutrators = process_names ($illustrated_by);
      $illustrated_by =~ s/&/&amp;/; # Now we have used the string let's fix  the &'s
    } else {
      $illustrated_text = "";
    }

  } # END OF $front_matter_block() PROCESSING

  $front_matter_block .= "\n\n"; # Some padding

  # Create a UUID
  my $uuid =  uuid_gen();

  print <<HERE;
<?xml version="1.0" encoding="iso-8859-1" ?>

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
foreach my $author_name (@authors) {
  if ($author_name->[2]) {
    print <<HERE;
      <author><name reg="$author_name->[2], $author_name->[0]">$author_name->[1] $author_name->[2]</name></author>
HERE
  } else {
    print <<HERE;
      <author><name reg="$author_name->[0]">$author_name->[0]</name></author>
HERE
  }
}
foreach my $illustrator_name (@illutrators) {
  if ($illustrator_name->[2]) {
    print <<HERE;
      <editor role="illustrator"><name reg="$illustrator_name->[2], $illustrator_name->[0]">$illustrator_name->[1] $illustrator_name->[2]</name></editor>
HERE
  } else {
    print <<HERE;
      <editor role="illustrator"><name reg="$illustrator_name->[0]">$illustrator_name->[0]</name></editor>
HERE
  }
}
if ($translated_by) {
print <<HERE;
      <editor role="translator">$translated_by</editor>
HERE
}
if (@editors) {
  foreach my $editor_name (@editors) {
    if ($editor_name->[2]) {
      print <<HERE;
      <editor role="editor"><name reg="$editor_name->[2], $editor_name->[0]">$editor_name->[1] $editor_name->[2]</name></editor>
HERE
    } else {

      print <<HERE;
      <editor role="editor"><name reg="$editor_name->[0]">$editor_name->[0]</name></editor>
HERE
    }
  }
}
print <<HERE;
    </titleStmt>
    <editionStmt>
      <edition n="$edition">Edition $edition, <date value="$lastupdated_iso">$lastupdated</date></edition>
      <respStmt>
        <resp>Original e-Text edition prepared by</resp>
        <name>$prod_first_by</name>
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
      <date value="$releasedate_iso">$releasedate</date>
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
      <title level="s">****</title>
      <idno type="vol">**</idno>
    </seriesStmt>
    <notesStmt>
      <note resp="redactor">$redactors_notes</note>
      <note type="transcriber">$transcriber_notes</note>
    </notesStmt>
    <sourceDesc>
      <biblStruct>
        <monogr>
HERE
foreach my $illustrator_name (@illutrators) {
  if ($illustrator_name->[2]) {
    print <<HERE;
          <editor role="illustrator"><name reg="$illustrator_name->[2], $illustrator_name->[0]">$illustrator_name->[1] $illustrator_name->[2]</name></editor>
HERE
  } else {
    print <<HERE;
          <editor role="illustrator"><name reg="$illustrator_name->[0]">$illustrator_name->[0]</name></editor>
HERE
  }
}
if ($translated_by) {
  print <<HERE;
          <editor role="translator">$translated_by</editor>
HERE
}
if (@editors) {
  foreach my $editor_name (@editors) {
    if ($editor_name->[2]) {
      print <<HERE;
          <editor role="editor">$editor_name->[2], $editor_name->[0]</editor>
HERE
    } else {
      print <<HERE;
          <editor role="editor">$editor_name->[2], $editor_name->[0]</editor>
HERE
    }
  }
}
foreach my $author_name (@authors) {
  if ($author_name->[2]) {
    print <<HERE;
          <author>$author_name->[2], $author_name->[0]</author>
HERE
  } else {

    print <<HERE;
          <author>$author_name->[0]</author>
HERE
  }
}
print <<HERE;
          <title>$title</title>
HERE
if ($sub_title) {
  print <<HERE;
          <title type="sub">$sub_title</title>
HERE
}
print <<HERE;
          <imprint>
            <pubPlace>$publishedplace</pubPlace>
            <publisher>$publisher</publisher>
            <date>$publishdate</date>
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
        <p>All double quotation marks rendered with q tags.</p>
      </quotation>
      <hyphenation eol="none">
        <p>Hyphenated words that appear at the end of the line have been reformed.</p>
      </hyphenation>
      <stdVals>
        <p>Standard date values are given in ISO form: yyyy-mm-dd.</p>
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
      <date value="$dcurdate">$current_date</date>
    </creation>
      <langUsage>
        <language id="$language_code">$language</language>
      </langUsage>
    <textClass>
      <keywords scheme="lc">
        <list>
          <item><!-- keywords for search --></item>
        </list>
      </keywords>
      <classCode scheme="lc"><!-- LoC Class (PR, PQ, ...) --></classCode>
    </textClass>
  </profileDesc>
  <revisionDesc>
    <change when="$dcurdate" who="Cook, Michael">
      Conversion of TXT document to TEI P5 by <name>Michael Cook</name>.
    </change>
HERE
  if ($revision_lastupdated) {
    print <<HERE;
    <change when="$lastupdated_iso" who="$produced_update_by">
      Project Gutenberg Edition $pg_edition.
    </change>
HERE
  }
  if ($firstupdated) {
    print <<HERE;
    <change when="$firstupdated_iso" who="unknown">
      Project Gutenberg Update Release.
    </change>
HERE
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
if ($illustrated_by) {
  print <<HERE;
    <byline>
      $illustrated_text <name>$illustrated_by</name>
    </byline>
HERE
}
if ($translated_by) {
  print <<HERE;
    <byline>
      $translated <name>$translated_by</name>
    </byline>
HERE
}
print <<HERE;
    <docEdition></docEdition>
    <docImprint>
      <pubPlace>$publishedplace</pubPlace>
      <publisher>$publisher</publisher>
      <docDate>$publishdate</docDate>
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
  print <<HERE;
</div>

HERE

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


################################################################################
# various cosmetic tweaks before output
################################################################################

sub process_footnotes {
  my $c = shift;

  # Some pre-processing for the Footnotes.
  $c =~ s|[{<\[]l[}>\]]|[1]|g;            # fix stupid [l] mistake. Number 1 not letter l.

  ## Check for * footnotes and fix up
  $c =~ s|^( *)\[?\*\*\* |[Footnote 2: |g;       # If a footnote uses [* ...] then replace (footnote 3)
  $c =~ s|^( *)\[?\*\* |[Footnote 2: |g;         # If a footnote uses [* ...] then replace (footnote 2)
  $c =~ s|^( *)\[?\* |[Footnote 1: |g;           # If a footnote uses [* ...] then replace (footnote 1)

  
  $c =~ s|(\*+)|[$1]|g;                   # Change * footnotes to [*]
  $c =~ s|\[\[(\*+)\]\]|[$1]|g;           # Fix some double brackets [[*]]

  ## Some footnotes are marked up with <>, {} or () so change to []
  my $note_exists = 0;
  if ( $c =~ m/\[(\d+|\*+|\w)\]/ ) { $note_exists = 1; }

  ## If footnotes are detected with the above, then we don't need to process these do we.
  if ($note_exists == 0) {
    if ( $c =~ s|<(\d+)>|[$1]|g ) {
      $note_exists = 1;
    } elsif ( $c =~ s|{(\d+)}|[$1]|g ) {
      $note_exists = 1;
    }
    # Change (1) only if other brackets NOT detected -- extra bit of safety in case (1) is used for another reason.
    if ($note_exists == 0) {
      $c =~ s|\((\d+)\)|[$1]|g;
    }
  }

  # FOOTNOTES: Semi-auto process on footnotes.    
  if ($c =~ s/[^ \n\t]{2,}\[(\d+|\*+|\w)\]/<note place="foot">\n\n[PLACE FOOTNOTE HERE]\n\n<\/note>/g) {
    $footnote_exists = 1;
  }

  return $c;
}

sub post_process {
  my $c = shift;

# Some UNICODE files have angled quotes; “quotes”. Replace with <q> tags
  $c =~ s|“|<q>|g;
  $c =~ s|”|</q>|g;

# substitute &
  $c =~ s|&|&amp;|g;

#  $c =~ s|<|&lt;|g;
#  $c =~ s|>|&gt;|g;


  # Try to remove any silly BOX formating. +----+, | (...text...) |  stuff!
  $c =~ s|\+-+\+|\n|g;
  $c =~ s/ *\|(.+)\| *\n/$1\n/g;

  # substitute ___ 10+ to <pb/>
  $c =~ s|_{10,}|<pb/>|g;
  # substitute ------ 15+ for <pb>
  $c =~ s|-{15,}|<pb/>|g;

  # substitute ----, --, -
  $c =~ s|----|&qdash;|g;
  $c =~ s|--|&#8212;|g;
  $c =~ s|—|&#8212;|g;

#substitute hellip for ...
  $c =~ s| *\.{3,}|&hellip;|g;
  $c =~ s| *(\. ){3,}|&hellip;|g;

#substitute °, @ OR #o (lowercase O) for &deg;
  $c =~ s|(°\|@)|&deg;|g;
  $c =~ s|(\d{1,3})o|$1&deg;|g;


################################################################################
# text highlighting
################################################################################

# Add <emph> tags; changing _ and <i> to <emph>

  $c =~ s|<i>|<emph>|g;
  $c =~ s|</i>|</emph>|g;

    $c =~ s|_(.*?)_|<emph>$1</emph>|gis;

  # The old way, maybe some of these are still needed?
#  $c =~ s|Illustration: _|Illustration: <emph>|g; # fix Illustrations
#  $c =~ s/_([\"\'\w]|<[fp])/<emph>$1/g;
#  $c =~ s|^_|<emph>|g;
#  $c =~ s|_|</emph>|g;
#  $c =~ s|<emph>(\w+)<emph>\'s|<emph>$1</emph>\'s|g;


################################################################################
# reserved characters
#
# these characters will give TeX trouble if left in

  $c =~ s|\\|&#92;|g;
  $c =~ s|\{|&#123;|g;
  $c =~ s|\}|&#125;|g;


################################################################################
# typografical entities
#

# substitute endash
#  $c =~ s|([0-9])-([0-9])|$1&ndash;$2|g;

  # HIPHENATED WORDS
#  $c =~ s|([a-zA-Z])-([a-zA-Z])|$1&ndash;$2|g;
  # ...for some reason, on single characters d-d-d the second - doesn't
  # get caught so need to run this again...HOW TO FIX???
#  $c =~ s|([a-zA-Z])-([a-zA-Z])|$1&ndash;$2|g;

#### Ignore hyphenated words and just replace all hyphens (-) ####
  $c =~ s|-|&#8211;|g;

# move dashes
  $c =~ s|&#8212; </q>([^ ])|&#8212;</q> $1|g;
  $c =~ s|&#8212; </q>|&#8212;</q>|g;
  $c =~ s|([^ ])<q> &#8212;|$1 <q>&#8212;|g;
  $c =~ s| &#8212;|&#8212;|g;
  $c =~ s| &qdash;|&qdash;|g;

  # SUPERSCRIPT
  $c =~ s|(\^)([^ ]+)|<sup>$2</sup>|g;
  # SUBSCRIPT (Only works for H_2O formula.)
  $c =~ s|(\w)_([0-9])|$1<sub>$2</sub>|g;
  $c =~ s|H2O|H<sub>2</sub>O|g; # In case no underscore has been added.


# insert a non-breaking space after Mr. Ms. Mrs.
  $c =~ s|(Mr?s?\.?)[ \n]+([[:upper:]])|$1&nbsp;$2|g;
# insert a non-breaking space after Mme.
  $c =~ s|(Mme\.?)[ \n]+([[:upper:]])|$1&nbsp;$2|g;
# insert a non-breaking space after Dr.
  $c =~ s|(Dr\.?)[ \n]+([[:upper:]])|$1&nbsp;$2|g;
# insert a non-breaking space after St.
  $c =~ s|(St\.?)[ \n]+([[:upper:]])|$1&nbsp;$2|g;
# insert a non-breaking space after No.
  $c =~ s|(No\.?)[ \n]+([[:digit:]])|$1&nbsp;$2|g;
# insert a non-breaking space after Rev.
  $c =~ s|(Rev\.?)[ \n]+([[:upper:]])|$1&nbsp;$2|g;
# insert a non-breaking space after Capt.
  $c =~ s|(Capt\.?)[ \n]+([[:upper:]])|$1&nbsp;$2|g;
# insert a non-breaking space after Gen.
  $c =~ s|(Gen\.?)[ \n]+([[:upper:]])|$1&nbsp;$2|g;

  $c =~ s|(Ew\.)[ \n]+([[:upper:]])|$1&nbsp;$2|g;

################################################################################
# various cosmetics
#
# strip multiple spaces
  $c =~ s|[ \t]+| |g;

# strip spaces before new line
  $c =~ s| \n|\n|g;


### Don't worry about Marcellos stuff here
#    $c =~ s|<qpre>|<q rend=\"post: none\">|g;
#    $c =~ s|<qpost>|<q rend=\"pre: none\">|g;
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
#    $tmp =~ s|[\r\n]+| |g;
    $tmp =~ s|\n+| |g;
    $c =~ s|(.*?)<figDesc>(.*?)</figDesc>(.*?)|$1<figDesc>$tmp</figDesc>$3|s;
  }
  $c =~ s|(.*?)<figDesc></figDesc>(.*?)|$1<figDesc>Illustration</figDesc>$2|; # Replace empty <figDesc>'s with an Illustration description

  $c =~ s|<head> ?(.*?) ?</head>|<head>$1</head>|g; # Strip the leading white space - Find a better way!!
  $c =~ s|<head>\"|<head><q>|g;     # apply more quotes
  $c =~ s|\"</head>|</q></head>|g;  # apply more quotes

  # substitute <milestone> to include the unit="tb" attribute.
  $c =~ s|<milestone>|<milestone unit="tb" \/>|g;

  # Change 'Named Entity' characters to 'Numbered Entity' codes.
  # For use with TEI DTD and XSLT.
  $c =~ s|&nbsp;|&#160;|g;
  $c =~ s|&ndash;|&#8211;|g;
  $c =~ s|&#8212;|&#8212;|g;
  $c =~ s|&qdash;|&#8213;|g;
  $c =~ s|&hellip;|&#8230;|g;
  $c =~ s|&deg;|&#176;|g;

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

  # January 1, 2000
  if ($wdate =~ m/^(\w+)\s+(\d{1,2}),?\s+(\d{2,4})$/) {
    ($year, $month, $day) = ($3, $1, $2);
  }

  # 9/19/01
  if ($wdate =~ m/^(\d{1,2})[\/-](\d{1,2})[\/-](\d{2,4})$/) {
    ($year, $month, $day) = ($3, $1, $2);
    $tmp_month = $month;
  }

  # January, 2000 or January 2000
  if ($wdate =~ m/^(\w+),?\s+(\d{2,4})$/) {
    ($year, $month, $day) = ($2, $1, 0);
  }

  # English format: 21st January, 2002
  if ($wdate =~ m/^(\d{1,2})(st|nd|rd|th)\s+(\w+),?\s+(\d{2,4})$/) {
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

  $names_string =~ s/\(.*\)|\[.*\]//;     # Change () brackets to [] brackets
  $names_string =~ s/ & / and /;          # Replace '&' to 'and' for the split
  $names_string =~ s/^ *(.*?) *$/$1/;     # Strip any end spaces

  my @names_list = split(/ and /, $names_string);

  my $count = 0;
  foreach my $name (@names_list) {
    if ($name =~ m/^(.*?) +([\w-]+)$/i) {
      my $orig_firstname = $1; # Keep the original first name for <front> data
      my $firstname = $1;
      my $lastname = $2;
      ## Some authors use initials, so assign proper name also
      if ($lastname eq 'Fitzgerald' and $firstname =~ /F. ?Scott/)   { $firstname = 'Francis Scott'; }
      if ($lastname eq 'Montgomery' and $firstname =~ /L. ?M./)      { $firstname = 'Lucy Maud'; }
      if ($lastname eq 'Nesbit'     and $firstname =~ /E./)          { $firstname = 'Edith'; }
      if ($lastname eq 'Smith'      and $firstname =~ /E. ?E./)      { $firstname = 'Edward Elmer'; }
      if ($lastname eq 'Smith'      and $firstname =~ /["']Doc["']/) { $firstname = 'Edward Elmer'; }
      if ($lastname eq 'Wells'      and $firstname =~ /H. ?G./)      { $firstname = 'Herbert George'; }
      if ($lastname eq 'Wodehouse'  and $firstname =~ /P. ?G./)      { $firstname = 'Pelham Grenville'; }
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
  my $langlist = "";
  foreach my $key (sort (keys %languages)) {
	  $langlist .= "      <language id=\"$key\">$languages{$key}</language>\n";
  }
  return $langlist;
}

sub guess_quoting_convention {
  # study the text and decide which quoting convention is used
  my $openquote1  = "";
  my $closequote1 = "";
  my $openquote2  = "";
  my $closequote2 = "";

  if ( length($override_quotes) ) {
  	$openquote1  = substr ($override_quotes, 0, 1);
  	$openquote2  = substr ($override_quotes, 1, 1);
  	$closequote2 = substr ($override_quotes, 2, 1);
  	$closequote1 = substr ($override_quotes, 3, 1);
  } else {
  	my $body = shift;
  	$body = $$body;

#	my $count_84 = ($body =~ tr/\x84/\x84/); # win-1252 („) opening double quote
	my $count_22 = ($body =~ tr/\x22/\x22/); # " ascii double quote
#	my $count_27 = ($body =~ tr/\x27/\x27/); # ' ascii single quote
	my $count_60 = ($body =~ tr/\x60/\x60/); # ` ascii single opening quote (grave accent)
	my $count_b4 = ($body =~ tr/\xb4/\xb4/); # ´ ascii single closing quote (acute accent)
	my $count_ab = ($body =~ tr/\xab/\xab/); # « left guillemet
	my $count_bb = ($body =~ tr/\xbb/\xbb/); # » right guillemet

#	my $single_quotes = $count_27 + $count_60 + $count_b4;
	my $single_quotes = $count_60 + $count_b4;
#	my $double_quotes = $count_22 + $count_84;
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
#	    $openquote1 = $count_84 ? "\x84" : "\x22";
	    $openquote1  = "\x22";
	    $closequote1 = "\x22";
#	    $openquote2  = $count_60 ? "\x60" : "\x27";
	    $openquote2  = "\x60";
#	    $closequote2 = "\x27";
	    $closequote2 = "\xb4";
#	} else { # british quotes
#	    $openquote1  = $count_60 ? "\x60" : "\x27";
#	    $closequote1 = "\x27";
#	    $openquote2  = $count_84 ? "\x84" : "\x22";
#	    $closequote2 = "\x22";
	}
	print ("\nguessed quotes: $openquote1 $closequote1 and $openquote2 $closequote2\n");
    }
    # how to catch quoted material
    # on nesting level1 and level2
    # pre is for paragraphs without closing quote
    # \B matches non-(word boundary), ^ and $ are considered non-words

# Marcello only checked quote when followed by limited characters :alpha: _ $ etc.
#    $quotes1    = qr/\B$openquote1(?=[[:alpha:]_\$$openquote2])(.*?)$closequote1\B/s;
#    $quotes1pre = qr/\B$openquote1(?=[[:alpha:]_\$$openquote2])(.*?)$/s;
#    $quotes2    = qr/\B$openquote2(?=[[:alpha:]])(.*?)$closequote2\B/s;
    $quotes1    = qr/\B$openquote1(.*?)$closequote1\B/s;
    $quotes1pre = qr/\B$openquote1(.*?)$/s;
    $quotes2    = qr/\B$openquote2(.*?)$closequote2\B/s;
}

sub study_paragraph {
  # learn interesting stuff about this paragraph

  my @lines = split (/\n/, shift);
  my $o = { };
  
  my $cnt_lines  = scalar (@lines);
  my $min_len    = 10000;
  my $max_len    = 0;
  my $sum_len    = 0;
  my $min_indent = 10000;
  my $max_indent = 0;
  my $cnt_indent = 0;
  my $sum_indent = 0;
  my $cnt_caps   = 0;
  my $cnt_short  = 0;
  my $cnt_center = 0;


  # Compute % of max line length (currently: 84%)
  my $threshhold = int ($max_line_length * 84 / 100);

  for (@lines) {
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
    $cnt_caps++ if (m/^([^a-zA-Z])*[[:upper:]]/);

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

  ## Here we check for number of indented lines instead of min_indent
  if ($o->{'cnt_indent'} < 2 && $o->{'min_indent'} == 0) {
    if ($o->{'cnt_long'} > 0) {
      return 0;
    }
  }

  # do all lines begin with capital letters ?
  if ($o->{'cnt_lines'} > 1) {                # Only check if more than one line
    return 0 if $o->{'cnt_caps'} < $o->{'cnt_lines'};
  }

  # are all lines shorter than average ?
  return 0 if $o->{'cnt_long'} > 0;

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

  $case =~ s/(.*?)/\l$1/g;
  $case =~ s/(\b)([a-z])/$1\u$2/g;
  $case =~ s/and/and/gi; # Replace 'And' with 'and'
  $case =~ s/<(\/?)(.*?)>/<$1\l$2>/g;
  $case =~ s/([NMQ])dash/$1dash/g; # Fix &ndash; caps
  $case =~ s/(.*?)\'S/$1's/g; # change 'S to 's

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
#  my $uuid = $ug->create_from_name_str(NameSpace_URL, "www.epubbooks.com");

  return $uuid;
}

sub usage {
  print <<HERE;

PGText to TEI converter

usage: gut2tei.pl [options] pgtextfile > teifile

--quotes="[()]"    quoting convention used (default: automatic detection)
                   [] = outer quotes, () = inner quotes
		   eg. --quotes="\\\"''\\\""
--chapter=n        empty lines before chapter        (default: $cnt_chapter_sep)
--head=n           empty lines after chapter heading (default: $cnt_head_sep)
--paragraph=n      empty lines before paragraph      (default: $cnt_paragraph_sep)
--drama            text is drama   (default: prose)
--verse            text is verse   (default: prose)
--locale           use this locale (default: $locale)
--help             display this screen

HERE

}

# Local Variables:
# mode:perl
# coding:iso-8859-1-unix
# End:
