package Text::Editor::Easy::Program::Eval::Print;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Program::Eval::Print - Redirection of prints coming from the macro panel of the "Editor.pl" program (insertion in a "Text::Editor::Easy" object).

=head1 VERSION

Version 0.33

=cut

our $VERSION = '0.33';

use threads;    # Pour debug

use Devel::Size qw(size total_size);

Text::Editor::Easy::Comm::manage_debug_file( __PACKAGE__, *DBG );

sub init_print_eval {
    my ( $self, $reference, $unique_ref ) = @_;

    print DBG "Dans init_print_eval de 0.1 : $self|$reference|$unique_ref|",
      threads->tid, "|\n";
    $self->[0] = bless \do { my $anonymous_scalar }, "Text::Editor::Easy";
    Text::Editor::Easy::Comm::set_ref ($self->[0], $unique_ref);

    #$self->[0]->insert("Fin de print eval\n");
    $self->[1] = $self->[0]->async;
}

sub print_eval {
    my ( $self, $data ) = @_;

    #return;
    print DBG "Dans print_eval : $self|$data\n";
    $self->[0]->insert($data);

    print DBG "Fin de print_eval $data\n";

    #Line->linesize;
}

sub idle_eval_print {
    return;
}

=head1 FUNCTIONS

=head2 idle_eval_print

=head2 init_print_eval

=head2 print_eval

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
