package Screen;
use Easy::Line;

# Ce package n'est qu'une interface orientée objet à des fonctions de Abstract.pm rendues inaccessibles (ne se trouvent
# pas dans les hachages gérés par AUTOLOAD de Editor) car susceptibles de changer

# Les fonctions de Abstract.pm réalisant toutes les méthodes de ce package commencent par "screen_" puis reprennent
# le nom de la méthode

use strict;
use Scalar::Util qw(refaddr);

#use Easy::Comm;
use Comm;

use threads;
use threads::shared;

my %ref_Editor;    # Récupération des queue de comm (par ref + type)

sub new {
    my ( $classe, $ref_editor ) = @_;

    my $screen = bless \do { my $anonymous_scalar }, $classe;

    my $ref = refaddr $screen;
    $ref_Editor{$ref} = $ref_editor;

    return $screen;
}

sub first {
    my ($self) = @_;

    my $ref = refaddr $self;
    my $id  = $ref_Editor{$ref}->screen_first;
    return Display->new(
        $ref_Editor{$ref}
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $id,
    );
}

sub last {
    my ($self) = @_;

    my $ref = refaddr $self;
    my $id  = $ref_Editor{$ref}->screen_last;
    return Display->new(
        $ref_Editor{$ref}
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $id,
    );
}

sub number {
    my ( $self, $number ) = @_;

    my $ref = refaddr $self;
    my $id  = $ref_Editor{$ref}->screen_number($number);
    return $id if ( $id !~ /_/ );
    return Display->new(
        $ref_Editor{$ref}
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $id,
    );
}

my %method = (

    # Les 2 méthodes suivantes doivent être virées (liées à un objet texte)
    'font_height' => \&Abstract::screen_font_height,
    'line_height' => \&Abstract::screen_line_height,

    'height'       => \&Abstract::screen_height,
    'y_offset'     => \&Abstract::screen_y_offset,
    'x_offset'     => \&Abstract::screen_x_offset,
    'margin'       => \&Abstract::screen_margin,
    'width'        => \&Abstract::screen_width,
    'set_width'    => \&Abstract::screen_set_width,
    'set_height'   => \&Abstract::screen_set_height,
    'set_x_corner' => \&Abstract::screen_set_x_corner,
    'set_y_corner' => \&Abstract::screen_set_y_corner,
    'move'         => \&Abstract::screen_move,
    'wrap'         => \&Abstract::screen_wrap,
    'set_wrap'     => \&Abstract::screen_set_wrap,
    'unset_wrap'   => \&Abstract::screen_unset_wrap,

    # Autres méthodes à développer
    # set_geometry        avec hachage de correspondance
    # get_geometry       ( hachage de correspondance )
    # get_title
    # set_title
);

sub AUTOLOAD {
    return if our $AUTOLOAD =~ /::DESTROY/;

    my ( $self, @param ) = @_;

    my $what = $AUTOLOAD;
    $what =~ s/^(\w+):://;

    if ( !$method{$what} ) {
        print "La méthode $what n'est pas connue de l'objet Screen\n";
        return;
    }

    return $ref_Editor{ refaddr $self }->ask2( 'screen_' . $what, @param );
}

1;

