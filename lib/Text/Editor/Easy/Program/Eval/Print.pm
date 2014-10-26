package Text::Editor::Easy::Program::Eval::Print;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Program::Eval::Print - Redirection of prints coming from the macro panel of the "Editor.pl" program (insertion in a "Text::Editor::Easy" object).

=head1 VERSION

Version 0.40

=cut

our $VERSION = '0.40';

use threads;    # Pour debug

use Devel::Size qw(size total_size);

Text::Editor::Easy::Comm::manage_debug_file( __PACKAGE__, *DBG );

# Length of the slash n on a file
my $length_s_n;

sub init_print_eval {
    my ( $self, $reference, $unique_ref ) = @_;

    print DBG "Dans init_print_eval de 0.1 : $self|$reference|$unique_ref|",
      threads->tid, "|\n";
    $self->[0] = bless \do { my $anonymous_scalar }, "Text::Editor::Easy";
    Text::Editor::Easy::Comm::set_ref ($self->[0], $unique_ref);

    #$self->[0]->insert("Fin de print eval\n");
    $self->[1] = $self->[0]->async;
    $length_s_n = Text::Editor::Easy->tell_length_slash_n;
}

sub print_eval {
    my ( $self, $seek_start, $data ) = @_;

    #return;
    print DBG "Dans print_eval : $self|$seek_start|$length_s_n|$data\n";
    my @lines = $self->[0]->insert($data);

    my $seek_current = $seek_start;
    my $indice = 0;
    my @data = split ( /\n/, $data );
    for my $line ( @lines ) {
        
        # Le texte doit �tre celui contenu dans $data, pas celui de la ligne !
        my $text = $line->text;
        my $length;
        if ( $indice == 0 ) {
            $length = length ( $data[0] );
        }
        else {
            $length = length ( $text );
        }
        $indice += 1;
        #print DBG "Ligne |$text|\n\tseek_start 1 = ", $line->seek_start, "\n";
        #if ( length($text) != 0 ) {
        $line->add_seek_start( "$seek_start,$seek_current,$length" );
        print "tutu";
        $seek_current += $length + $length_s_n;
        print DBG "Ligne |$text| seek_start 2 = ", $line->seek_start, "\n";
        #}
        
    }
    print DBG "Fin de print_eval $data\n";
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

=cut

1;