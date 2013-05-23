#!/usr/bin/env perl

use strict;
use warnings;
use 5.014;
use File::Find::Rule;
use String::Tagged::HTML;

my $pc = Pod::Cats::PodCats->new({
    delimiters => '[<{|'
});

my @files = File::Find::Rule->file()->name('*.pc')->in('pod');

for my $file (@files) {
    my $html_fn = $file =~ s/pod/html/r =~ s/\.pc$/.html/r;

    !-e $html_fn or (stat $file)[9] > (stat $html_fn)[9] or next;

    open my $html_out, ">", $html_fn or warn "Could not open $html_fn: $!" and next;
    $pc->{html} = String::Tagged::HTML->new();
    $pc->parse_file($file);

    $html_out->print($pc->{html});
}

package Pod::Cats::PodCats;
use parent qw(Pod::Cats);

our @COMMANDS = qw(
    h1 h2 h3 h4 hr
);

our @BLOCKS = qw(
    
);

sub handle_command {
    my $self = shift;

    my $command = $_[0];
    my $default = $self->SUPER::handle_command(@_);

    grep $_ eq $command, @COMMANDS or die "Not a command: $command";

    if ($command =~ /h\d/) {
        my $str = String::Tagged::HTML->new($default);
        $self->{html} .= "\n" . $str->as_html($command) . "\n";
    }
    if ($command eq 'hr') {
        $self->{html} .= String::Tagged::HTML->new_raw('<hr />');
    }
}

sub handle_begin {
}

sub handle_paragraph {
    my $self = shift;

    local $" = '';
    my $str = String::Tagged::HTML->new("@_");
    $self->{html} .= "\n" . $str->as_html('p') . "\n";
}

sub handle_verbatim {
    my $self = shift;
    my $para = $self->SUPER::handle_verbatim(@_);

    my $str = String::Tagged::HTML->new($para);
    $self->{html} .= "\n" . $str->as_html('pre') . "\n";
}

sub handle_entity {
    my $self = shift;
    my $entity = shift;
    my @content = @_;

    my $simple = {
        'B' => 'b',
        'C' => 'code',
        'I' => 'em',
    }->{$entity};

    if ($simple) {
        my $str = String::Tagged::HTML->new("@content");
        $str->apply_tag(-1, -1, $simple => 1);
        return $str;
    }

    if ($entity eq 'L') {
        my ($link, $text) = split /\|/, shift @content;
        my $str = String::Tagged::HTML->new("$text @content");
        $str->apply_tag(-1, -1, a => { href => $link });
        return $str;
    }

    return $self->SUPER::handle_entity($entity, @content);
}
