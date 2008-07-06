use strict;
use Test::More tests => 1;

my $pid = open ( TK, "perl test_tk.pl |" ) or die "Can't fork : $!\n";

while ( <TK> ) {
    if ( /couldn't connect to display/ ) {
        kill $pid;
	print "In parent, received $_";
	is ( 1, 1, "Tk is not working properly : server X is not started or DISPLAY variable is unfit");
	exit 0;
    }
    if ( /TK is OK/ ) {
	print "In parent, received $_";
	is ( 1, 1, "Tk is OK");
	exit 0;
    }
}