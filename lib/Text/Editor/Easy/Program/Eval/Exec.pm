package Text::Editor::Easy::Program::Eval::Exec;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Program::Eval::Exec - Execution of macro panel instructions in the "Editor.pl" program.

=head1 VERSION

Version 0.3

=cut

our $VERSION = '0.3';

use Text::Editor::Easy::Comm;
use threads;    # Pour debug

Text::Editor::Easy::Comm::manage_debug_file( __PACKAGE__, *DBG );

sub exec_eval {
    my ( $self, $program, $hash_ref ) = @_;

# Ajout d'une instruction "return if anything_for_me;" entre chaque ligne pour réactivité maximum

    $program =~ s/;(\n+)/;\nreturn if ( anything_for_me() );$1/g;
    print DBG "Dans exec_eval(", threads->tid, ") : \n$program\n\n";
	print DBG "origin     = ", $hash_ref->{'origin'}, "\n";
	print DBG "sub_origin = ", $hash_ref->{'sub_origin'}, "\n";
	my $sub_sub_origin = $hash_ref->{'sub_sub_origin'};
	print DBG "sub_sub_origin = ", $hash_ref->{'sub_sub_origin'}, "\n";

    #print substr ( $program, 0, 150 ), "\n\n";
    eval $program;
    print STDERR $@ if ($@);
}

sub idle_eval_exec {
    my ( $self, $eval_print ) = @_;

    if ( defined $eval_print ) {
        Text::Editor::Easy->empty_queue($eval_print);
    }
}

=head1 FUNCTIONS

=head2 exec_eval

=head2 idle_eval_exec

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
