#! perl

use Test::Lib;
use Test2::V0;
use Test2::Tools::PDL;

use Scalar::Util qw[ refaddr ];

package Test {

    use Test2::V0;
    use Role::Tiny::With;
    use My::Class;
    use PDL::Lite;

    with 'My::Test::Role::Single';

    sub test_obj {
        my $class = shift;

        $class->test_class_new(
            p1 => PDL->sequence( 5 ),
            p2 => PDL->sequence( 5 ) + 1,
        );

    }
}


Test->test(
    "where",
    sub { $_[0]->where( $_[0]->p1 % 2 ) },
    p1 => [ 1, 3 ],
    p2 => [ 2, 4 ],
);

Test->test(
    "index",
    sub { $_[0]->index( PDL->new( 0, 1, 3 ) ) },
    p1 => [ 0, 1, 3 ],
    p2 => [ 1, 2, 4 ],
);


subtest 'at' => sub {
    my $o  = Test->test_obj;
    my $at = $o->at( 3 );
    is( $at->p1, 3, 'p1' );
    is( $at->p2, 4, 'p2' );
};


subtest 'copy' => sub {

    my $o = Test->test_obj;

    my $n = $o->copy;

    isnt( refaddr( $n ), refaddr( $o ), "same object returned" );

    isnt(
        refaddr( $o->p1->get_dataref ),
        refaddr( $n->p1->get_dataref ),
        'refaddr o.p1 != n.p1'
    );

    isnt(
        refaddr( $o->p2->get_dataref ),
        refaddr( $n->p2->get_dataref ),
        'refaddr o.p2 != n.p2'
    );

    pdl_is( $n->p1, $o->p1, 'o.p1: contents' );
    pdl_is( $n->p2, $o->p2, 'o.p2: contents' );

};

subtest 'sever' => sub {

    my $o = Test->test_obj;

    my $n = $o->index( PDL->new( 0, 1, 3 ) );

    $n->p1->set( 0, 22 );

    is( $o->p1->at( 0 ), 22, 'not severed' );

    $n->sever;
    $n->p1->set( 0, 24 );
    is( $o->p1->at( 0 ), 22, 'severed' );
};


done_testing;
