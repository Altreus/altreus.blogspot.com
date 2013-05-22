#!/usr/bin/env perl

use strict;
use warnings;
use 5.014;
use File::Find::Rule;

my $pc = Pod::Cats::PodCats->new({
    delimiters => '[<{|'
});

my @files = File::Find::Rule->file()->name('*.pc')->in('pod');

for my $file (@files) {
    my $html_fn = $file =~ s/pod/html/r =~ s/\.pc$/.html/r;

    !-e $html_fn or (stat $file)[9] > (stat $html_fn)[9] or next;

    open my $html_out, ">", $html_fn or warn "Could not open $html_fn: $!" and next;
    $pc->{print_to} = $html_out;
    $pc->parse_file($file);
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
        print {$self->{print_to}} "<$command>$default</$command>\n\n";
    }
    if ($command eq 'hr') {
        print {$self->{print_to}} "<hr/>\n\n";
    }
}

sub handle_begin {
}

sub handle_paragraph {
    my $self = shift;

    local $" = '';
    print {$self->{print_to}} "<p>@_</p>\n\n";
}

sub handle_verbatim {
    my $self = shift;
    my $para = $self->SUPER::handle_verbatim(@_);

    print {$self->{print_to}} "<pre>$para</pre>\n\n";
}

sub handle_entity {
    my $self = shift;
    my $entity = shift;
    my @content = @_;

    if ($entity eq 'B') {
        return "<strong>@content</strong>";
    }
    if ($entity eq 'C') {
        return "<code>@content</code>";
    }
    if ($entity eq 'I') {
        return "<em>@content</em>";
    }
    if ($entity eq 'L') {
        my ($link, $text) = split /\|/, shift @content;
        return qq(<a href="$link">$text @content</a>);
    }

    return $self->SUPER::handle_entity($entity, @content);
}
