#!/usr/bin/perl
#
# This utility will create a BAT file of all the files in a dir
# and create the TEI files from this list of TXT files.

require 5.004;
use strict;

## Perl and Book paths
my $perl_bin = "perl";    # For U3 drive use; /xampp/perl/bin/perl.exe
my $book_dir = ".";

# Write the BAT file
open (FILEOUT, "> pg2tei.bat") or die "Couldn't open $book_dir for writing: $!";

# Scan BASE dir and process all TXT files
opendir(BIN, $book_dir) or die "Can't open $book_dir: $!";
while( defined (my $txt_filename = readdir BIN) ) {
  next unless ($txt_filename =~ /\.txt/);

  my $filename = $txt_filename;
  $filename =~ s|(.*?)\.txt|$1|;
  my $tei_filename = $filename . ".tei";

  print FILEOUT $perl_bin . " -w " . "pg2tei.pl " . $txt_filename . " > " . $tei_filename . "\n";

}
closedir(BIN);

close FILEOUT;

############################
# RUN the pg2tei.bat file. #
############################
system "pg2tei.bat";
