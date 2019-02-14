package My::Test::Role::Nested;

use Test2::V0;
use Hash::Wrap;

use Scalar::Util qw[ refaddr ];

use Role::Tiny;
with 'My::Test::Role::Base';

use namespace::clean;

requires 'test_obj';

sub test_inplace {

    my $class = shift;

    my ( $sub, $expected, $build_test_obj ) = @_;

    my $context = context();

    subtest 'inplace' => sub {

        my $orig = $class->test_obj;

        my $new = $sub->( $orig->inplace );

        for my $c ( 'c1', 'c2' ) {

            subtest $c => sub {
                $class->test_inplace_flat_obj( $orig->$c, $new->$c,
                    $expected->$c );
            }
        }

    };

    $context->release;
}

sub test_not_inplace {

    my $class = shift;

    my ( $sub, $expected ) = @_;

    my $context = context();

    subtest '! inplace' => sub {

        my $orig = $class->test_obj;

        my %data;

        for my $c ( 'c1', 'c2' ) {

            my $pobj = $orig->$c;

            my $expected = $expected->$c;
            my $fp       = $data{$c} = {};

            for my $p ( 'p1', 'p2' ) {
                $fp->{$p} = wrap_hash( {
                    refaddr => refaddr( $pobj->$p->get_dataref ),
                    copy    => $pobj->$p->copy,
                } );
            }
        }

        my $new = $sub->( $orig );

        for my $c ( 'c1', 'c2' ) {
            subtest $c => sub {
                $class->test_not_inplace_flat_obj( $orig->$c, $new->$c,
                    $expected->$c, %{ $data{$c} } );
            };
        }

        $context->release;
    };
}

sub build_expected {
    my $class = shift;

    my %data = @_;

    My::NestedClass->new(
        c1 => My::Class->new(
            p1 => PDL->new( $data{c1}{p1} ),
            p2 => PDL->new( $data{c1}{p2} ),
        ),
        c2 => My::Class->new(
            p1 => PDL->new( $data{c2}{p1} ),
            p2 => PDL->new( $data{c2}{p2} ),
        ),
    );

}

1;
