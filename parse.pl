#!/usr/bin/env perl

use strict;
use warnings;
use 5.014;

use lib 'lib';

use Opt::Imistic;

use File::Basename;
use File::Find::Rule;
use PodCats::Parser;

my @files = @ARGV ? @ARGV : File::Find::Rule->file()->name('*.pc')->in('pod');

for my $file (@files) {
    my $pc = PodCats::Parser->new({
        delimiters => '[<{|',
        post_name => basename($file, '.pc'),
    });

    my $html_fn = $file =~ s/pod/html/r =~ s/\.pc$/.html/r;

    if (not $ARGV{f} and -e $html_fn and (stat $file)[9] < (stat $html_fn)[9]) {
        print "Skipping $file\n";
        next;
    }

    $pc->parse_file($file);

    say $html_fn;
    say $file;

    if ($ARGV{d}) {
        print $pc->as_html;
    }
    else {
        open my $html_out, ">", $html_fn or die "Could not open $html_fn: $!", next;
        $html_out->print($pc->as_html);
    }
}

