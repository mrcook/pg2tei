#!/usr/bin/perl
#
# Any redistributions of files must retain the copyright notice below.
#
# @author     Michael Cook | epubBooks (http://www.epubbooks.com)
# @copyright  Copyright (c)2007-2009 Michael Cook
# @package    img2tei - Collect images from HTML file and place in TEI
# @created    Jan 2010
# @version    $Id$
#

use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use File::Find;
use File::Spec;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

use constant DS => '/';   ## Default Directory Separator

##################################
## Get correct DRIVES and PATHS ##
##################################
$current_dir   = File::Spec->curdir();
$current_dir   = File::Spec->rel2abs($current_dir) unless ( File::Spec->file_name_is_absolute($current_dir) );
$current_drive = (File::Spec->splitpath($current_dir))[0];

## DRIVE & PATH to .epub files.
$books_drive   = 'H:';
$books_folder  = DS . 'conversions';

if (-d($current_drive . $books_folder)) {
  $books_drive = $current_drive; # for when executed on USB drive.
}

find (\&eachTEI, $books_drive . $books_folder);

sub eachTEI {
  ## Let's reset some variables
  ($bookspath, $filename, $filenoext, $bookspath, $fullpath, $line, $data, $tei_path_file) = '';

  if ($_ =~ m/\.htm/) { $html_file = $_; }

  return unless $_=~ m|\.tei|;    ## Skip non-TEI files

  return if $_=~ m|-new\.tei|;       ## Skip the XXX-new.tei file.

  $filename  = $_;
  $filenoext = $filename;
  $filenoext =~ s|(.*?)\.tei|$1|;
  $bookspath = $File::Find::name;
  $bookspath =~ s|/(.*?)/tei/$filename|/$1|;
  $fullpath  = $bookspath . DS . 'tei';
  $tei_path_file = $fullpath . DS . $filenoext . '-new.tei';

  ################################
  ## Read .HTM(L) to get images ##
  ################################
  $html_file = $bookspath . DS . $html_file;
  open(HTML, $html_file) || die('Could not open file!');
    @raw_data = <HTML>;
  close(HTML);

  foreach $line (@raw_data) {
    $data .= $line;
  }
  undef @raw_data;

#  print "\n\n$html_file\n\n";

  my @images;
  my $tmp_count = 0;
  while ($data =~ s|<img\s+src="images/(.*?)"(.*?)alt="(.*?)"(.*?)/>||s) {
    push @{ $images[$tmp_count] }, "$1", "$3";
    $tmp_count++;
  }
  undef $data;


  # OPEN the TEI for working with
  open(TEI, $fullpath . DS . $filename) || die("Could not open file!");
    @raw_data = <TEI>;
  close(TEI);
  foreach $line (@raw_data) {
    $data .= $line;
  }
  undef @raw_data;

  my $tmp;
  for $image ( @images ) {
    $tmp = '';
    if (@$image[1] and @$image[1] ne 'logo') {
      @$image[1] =~ s|\s+| |g;
      $data =~ s|<figure url="images/">(\s+)<figDesc>(.*?)</figDesc>(\s+)</figure>|<figure url="images/@$image[0]">$1<figDesc>@$image[1]</figDesc>$3</figure>|;
    } else {
      @$image[1] =~ s|\s+| |g;
      $data =~ s|<figure url="images/">(\s+)<figDesc>(.*?)</figDesc>(\s+)</figure>|<figure url="images/@$image[0]">$1<figDesc>$2</figDesc>$3</figure>|;    
    }
  }

  ############################
  ## Write out new TEI file ##
  ############################
  if (unlink($tei_path_file) == 1) {
    print "\n\n--- Old file has been deleted ---\n\n";
  }
  open (OUT,  ">", $tei_path_file) or die "Could not open file\n";
    print OUT $data;
  close(OUT);

}
