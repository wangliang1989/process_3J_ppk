#!/usr/bin/env perl
use strict;
use warnings;
$ENV{SAC_DISPLAY_COPYRIGHT} = 0;
use Parallel::ForkManager;

@ARGV == 1 or die "Usage: perl $0 dirname\n";
my ($dir) = @ARGV;

chdir $dir;
my $pm = Parallel::ForkManager->new(8);

foreach my $file (glob "*.SAC") {
    my $pid = $pm->start and next;
    open(SAC, "| sac") or die "Error in opening sac\n";
    print SAC "wild echo off\n";
    print SAC "r $file\n";
    print SAC "trans from polezero subtype /data/PZ.ALL to vel freq 0.01 0.02 15 18\n";
    print SAC "w over\n";
    print SAC "q\n";
    close(SAC);

    $pm->finish;
}
$pm->wait_all_children;
