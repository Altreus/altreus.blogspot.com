package PodCats::Parser;
use strict; 
use warnings;
use 5.010;

use parent qw(Pod::Cats);

use String::Tagged::HTML;
use List::Util qw(reduce);
use Digest::SHA qw(sha1_hex);

our @COMMANDS = qw(
    h1 h2 h3 h4 hr
    notice footnote
    item
    head cell
);

our @BLOCKS = qw(
    
);

sub new {
    my $self = (shift)->SUPER::new(@_);

    $self->{sha} = sha1_hex $self->{post_name};
    $self->{html} = String::Tagged::HTML->new('');
    return $self;
}

sub handle_command {
    my $self = shift;

    my $command = shift;
    my $str = reduce { $a . $b } make_str(@_, "\n");

    grep $_ eq $command, @COMMANDS or die "Not a command: $command";

    if ($command =~ /h\d/) {
        $str->apply_tag(0, $str->length - 1, $command => 1);
        $self->{html} .= $str;
    }
    if ($command eq 'hr') {
        $self->{html} .= String::Tagged::HTML->new_raw('<hr />');
    }
    if ($command eq 'notice') {
        $str->apply_tag(0, $str->length - 1, p => { class => "notice" });
        $self->{html} .= $str;
    }
    if ($command eq 'footnote') {
        my ($num) = $str =~ /(\d+)/;

        $str->apply_tag($-[0], $+[0], a => { 
            href => "#fn-$self->{sha}-$num",
            name => "footnote-$self->{sha}-$num" 
        });
        $str->apply_tag($-[0], $+[0], sup => 1);
        $str->apply_tag(0, length $str, p => { class => 'footnote' });
        $self->{html} .= $str;
    }

    if ($command eq 'item') {
        $str->apply_tag(0, $str->length - 1, li => 1);
        $self->{html} .= $str;
    }

    if ($command eq 'head') {
        if (! $self->{table_head}) {
            $self->{html} .= String::Tagged::HTML->new_raw('<tr>');
        }

        $self->{tr_size}++;
        $self->{table_head} = 1;

        $str->apply_tag(0, $str->length - 1, th => 1);
        $self->{html} .= $str;
    }

    if ($command eq 'cell') {
        if (! $self->{tr_size}) {
            warn "Don't know how big to make tables without =heads";
            return;
        }
        if ($self->{table_head}) {
            $self->{html} .= String::Tagged::HTML->new_raw('</tr>' . "\n");
            delete $self->{table_head};
        }

        if (! $self->{cell}) {
            $self->{html} .= String::Tagged::HTML->new_raw('<tr>' . "\n");
        }
        
        $str->apply_tag(0, $str->length - 1, td => 1);
        $self->{html} .= $str;

        if (++$self->{cell} == $self->{tr_size}) {
            $self->{html} .= String::Tagged::HTML->new_raw('</tr>' . "\n");
            $self->{cell} = 0;
        }
    }
}

sub handle_begin {
    my $self = shift;
    my $command = shift;
    my @params = @_;

    if ($command eq 'list') {
        $self->{html} .= String::Tagged::HTML->new_raw('<ul>');
    }
    elsif ($command eq 'table') {
        $self->{html} .= String::Tagged::HTML->new_raw('<table>' . "\n");
    }
}

sub handle_end {
    my $self = shift;
    my $command = shift;

    if ($command eq 'list') {
        $self->{html} .= String::Tagged::HTML->new_raw('</ul>');
    }
    elsif ($command eq 'table') {
        $self->{html} .= String::Tagged::HTML->new_raw('</table>' . "\n");
        delete $self->{tr_size};
        delete $self->{cell};
    }
}

sub handle_paragraph {
    my $self = shift;

    my $str = reduce { $a . $b } make_str(@_, "\n");
    $str->apply_tag(0, $str->length - 1, p => 1);
    $self->{html} .= $str;
}

sub handle_verbatim {
    my $self = shift;
    my $para = $self->SUPER::handle_verbatim(@_);

    my $str = make_str($para . "\n");
    $str->apply_tag(0, $str->length - 1, pre => 1);
    $self->{html} .= $str;
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
        my $str = reduce { $a . $b } make_str(@content);
        $str->apply_tag(0, $str->length, $simple => 1);
        return $str;
    }

    if ($entity eq 'L') {
        my ($link, $text) = split /\|/, shift @content;

        $text = $link if not $text;

        # looks like a module
        if ($link =~ /^(\w+)(::\w+)*$/) {
            $link = "https://metacpan.org/module/$link";
        }

        my $str = reduce { $a . $b } make_str($text, @content);
        $str->apply_tag(0, $str->length, a => { href => $link });
        return $str;
    }

    # F for Footnote - links to the =footnote of the same $num
    if ($entity eq 'F') {
        my $num = $content[0];
        my $str = make_str($num);
        $str->apply_tag(0, length $num, a => { 
            href => "#footnote-$self->{sha}-$num", 
            name => "fn-$self->{sha}-$num"
        });
        $str->apply_tag(0, length $num, sup => 1);
        return $str;
    }

    if ($entity eq 'N') {
        return String::Tagged::HTML->new_raw('<br/>' . "\n");
    }

    return make_str($self->SUPER::handle_entity($entity, @content));
}

sub make_str {
    if (wantarray) {
        return map { scalar make_str($_) } @_;
    }
    else {
        return ref $_[0] ? $_[0] : String::Tagged::HTML->new($_[0]) 
    }
}
1;
