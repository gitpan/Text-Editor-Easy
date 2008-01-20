package Line;

# Ce package n'est qu'une interface orientée objet à des fonctions de File_manager.pm rendues inaccessibles (ne se trouvent
# pas dans les hachages gérés par AUTOLOAD de Editor) car susceptibles de changer

# Les fonctions de File_manager.pm réalisant toutes les méthodes de ce package commencent par "line_" puis reprennent
# le nom de la méthode

use strict;
use Scalar::Util qw(refaddr weaken);
use Devel::Size qw(size total_size);

#use Easy::Comm;
use Comm;
use Easy::Display;

# 2 attributs pour un objet "Line"
my %ref_Editor;    # Une ligne appartient à un éditeur unique
my %ref_id;        # A une ligne, correspond un identifiant

# Recherche d'un identifiant pour un éditeur donné
my %ref_line
  ; # Il y aura autant de hachage de références que de threads demandeurs de lignes

# Remarque : les hachages précédents ne sont pas 'shared' : il y en a autant que de threads

sub new {
    my ( $classe, $editor, $ref_id ) = @_;

    return if ( !$ref_id );

    my $ref_Editor = $editor->ref;
    my $line       = $ref_line{$ref_Editor}{$ref_id};
    if ($line) {
        return $line;
    }
    $line = bless \do { my $anonymous_scalar }, $classe;

    my $ref = refaddr $line;

    #print "REf EDITOR de $ref = $editor\n";
    $ref_Editor{$ref}               = $editor;
    $ref_id{$ref}                   = $ref_id;
    $ref_line{$ref_Editor}{$ref_id} = $line;
    weaken $ref_line{$ref_Editor}{$ref_id};

    return $line;
}

sub text {
    my ($self) = @_;

    my $ref    = refaddr $self;
    my $editor = $ref_Editor{$ref};
    return $editor->get_text_from_ref( $ref_id{$ref} );
}

sub next {
    my ($self) = @_;

    my $ref       = refaddr $self;
    my $editor    = $ref_Editor{$ref};
    my ($next_id) = $editor->next_line( $ref_id{$ref} );
    return Line->new(
        $editor
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $next_id,
    );
}

sub previous {
    my ($self) = @_;

    my $ref           = refaddr $self;
    my $editor        = $ref_Editor{$ref};
    my ($previous_id) = $editor->previous_line( $ref_id{$ref} );
    return Line->new(
        $editor
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $previous_id,
    );
}

sub seek_start {
    my ($self) = @_;

    my $ref    = refaddr $self;
    my $editor = $ref_Editor{$ref};
    return $editor->line_seek_start( $ref_id{$ref} );
}

sub ref {
    my ($self) = @_;

    return $ref_id{ refaddr $self };
}

sub DESTROY {
    my ($self) = @_;

    my $ref = refaddr $self;
    delete $ref_line{ $ref_Editor{$ref} }{ $ref_id{$ref} };
    delete $ref_Editor{$ref};
    delete $ref_id{$ref};
}

sub displayed {
    my ( $self, @param ) = @_;

    my $ref        = refaddr $self;
    my $ref_editor = $ref_Editor{$ref};

    #print "ref_editor = $ref_editor, $ref\n";
    my @ref = $ref_editor->line_displayed( $ref_id{$ref} );

    if (wantarray) {

        # Création des "lignes d'écran"
        my @display;
        for (@ref) {
            push @display, Display->new(
                $ref_editor
                , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
                $_,
            );
        }
        return @display;
    }
    else {
        return scalar @ref;
    }
}

sub set {
    my ( $self, $text ) = @_;

    my $ref = refaddr $self;
    print "Dans line set, text = $ref|", $ref_id{$ref}, "$text\n";

    # Vérifier que la ligne n'est pas affichée :
    # ==> appel obligatoire à Abstract
    # ==> si pas affichée, appel modify_line
    my $editor = $ref_Editor{$ref};
    return $editor->modify_line( $ref_id{$ref} );
}

my %sub = ( 'select' => [ 'graphic', \&Abstract::line_select ], );

sub AUTOLOAD {
    return if our $AUTOLOAD =~ /::DESTROY/;

    my ( $self, @param ) = @_;

    my $what = $AUTOLOAD;
    $what =~ s/^(\w+):://;

    if ( !$sub{$what} ) {
        print STDERR "La méthode $what n'est pas connue de l'objet Line\n";
        return;
    }

    my $ref        = refaddr $self;
    my $ref_editor = $ref_Editor{$ref};

    return $ref_editor->ask2( 'line_' . $what, $ref_id{$ref}, @param );
}

# Méthode de paquetage : compte le nombre d'objets "Line" en mémoire pour ce thread
sub count {
    my $total = 0;

    for my $edit ( keys %ref_line ) {
        $total += scalar( keys %{ $ref_line{$edit} } );
    }
    return $total;
}

sub linesize {
    my ($self) = @_;

    print "TAILLE ref_Editor : ", total_size( \%ref_Editor ), "\n";
    print "TAILLE ref_id     : ", total_size( \%ref_id ),     "\n";
    print "TAILLE ref_line   : ", total_size( \%ref_line ),   "\n";
}
1;
