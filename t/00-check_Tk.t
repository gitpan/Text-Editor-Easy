use strict;
use Test::More tests => 1;

use Tk;

my $mw = MainWindow->new();

$mw->after( 1000, \&write_and_exit );

MainLoop;

is ( 1, 1, "Tk is KO");


sub write_and_exit {
    is ( 1, 1, "Tk is OK");
	open (TK, ">tk_is_ok" ) or die "Fail to open file tk_is_ok : $!\n";
	print TK "Tk is ok, graphical tests can be done\n";
	close TK;
	exit;
}