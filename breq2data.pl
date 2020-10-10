#!/usr/bin/env perl
use strict;
use warnings;
use List::Util qw(min);
use List::Util qw(max);
use Time::Local;
use POSIX qw(strftime);
$ENV{SAC_DISPLAY_COPYRIGHT}=0;

@ARGV >= 1 or die "Usage: perl $0 breq-mail\n";
my $dataroot = $ENV{DATA_BASE};
my %keys;
open (IN, "< $dataroot/station_builder.txt") or die;
foreach (<IN>) {
    # CD|BBSX|30.3282|103.046|CDUT|2016-11-22T09:24:42|2018-01-27T10:08:01|
    my ($net, $sta, $lat, $lon) = (split m/\|/)[0..3];
    $keys{$sta} = "knetwk $net stla $lat stlo $lon";
}
close(IN);
open (IN, "< $dataroot/index.txt") or die;
my @index = <IN>;
close(IN);
foreach my $breqfile (@ARGV) {
    my $breq = (split m/\./, $breqfile)[0];

    open (IN, "< $breqfile") or die "can not open $breqfile";
    my @info = <IN>;
    close (IN);
    #.NAME ctgluthc
    #.EMAIL 18903368885@163.com
    #.SOURCE ~NEIC PDE~Jan 1990 PDE~National Earthquake Information Center - USGS DOI~
    #.HYPO ~2018 05 16 08 46 20~29.3409~102.385~72.56~18~216~Mariana~
    #.MAGNITUDE ~4.4~mb~
    #.QUALITY B
    #.LABEL 20180101
    #.END
    my $name;
    my $label;
    my ($evlo, $evla, $evdp, $mag, $magtype);
    my ($year, $jday, $hour, $minute, $sec, $msec, $month, $day, $second);
    foreach my $line (@info) {
        my ($stat, $word) = split m/\s+/, $line;
        if ($stat eq ".NAME") {
            $name = $word;
        } elsif ($stat eq ".LABEL") {
            $label = $word;
        } elsif ($stat eq ".HYPO") {
            my $origin;
            ($origin, $evla, $evlo, $evdp) = (split "~", $line)[1..4];
            ($year, $month, $day, $hour, $minute, $second) = split m/\s+/, $origin;
            # 秒和毫秒均为整数
            ($sec, $msec) = split /\./, $second;
            $msec = int(($second - $sec) * 1000 + 0.5);
            # 计算发震日期是一年中的第几天
            $jday = strftime("%j", $second, $minute, $hour, $day, $month-1, $year-1900);
        } elsif ($stat eq ".MAGNITUDE") {
            ($mag, $magtype) = (split "~", $word)[1..2];
        }
    }
    mkdir $name;
    system "rm -f $name/$label/*" if (-d "$name/$label");
    my $rm = 0;
    mkdir "$name/$label";

    foreach (@info) {
        # DCZ01 CD 2018 01 01 00 00 00 2018 01 02 00 00 00
        my ($sta, $net, $year0, $mon0, $day0, $hour0, $min0, $sec0, $year1, $mon1, $day1, $hour1, $min1, $sec1) = split m/\s+/;
        next if ($sta =~ "\\.");
        my $start =  timegm($sec0, $min0, $hour0, $day0, $mon0 - 1, $year0);
        my $end =  timegm($sec1, $min1, $hour1, $day1, $mon1 - 1, $year1);
        foreach (@index) {
            # BJHC /data/2017LiangCT_WuJ_LushanGAP/BJHC/2017229/2017.229.09.BJHC.00.BHZ.SAC 1502960400 1502963999.99
            my ($ista, $sacfile, $file_start, $file_end) = split m/\s+/;
            next unless ($sta eq $ista);
            next if ($start >= $file_end);
            next if ($end <= $file_start);
            my ($origin) = &timegmsac($sacfile);
            my $b = max($start, $file_start) - $origin;
            my $e = min($end, $file_end) - $origin;
            my $filename = (split "/", $sacfile)[-1];
            my ($kcmpnm) = (split m/\s+/, `saclst kcmpnm f $sacfile`)[1];
            open(SAC, "| sac") or die "Error in opening sac\n";
            print SAC "wild echo off \n";
            print SAC "cut $b $e\n";
            print SAC "r $sacfile\n";
            print SAC "ch cmpaz 0 cmpinc 90\n" if ($kcmpnm eq "BHN");
            print SAC "ch cmpaz 90 cmpinc 90\n" if ($kcmpnm eq "BHE");
            print SAC "ch cmpaz 0 cmpinc 0\n" if ($kcmpnm eq "BHZ");
            print SAC "ch $keys{$sta} khole 01\n";
            print SAC "ch o gmt $year $jday $hour $minute $sec $msec\n" if defined($year);
            print SAC "ch evlo $evlo evla $evla evdp $evdp\n" if defined($evlo);
            print SAC "ch mag $mag\n" if defined($mag);
            print SAC "w $name/$label/$filename\n";
            print SAC "q\n";
            close (SAC);
            &renamesac("$name/$label", $filename);
            $rm++;
        }
    }
    if ($rm == 0) {
        print "no data for $label\n";
        system "rm -rf $name/$label";
    }else{
        print "find $rm files for $breqfile\n";
    }
}
sub add_zero(){
    my @in = @_;
    my @out;
    foreach (@in) {
        if (length($_) < 2) {
            push @out, "0$_";
        }else{
            push @out, "$_";
        }
    }
    return @out;
}
sub addd_zero(){
    my @in = @_;
    my @out;
    foreach (@in) {
        if (length($_) == 1) {
            push @out, "00$_";
        }elsif (length($_) == 2) {
            push @out, "0$_";
        }else{
            push @out, "$_";
        }
    }
    return @out;
}
sub timegmsac() {
    my ($sacfile) = @_;
    my ($kzdate, $kztime, $kcmpnm) = (split m/\s+/, `saclst kzdate kztime kcmpnm f $sacfile`)[1..3];
    my ($year, $mon, $day) = split "/", $kzdate;
    my ($hour, $min, $sec) = split ":", $kztime;
    $mon -= 1;
    # 计算该时刻与计算机元年的秒数差
    my ($origin) = timegm($sec, $min, $hour, $day, $mon, $year);
}
sub renamesac() {
    my ($dir, $file) = @_;
    my ($origin) = &timegmsac("$dir/$file");
    my ($b) = (split m/\s+/, `saclst b f $dir/$file`)[1];
    my $time = $origin + $b;
    my ($sec ,$min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime($time);
    $year = 1900 + $year;
    $mon = $mon + 1;
    $yday = $yday + 1;
    my ($knetwk, $kstnm, $khole, $kcmpnm) = (split m/\s+/, `saclst knetwk kstnm khole kcmpnm f $dir/$file`)[1..4];
    ($yday) = &addd_zero($yday);
    ($hour, $min, $sec) = &add_zero($hour, $min, $sec);
    my $newname = "${year}.${yday}.${hour}.${min}.${sec}.0000.${knetwk}.${kstnm}.${khole}.${kcmpnm}.M.SAC";
    rename "$dir/$file", "$dir/$newname";
}
