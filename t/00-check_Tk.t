use strict;
use Test::More tests => 1;

my $program_to_call = $0;

$program_to_call =~ s/00-check_Tk\.t$/test_tk\.pl/;

print "Program to call : $program_to_call\n";

my $pid = open ( TK, "perl $program_to_call |" ) or die "Can't fork : $!\n";

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
        open (TK, ">tk_is_ok" ) or die "Fail to open file tk_is_ok : $!\n";
        print TK "Tk is ok, graphical tests can be done\n";
        close TK;

	    exit 0;
    }
}

