package PodCats::Parser;
use strict; 
use warnings;
use 5.010;

use parent qw(Pod::Cats);

use String::Tagged::HTML;
use List::Util qw(reduce);

our @COMMANDS = qw(
    h1 h2 h3 h4 hr
    notice footnote
    item
    head cell
);

our @BLOCKS = qw(
    
);

sub handle_command {
    my $self = shift;

    my $command = $_[0];
    my $default = $self->SUPER::handle_command(@_);

    grep $_ eq $command, @COMMANDS or die "Not a command: $command";

    if ($command =~ /h\d/) {
        $self->{html} .= qq(\n<$command>$default</$command>\n);
    }
    if ($command eq 'hr') {
        $self->{html} .= "\n<hr />\n";
    }
    if ($command eq 'notice') {
        $self->{html} .= qq(\n<p class="notice">$default</p>\n);
    }

    if ($command eq 'footnote') {
        my $str = String::Tagged::HTML->new($default);
        my $num = $default =~ /\d+/;

        $str->apply_tag($-[0], $+[0], a => { href => "#fn-$num", name => "#footnote-$num" });

        $self->{html} .= $str->as_html(p => { class => 'footnote' }) . "\n";
    }

    if ($command eq 'item') {
        $self->{html} .= qq(\n<li>$default</li>\n);

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
        $self->{html} .= '<ul>';
    }
    elsif ($command eq 'table') {
        $self->{html} .= String::Tagged::HTML->new_raw('<table>' . "\n");
    }
}

sub handle_end {
    my $self = shift;
    my $command = shift;

    if ($command eq 'list') {
        $self->{html} .= '</ul>';
    }
    elsif ($command eq 'table') {
        $self->{html} .= String::Tagged::HTML->new_raw('</table>' . "\n");
        delete $self->{tr_size};
        delete $self->{cell};
    }
}

sub handle_paragraph {
    my $self = shift;

    local $" = '';

    my $str = reduce { $a . $b } @_;
    $self->{html} .= "\n<p>@_</p>\n";
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

        $text = $link if not $text;

        # looks like a module
        if ($link =~ /^(\w+)(::\w+)*$/) {
            $link = "https://metacpan.org/module/$link";
        }

        my $str = String::Tagged::HTML->new("$text @content");
        $str->apply_tag(-1, -1, a => { href => $link });
        return $str;
    }

    # F for Footnote - links to the =footnote of the same $num
    if ($entity eq 'F') {
        my $num = $content[0];
        my $str = String::Tagged::HTML->new($num);
        $str->apply_tag(0, length $num, a => { href => "#footnote-$num", name => "#fn-$num" });
        return $str;
    }

    return $self->SUPER::handle_entity($entity, @content);
}

1;
