package Easy::Program::Eval::Exec;
use strict;

#use Easy::Comm;
use Comm;
use threads;    # Pour debug

use File::Basename;
my $name      = fileparse($0);
my $exec_eval = "tmp/${name}_Eval_Exec.trc";
open( EXE, ">$exec_eval" ) or print "Impossible d'écrire dans $exec_eval :$!\n";

sub exec_eval {
    my ( $self, $program ) = @_;

# Ajout d'une instruction "return if anything_for_me;" entre chaque ligne pour réactivité maximum

    $program =~ s/;(\n+)/;\nreturn if ( anything_for_me() );$1/g;
    print EXE "Dans exec_eval(", threads->tid, ") : \n$program\n\n";

    #print substr ( $program, 0, 150 ), "\n\n";
    eval $program;
    print STDERR $@ if ($@);
}

sub idle_eval_exec {
    my ( $self, $eval_print ) = @_;

    if ( defined $eval_print ) {
        Editor->empty_queue($eval_print);
    }
}
