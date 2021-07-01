# NAME

MooX::PDL::Role::Proxy - treat a container of piddles as if it were a piddle

# VERSION

version 0.06

# SYNOPSIS

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

# DESCRIPTION

**MooX::PDL::Role::Proxy** is a [Moo::Role](https://metacpan.org/pod/Moo::Role) which turns its
consumer into a proxy object for some of its attributes, which are
assumed to be **PDL** objects (or other proxy objects). A subset of
**PDL** methods applied to the proxy object are applied to the selected
attributes. (See [PDL::QuckStart](https://metacpan.org/pod/PDL::QuckStart) for more information on **PDL** and
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

With **MooX::PDL::Role::Proxy** this turns into

    my $copy = $obj->where( $mask );

Or, if the results should be stored in the same object,

    $obj->inplace->where( $mask );

## Usage and Class requirements

Each attribute to be operated on by the common `PDL`-like
operators should be given a `piddle` option, e.g.

    has p1 => (
        is      => 'rw',
        default => sub { sequence( 10 ) },
        piddle  => 1,
    );

(Treat the option value as an identifier for the group of piddles
which should be operated on, rather than as a boolean).

To support non-inplace operations, the class must provide a
`clone_with_piddles` method with the following signature:

    sub clone_with_piddles ( $self, %piddles )

It should clone `$self` and assign the values in `%piddles`
to the attributes named by its keys.  To assist with the latter
operation, see the provided ["\_set\_attrs"](#_set_attrs) method.

To support inplace operations, attributes tagged with the `piddle`
option must have write accessors.  They may be public or private.

## Nested Proxy Objects

A class with the applied role should respond equivalently to a true
piddle when the supported methods are called on it (it's a bug
otherwise).  Thus, it is possible for a proxy object to contain
another, and as long as the contained object has the `piddle`
attribute set, the supported method will be applied to the
contained object appropriately.

# METHODS

## \_piddles

    @piddle_names = $obj->_piddles;

This returns a list of the names of the object's attributes with
a `piddle` tag set.  The list is lazily created by the `_build__piddles`
method, which can be modified or overridden if required. The default
action is to find all tagged attributes with tag `piddle`.

## \_clear\_piddles

Clear the list of attributes which have been tagged as piddles.  The
list will be reset to the defaults when `_piddles` is next invoked.

## \_apply\_to\_tagged\_attrs

    $obj->_apply_to_tagged_attrs( \&sub );

Execute the passed subroutine on all of the attributes tagged with the
`piddle` option. The subroutine will be invoked as

    sub->( $attribute, $inplace )

where `$inplace` will be true if the operation is to take place inplace.

The subroutine should return the piddle to be stored.

Returns `$obj` if applied in-place, or a new object if not.

## inplace

    $obj->inplace( ?$how )

Indicate that the next _inplace aware_ operation should be done inplace.

An optional argument indicating how the piddles should be updated may be
passed (see ["set\_inplace"](#set_inplace) for more information).  This API differs from
from the [inplace](https://metacpan.org/pod/PDL::Core#inplace) method.

It defaults to using the attributes' accessors to store the results,
which will cause triggers, etc. to be called.

Returns `$obj`.
See also ["inplace\_direct"](#inplace_direct) and ["inplace\_accessor"](#inplace_accessor).

## inplace\_store

    $obj->inplace_store

Indicate that the next _inplace aware_ operation should be done
inplace.  Piddles are changed inplace via the `.=` operator, avoiding
any side-effects caused by using the attributes' accessors.

It is equivalent to calling

    $obj->set_inplace( MooX::PDL::Role::Proxy::INPLACE_STORE );

Returns `$obj`.
See also ["inplace"](#inplace) and ["inplace\_accessor"](#inplace_accessor).

## inplace\_set

    $obj->inplace_set

Indicate that the next _inplace aware_ operation should be done inplace.
The object level attribute accessors will be used to store the results (which
may be the same piddle).  This will cause [Moo](https://metacpan.org/pod/Moo) triggers, etc to be
called.

It is equivalent to calling

    $obj->set_inplace( MooX::PDL::Role::Proxy::INPLACE_SET );

Returns `$obj`.
See also ["inplace\_direct"](#inplace_direct) and ["inplace"](#inplace).

## set\_inplace

    $obj->set_inplace( $value );

Change the value of the inplace flag.  Accepted values are

- MooX::PDL::Role::Proxy::INPLACE\_SET

    Use the object level attribute accessors to store the results (which
    may be the same piddle).  This will cause [Moo](https://metacpan.org/pod/Moo) triggers, etc to be
    called.

- MooX::PDL::Role::Proxy::INPLACE\_STORE

    Store the results directly in the existing piddle using the `.=` operator.

## is\_inplace

    $bool = $obj->is_inplace;

Test if the next _inplace aware_ operation should  be done inplace

## copy

    $new = $obj->copy;

Create a copy of the object and its piddles.  If the `inplace` flag
is set, it returns `$obj` otherwise it is exactly equivalent to

    $obj->clone_with_piddles( map { $_ => $obj->$_->copy } @{ $obj->_piddles } );

## sever

    $obj = $obj->sever;

Call ["sever" in PDL::Core](https://metacpan.org/pod/PDL::Core#sever) on tagged attributes.  This is done inplace.
Returns `$obj`.

## index

    $new = $obj->index( PIDDLE );

Call ["index" in PDL::Slices](https://metacpan.org/pod/PDL::Slices#index) on tagged attributes.  This is inplace aware.
Returns `$obj` if applied in-place, or a new object if not.

## at

    $obj = $obj->at( @indices );

Returns a simple object containing the results of running
["index" in PDL::Core](https://metacpan.org/pod/PDL::Core#index) on tagged attributes.  The object's attributes are
named after the tagged attributes.

## where

    $obj = $obj->where( $mask );

Apply ["where" in PDL::Primitive](https://metacpan.org/pod/PDL::Primitive#where) to the tagged attributes.  It is in-place aware.
Returns `$obj` if applied in-place, or a new object if not.

## \_set\_attr

    $obj->_set_attr( %attr )

Set the object's attributes to the values in the `%attr` hash.

Returns `$obj`.

## qsort

    $obj->qsort;

Sort the piddles.  This requires that the object has a `qsorti` method, which should
return a piddle index of the elements in ascending order.

For example, to designate the `radius` attribute as that which should be sorted
on by qsort, include the `handles` option when declaring it:

    has radius => (
        is      => 'ro',
        piddle  => 1,
        isa     => Piddle1D,
        handles => ['qsorti'],
    );

It is in-place aware. Returns `$obj` if applied in-place, or a new object if not.

## qsort\_on

    $obj->sort_on( $piddle );

Sort on the specified `$piddle`.

It is in-place aware.
Returns `$obj` if applied in-place, or a new object if not.

## clip\_on

    $obj->clip_on( $piddle, $min, $max );

Clip on the specified `$piddle`, removing elements which are outside
the bounds of \[`$min`, `$max`).  Either bound may be `undef` to indicate
it should be ignore.

It is in-place aware.

Returns `$obj` if applied in-place, or a new object if not.

## slice

    $obj->slice( $slice );

Slice.  See ["slice" in PDL::Slices](https://metacpan.org/pod/PDL::Slices#slice) for more information.

It is in-place aware.
Returns `$obj` if applied in-place, or a new object if not.

# LIMITATIONS

There are significant limits to this encapsulation.

- The piddles operated on must be similar enough in structure so that
the ganged operations make sense (and are valid!).
- There is (currently) no way to indicate that there are different sets
of piddles contained within the object.
- The object must be able to be cloned relatively easily, so that
non-inplace operations can create copies of the original object.

# SUPPORT

## Bugs

Please report any bugs or feature requests to   or through the web interface at: https://rt.cpan.org/Public/Dist/Display.html?Name=MooX-PDL-Role-Proxy

## Source

Source is available at

    https://gitlab.com/djerius/moox-pdl-role-proxy

and may be cloned from

    https://gitlab.com/djerius/moox-pdl-role-proxy.git

# AUTHOR

Diab Jerius <djerius@cpan.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 by Smithsonian Astrophysical Observatory.

This is free software, licensed under:

    The GNU General Public License, Version 3, June 2007
