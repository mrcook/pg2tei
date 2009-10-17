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

## Default BOOK Drive/Path ##
$booksdrive = 'K:';                                     ## Default Books Drive
$booksfolder = DS . 'BOOK-Files' . DS . '04-TEI' . DS;  ## Default Books Path

## Get current drive
my $cur_dir = File::Spec->curdir();
   $cur_dir = File::Spec->rel2abs unless ( File::Spec->file_name_is_absolute($cur_dir) );
my $cur_drive = (File::Spec->splitpath($cur_dir))[0];

my $appspath = '_apps';


##############################################
## Search through folders for all TXT files ##
##############################################
find (\&eachTEI, $cur_drive . $booksfolder);

sub eachTEI {
  return unless $_=~ /\.txt/;    ## Skip non-TXT files
  $file = $_;
  $bookspath = $File::Find::name;
  $bookspath =~ s|/(.*?)/$file|/$1|;

  $filename = $file;
  $filename =~ s|(.*?)\.txt|$1|;
#  $tei_file = $booksfolder . $filename . DS . "tei" . DS . $filename . ".tei";
#  $txt_file = $booksfolder . $file;

  ## create default "/##/tei/" folder structure for each book *saves a few seconds manual work* :)
  mkdir($booksfolder . $filename . DS, 0777) || print "\nCan't create $filename folder: $!\n";
  mkdir($booksfolder . $filename . DS . "pg-orig", 0777) || print "\nCan't create PG_ORIG folder: $!\n";
  mkdir($booksfolder . $filename . DS . "tei", 0777) || print "\nCan't create TEI folder: $!\n";

 ## Make a copy of the old .txt file in the "pg-orig" folder as backup.
  copy($file, $booksfolder . $filename . DS . "pg-orig" . DS . $filename . ".txt") or die "copy failed: $!";

  system "perl -w " . $booksfolder . $file;

  
print $booksfolder . $file . "\n";
exit;

 # print FILEOUT $perl_bin . " -w " . $pg2tei_path . "pg2tei.pl " . $txt_filename . " > " . $tei_filename . "\n";

## Run the XSLT stylesheets to grab EXCERPT ##
#  system "java -jar $cur_drive/$appspath/$saxonpath/saxon9.jar -t -s:$fullpath/ -xsl:$cur_drive/$xsltpath/epb-book-csv.xsl -o:$booksdrive/";

## Grab Excerpt data from TEI file ##
#  open(EXCERPT, $booksdrive . '/excerpt.html') || die("Could not open file!");
#    $excerpt = <EXCERPT>;
#  close(EXCERPT);

#  $excerpt =~ s|<p></p>||;


## Grab fields from TEI file ##
  open(TEI, $file) || die("Could not open file!");
    @raw_data = <TEI>;
  close(TEI);


##################################################
## YOU MUST RUN THE TEI2EPUB CONVERTER FIRST!!! ##
##################################################

  $count_start = 0;
  $title = '';
  $subtitle = '';
  $author = '';
  $published = '';
  $bookset_title = '';
  $bookset_num = '';
  $bookset_slug = '';
  $language = '';
  $illustrations = '';
  $source = '';
  $wordcount = 0;
  $pgnum = '';
  $uuid = '';
  $file_version = '';
  $filename = '';
  $book_slug = '';


# Need to find and read in the .epub for the $filesize
  opendir(DIR, $bookspath);
    @files = readdir(DIR);
    for $dirfiles (@files) {
      next unless $dirfiles =~ /\.epub$/;
      if ($dirfiles =~ /\.epub$/) { $epubfile = $dirfiles; }
    }
  closedir(DIR);
  $filesize = -s $bookspath . DS . $epubfile;
  $filename = $epubfile;

  foreach $line (@raw_data) {
    chomp ($line);
    $line =~ s/^ +//;

    if ($line =~ s|<title>(.*?)</title>|$1|) {
      if($title eq '') {
        $title = $line;
        $book_slug = make_slug($line);
      }
    }
    if ($line =~ s|<title type="sub">(.*?)</title>|$1|) {
      if($subtitle eq '') {
        $subtitle = $line;
        $subtitle =~ s|</?q>|"|g;
      }
    }
    if ($line =~ s|<author><name reg="(.*?)">(.*?)</name></author>|$1|) {
      if($author eq '') {
        $author = $line;
      }
    }
    if ($line =~ s|<edition n="(.*?)">(.*?)</edition>|$1|) {
      if($file_version eq '') { $file_version = $line; }
    }
    if ($line =~ s|<title level="s">(.*?)</title>|$1|) {
      if($line ne '****' && $bookset_title eq '') {
        $bookset_title = $line;
        $bookset_slug = make_slug($line);
      }
    }
    if ($line =~ s|<idno type="vol">(.*?)</idno>|$1|) {
      if($line ne '**' && $bookset_num eq '') {
        $bookset_num = $line;
      }
    }
    if ($line =~ s|<idno type="gutenberg-no">(.*?)</idno>|$1|) {
      if($pgnum eq '') { $pgnum = $line; }
    }
    if ($line =~ s|<idno type="UUID">(.*?)</idno>|$1|) {
      if($uuid eq '') { $uuid = uc($line); }
    }
    if ($line =~ s|<date>(\d+)</date>|$1|) {
      if($published eq '') { $published = $line; }
    }
    if ($line =~ s|<language id="(.*?)">(.*?)</language>|$2|) {
      if($language eq '') {
        $language = $line;
        if ($language eq 'British') { $language = 'English'; }
      }
    }

    $source = 'Project Gutenberg';

    if ($epubfile =~ m|^(.*?)-illustrations\.epub$|) {
      if($illustrations eq '') { $illustrations = 'YES'; }
    }

    if ($count_start == 0) {
      if ($line =~ m|<body>|) { $count_start = 1; }
    } else {
      $line =~ s|(<(.*?)>\|&#(.*?);)| |g;
      $line =~ s|[^\w\d]| |g;
      $word = '';
      foreach $word (split(/ +/, $line)) {
        $wordcount++;
      }
    }
  }

## Search Movie DB (literature.list) for film & author ##
  $movie_title = '';
  $movie_author_lastname = '';
  $movie_author = '';
  $movie = '';

  open(MOVIES, $booksdrive . '/literature.list') || die("Could not open file!");
    @movie_data = <MOVIES>;
  close(MOVIES);

  MOVIE: foreach $line (@movie_data) {
    chomp ($line);
    $line =~ s/^ +//;

    if ($movie_title ne 'YES') {
      if ($line =~ s|MOVI:(.*?)($title)|$2|) {
        $movie_title = 'YES';
      }
    }
    if ($movie_title eq 'YES') {
      if ($line =~ m|^-{50,}$|) { # if we reach a break then reset and start again
        $movie_title = '';
      } else {
        $movie_author_lastname  = $author;
        $movie_author_lastname  =~ s|^(.*?), (.*?)$|$1|;
        if ($line =~ s|($movie_author_lastname)|$1|) {
          $movie_author = 'YES';
          print $line . "\n";
        }
      }
    }
  }
}

sub make_slug {
  my $tmp = shift;

  $tmp =~ s|^The ||gis;         # No slug should start with a 'The ' word
  $tmp =~ s|^ (.*?) $|$1|gis;   # Strip any end spaces
  $tmp =~ s| |-|gis;            # Replace spaces with hyphens '-'
  $tmp =~ s|[^\w\d-]||gis;      # removing these characters non-letters & numbers
  $tmp = lc($tmp);              # Make lowercase

  return $tmp;
} 
