#!/usr/bin/env perl
use strict;
use warnings;

@ARGV >= 1 or die "Usage: \n\tperl $0 dir1 dir2 ... dirn\n";

my @dirs = @ARGV;

foreach my $dir (@dirs) {
    system "perl 2.merge.pl $dir";
    system "perl 4.synchronize.pl $dir";
    system "perl 5.transfer.pl $dir";
    system "perl 7.sac2mseed.pl $dir";
}
