package Text::Editor::Easy;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy - A perl module to edit perl code with syntax highlighting and more.

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

There is neither an IDE written in perl, nor designing tools to take benefit from the fact that perl is highly dynamic. A perl IDE
should allow, indeed, much more than what classical IDE does. This module is the first part of this tremendous task.

This module enables you to manipulate a highly multi-threaded graphical object. Several demos are provided
with this module. To run them and have a glance at the capabilities of this module, launch the perl program
"Editor.pl" which only use "Text::Editor::Easy" objects. See README file for installation instructions.

The demos (9 demos to be tested from the "Editor.pl" program) will show you examples of how to call this module.

    use Text::Editor::Easy;

    my $editor = Text::Editor::Easy->new();
    ...

=head1 EXPORT

This module is object-oriented. Once created, numerous methods are accessible. New methods can be added
on the fly with, why not, new threads associated with these new methods.

Sometimes, you need to consume CPU to achieve your goal. But this shouldn't block the user who interactively
use your graphical module : the interface of the module (especially, method "create_new_server") allows
you to create threads as simply as you create a new variables. See module "Text::Editor::Easy::Comm" for the thread
mecanism.

Threads are not only used for speed. With private variables, they allow you to partition your code. So you don't
have a large program with a huge amount of data to manage but a lot of little threads, specialized in a much simpler
task with fewer variables to manage.
The only remaining problem is how to communicate with all these "working together threads" : the "Text::Editor::Easy::Comm"
provide the solution. All you have to do is define a new thread associated with your new methods. When the new methods
are called (by any thread, the new created one or any other one), your new thread will be called automatically and the response will be automatically
provided to the initial calling thread (in the context of the caller). Easy, isn't it ! Again, see module "Text::Editor::Easy::Comm" for the thread
mecanism.

The graphical part of the module is handled mainly by "Text::Editor::Easy::Asbtract". The "Abstract" name has been given because,
even if I use Tk for now, there is no Tk calls in all the Abstract module. Tk calls are concentrated in "Text::Editor::Easy::Graphic:Tk_Glue"
module : other "Graphic glue" modules are possible. I think of "Gtk", "Console", and why not "Qt" or "OpenGl" ? There is a limited 
communicating object (a "Text::Editor::Easy::Graphic") between the Abstract module and the glue module : this is the interface.
This interface may change a little in order to allow other "Glue module" to be written, but, of course, all graphic glue modules would
have to use the same interface.
You can see the "Text::Editor::Easy" as a super graphical layer above other layers. I imagine a generator where you design an
application in your preferred graphical mode but the generated application could run (maybe in a limited way) in "Console mode".
Constant re-use is the key to hyper-productivity.

=head1 FUNCTIONS

=cut

use Scalar::Util qw(refaddr);
use threads;

use Text::Editor::Easy::Comm;
use Text::Editor::Easy::File_manager;

our %Trace; # Hash to tell modules if they have to make displays or to be silent

my %ref_undo;
my %unique_ref;

use Text::Editor::Easy::Cursor;
use Text::Editor::Easy::Screen;

{

    sub new {
        my ( $classe, $hash_ref ) = @_;

        # Création du "thread modèle", générateur de tous les autres
        if ( my $trace_ref = $hash_ref->{'trace'} ) {

# Hash "%Trace" must be seen by all future created threads but needn't be  a shared hash
# ===> will be duplicated by perl thread creation mecanism
            %Trace = %{$trace_ref};
        }
        Text::Editor::Easy::Comm::verify_model_thread();

        my $editor = bless \do { my $anonymous_scalar }, $classe;

        my $ref = refaddr $editor;
        $unique_ref{$ref} = $ref;

        my $zone = $hash_ref->{'zone'};
        if ( defined $zone and !CORE::ref $zone ) {
            $hash_ref->{'zone'} = Text::Editor::Easy::Zone->named($zone);
        }

        Text::Editor::Easy::Comm::verify_graphic( $hash_ref, $editor, $ref );

        Text::Editor::Easy::Comm::verify_motion_thread( $ref, $hash_ref );

       #return
       #  if ( !defined $ref_Abstract{$ref} );  # On n'est pas dans le process 0

        #$file_name{ $ref } = $hash_ref->{file};

        if ( defined $hash_ref->{'growing_file'} ) {
            print "GROWING FILE ..$hash_ref->{'growing_file'}\n";
        }
        print "Avant appel pour création d'un nouveau thread file_manager\n";

        my ( $init_file, $init_grow, $init_save ) = (
            $hash_ref->{'file'},
            $hash_ref->{'growing_file'},
            $hash_ref->{'save_info'}
        );
        my $file_tid = $editor->create_new_server(
            {
                'use'     => 'Text::Editor::Easy::File_manager',
                'package' => 'Text::Editor::Easy::File_manager',
                'methods' => [
                    'delete_line',
                    'get_line',
                    'get_text_from_ref',
                    'modify_line',
                    'new_line',
                    'next_line',
                    'previous_line',
                    'save_internal',
                    'query_segments',
                    'revert_internal',
                    'read_next',
                    'read_until',
                    'read_until2',
                    'create_ref_current',
                    'init_read',
                    'ref_of_read_next',
                    'save_action',
                    'save_line_number',
                    'get_line_number_from_ref_internal',
                    'get_ref_for_empty_structure',
                    'line_seek_start',
                    'empty_internal',
                    'save_info',
                    'load_info',
                    'close',
                ],
                'object' => [],
                'init'   => [
                    'Text::Editor::Easy::File_manager::init_file_manager',
                    $init_file,
                    $init_grow,
                    $init_save,

                    #$hash_ref->{'file'},
                    #$hash_ref->{'growing_file'},
                    #$hash_ref->{'save_info'},
                ],
                'name' => 'File_manager',
            }
        );

        # Référencement de l'éditeur
        Text::Editor::Easy->reference_editor( $ref, $hash_ref->{'zone'},
            $hash_ref->{'file'}, $hash_ref->{'name'} );

        my $new_editor;

        if ( $hash_ref->{sub} ) {

            # On demande la création d'un thread supplémentaire
            my $thread = $editor->create_client_thread( $hash_ref->{sub} );
            $editor->set_synchronize();
            if ( threads->tid == 0 ) {
                print "Appel de la main loop (méthode new)\n";
                Text::Editor::Easy->manage_event;
                print "Fin de la main loop (méthode new)\n";

                #Text::Editor::Easy::Comm::stop_all_threads;
                Text::Editor::Easy::Comm::untie_print;
                return $editor;
            }
        }
        else {
            $editor->set_synchronize();
        }

        #print "Appel de editor on_top pour zone = ",
        #  $hash_ref->{'zone'}{'name'}, " tid : ", threads->tid, "\n";
        my $focus = $hash_ref->{'focus'};
        if ( !defined $focus ) {
            $editor->on_top($hash_ref);
        }
        elsif ( $focus eq 'yes' ) {
            $editor->focus($hash_ref);
        }
        print "Après appel de editor_on_top\n";
        return $editor;
    }

    sub file_name {
        my ($self) = @_;

        my $ref    = $self->ref;
        my $retour = Text::Editor::Easy->data_file_name($ref);

        #print "RETOUR de file_name : $retour\n";
        return $retour;
    }

    sub name {
        my ($self) = @_;

        my $ref = $self->ref;
        return $self->data_name($ref);
    }
}

sub revert {
    my ( $self, $line_number ) = @_;

#print "Demande de restauration du fichier ", $file_name{ refaddr $self }, "\n";
    my $wait = $self->revert_internal;

    if ( $line_number eq 'end' ) {
        return
          $self->previous_line;    # On renvoie la référence à la dernière ligne
    }
    else {
        return $self->go_to($line_number)
          ;    # On renvoie la référence du numéro de la ligne demadée
    }
}

sub insert_text {
    my ( $self, $line_text, $text, $pos, $insert, $ref ) = @_;

# Attention, pour efficacité, $line_text et $ref sont liés
# Cette fonction devrait rester interne et ne devrait pas être dans l'interface ... sauf
# qu'elle se trouve dans le package Text::Editor::Easy, donc accessible ... à voir

    if ( $ref_undo{ refaddr $self} ) {    # Gestion de l'annulation, à revoir
        my $line_number = $self->get_line_number_from_ref_internal($ref);

        my $replace = "";
        if ( length($line_text) > $pos ) {
            $replace =
              substr( $line_text, $pos, 1 ); # Longueur supérieur à 1 maintenant
        }

        $ref_undo{ refaddr $self}
          ->save_action( $line_number, $pos, $insert, $text, $replace );
    }

    my $start = substr( $line_text, 0, $pos );
    my $end = substr( $line_text, $pos );
    if ($insert) {
        $line_text = $start . $text . $end;
    }
    else {
        if ( length($end) > length($text) ) {
            $line_text = $start . $text . substr( $end, length($text) );
        }
        else {
            $line_text = $start . $text;
        }
    }

    $self->modify_line( $ref, $line_text );
    return $line_text;
}

sub insert_return {
    my ( $self, $text, $pos, $ref ) = @_;

    if ( $ref_undo{ refaddr $self} ) {    # Gestion de l'annulation, à revoir
        my $line_number = $self->get_line_number_from_ref_internal($ref);

#        $ref_undo{refaddr $self}->save_action( $line_number, $pos, $insert, $key, $replace );
    }

    my ( $new_text, $new_ref );
    $new_text =
      substr( $text, $pos )
      ;    # Texte de la nouvelle ligne : c'est ce qu'il y a après le curseur
    $text =
      substr( $text, 0, $pos );    # Texte de la ligne modifiée (ligne tronquée)
    $new_ref = $self->new_line( $ref, "after", $new_text );

    $self->modify_line( $ref, $text );
    return ( $text, $new_text, $new_ref );
}

sub save_action {
    my ( $self, $line_number, $pos, $insert, $key, $replace ) = @_;

    print "Après appel :$line_number:$pos:$insert:$key;$replace:\n";

    #print "Dans save_action :$who:$line_number:$pos:$key:$insert\n";
    $self->append(
        "line $line_number,$pos ,$insert :" . $key . ":, :" . $replace . ":" );
}

sub save {
    my ( $self, $file_name ) = @_;

    $self->save_internal($file_name);

# A revoir dans le principe : il faut référencer ce changement dans Data qui doit générer un nouveau type d'évènement
# Cet évènement doit être catché par le Tab principal qui changera le titre de la fenêtre principale
# Mais Data pourra décider de le faire lui-même (changer le titre) si il n'y a aucune redirection de cet évènement
# et une seule zone (que faire si plusieurs zones sans redirection ?....)

    #if ( $file_name ) {
    #        $self->change_title($file_name);
    #}
}

sub insert_mode {
    my ($self) = @_;

    return $self->ask2('editor_insert_mode');
}

sub set_insert {
    my ($self) = @_;

    return $self->ask2('editor_set_insert');
}

sub set_replace {
    my ($self) = @_;

    return $self->ask2('editor_set_replace');
}

sub regexp {

# entrée :
#        - regexp : expression régulière perl à rechercher
#        - line_start : ligne fichier de début de recherche
#        - pos_start : position de début de la recherche dans la ligne fichier de début de recherche
#        - line_stop : ligne fichier de fin de recherche (si égale à line_start, on fait un tour complet : pas d'arrêt immédiat)
#        - pos_stop : position de fin de la recherche dans la ligne fichier de fin de recherche

    my ( $self, $exp, $options_ref ) = @_;

    return if ( !defined $exp );

    #print "Demande de recherche de $exp\n";
    my $ref;
    my $cursor = $self->cursor;
    my $line   = $options_ref->{'line_start'};
    if ( defined $line ) {
        $ref = $line->ref if ( ref $line eq 'Text::Editor::Easy::Line' );
    }
    if ( !defined $ref ) {
        $line = $cursor->line;
        $ref  = $line->ref;
    }

    #print "LINE $line\n";
    my $text = $self->get_text_from_ref($ref);
    return
      if ( !defined $text )
      ;    # La ligne indiquée a été supprimée ... on ne peut pas s'y référer
           #print "Ligne de départ de la recherche |$text|\n";

    my $pos = $options_ref->{'pos_start'};
    if ( !defined $pos ) {
        $pos = $cursor->get;
    }
    else {    # Vérification de la cohérence
        if ( $pos > length($text) ) {
            $pos = length($text);
        }
    }

    #print "Position de départ de la recherche |$pos|\n";

    my $regexp = qr/$exp/i;
    print "REGEXP $regexp\n";

    my $end_ref;
    my $line_stop;
    if ( defined( $line_stop = $options_ref->{'line_stop'} ) ) {
        if ( ref $line_stop eq 'Text::Editor::Easy::Line' ) {
            $end_ref = $line_stop->ref;
        }
    }
    if ( !defined $line_stop ) {
        $line_stop = $line;
    }

    #print "LINE_STOP : $line_stop\n";
    my $ref_editor = refaddr $self;
    pos($text) = $pos;
    if ( $text =~ m/($regexp)/g ) {
        my $length    = length($1);
        my $end_pos   = pos($text);
        my $start_pos = $end_pos - $length;

#print "Trouvé dans la ligne de la position $start_pos à la position $end_pos\n";

        #print "SELF $self\n";
        my $line = Text::Editor::Easy::Line->new( $self, $ref, );

        return ( $line, $start_pos, $end_pos );
    }

    #print "Pas trouvé à partir de la position souhaitée\n";

    $end_ref = $ref if ( !defined $end_ref );
    my $desc = threads->tid;
    $text =
      $self->read_until2( $desc,
        { 'line_start' => $ref, 'line_stop' => $end_ref } );

    pos($text) = 0;
    while ( defined($text) ) {

        #print "$text\n";
        if ( $text =~ m/($regexp)/g ) {
            my $length    = length($1);
            my $end_pos   = pos($text);
            my $start_pos = $end_pos - $length;

#print "Trouvé dans la ligne de la position $start_pos à la position $end_pos\n";
# Récupération de la référence de la ligne à faire
#print "TEXTE de la ligne trouvée : $text\n";
            my $new_ref = $self->create_ref_current($desc);

            #print "Référence de la ligne trouvée : $new_ref\n";

            my $line = Text::Editor::Easy::Line->new( $self, $new_ref, );
            return ( $line, $start_pos, $end_pos );
        }
        $text = $self->read_until2( $desc, { 'line_stop' => $end_ref } );
    }

    # Début de la ligne $ref à faire ici...

    return;    # Rien trouvé...
}

sub search {
    my ( $self, $exp, $options_ref ) = @_;

    $exp =~ s/\\/\\\\/g;
    $exp =~ s/\//\\\//g;
    $exp =~ s/\(/\\\(/g;
    $exp =~ s/\[/\\\[/g;
    $exp =~ s/\{/\\\{/g;
    $exp =~ s/\)/\\\)/g;
    $exp =~ s/\]/\\\]/g;
    $exp =~ s/\}/\\\}/g;
    $exp =~ s/\./\\\./g;
    $exp =~ s/\^/\\\^/g;
    $exp =~ s/\$/\\\$/g;

    return $self->regexp( $exp, $options_ref );
}

sub next_search {
    my ($self) = @_;

    my $ref_editor = refaddr $self;
    my $hash_ref   = $self->ask2('load_search');

    return if ( !defined $hash_ref );
    my $ref_start = $hash_ref->{'line_start'};
    $hash_ref->{'line_start'} =
      Text::Editor::Easy::Line->new( $unique_ref{$ref_editor}, $ref_start, );
    my $ref_stop = $hash_ref->{'line_stop'};
    $hash_ref->{'line_stop'} =
      Text::Editor::Easy::Line->new( $unique_ref{$ref_editor}, $ref_stop, );

    my ( $line, $start, $end ) = $self->regexp( $hash_ref->{'exp'}, $hash_ref );
    if ($line) {
        $self->display($line);
        $self->cursor->set( $end, $line );
    }
}

sub number {

# Horrible sub not yet optimized : very, very long ! So lazy mode (return if anything_for_me) for server thread
# Still longer as all method calls are traced and one method call is made for each single line of the file read
# Will be integrated in File_manager.pm (only one call) and optimized
    my ( $self, $line ) = @_;

    my $desc = threads->tid;
    $self->init_read($desc);
    my $text = $self->read_next($desc);

    my $current;
    while ( defined($text) ) {
        $current += 1;
        if ( $current == $line ) {
            my $new_ref = $self->create_ref_current($desc);
            $self->save_line_number( $desc, $new_ref, $line );
            my $ref = refaddr $self;
            return Text::Editor::Easy::Line->new( $self, $new_ref, );
        }
        return if ( anything_for_me() );
        $text = $self->read_next($desc);
    }

# La ligne n'a pas été trouvée : elle n'existe pas (pas assez de lignes dans le fichier)
    return;
}

sub get_line_number_from_ref {
    my ( $self, $ref ) = @_;

    $| = 1;

    #print "Recherche du numéro de la ligne ayant pour référence $ref\n";
    my $current = $self->get_line_number_from_ref_internal($ref);
    if ($current) {
        return $current;
    }
    my $desc        = threads->tid;
    my $ok          = $self->init_read($desc);
    my $current_ref = $self->ref_of_read_next($desc);
    while ( defined($current_ref) ) {

        #while ( defined ($ref)  ) {
        $current += 1;
        if ( $current_ref == $ref ) {
            return $current;
        }
        $current_ref = $self->ref_of_read_next($desc);
    }
    return;
}

sub append {
    my ( $self, $text ) = @_;

    my ( $ref, $new_text ) = $self->previous_line();
    my $OK = $self->new_line( $ref, "after", $text );
}

sub AUTOLOAD {
    return if our $AUTOLOAD =~ /::DESTROY/;

    my ( $self, @param ) = @_;

    my $what = $AUTOLOAD;
    $what =~ s/^Text::Editor::Easy:://;
    $what =~ s/^Async:://;
    print( "Dans AUTOLOAD  |", $self->file_name, "|$self|", $self->ref, "|\n" )
      if ( $what eq 'focus' );

    return Text::Editor::Easy::Comm::ask2( $self, $what, @param );
}

sub delete_key {
    my ( $self, $text, $pos, $ref ) = @_;

    if ( $pos == length($text) ) {

        # Caractère supprimé : <Return>
        my ( $next_ref, $next_text ) = $self->next_line($ref);

        $text .= $next_text;

        $self->modify_line( $ref, $text );

        $self->delete_line($next_ref);
        my $concat = "yes";
        return ( $text, $concat );
    }
    else {
        $text = substr( $text, 0, $pos ) . substr( $text, $pos + 1 );

        $self->modify_line( $ref, $text );
        return ( $text, "false" );    # $concat vaut "false"
    }
}

sub erase_text {                      # On supprime un ou plusieurs caractères
    my ( $self, $number, $text, $pos, $ref ) = @_;

    if ( length($text) - $pos > $number ) {
        $text = substr( $text, 0, $pos ) . substr( $text, $pos + $number );

        $self->modify_line( $ref, $text );
        return ( $text, "false" );    # $concat vaut "false"
    }
    else {
        $text = substr( $text, 0, $pos );
        $self->modify_line( $ref, $text );
        return ( $text, "false" );    # $concat vaut "false"
    }
}

my %cursor;                           # Référence au "sous-objet" cursor

sub cursor {
    my ($self) = @_;

    my $ref    = refaddr $self;
    my $cursor = $cursor{$ref};
    return $cursor if ($cursor);

    $cursor = Text::Editor::Easy::Cursor->new($self);

    $cursor{$ref} = $cursor;
    return $cursor;
}

my %screen;    # Référence au "sous-objet" cursor

sub screen {
    my ($self) = @_;

    my $ref    = refaddr $self;
    my $screen = $screen{$ref};
    return $screen if ($screen);

    $screen = Text::Editor::Easy::Screen->new($self);

    $screen{$ref} = $screen;
    return $screen;
}

# Méthode insert : renvoi d'objets "Line" au lieu de références numériques (cas du wantarray)
sub insert {
    my ( $self, @param ) = @_;

    my $ref = refaddr $self;

    if ( !wantarray ) {
        return $self->ask2( 'insert', @param );
    }
    elsif ( CORE::ref($self) eq 'Text::Editor::Easy::Async' )
    {    # Appel asynchrone, insert ne renvoie pas une référence de ligne
        return $self->ask2( 'insert', @param );
    }
    else {
        my @refs = $self->ask2( 'insert', @param );
        my @lines;
        for (@refs) {

# Création d'un objet ligne pour chaque référence (dans le thread de l'appelant)
            push @lines, Text::Editor::Easy::Line->new(

#$unique_ref{ $ref },         # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
                $self,
                $_,
            );
        }
        return @lines;
    }
}

sub display {
    my ( $self, $line, $options_ref ) = @_;

    my $ref = refaddr $self;

    #print $line->ref, "\n";

    $self->ask2( 'display', $line->ref, $options_ref );
}

sub last {
    my ($self) = @_;

    my ($id) = $self->previous_line;

    return Text::Editor::Easy::Line->new( $self, $id, );
}

sub first {
    my ($self) = @_;

    my ( $id, $text ) = $self->next_line;

    print "Dans first : $self|", $self->get_unique_ref, "|$id|$text|\n";
    return Text::Editor::Easy::Line->new(
        $self
        , # Cette référence n'est renseignée que pour l'objet editeur du thread principal (tid == 0)
        $id,
    );
}

sub get_unique_ref {
    my ($self) = @_;

    return $unique_ref{ refaddr $self };
}

sub reference {
    my ( $self, $unique_ref ) = @_;

    return if ( !defined $unique_ref );    # Impossible de référencer undef

# %unique_ref de Text::Editor::Easy.pm doit disparaître au profit de %com_unique de Text::Editor::Easy::Comm
# ==> Migration à finaliser
    $unique_ref{ refaddr $self } = $unique_ref;
    $self->set_ref($unique_ref);
}

# Ecrasement de la méthode async du package thread mais pas moyen de la
# désimporter (no threads 'async') et pas de meilleur nom que async...
# ==> Avertissement prototype mismatch
no warnings;

sub async {
    my ($self) = @_;

    my $async = bless \do { my $anonymous_scalar }, 'Text::Editor::Easy::Async';
    $unique_ref{ refaddr $async} = $unique_ref{ refaddr $self};
    return $async;
}
use warnings;

sub slurp {
    my ($self) = @_;

    # This function is not safe in a multi-thread environnement
    # But if you know what you are doing...
    #print "Dans slurp de $self\n";
    my $file;

    my $number = 0;
    my $line   = $self->first;
    while ($line) {
        $number += 1;
        $file .= $line->text . "\n";
        $line = $line->next;
    }

    #print "Total lignes lues : $number\n";
    return $file;

}

#sub print_self {
#        my ( $self ) = @_;
#
#        print "SELF $self, ref self = ", CORE::ref($self), "\n";
#}

sub get_in_zone {
    my ( $self, $zone, $number ) = @_;

    my @ref = Text::Editor::Easy->list_in_zone($zone);
    if ( scalar @ref < $number + 1 ) {
        return;
    }
    my $editor = bless \do { my $anonymous_scalar }, "Text::Editor::Easy";
    $editor->reference( $ref[$number] );
    return $editor;
}

sub whose_name {
    my ( $self, $name ) = @_;

    my $ref = Text::Editor::Easy->data_get_editor_from_name($name);
    if ($ref) {

        #print "Référence récupérée de data |$ref|\n";
        my $editor = bless \do { my $anonymous_scalar }, "Text::Editor::Easy";
        $editor->reference($ref);
        return $editor;
    }
    return;
}

sub whose_file_name {
    my ( $self, $file_name ) = @_;

    my $ref = Text::Editor::Easy->data_get_editor_from_file_name($file_name);
    if ($ref) {
        my $editor = bless \do { my $anonymous_scalar }, "Text::Editor::Easy";
        $editor->reference($ref);
        return $editor;
    }
    return;
}

sub substitute_eval_with_file {
    my ( $self, $file ) = @_;

    return if ( !defined $file );

    # Les eval sont comptés par thread
    eval "{{;";
    my $message = $@;
    my $number  = 0;
    if ( $message =~ /eval (\d+)/ ) {
        $number = $1;

        #print "NUMBER = $number\n";
    }
    Text::Editor::Easy->data_substitute_eval_with_file( $file, $number + 1 );
}

package Text::Editor::Easy::Zone;
use Scalar::Util qw(refaddr);

# A modifier en un référence de scalaire...
sub new {
    my ( $classe, $hash_ref ) = @_;

    my $zone = bless $hash_ref, $classe;
    my $name = $hash_ref->{'name'};
    if ( defined $name ) {

        # le thread Data n'est peut être pas opérationnel
        #Text::Editor::Easy::Async->reference_zone($hash_ref);
        Text::Editor::Easy->reference_zone($hash_ref);
    }
    if ( my $new_hash_ref = $hash_ref->{'on_top_editor_change'} ) {
        Text::Editor::Easy->reference_zone_event( $name, 'on_top_editor_change',
            $new_hash_ref, undef );
    }
    return $zone;
}

sub named {
    my ( $self, $name ) = @_;

    return if ( !defined $name );
    return Text::Editor::Easy->zone_named($name);
}

sub list {
    my ($self) = @_;

    return Text::Editor::Easy->zone_list;
}

package Text::Editor::Easy::Async;
our @ISA = 'Text::Editor::Easy';

=head1 FUNCTIONS

=head2 append

=head2 cursor

=head2 delete_key

=head2 display

=head2 enter

=head2 erase

=head2 erase_text

=head2 file_name

=head2 first

=head2 get_displayed_editor

=head2 get_in_zone

=head2 get_line_number_from_ref

=head2 get_unique_ref

=head2 insert

=head2 insert_mode

=head2 insert_return

=head2 insert_text

=head2 last

=head2 manage_event

=head2 name

=head2 new

=head2 next_search

=head2 number

=head2 reference

=head2 regexp

=head2 revert

=head2 save

=head2 save_action

=head2 screen

=head2 search

=head2 set_insert

=head2 set_replace

=head2 slurp

=head2 substitute_eval_with_file

=head2 whose_file_name

=head2 whose_name

=cut

=head1 AUTHOR

Sebastien Grommier, C<< <sgrommier at free.fr> >>

=head1 BUGS

This module is moving fast. Bugs are not yet managed.

Maybe you'd like to know that I writed this Editor from scratch. I didn't take a single line to any existing editor. The very few
editors I had a glance at were too tightly linked to a graphical user interface. Maybe you obtain faster execution results like that,
but you do not recycle anything. I wanted an engine which you could plug to, a little like perl has been designed.

=head1 SUPPORT

The best support for this module is the "Editor.pl" program. Read the README file to install the module
and launch the "Editor.pl" program.

To be in an editor allows you to display information interactively. Full documentation will be accessible from here with version 1.0.

In future versions, there will be a "video mode" : perl code to make the images and ogg files for the sound. These videos will cost almost
nothing in space compared to actual compressed videos (the sound will be, by far, the heaviest part of them).

All softwares should include "help videos" like what I describe : it would prove that what you are about to use is easy to manipulate and it
would give you a quick interactive glance of all the possibilities. But most softwares are awfully limited if you want to use them in a
"programmatic way" (yet, interactively, it's often very pretty, but I don't mind : I want POWER !). In my ill productive point of view,
most softwares should be written again...

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;    # End of Text::Editor::Easy
