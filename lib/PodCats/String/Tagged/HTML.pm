package PodCats::String::Tagged::HTML;

use parent qw(String::Tagged::HTML);

use overload '""' => sub {
    my $self = shift;
    $self->as_html;
};

1;
