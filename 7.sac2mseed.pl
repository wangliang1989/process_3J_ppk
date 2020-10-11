#!/usr/bin/env perl
use strict;
use warnings;

@ARGV == 1 or die "Usage: perl $0 dirname\n";

my ($dir) = @ARGV;

chdir $dir;

# rename
foreach my $file (glob "*.SAC") {
    my ($net, $sta, $loc, $chn) = (split /\./, $file)[6..9];
    rename $file, "3J_$sta.e" if ($chn eq "BHE");
    rename $file, "3J_$sta.n" if ($chn eq "BHN");
    rename $file, "3J_$sta.z" if ($chn eq "BHZ");
}
open(SAC, "| sac") or die "Error in opening SAC\n";
print SAC "wild echo off \n";
print SAC "cuterr fillz \n";
print SAC "cut 0 86400 \n";
print SAC "r *.[enz] \n";
print SAC "w over \n";
print SAC "q \n";
close(SAC);
foreach my $zfile (glob "*.z") {
    my ($sta) = split m/\./, $zfile;
    system "sac2mseed ${sta}.? -s 1 -l 01 -o ${sta}.mseed";
}
unlink glob "*.[enz]";
