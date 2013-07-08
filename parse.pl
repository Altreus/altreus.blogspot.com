#!/usr/bin/env perl

use strict;
use warnings;
use 5.014;

use lib 'lib';

use File::Find::Rule;
use PodCats::Parser;

my $pc = PodCats::Parser->new({
    delimiters => '[<{|'
});

my @files = (shift) // File::Find::Rule->file()->name('*.pc')->in('pod');

for my $file (@files) {
    my $html_fn = $file =~ s/pod/html/r =~ s/\.pc$/.html/r;

    !-e $html_fn or (stat $file)[9] > (stat $html_fn)[9] or next;

    open my $html_out, ">", $html_fn or warn "Could not open $html_fn: $!" and next;
    $pc->parse_file($file);

    $html_out->print($pc->{html}->as_html());
}

