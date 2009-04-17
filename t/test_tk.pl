use strict;

use IO::File;
autoflush STDOUT;

open STDERR, ">&STDOUT" or die "cannot dup STDERR to STDOUT: $!\n";
autoflush STDERR;

use Tk;

my $mw = MainWindow->new();

print "TK is OK\n";


