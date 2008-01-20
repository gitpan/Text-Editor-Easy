#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Text::Editor::Easy' );
}

diag( "Testing Text::Editor::Easy $Text::Editor::Easy::VERSION, Perl $], $^X" );
