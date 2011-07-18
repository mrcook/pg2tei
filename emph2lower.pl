#!/usr/bin/perl
#
# Any redistributions of files must retain the copyright notice below.
#
# @author     Michael Cook | epubBooks (http://www.epubbooks.com)
# @copyright  Copyright (c)2011 Michael Cook
# @package    Uppercase emphasis tagger
# @created    July 2011
# @version    $Id$
#

## DRIVE & PATH to .epub files.
$path = 'E:/conversions/';
$file = '968.tei';

my $convert = 1;

if ($convert == 1) {
  # OPEN the TEI for working with
  open(TEI, "<", $path . $file) || die("Could not open file!");
    @raw_data = <TEI>;
  close(TEI);

  $add_emph = 0;
  foreach $line (@raw_data) {
    if ($line =~ m|</titlePage>|) { $add_emph = 1; }
    if ($line =~ m|</body>|)      { $add_emph = 0; }
    if ($add_emph == 1) {
      # Tag UPPCASE words with <emph>
      $line =~ s|([A-Z][A-Z]+)|<emph>$1</emph>|gs;
      $line =~ s|(<head.*?>)<emph>|$1|gs;
      $line =~ s|</emph>(</head>)|$1|gs;
      if ($line =~ m|<signed>|) {
        $line =~ s|</?emph>||gs;
      }
      $line =~ s|</emph>&#8217;<emph>|&#8217;|gs;
      $line =~ s|</emph>&#8211;<emph>|&#8211;|gs;
      $line =~ s|<emph>([A-Z]+)</emph>&#8217;([A-Z][A-Z]?) |<emph>$1&#8217;$2</emph> |g;
      $line =~ s|</emph>&#8217;([A-Z]+) <emph>|&#8217;$1 |gs;
      $line =~ s!</emph>(&#8211;| )A( |&#8211;)<emph>!$1A$2!gs;
      $line =~ s|</emph> &amp; <emph>| &amp; |gs;
    }

    $data .= $line;
  }
  undef @raw_data;

  $data =~ s|</emph>([\s,.!;?]+)<emph>|$1|gs;

  # Lowercase contents
  $data =~ s|<emph>(.*?)</emph>|<emph>\L$1</emph>|gs;

  # Capitalise contents of <emph>...</emph> where needed
  $data =~ s|([.!?]\s?'?)<emph>(.*?)</emph>|$1<emph>\u$2</emph>|gs;
  $data =~ s|(<p>'?)<emph>(.*?)</emph>|$1<emph>\u$2</emph>|gs;
  $data =~ s|(<p>'?<q>)<emph>(.*?)</emph>|$1<emph>\u$2</emph>|gs;

  $data =~ s|<emph>(.*?)(mr\.?)&#160;(.*?)</emph>|<emph>$1\u$2&#160;\u$3</emph>|gs;
  $data =~ s!((Mr|Ms|Dr|Capt|Sgt|Gen|Rev|Mme|Mrs)\.?&#160;)<emph>(.*?)</emph>!$1<emph>\u$3</emph>!gs;


  ############################
  ## Write out new TEI file ##
  ############################
  open (OUT,  ">", $path . 'NEW-' . $file) or die "Could not open file\n";
    print OUT $data;
  close(OUT);
 }


# OPEN the TEI for working with
$file = "NEW-" . $file;
open(READTEI, "<", $path . $file) || die("Could not open file!");
  @raw_data = <READTEI>;
close(READTEI);

foreach $line (@raw_data) {
  if ($line =~ m|(..........)<emph>(.*?)</emph>(..........)|g) { print "$1     $2     $3\n";}
}