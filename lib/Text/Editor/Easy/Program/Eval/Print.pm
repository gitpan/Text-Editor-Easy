package Easy::Program::Eval::Print;
use strict;

#use Easy::Comm;
use Comm;
use threads;    # Pour debug

use Devel::Size qw(size total_size);
use IO::File;
use File::Basename;
my $name       = fileparse($0);
my $eval_print = "tmp/${name}_Eval_Print.trc";
open( DBG, ">$eval_print" ) or die "Impossible d'ouvrir $eval_print : $!\n";
autoflush DBG;

sub init_print_eval {
    my ( $self, $unique_ref ) = @_;

    #print "Dans init_print_eval : $self|$unique_ref\n";
    $self->[0] = bless \do { my $anonymous_scalar }, "Editor";
    $self->[0]->reference($unique_ref);

    #$self->[0]->insert("Fin de print eval\n");
    $self->[1] = $self->[0]->async;
}

sub print_eval {
    my ( $self, $data ) = @_;

    #print DBG "Dans print_eval ", total_size($self), " : $data\n";
    $self->[0]->insert($data);

    #Line->linesize;
}

sub idle_eval_print {
    return;
}
