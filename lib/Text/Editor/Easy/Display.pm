package Text::Editor::Easy::Display;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Display - Object oriented interface to displays (managed by "Text::Editor::Easy::Abstract"). A display is a screen line. With
wrap mode, you can have several displays for a single line on a file.

=head1 VERSION

Version 0.3

=cut

our $VERSION = '0.3';

# Ce package n'est qu'une interface orientée objet à des fonctions de File_manager.pm rendues inaccessibles (ne se trouvent
# pas dans les hachages gérés par AUTOLOAD de Text::Editor::Easy) car susceptibles de changer

# Les fonctions de File_manager.pm réalisant toutes les méthodes de ce package commencent par "line_" puis reprennent
# le nom de la méthode

use Scalar::Util qw(refaddr weaken);

use Text::Editor::Easy::Comm;

# 2 attributs pour un objet "Line"
my %ref_Editor;    # Une ligne appartient à un éditeur unique
my %ref_id;        # A une ligne, correspond un identifiant

# Recherche d'un identifiant pour un éditeur donné
my %ref_line
  ; # Il y aura autant de hachage de références que de threads demandeurs de lignes

sub new {
    my ( $classe, $ref_Editor, $ref_id ) = @_;

    return if ( !$ref_id );
    my $line = $ref_line{$ref_Editor}{$ref_id};
    if ($line) {
        return $line;
    }
    my $unique_ref = $ref_Editor->get_ref;
    $line = bless \do { my $anonymous_scalar }, $classe;

    my $ref = refaddr $line;
    $ref_Editor{$ref}               = $ref_Editor;
    $ref_id{$ref}                   = $ref_id;
    $ref_line{$ref_Editor}{$ref_id} = $line;
    weaken $ref_line{$ref_Editor}{$ref_id};

    return $line;
}

sub next {
    my ($self) = @_;

    my $ref        = refaddr $self;
    my $ref_editor = $ref_Editor{$ref};
    my $next_id    = $ref_editor->display_next( $ref_id{$ref} );
    return Text::Editor::Easy::Display->new(
        $ref_editor
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $next_id,
    );
}

sub previous {
    my ($self) = @_;

    my $ref         = refaddr $self;
    my $ref_editor  = $ref_Editor{$ref};
    my $previous_id = $ref_editor->display_previous( $ref_id{$ref} );
    return Text::Editor::Easy::Display->new(
        $ref_editor
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $previous_id,
    );
}

sub next_in_file {
    my ($self) = @_;

    my $ref = refaddr $self;
    my ( $id, $num ) = split( /_/, $ref_id{$ref} );
    my $ref_editor = $ref_Editor{$ref};
    my ($next_id) = $ref_editor->next_line($id);
    return Text::Editor::Easy::Line->new(
        $ref_editor
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $next_id,
    );
}

sub previous_in_file {
    my ($self) = @_;

    my $ref = refaddr $self;
    my ($id) = split( /_/, $ref_id{$ref} );
    my $ref_editor = $ref_Editor{$ref};
    my ($previous_id) = $ref_editor->previous_line($id);

    return Text::Editor::Easy::Line->new(
        $ref_editor
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $previous_id,
    );
}

sub line {
    my ($self) = @_;

    my $ref = refaddr $self;
    my ( $id, $num ) = split( /_/, $ref_id{$ref} );
    my $ref_editor = $ref_Editor{$ref};

    return Text::Editor::Easy::Line->new(
        $ref_Editor{$ref}
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $id,
    );
}

sub ref {
    my ($self) = @_;

    return $ref_id{ refaddr $self };
}

sub DESTROY {
    my ($self) = @_;

    my $ref = refaddr $self;

    #print "Destructions de ", $ref_id{ $ref }, ", ", threads->tid, "\n";

    # A revoir : pas rigoureux
    return if ( !$ref );
    if ( defined $ref_Editor{$ref} ) {
        if ( defined $ref_line{ $ref_Editor{$ref} } ) {
            if ( defined $ref_line{ $ref_Editor{$ref} }{ $ref_id{$ref} } ) {
                delete $ref_line{ $ref_Editor{$ref} }{ $ref_id{$ref} };
            }
            delete $ref_line{ $ref_Editor{$ref} };
        }
        delete $ref_Editor{$ref};
    }
    delete $ref_id{$ref};
}

my %sub = (
    'text' => [ 'graphic', \&Text::Editor::Easy::Abstract::display_text ],
    'next_is_same' =>
      [ 'graphic', \&Text::Editor::Easy::Abstract::display_next_is_same ],
    'previous_is_same' =>
      [ 'graphic', \&Text::Editor::Easy::Abstract::display_previous_is_same ],
    'ord'    => [ 'graphic', \&Text::Editor::Easy::Abstract::display_ord ],
    'height' => [ 'graphic', \&Text::Editor::Easy::Abstract::display_height ],
    'middle_ord' => [ 'graphic', \&Text::Editor::Easy::Abstract::display_middle_ord ],
    'number' => [ 'graphic', \&Text::Editor::Easy::Abstract::display_number ],
    'abs'    => [ 'graphic', \&Text::Editor::Easy::Abstract::display_abs ],
    'select' => [ 'graphic', \&Text::Editor::Easy::Abstract::display_select ],
);

sub AUTOLOAD {
    return if our $AUTOLOAD =~ /::DESTROY/;

    my ( $self, @param ) = @_;

    my $what = $AUTOLOAD;
    $what =~ s/^Text::Editor::Easy::Display:://;

    if ( !$sub{$what} ) {
        print
"La méthode $what n'est pas connue de l'objet Text::Editor::Easy::Display\n";
        return;
    }

    my $ref        = refaddr $self;
    my $ref_editor = $ref_Editor{$ref};

    return $ref_editor->ask2( 'display_' . $what, $ref_id{$ref}, @param );
}

# Méthode de paquetage : compte le nombre d'objets "Line" en mémoire pour ce thread
sub count {
    my $total = 0;

    for my $edit ( keys %ref_line ) {
        $total += scalar( keys %{ $ref_line{$edit} } );
    }
    return $total;
}

=head1 FUNCTIONS

=head2 count

=head2 line

=head2 new

=head2 next

=head2 next_in_file

=head2 previous

=head2 previous_in_file

=head2 ref

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
