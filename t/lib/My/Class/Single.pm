package My::Class::Single;

use Moo::Role;
use PDL::Lite ();

use overload '""'     => 'to_string';
use overload fallback => 1;

sub to_string {
    return join( "\n", "p1 = " . $_[0]->p1, "p2 = " . $_[0]->p2, );
}

has '+p1' => (
    is      => 'rwp',
    default => sub { PDL->null },
    trigger => sub { $_[0]->triggered(1) },
);

has '+p2' => (
    is      => 'rwp',
    default => sub { PDL->null },
);

has triggered => (
    is      => 'rw',
    clearer => 1,
    default => 0,
);

1;
