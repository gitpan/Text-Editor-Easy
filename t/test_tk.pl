use strict;

use IO::File;
autoflush STDOUT;

open STDERR, ">&STDOUT" or die "cannot dup STDERR to STDOUT: $!\n";

autoflush STDERR;

use Tk;

my $mw = MainWindow->new();

$mw->after( 1000, \&write_and_exit );

MainLoop;

sub write_and_exit {
    # Creation of file for following Text::Editor::Easy tests
    open (TK, ">tk_is_ok" ) or die "Fail to open file tk_is_ok : $!\n";
    print TK "Tk is ok, graphical tests can be done\n";
    close TK;
    
    # Inform parent everything is OK
    print "TK is OK\n";
    exit 0;
}
