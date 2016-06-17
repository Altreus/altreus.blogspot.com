package PodCats::Parser;
use strict;
use warnings;
use 5.010;

use parent qw(Pod::Cats);

use HTML::Element;
use HTML::TreeBuilder;
use List::Util qw(reduce any pairmap);
use Digest::SHA qw(sha1_hex);
use URI::file;
use Image::Size qw(imgsize);
use Scalar::IfDefined qw(lifdef);

$Image::Size::NO_CACHE = 1;

our @COMMANDS = qw(
    h1 h2 h3 h4 hr
    notice footnote
    item img
    head cell
    quote fig
);

our @BLOCKS = qw(

);

sub new {
    my $self = (shift)->SUPER::new(@_);

    $self->{sha} = sha1_hex $self->{post_name};
    $self->{html} = HTML::Element->new('div');
    $self->{_html_ctx} = $self->{html};
    return $self;
}

sub handle_command {
    my $self = shift;

    my $command = shift;

    any {$_ eq $command} @COMMANDS or die "Not a command: $command";

    if ($command =~ /h\d/) {
        my @data = split ' ', $_[0];
        my %properties = $self->collapse_properties($self->shift_properties(\@data));

        $self->add_element($command => \%properties, "@data");
    }
    if ($command eq 'hr') {
        $self->add_element('hr');
    }
    if ($command eq 'notice') {
        $self->add_element(p => @_, { class => 'notice' });
    }
    if ($command eq 'footnote') {
        my ($num) = $_[0] =~ s/(\d+)//;

        $self->add_element(sup => [
            'a', $num, @_, {
                href => sprintf('#fn-%s-%d', $self->{sha}, $num),
                name => sprintf('footnote-%s-%d', $self->{sha}, $num),
                class => 'footnote-to',
            },
        ]);
    }

    if ($command eq 'item') {
        $self->add_element( li => @_ );
    }

    if ($command eq 'head') {
        if (! $self->{table_head}) {
            $self->{table_head} = $self->add_element('tr');
        }

        $self->{tr_size}++;
        $self->{table_head}->push_content([th => @_]);
    }

    if ($command eq 'cell') {
        if (! $self->{tr_size}) {
            warn "Don't know how big to make tables without =heads";
            return;
        }
        if ($self->{table_head}) {
            # It stays in $self->{html} of course
            delete $self->{table_head};
        }

        if (! $self->{table_row}) {
            $self->{table_row} = $self->add_element('tr');
        }

        $self->{table_row}->push_content([td => @_]);

        if ($self->{table_row}->content_list == $self->{tr_size}) {
            delete $self->{table_row};
        }
    }
    if ($command eq 'img') {
        my @data = split ' ', $_[0];

        if (@data == 1 && -e $data[0]) {
            push @data, imgsize $data[0];
        }

        $self->add_element(img => {
            src => $data[0],
            $data[1] ? (width => $data[1]) : (),
            $data[2] ? (height => $data[2]) : (),
        });
    }
    if ($command eq 'quote') {
        $self->add_element(blockquote => @_);
    }
    if ($command eq 'fig') {
        my @data = split ' ', $_[0];

        my %properties = $self->shift_properties(\@data, {
            width => '',
        });

        my $img = shift @data;
        my $img_src = URI::file->new($img)->abs(URI::file->cwd);
        if (-e $img) {
            my ($w, $h) = imgsize $img;
            $properties{style}->{'max-width'} = $w
                if $w and exists $properties{style}->{'max-width'};

            $properties{style}->{'max-height'} = $h
                if $h and exists $properties{style}->{'max-height'};
        }
        else {
            warn "Couldn't determine size of $img"
                if exists $properties{style}->{'max-height'}
                or exists $properties{style}->{'max-width'};

            delete $properties{style}->{'max-height'};
            delete $properties{style}->{'max-width'};
        }

        %properties = $self->collapse_properties(%properties);

        $self->add_element( figure =>
            \%properties,
            [
                img => {
                    src => $img_src
                },
                [ figcaption => "@data" ]
            ]
        );
    }
}

sub handle_begin {
    my $self = shift;
    my $command = shift;
    my @params = @_;

    if ($command eq 'list') {
        $self->enter_element('ul');
    }
    elsif ($command eq 'table') {
        $self->enter_element('table')
    }
    elsif ($command eq 'quote') {
        $self->enter_element('blockquote')
    }
    elsif ($command eq 'html') {
        $self->{raw} = 1;
    }
}

sub handle_end {
    my $self = shift;
    my $command = shift;

    if ($command eq 'list') {
        $self->end_element('ul');
    }
    elsif ($command eq 'table') {
        $self->end_element('table');
        delete $self->{tr_size};
        delete $self->{cell};
    }
    elsif ($command eq 'quote') {
        $self->end_element('blockquote');
    }
    elsif ($command eq 'html') {
        $self->{raw} = 0;
    }
}

sub handle_paragraph {
    my $self = shift;

    if ($self->{raw}) {
        $self->add_raw(@_);
        return;
    }

    $self->add_element( p => @_ );
}

sub handle_verbatim {
    my $self = shift;
    my $para = $self->SUPER::handle_verbatim(@_);

    if ($self->{raw}) {
        $self->add_raw(@_);
        return;
    }

    $self->add_element( pre => @_ );
}

# in handle_entity we return arrayrefs. Pod::Cats will nest them appropriately.
# Eventually, the nested LoL will end up in handle_paragraph, or similar; at
# which point, add_element will just see a list-of-lists and HTML::Element
# should DTRT.
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
        return [ $simple => @content ];
    }

    if ($entity eq 'L') {
        my ($link, $text) = split /\|/, shift @content;

        $text = $link if not $text;

        # looks like a module
        if ($link =~ /^(\w+)(::\w+)*$/) {
            $link = "https://metacpan.org/module/$link";
        }

        return [ a => { href => $link }, @content ];
    }

    # F for Footnote - links to the =footnote of the same $num
    if ($entity eq 'F') {
        my $num = $content[0];
        return [
            sup => [
                a => {
                    href => "#footnote-$self->{sha}-$num",
                    name => "fn-$self->{sha}-$num",
                    class => 'footnote-from',
                }
            ]
        ];
    }

    if ($entity eq 'N') {
        return [ 'br' ];
    }

    die "Unhandled entity $entity";
}

sub add_element {
    my $self = shift;
    $self->{_html_ctx}->push_content(\@_);
}

sub enter_element {
    my $self = shift;
    my $element = HTML::Element->new_from_lol(\@_);
    $self->{_html_ctx}->push_content($element);
    $self->{_html_ctx} = $element;
}

# Pod::Cats dies for us if the syntax is bad.
sub end_element {
    my $self = shift;
    $self->{_html_ctx} = $self->{_html_ctx}->parent;
}

sub add_raw {
    my $self = shift;
    $self->{_html_ctx}->push_content(
        HTML::TreeBuilder->new->parse_content($_[0])->disembowel
    );
}

sub as_html {
    my $self = shift;
    return join '', map { $_->as_HTML('<&>', '  '), "\n" } $self->{html}->content_list;
}

sub shift_properties {
    my $self = shift;
    my $data = shift;
    my $values = shift;

    my %properties = ( style => {} );

    while ($data->[0] =~ /^:/) {
        my $p = shift @$data;
        if ($p eq ':left') {
            $properties{style}->{float} = 'left';
        }
        if ($p eq ':right') {
            $properties{style}->{float} = 'right';
        }
        if ($p eq ':clear') {
            $properties{style}->{clear} = 'both';
        }
        if ($p eq ':width') {
            $properties{style}->{'max-width'} = $values->{width};
        }
        if ($p eq ':height') {
            $properties{style}->{'max-height'} = $values->{height};
        }
    }

    return %properties;
}

sub collapse_properties {
    my $self = shift;
    my %properties = @_;

    $properties{style} = join ';', pairmap { "$a:$b" } %{ $properties{style} }
        if $properties{style};

    return %properties;
}

sub img_info {
    my $self = shift;
    my $img = shift;
}

1;
