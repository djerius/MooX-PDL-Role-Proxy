package MooX::PDL::Role::Proxy;

# ABSTRACT: treat a container of piddles as if it were a piddle

use 5.010;
use strict;
use warnings;

our $VERSION = '0.06';

use Types::Standard -types;

use PDL::Primitive ();
use Hash::Wrap;
use Scalar::Util ();

use Moo::Role;
use Lexical::Accessor;

use namespace::clean;

use MooX::TaggedAttributes -tags => [qw( piddle )];

my $croak = sub {
    require Carp;
    Carp::croak( @_ );
};

lexical_has attr_subs => (
    is      => 'ro',
    isa     => HashRef,
    reader  => \( my $attr_subs ),
    default => sub { {} },
);


lexical_has 'is_inplace' => (
    is      => 'rw',
    clearer => \( my $clear_inplace ),
    reader  => \( my $is_inplace ),
    writer  => \( my $set_inplace ),
    default => 0
);


# requires 'clone_with_piddles';

=method _piddles

  @piddle_names = $self->_piddles;

This returns a list of the names of the object's attributes with
a C<piddle> tag set.  The list is lazily created by the C<_build__piddles>
method, which can be modified or overridden if required. The default
action is to find all tagged attributes with tag C<piddle>.

=method _clear_piddles

Clear the list of attributes which have been tagged as piddles.  The
list will be reset to the defaults when C<_piddles> is next invoked.

=cut

has _piddles => (
    is       => 'lazy',
    isa      => ArrayRef [Str],
    init_arg => undef,
    clearer  => 1,
    builder  => sub {
        my $self = shift;
        [ keys %{ $self->_tags->{piddle} } ];
    },
);


=method _apply_to_tagged_attrs

   $self->_apply_to_tagged_attrs( \&sub );

Execute the passed subroutine on all of the attributes tagged with the
C<piddle> option. The subroutine will be invoked as

   sub->( $attribute, $inplace )

where C<$inplace> will be true if the operation is to take place inplace.

The subroutine should return the piddle to be stored.

Returns C<$self> if applied in-place, or a new object if not.

=cut

sub _apply_to_tagged_attrs {
    my ( $self, $action ) = @_;

    my $inplace = $self->$is_inplace;

    my %attr = map {
        my $field = $_;
        $field => $action->( $self->$field, $inplace );
    } @{ $self->_piddles };

    if ( $inplace ) {
        $self->$clear_inplace;
        $self->_set_attr( %attr );
        return $self;
    }

    return $self->clone_with_piddles( %attr );
}


=method inplace

  $self->inplace

Indicate that the next I<inplace aware> operation should be done inplace
Returns C<$self>.

=cut

sub inplace {
    $_[0]->$set_inplace( 1 );
    $_[0];
}

=method set_inplace

  $self->set_inplace( $bool );

Change the value of the inplace flag.

=cut

sub set_inplace {
    2 == @_ or $croak->( "set_inplace requires two arguments" );
    $_[0]->$set_inplace( !!$_[1] );
    return;
}

=method is_inplace

  $bool = $self->is_inplace;

Test if the next I<inplace aware> operation should  be done inplace

=cut

sub is_inplace { goto &$is_inplace }

=method copy

  $new = $self->copy;

Create a copy of the object and its piddles.  If the C<inplace> flag
is set, it returns C<$self> otherwise it is exactly equivalent to

  $self->clone_with_piddles( map { $_ => $self->$_->copy } @{ $self->_piddles } );

=cut


sub copy {
    my $self = shift;

    if ( $self->is_inplace ) {
        $self->set_inplace( 0 );
        return $self;
    }

    return $self->clone_with_piddles( map { $_ => $self->$_->copy }
          @{ $self->_piddles } );
}

=method sever

  $self = $self->sever;

Call L<PDL::Core/sever> on tagged attributes.  This is done inplace.
Returns C<$self>.

=cut

sub sever {
    my $self = shift;
    $self->$_->sever for @{ $self->_piddles };
    return $self;
}

=method index

   $new = $self->index( PIDDLE );

Call L<PDL::Slices/index> on tagged attributes.  This is inplace aware.
Returns C<$self> if applied in-place, or a new object if not.

=cut

sub index {
    my ( $self, $index ) = @_;
    return $self->_apply_to_tagged_attrs( sub { $_[0]->index( $index ) } );
}

# is there a use for this?
# sub which {
#     my ( $self, $which ) = @_;
#     return PDL::Primitive::which(
#         'CODE' eq ref $which
#         ? do { local $_ = $self; $which->() }
#         : $which
#     );
# }

=method at

   $obj = $self->at( @indices );

Returns a simple object containing the results of running
L<PDL::Core/index> on tagged attributes.  The object's attributes are
named after the tagged attributes.

=cut

sub at {
    my ( $self, @idx ) = @_;
    wrap_hash( { map { $_ => $self->$_->at( @idx ) } @{ $self->_piddles } } );
}

=method where

   $obj = $self->where( $mask );

Apply L<PDL::Primitive/where> to the tagged attributes.  It is in-place aware.
Returns C<$self> if applied in-place, or a new object if not.

=cut

sub where {
    my ( $self, $where ) = @_;

    return $self->_apply_to_tagged_attrs( sub { $_[0]->where( $where ) } );
}



=method _set_attr

   $self->_set_attr( %attr )

Set the object's attributes to the values in the C<%attr> hash.

Returns C<$self>.

=cut


sub _set_attr {
    my ( $self, %attr ) = @_;
    my $subs = $self->$attr_subs;

    for my $key ( keys %attr ) {
        my $sub = $subs->{$key};

        if ( !defined $sub ) {
            Scalar::Util::weaken( $subs->{$key} = $self->can( "_set_${key}" )
                  // $self->can( $key ) );
            $sub = $subs->{$key};
        }

        $sub->( $self, $attr{$key} );
    }

    return $self;
}

=method qsort

  $self->qsort;

Sort the piddles.  This requires that the object has a C<qsorti> method, which should
return a piddle index of the elements in ascending order.

For example, to designate the C<radius> attribute as that which should be sorted
on by qsort, include the C<handles> option when declaring it:

  has radius => (
      is      => 'ro',
      piddle  => 1,
      isa     => Piddle1D,
      handles => ['qsorti'],
  );


It is in-place aware. Returns C<$self> if applied in-place, or a new object if not.

=cut

sub qsort {

    $_[0]->index( $_[0]->qsorti );
}

=method qsort_on

  $self->sort_on( $piddle );

Sort on the specified C<$piddle>.

It is in-place aware.
Returns C<$self> if applied in-place, or a new object if not.

=cut

sub qsort_on {

    my ( $self, $attr ) = @_;

    $self->index( $attr->qsorti );
}

=method clip_on

  $events->clip_on( $piddle, $min, $max );

Clip on the specified C<$piddle>, removing elements which are outside
the bounds of [C<$min>, C<$max>).  Either bound may be C<undef> to indicate
it should be ignore.

It is in-place aware.
Returns C<$self> if applied in-place, or a new object if not.

=cut

sub clip_on {

    my ( $self, $attr, $min, $max ) = @_;

    my $mask;

    if ( defined $min ) {
        $mask = $attr >= $min;
        $mask &= $attr < $max
          if defined $max;
    }
    elsif ( defined $max ) {
        $mask = $attr < $max;
    }
    else {
        $croak->( "one of min or max must be defined\n" );
    }

    $self->where( $mask );
}


=method slice

  $events->slice( $slice );

Slice.  See L<PDL::Slices/slice> for more information.

It is in-place aware.
Returns C<$self> if applied in-place, or a new object if not.

=cut

sub slice {

    my ( $self, $slice ) = @_;

    return $self->_apply_to_tagged_attrs( sub { $_[0]->slice( $slice ) } );
}



1;

# COPYRIGHT

__END__


=head1 SYNOPSIS

  package My::Class;

  use Moo;
  use MooX::PDL::Role::Proxy;

  use PDL;

  has p1 => (
      is      => 'rw',
      default => sub { sequence( 10 ) },
      piddle  => 1
  );

  has p2 => (
      is      => 'rw',
      default => sub { sequence( 10 ) + 1 },
      piddle  => 1
  );


  sub clone_with_piddles {
      my ( $self, %piddles ) = @_;

      $self->new->_set_attr( %piddles );
  }


  my $obj = My::Class->new;

  # clone $obj and filter piddles.
  my $new = $obj->where( $obj->p1 > 5 );


=head1 DESCRIPTION

B<MooX::PDL::Role::Proxy> is a L<Moo::Role> which turns its
consumer into a proxy object for some of its attributes, which are
assumed to be B<PDL> objects (or other proxy objects). A subset of
B<PDL> methods applied to the proxy object are applied to the selected
attributes. (See L<PDL::QuckStart> for more information on B<PDL> and
its objects (piddles)).

As an example, consider an object representing a set of detected
events (think physics, not computing), which contains metadata
describing the events as well as piddles representing event position,
energy, and arrival time.  The structure might look like this:

  {
      metadata => \%metadata,
      time   => $time,         # piddle
      x      => $x,            # piddle
      y      => $y,            # piddle
      energy => $energy        # piddle
  }


To filter the events on energy would traditionally be performed
explicitly on each element in the structure, e.g.

  my $mask = which( $obj->{energy} > 20 );

  my $copy = {};
  $copy->{time}   = $obj->{time}->where( $mask );
  $copy->{x}      = $obj->{x}->where( $mask );
  $copy->{y}      = $obj->{y}->where( $mask );
  $copy->{energy} = $obj->{energy}->where( $mask );

Or, more succinctly,

  $new->{$_} = $obj->{$_}->where( $mask ) for qw( time x y energy );

With B<MooX::PDL::Role::Proxy> this turns into

  my $copy = $obj->where( $mask );

Or, if the results should be stored in the same object,

  $obj->inplace->where( $mask );

=head2 Usage and Class requirements

Each attribute to be operated on by the common C<PDL>-like
operators should be given a C<piddle> option, e.g.

  has p1 => (
      is      => 'rw',
      default => sub { sequence( 10 ) },
      piddle  => 1,
  );

(Treat the option value as an identifier for the group of piddles
which should be operated on, rather than as a boolean).

To support non-inplace operations, the class must provide a
C<clone_with_piddles> method with the following signature:

   sub clone_with_piddles ( $self, %piddles )

It should clone C<$self> and assign the values in C<%piddles>
to the attributes named by its keys.  To assist with the latter
operation, see the provided L</_set_attrs> method.

To support inplace operations, attributes tagged with the C<piddle>
option must have write accessors.  They may be public or private.

=head2 Nested Proxy Objects

A class with the applied role should respond equivalently to a true
piddle when the supported methods are called on it (it's a bug
otherwise).  Thus, it is possible for a proxy object to contain
another, and as long as the contained object has the C<piddle>
attribute set, the supported method will be applied to the
contained object appropriately.


=head1 LIMITATIONS

There are significant limits to this encapsulation.

=over

=item *

The piddles operated on must be similar enough in structure so that
the ganged operations make sense (and are valid!).

=item *

There is (currently) no way to indicate that there are different sets
of piddles contained within the object.

=item *

The object must be able to be cloned relatively easily, so that
non-inplace operations can create copies of the original object.

=back

