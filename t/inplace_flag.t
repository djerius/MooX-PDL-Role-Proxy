#! perl

use Test::Lib;
use Test2::V0;
use My::Class;;

my $obj = My::Class->new();

is ( !!$obj->is_inplace, !!0 , "initialized: not inplace" );
is ( $obj->inplace, $obj, "inplace returns object" );
is ( !!$obj->is_inplace, !!1, "inplace sets flag" );
$obj->set_inplace( 0 );
is ( !!$obj->is_inplace, !!0, "set_inplace resets flag" );
$obj->set_inplace( 1 );
is ( !!$obj->is_inplace, !!1, "set_inplace sets flag" );

done_testing;
