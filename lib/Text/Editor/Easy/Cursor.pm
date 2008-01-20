package Cursor;

# Ce package n'est qu'une interface orientée objet à des fonctions de Abstract.pm rendues inaccessibles
# car susceptibles de changer

# Les fonctions de Abstract.pm réalisant toutes les méthodes de ce package commencent par "cursor_" puis reprennent
# le nom de la méthode

use strict;
use Scalar::Util qw(refaddr);

#use Easy::Comm;
use Comm;
use Easy::Line;

my %ref_Editor;    # Récupération des queue de comm (par ref + type)

sub new {
    my ( $classe, $ref_editor ) = @_;

    my $cursor = bless \do { my $anonymous_scalar }, $classe;

    my $ref = refaddr $cursor;
    $ref_Editor{$ref} = $ref_editor;

    return $cursor;
}

sub set {
    my ( $self, $position, $line1, $line2 ) = @_;

    #print "Dans cursor set : $position, $line1, $line2\n";
    my $line;
    if ( defined $line1 ) {
        if ( ref $line1 eq 'Line' or ref $line1 eq 'Display' ) {
            $line = $line1->ref;
        }
        elsif ( defined $line2
            and ( ref $line2 eq 'Line' or ref $line2 eq 'Display' ) )
        {
            $line = $line2->ref;
        }
    }

# Ecrasement des valeurs objet "line" et display" éventuelles de l'éventuel hachage $position
    if ( ref $position eq 'HASH' ) {
        if ( $position->{'line'} ) {
            $position->{'line'} = $position->{'line'}->ref;
        }
        if ( $position->{'display'} ) {
            $position->{'display'} = $position->{'display'}->ref;
        }
    }
    my $ref = refaddr $self;
    $ref_Editor{$ref}->cursor_set( $position, $line );
}

my %method = (
    'position_in_display' => \&Abstract::cursor_position_in_display,
    'position_in_text'    => \&Abstract::cursor_position_in_text,
    'abs'                 => \&Abstract::cursor_abs,
    'virtual_abs'         => \&Abstract::cursor_virtual_abs,
    'line'                => \&Abstract::cursor_line,
    'get'                 => \&Abstract::cursor_get,
    'make_visible'        => \&Abstract::cursor_make_visible,
);

sub AUTOLOAD {
    return if our $AUTOLOAD =~ /::DESTROY/;

    my ( $self, @param ) = @_;

    my $what = $AUTOLOAD;
    $what =~ s/^(\w+):://;

    if ( !$method{$what} ) {
        warn "La méthode '$what' n'est pas connue de l'objet Cursor $self\n";
        return;
    }

    my $ref = refaddr $self;
    return $ref_Editor{$ref}->ask2( 'cursor_' . $what, @param );
}

sub line {
    my ($self) = @_;

    my $ref = refaddr $self;
    my $id  = $ref_Editor{$ref}->cursor_line();
    return Line->new(
        $ref_Editor{$ref}
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $id,
    );
}

sub display {
    my ($self) = @_;

    my $ref = refaddr $self;
    my $id  = $ref_Editor{$ref}->cursor_display();

    return Display->new(
        $ref_Editor{$ref}
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $id,
    );
}

1;

