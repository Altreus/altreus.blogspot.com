package PodCats::Parser;
use strict; 
use warnings;
use 5.010;

use parent qw(Pod::Cats);

use PodCats::String::Tagged::HTML;

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
        my $str = PodCats::String::Tagged::HTML->new($default);
        $self->{html} .= "\n" . $str->as_html($command) . "\n";
    }
    if ($command eq 'hr') {
        $self->{html} .= PodCats::String::Tagged::HTML->new_raw('<hr />');
    }
}

sub handle_begin {
}

sub handle_paragraph {
    my $self = shift;

    use Data::Dumper; print Dumper \@_;
    local $" = '';

    $self->{html} .= "\n<p>@_</p>\n";
}

sub handle_verbatim {
    my $self = shift;
    my $para = $self->SUPER::handle_verbatim(@_);

    my $str = PodCats::String::Tagged::HTML->new($para);
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
        my $str = PodCats::String::Tagged::HTML->new("@content");
        $str->apply_tag(-1, -1, $simple => 1);
        return $str;
    }

    if ($entity eq 'L') {
        my ($link, $text) = split /\|/, shift @content;
        my $str = PodCats::String::Tagged::HTML->new("$text @content");
        $str->apply_tag(-1, -1, a => { href => $link });
        return $str;
    }

    return $self->SUPER::handle_entity($entity, @content);
}

1;
