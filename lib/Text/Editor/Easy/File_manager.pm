package Text::Editor::Easy::File_manager;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::File_manager - Management of the data that is edited.

=head1 VERSION

Version 0.2

=cut

our $VERSION = '0.2';

=head1 SYNOPSIS

By complexity order, this module, I think, is the third.

If you create a "Text::Editor::Easy" object, this module will be called very often (but you don't even have to know 
that this module exists, thanks to "Text::Editor::Easy::Comm").

It manages "file" or "memory" data in a very lazy way. Too lazy for now. I'm going to ask more to this module
soon.

You can read data from the start of the file, from the bottom, from the midde, ... from where you want in fact.
I just use the "seek" instruction for that. You can read a line, its next or its previous.

This module is lazy because it doesn't read the file even once. I will change this to compute the line number and
put some references in order to access faster to a given line number (with an interuptible long task at start).

If you modify a line that is on a file, well it has to work (reluctantly !). It puts the line in memory and will never
fetch this line any more from the file.

When you save a modified file, it reads data from the initial file (for non-modified lines) or from memory 
(when modified), create a new file and when finished, move the new file to the initial.

There is a little drawback : you need more disk space than an Editor which would load everything into memory.
The big advantage is that this module don't waste time reading uninteresting data : it reads only on the file the
part you can see on the screen. Said like that, this seems obvious not to ask more to your computer. But most
Editors think it's useful to read everything (well, it's surely because most programmers don't want to manage the
complexity !). And when the file is huge, your entire system blocks. This seems stupid, because who is able
to watch several Go of text data in a single day ? Well, I should say in a single year : but, nowadays, with 
cheap hard drive, most people don't know any more what can contain 1 single Go of text data.

=cut

#use Text::Editor::Easy::Comm; Interruptible task not yet done, so Comm is still useless

use Scalar::Util qw(refaddr);
use Data::Dump qw(dump);
use Devel::Size qw(size total_size);

use constant {
    FILE_DESC    => 0, # Descripteur de fichier, rattaché à un segment container
    LINE_TO_SEEK => 1,
    SEEK_TO_LINE => 2,
    MODIFIED     => 3, # A supprimer
    WHO          => 4,
    REF          => 5, # Garde le numéro de la dernière référence donnée
    HASH_REF     => 6
    , # Associe un simple entier à une référence de tableau correspondant à la ligne
    ROOT        => 7,
    NO_CREATION => 8,    # Si true, pas de création de lignes
    DESC        => 9
    , # Sauvegarde des lignes en cours de lecture par la procédure read_next (sauvegarde
     # par thread, identique à un DESCripteur de fichier noyau : ligne, segments précédent et suivant)
    UNDO        => 10,
    LAST_UPDATE => 11,
    GROWING     => 12,
    TO_DELETE   => 13,
    SAVED_INFO  => 14,

    UNTIL => 0, # Mémorisation de l'appel initial à until (procédure read_until)
                # On mémorise ici la référence  ne pas dépasser

    # Lignes de fichier
    SEEK_START => 1,
    SEEK_END   => 2,
    NEXT       => 3,
    PREVIOUS   => 4,

    # REF => 5,
    PARENT      => 6,
    TYPE        => 7,    # "container","empty", "line"
    FIRST       => 8,
    LAST        => 9,
    TEXT        => 10,
    DIRTY       => 11,
    FILE_NAME   => 12,
    LINE_NUMBER => 13,

    # Gestion de LINE_NUMBER
    LAST_COMPUTE => 0,
    NUMBER       => 1,
};

sub init_file_manager {

    #my ( $editor, $file_name, $growing_file, $save_info ) = @_;
    my ( $file_manager_ref, $reference, $file_name, $growing_file, $save_info )
      = @_;

#print "Dans init_file_manager tid ", threads-> tid, " $file_manager_ref|$reference|$file_name\n";

    my $file_desc;

    #my $file_manager_ref;

    my $segment_ref;    # Segment père de tous les segments

    if ($file_name) {
        $segment_ref->[FILE_NAME] = $file_name;
        if ( open( $file_desc, $file_name ) ) {

            # Le fichier existe
            $segment_ref->[SEEK_START] = 0;
            my $seek_end = ( stat $file_desc )[7];
            $segment_ref->[SEEK_END]       = $seek_end;
            $segment_ref->[FILE_DESC]      = $file_desc;
            $file_manager_ref->[FILE_DESC] = $file_desc;
            $file_manager_ref->[SEEK_END]  = $seek_end;
        }
        else {
            $segment_ref->[SEEK_END]      = 0;
            $segment_ref->[SEEK_START]    = 0;
            $file_manager_ref->[SEEK_END] = 0;
        }

    }
    $segment_ref->[TYPE] = "container";

    $file_manager_ref->[ROOT] = $segment_ref;
    if ( defined $save_info ) {

        #	print "Save info = " dump ($save_info), "\n";
        $file_manager_ref->[SAVED_INFO] = $save_info;
    }

    $file_manager_ref->[LAST_UPDATE] = 1;
    if ( defined $growing_file ) {
        $file_manager_ref->[GROWING] = $growing_file;
    }
    else {    #Avoid warnings
        $file_manager_ref->[GROWING] = 0;
    }

    return $file_manager_ref;
}

sub display {
    my ($self) = @_;

    print dump($self);
    return;
}

sub new_line {
    my ( $self, $ref, $where, $text ) = @_;

    $self->[DIRTY] = 1;
    $self->[LAST_UPDATE] += 1;

    my $line_ref = $self->[HASH_REF]{$ref};

    my $new_line_ref;
    $new_line_ref->[TEXT] = $text;
    my $new_ref = get_next_ref($self);
    $new_line_ref->[REF]        = $new_ref;
    $new_line_ref->[PARENT]     = $line_ref->[PARENT];
    $new_line_ref->[TYPE]       = "line";
    $self->[HASH_REF]{$new_ref} = $new_line_ref;

    if ( $where eq "after" ) {
        $new_line_ref->[SEEK_START] = $line_ref->[SEEK_END];
        $new_line_ref->[SEEK_END]   = $line_ref->[SEEK_END];
        $new_line_ref->[PREVIOUS]   = $line_ref;
        $new_line_ref->[NEXT]       = $line_ref->[NEXT];
        $line_ref->[NEXT]           = $new_line_ref;
        if ( $new_line_ref->[NEXT] ) {
            $new_line_ref->[NEXT][PREVIOUS] = $new_line_ref;
        }
        if ( $line_ref->[PARENT][LAST] == $line_ref ) {
            $line_ref->[PARENT][LAST] = $new_line_ref;
        }
    }
    else {    # $where eq "before"
        $new_line_ref->[SEEK_START] = $line_ref->[SEEK_START];
        $new_line_ref->[SEEK_END]   = $line_ref->[SEEK_START];
        $new_line_ref->[NEXT]       = $line_ref;
        $new_line_ref->[PREVIOUS]   = $line_ref->[PREVIOUS];
        $line_ref->[PREVIOUS]       = $new_line_ref;

        #print "REF de new_line_ref $new_ref, NEXT = $line_ref->[NEXT][REF]\n";
        if ( $new_line_ref->[PREVIOUS] ) {
            $new_line_ref->[PREVIOUS][NEXT] = $new_line_ref;
        }
        if ( $line_ref->[PARENT][FIRST] == $line_ref ) {
            $line_ref->[PARENT][FIRST] = $new_line_ref;
        }
    }
    return $new_ref;
}

sub modify_line {
    my ( $self, $ref, $text ) = @_;

    $self->[DIRTY] = 1;

    my $line_ref = $self->[HASH_REF]{$ref};
    return if ( !defined $line_ref );
    $line_ref->[TEXT] = $text;    # Valeur de retour, texte forcé
}

sub delete_line {
    my ( $self, $ref ) = @_;

    $self->[DIRTY] = 1;
    $self->[LAST_UPDATE] += 1;

    # Travail sale, on met à "empty" le segment de ligne correspondant
    # Il faudrait éventuellement concaténer avec un autre segment empty contigü
    # et aussi modifier le nombre de lignes résultant du segment PARENT...
    my $line_ref = $self->[HASH_REF]{$ref};
    $line_ref->[TYPE] = "empty";
    delete $self->[HASH_REF]{$ref};
}

sub read_until {
    my ( $self, $who, $ref ) = @_;

    my $line_ref;
    if ( !$self->[DESC]{$who} or $ref ) {

        #print "Premier accès pour read_until who = $who\n";
        if ( !$ref ) {
            print STDERR
              "Appel incorrect à read_until : position perdue sans référence\n";
        }
        $line_ref = $self->[HASH_REF]{$ref};
        $self->[DESC]{$who}[REF] = $line_ref;
    }
    if ($ref) {
        $self->[DESC]{$who}[UNTIL] = $ref;
    }
    $ref = $self->[DESC]{$who}[UNTIL];

    $line_ref = read_line_ref( $self, $who );
    if ( !$line_ref ) {    # On est à la fin du fichier
        $line_ref =
          read_line_ref( $self, $who )
          ; # Nouvelle lecture et recréation de $self->[DESC]{$who} par read_line_ref
        $self->[DESC]{$who}[UNTIL] = $ref;
    }
    if ( $line_ref->[REF] and $line_ref->[REF] == $self->[DESC]{$who}[UNTIL] ) {

        # "Démémorisation"
        init_read( $self, $who );

        #undef $self->[DESC]{$who};
        return;    # Fin du read_until
    }
    return $line_ref->[TEXT];
}

sub read_until2 {
    my ( $self, $who, $options_ref ) = @_;

    my $line_ref;
    if ( !$self->[DESC]{$who} or $options_ref->{'line_start'} ) {
        my $start_ref = $options_ref->{'line_start'};
        if ( defined $start_ref ) {
            $line_ref = read_line_ref( $self, $who, $start_ref );
        }
        else {
            $line_ref = read_line_ref( $self, $who );
        }
    }
	else {
		$line_ref = read_line_ref( $self, $who );
    }
    if ( !$line_ref ) {    # On est à la fin du fichier
        $line_ref = read_line_ref( $self, $who );
    }
    if ( !$line_ref ) {
			return; #A la fin du fichier
	}
	my $stop_ref = $options_ref->{'line_stop'};
    if ( $line_ref->[REF] and $stop_ref and $line_ref->[REF] == $stop_ref ) {

        # "Démémorisation"
        init_read( $self, $who );

        #undef $self->[DESC]{$who};
        return;                  # Fin du read_until
    }
    return $line_ref->[TEXT];
}

sub create_ref_current {
    my ( $self, $who ) = @_;

    my $line_ref = $self->[DESC]{$who}[REF];
    my $ref      = $line_ref->[REF];
    if ( !$line_ref->[REF] ) {
        $ref = save_line( $self, $line_ref );
    }
    return $ref;
}

sub save_line_number {
    my ( $self, $who, $ref, $line_number ) = @_;

    #my ( $self, $ref, $line_number ) = @_;

    my $line_ref = $self->[DESC]{$who}[REF];
    $line_ref->[LINE_NUMBER][LAST_COMPUTE] = $self->[LAST_UPDATE];
    $line_ref->[LINE_NUMBER][NUMBER]       = $line_number;
    return;
}

sub get_line_number_from_ref_internal {
    my ( $self, $who, $ref ) = @_;

    $| = 1;
    my $line_ref = $self->[DESC]{$who}[REF];
    if (    $line_ref->[LINE_NUMBER]
        and $self->[LAST_UPDATE] <= $line_ref->[LINE_NUMBER][LAST_COMPUTE] )
    {
        return $line_ref->[LINE_NUMBER][NUMBER];
    }
    return;
}

sub prev_line {
    my ( $segment_ref, $pos ) = @_;

    #print "Début de prev_line $pos\n";
    if ( !$segment_ref->[FILE_DESC] ) {

        # Pas de fichier connu, donc on est au début du fichier
        return ( 0, "" );
    }
    seek $segment_ref->[FILE_DESC], $pos, 0;
    my $end_position = tell $segment_ref->[FILE_DESC];
    return ( 0, "" ) if ( !$end_position );    # On est au début du fichier

    #print "position > 0\n";
    my $decrement = 0;

    # But de la boucle, être sûr de lire une ligne entière
  SEEK: while ( tell $segment_ref->[FILE_DESC] == $end_position ) {
        $decrement += 50;
        if ( $decrement < $pos ) {
            seek $segment_ref->[FILE_DESC], $pos - $decrement, 0;
            readline $segment_ref->[FILE_DESC];
        }
        else {
            seek $segment_ref->[FILE_DESC], 0, 0;
            my $start_position = 0;
            while ( tell $segment_ref->[FILE_DESC] != $end_position ) {
                $start_position = tell $segment_ref->[FILE_DESC];
                readline $segment_ref->[FILE_DESC];
            }
            seek $segment_ref->[FILE_DESC], $start_position, 0;
            last SEEK;
        }
    }

    #print "Après première boucle : $end_position\n";
    my $text;
    while ( tell $segment_ref->[FILE_DESC] != $end_position ) {
        $pos = tell $segment_ref->[FILE_DESC];

        #print "pos = $pos\n";
        $text = readline $segment_ref->[FILE_DESC];

        #print tell  $segment_ref->[FILE_DESC], "\n";
    }

    #print "Fin de prev_line $pos, $text\n";
    return ( $pos, $text );
}

sub get_text_from_ref {
    my ( $self, $ref ) = @_;

    my $line_ref = $self->[HASH_REF]{$ref};
    return if ( !defined $line_ref );
    my ( undef, $text ) = get_ref_and_text_from_line_ref($line_ref);

    return $text;
}

sub query_segments {
    my ($self) = @_;

    for my $ref ( sort { $a <=> $b } keys %{ $self->[HASH_REF] } ) {
        my $line_ref = $self->[HASH_REF]{$ref};
        print
"$ref:$line_ref->[TYPE]:$line_ref->[SEEK_START]:$line_ref->[SEEK_END]:$line_ref->[TEXT]:\n";
    }
}

sub close {
    my ($self) = @_;

    CORE::close $self->[ROOT][FILE_DESC];
}

sub save_internal {

# Cette fonction est bloquante : à réécrire : sauvegarde rapide la structure, puis création d'un thread de sauvegarde avec doublage
# des saisies dans un tampon, rattrapage du tampon sur la nouvelle structure après la fin de la sauvegarde puis bascule sur la nouvelle structure
    my ( $self, $file_name ) = @_;

    return if ( !$self->[DIRTY] );    # Rien n'a été modifié, sauvegarde inutile

    if ( !$file_name ) {
        if ( !$self->[ROOT][FILE_NAME] ) {
            print STDERR "Sauvegarde impossible : aucun nom disponible\n";
            return;
        }
        $file_name = $self->[ROOT][FILE_NAME];
    }

    my $temp_file_name = $file_name . "_tmp_";
    my $new_root_ref;    # Future arborescence (références récupérées)
    $new_root_ref->[SEEK_START] = 0;
    my $new_file_desc;
    open( $new_file_desc, ">$temp_file_name" )
      or die "Impossible d'ouvrir $temp_file_name : $!\n";
    $new_root_ref->[FILE_DESC] = $new_file_desc;
    $new_root_ref->[FILE_NAME] = $self->[ROOT][FILE_NAME];
    $new_root_ref->[TYPE]      = "container";
    my %hash;

    my $previous_line_ref;
    while ( my $line_ref = read_line_ref($self) ) {
        if ($previous_line_ref) {
            print {$new_file_desc} "\n";
            if ( $previous_line_ref->[REF] ) {
                $previous_line_ref->[SEEK_END] = tell $new_file_desc;
            }
        }

        if ( $line_ref->[REF] ) {

# Duplication de la ligne pour ne pas modifier la vraie ligne (SEEK_END, SEEK_START...)
            my @new_line     = @{$line_ref};
            my $new_line_ref = \@new_line;

            $new_line_ref->[SEEK_START] = tell $new_file_desc;
            $new_line_ref->[PARENT]     = $new_root_ref;
            if ( $new_root_ref->[LAST] ) {
                $new_root_ref->[LAST][NEXT] = $new_line_ref;
                $new_line_ref->[PREVIOUS]   = $new_root_ref->[LAST];
                $new_root_ref->[LAST]       = $new_line_ref;
            }
            else {
                $new_root_ref->[FIRST] = $new_line_ref;
                $new_root_ref->[LAST]  = $new_line_ref;
            }
            print $new_file_desc $new_line_ref->[TEXT];
            $previous_line_ref = $new_line_ref;
            $hash{ $new_line_ref->[REF] } = $new_line_ref;
        }
        else {
            print $new_file_desc $line_ref->[TEXT];
            $previous_line_ref = $line_ref;
        }
    }
    if ( $previous_line_ref and $previous_line_ref->[REF] ) {
        $previous_line_ref->[SEEK_END] = tell $new_file_desc;
    }
    $new_root_ref->[SEEK_END] = tell $new_file_desc;

    if ( $self->[ROOT][FILE_DESC] ) {
        CORE::close $self->[ROOT][FILE_DESC];
    }
    CORE::close $new_file_desc;    # Vérification avec diff
    use File::Copy;
    move( $temp_file_name, $file_name );

    # Ménage à faire (supprimer l'arborescence $self->[ROOT] et [HASH_REF]
    open( $new_file_desc, "$file_name" )
      or die "Impossible d'ouvrir $file_name : $!\n";
    $self->[ROOT]            = $new_root_ref;
    $self->[ROOT][FILE_DESC] = $new_file_desc;
    $self->[HASH_REF]        = \%hash;

    $self->[ROOT][FILE_NAME] = $file_name;

    return 1;    # OK
}

sub revert_internal {
    my ($self) = @_;

    if ( !$self->[ROOT][FILE_DESC] ) {

        # Pas de fichier connu, donc il n'a pas de revert possible
        return ( 0, "" );
    }

    # Horribles fuites mémoires !!
    # ------------------------------

    undef $self->[ROOT][FIRST];
    undef $self->[ROOT][LAST];
    CORE::close $self->[ROOT][FILE_DESC];
    open( $self->[ROOT][FILE_DESC], $self->[ROOT][FILE_NAME] )
      or die "Impossible dans revert d'ouvrir $self->[ROOT][FILE_NAME] : $!\n";
    $self->[ROOT][SEEK_START] = 0;
    $self->[ROOT][SEEK_END]   = ( stat $self->[ROOT][FILE_DESC] )[7];

    #print "SELF->ROOT = $self->[ROOT]\n";
    #print "self->[ROOT][SEEK_END] = $self->[ROOT][SEEK_END]\n";
    return;
}

sub empty_internal {
    my ($self) = @_;

   # Horribles fuites mémoires !!
   # ------------------------------
   #print "Size self (ROOT) avant nettoyage :", total_size($self->[ROOT]), "\n";
   #print "Size self avant nettoyage :", total_size($self), "\n";
    for my $keys ( keys %{ $self->[HASH_REF] } ) {
        delete $self->[HASH_REF]{$keys};
    }
    delete $self->[HASH_REF];
    clean( $self->[ROOT] );

   #print "Size self (ROOT) après nettoyage :", total_size($self->[ROOT]), "\n";
   #print "Size self après nettoyage :", total_size($self), "\n";
   #if ( ! defined $self->[TO_DELETE] ) {
   #    $self->[TO_DELETE][FIRST] = $self->[ROOT];
   #    $self->[TO_DELETE][LAST] = $self->[ROOT];
   #}
   #else {
   #    $self->[TO_DELETE][LAST][NEXT] = $self->[ROOT];
   #    $self->[TO_DELETE][LAST] = $self->[ROOT];
   #}

#print "Avant undef : self->[TO_DELETE][FIRST] = ", dump $self->[TO_DELETE][FIRST], "\n";
#print "Avant undef : self->[TO_DELETE][LAST]  = ", dump $self->[TO_DELETE][LAST], "\n";
    undef $self->[ROOT][FIRST];
    undef $self->[ROOT][LAST];

#print "Après undef : self->[TO_DELETE][FIRST] = ", dump $self->[TO_DELETE][FIRST], "\n";
#print "Après undef : self->[TO_DELETE][LAST]  = ", dump $self->[TO_DELETE][LAST], "\n";
    if ( $self->[ROOT][FILE_DESC] ) {
        CORE::close $self->[ROOT][FILE_DESC];
        undef $self->[ROOT][FILE_DESC];
        $self->[ROOT][SEEK_START] = 0;
        $self->[ROOT][SEEK_END]   = 0;

#open ( $self->[ROOT][FILE_DESC], ">" . $self->[ROOT][FILE_NAME] ) or die "Impossible dans revert d'ouvrir $self->[ROOT][FILE_NAME] : $!\n";
#$self->[ROOT][SEEK_START] = 0;
#$self->[ROOT][SEEK_END] = (stat $self->[ROOT][FILE_DESC] )[7];
    }
    return;
}

sub read_line_ref {

    # PROCEDURE INTERNE au thread file_manager (non inter-thread) !!!!

# Attention, la variable $who en entrée ne signifie pas que l'on va renvoyer la réponse à un autre "thread"
# Elle est en entrée car la mémorisation de la position actuelle sur le "fichier édité" est mémorisée pour chaque thread (plusieurs lectures simultanées possibles)
# $ref permet de commencer la lecture ailleurs qu'au début (recherche de texte)
# On peut supprimer la mémorisation en envoyant $ref défini mais faut ("" ou 0)
    my ( $self, $who, $ref ) = @_;
    if ( !defined($who) ) {
        $who = threads->self->tid;
    }
    if ( !$self->[DESC]{$who} ) {

        #print "ZZZPremier accès pour who = $who\n";

        my $line_ref;
        if ($ref) {
            $line_ref = $self->[HASH_REF]{$ref};
            $line_ref = next_($line_ref);
        }
        else {
            $line_ref = first_( $self->[ROOT] );
        }

        if ($line_ref) {

            #print "ZZZwho = $who, text = $line_ref->[TEXT]\n";
            $self->[DESC]{$who}[REF] = $line_ref;

            return $line_ref;
        }
        else {    # Rien dans le "fichier" édité
            return;
        }
    }
    my $line_ref = $self->[DESC]{$who}[REF];
    if ( defined $ref ) {
        if ($ref) {
            $line_ref = $self->[HASH_REF]{$ref};
        }
        else {

            #print "Demande de démémorisation\n";
            init_read( $self, $who );

            #undef $self->[DESC]{$who};
            return;
        }
    }
    $line_ref = next_($line_ref);
    if ($line_ref) {
        $self->[DESC]{$who}[REF] = $line_ref;
        return $line_ref;
    }

    #print "Dernier appel read_next...démémorisation\n";
    init_read( $self, $who );

    #undef $self->[DESC]{$who};
    return;
}

sub init_read {

    #  my ( $self, $who ) = @_;
    my ( $self, $who ) = @_;

    #print "Dans init_read $who\n";
    #delete $self->[DESC]{$who}[REF];
    #delete $self->[DESC]{$who}[UNTIL];
    #delete $self->[DESC]{$who};

    $self->[DESC]{$who} = ();

    #undef $self->[DESC]{$who};
    #print "Fin de init_read $who\n";
    return;
}

sub read_next
{ #Eclater read_next en 2 procédures : une qui renvoie seulement le texte et une qui renvoie la référence + le texte
     # Ces 2 procédures faisant appel à la même (procédure interne au thread fichier) qui renvoie une référence de tableau (la ligne)
    my ( $self, $who, $ref ) = @_;

    my $line_ref = read_line_ref( $self, $who, $ref );
    if ($line_ref) {
        return $line_ref->[TEXT];
    }
    return;
}

sub ref_of_read_next {
    my ( $self, $who, $ref ) = @_;

    my $line_ref = read_line_ref( $self, $who, $ref );
    if ($line_ref) {
        if ( $line_ref->[REF] ) {
            return $line_ref->[REF];
        }
        else {    # Ligne "fichier" non mémorisée
            return;
        }
    }
    return;
}

sub next_line {
    my ( $self, $ref ) = @_;

    if ( !$ref ) {

        #print "next_line : pas de ref demandée\n";
        my $line_ref = first_( $self->[ROOT] );
        if ($line_ref) {
            my $ref = save_line( $self, $line_ref );
            print
              "Dans next_line Une référence a été trouvée : $line_ref|$ref|",
              $line_ref->[TEXT], "\n";
            return ( $ref, $line_ref->[TEXT] );
        }
        else {    # Aucune ligne à renvoyer
            print "Dans next line : Pas de référence trouvée, Threads tid : ",
              threads->tid, "\n";
            return;
        }
    }

    # Utilisation de la référence pour connaître la position
    my $line_ref = $self->[HASH_REF]{$ref};

    my $next_line_ref = next_($line_ref);

    if ($next_line_ref) {
        my $next_ref = save_line( $self, $next_line_ref );
        return ( $next_ref, $next_line_ref->[TEXT] );
    }
    return;
}

sub next_ {

# Récupère le segment suivant à partir d'un segment : renvoie undef si rien après (à la fin)
    my ($segment_ref) = @_;

    if (    $segment_ref->[NEXT]
        and $segment_ref->[NEXT][SEEK_START] == $segment_ref->[SEEK_END] )
    {
        return ( first_( $segment_ref->[NEXT] ) );
    }
    if (    $segment_ref->[PARENT]
        and $segment_ref->[PARENT][SEEK_END] > $segment_ref->[SEEK_END] )
    {
        my $line_ref;

# Problème à résoudre : segment_ref peut être un segment sans référence (parcours du fichier)
# Si line_ref vient à être sauvegardé (référencé) son PREVIOUS
#   pointera à tort sur une fausse référence
        if ( $segment_ref->[REF] ) {
            $line_ref->[PREVIOUS] = $segment_ref;
        }
        elsif ( $segment_ref->[PREVIOUS] ) {
            $line_ref->[PREVIOUS] = $segment_ref->[PREVIOUS];
            if ( !$segment_ref->[PREVIOUS][REF] ) {

# Normalement impossible car les segments sans référence ne sont pas pointés par les segments référencés
                print "2 segments sans réf se suivent\n";

            }
        }
        $line_ref->[NEXT] = $segment_ref->[NEXT];   # Peut être affectation vide
        $line_ref->[SEEK_START] = $segment_ref->[SEEK_END];
        $line_ref->[PARENT]     = $segment_ref->[PARENT];
        return ( read_($line_ref) );
    }
    if ( $segment_ref->[PARENT] ) {
        return ( next_( $segment_ref->[PARENT] ) );
    }

    # Pas de ligne suivante
    return;                                         # Renvoie undef
}

sub first_ {

    # Récupère le premier segment contenu dans un segment :
    # Si container : cela correspond effectivement à ce que l'on attend
    # Si "line" : la ligne se renvoie elle-même
    # Si "empty" : n'existe pas vraiment : renvoie le suivant
    # Si "empty" : n'existe pas vraiment : renvoie le suivant
    my ($segment_ref) = @_;

    if ( $segment_ref->[FIRST] ) {
        if ( $segment_ref->[FIRST][SEEK_START] == $segment_ref->[SEEK_START] ) {
            return ( first_( $segment_ref->[FIRST] ) );
        }
        else {
            my $line_ref;
            $line_ref->[NEXT]       = $segment_ref->[FIRST];
            $line_ref->[SEEK_START] = $segment_ref->[SEEK_START];
            $line_ref->[PARENT]     = $segment_ref;
            return ( read_($line_ref) );
        }
    }
    if ( $segment_ref->[TYPE] eq "line" ) {
        return ($segment_ref);
    }

    # On est sur un segment container mais ne contenant pas encore d'éléments
    if ( $segment_ref->[TYPE] eq "container" ) {

#print "On est dans un segment container\n";
# Il faut créer un nouveau segment : si le container est vide c'est que :
#   - soit le fichier est intact : création d'un segment "line"
#   - soit il n'y a pas de fichier (buffer vide), pas encore sauvegardé : aucune ligne à renvoyer
        if ( $segment_ref->[FILE_DESC] ) {
            if ( $segment_ref->[SEEK_START] != $segment_ref->[SEEK_END] ) {

                # Fichier intact
                my $line_ref;
                $line_ref->[SEEK_START] = $segment_ref->[SEEK_START];
                $line_ref->[PARENT]     = $segment_ref;
                return ( read_($line_ref) );
            }
        }
        else {

            # Cas d'un buffer vide à faire ici
            return;
        }
    }
    if ( $segment_ref->[TYPE] eq "empty" ) {
        if ( $segment_ref->[NEXT] ) {

#Deep recursion on subroutine "File_manager::first_" at ../File_manager.pm line 613
# Pour éviter ce message, supprimer correctement (voir remarques dans 'delete_line')
            return ( first_( $segment_ref->[NEXT] ) );
        }
        else {

            # On considère qu'un segment vide a toujours un parent
            return ( next_( $segment_ref->[PARENT] ) );
        }
    }
}

sub read_ {
    my ($line_ref) = @_;

    return if ( !$line_ref->[PARENT][FILE_DESC] );

    my $file_desc = $line_ref->[PARENT][FILE_DESC];
    seek $file_desc, $line_ref->[SEEK_START], 0;
    $line_ref->[TEXT] = readline $file_desc;
    chomp $line_ref->[TEXT];

    # Suppression des retours chariots
    $line_ref->[TEXT] =~ s/\r//g;

    # Suppression des tabulations ...
    $line_ref->[TEXT] =~ s/\t/    /g;

    $line_ref->[SEEK_END] = tell $file_desc;

    return $line_ref;
}

sub previous_ {

# Récupère le segment précédant à partir d'un segment : renvoie undef si rien avant (au début)
    my ($segment_ref) = @_;

    if (    $segment_ref->[PREVIOUS]
        and $segment_ref->[PREVIOUS][SEEK_END] == $segment_ref->[SEEK_START] )
    {

#print "segment_ref->[PREVIOUS][SEEK_END] : $segment_ref->[PREVIOUS][SEEK_END]\n";
#print "segment_ref->[PREVIOUS][TEXT] : $segment_ref->[PREVIOUS][TEXT]\n";
        return ( last_( $segment_ref->[PREVIOUS] ) );
    }
    if (    $segment_ref->[PARENT]
        and $segment_ref->[PARENT][SEEK_START] < $segment_ref->[SEEK_START] )
    {
        my $line_ref;

# OK mais seulement car il n'existe pas de procédure de parcours arrière sans mémorisation
#  ==> différence importante par rapport à "sub next_"
        $line_ref->[NEXT] = $segment_ref;

        $line_ref->[PREVIOUS] =
          $segment_ref->[PREVIOUS];    # Peut être affectation vide
        $line_ref->[SEEK_END] = $segment_ref->[SEEK_START];
        $line_ref->[PARENT]   = $segment_ref->[PARENT];
        return ( read_previous_($line_ref) );
    }
    if ( $segment_ref->[PARENT] ) {
        return ( previous_( $segment_ref->[PARENT] ) );
    }

    # Pas de ligne suivante
    return;                            # Renvoie undef
}

sub last_ {

    # Récupère le premier segment contenu dans un segment :
    # Si container : cela correspond effectivement à ce que l'on attend
    # Si "line" : la ligne se renvoie elle-même
    # Si "empty" : n'existe pas vraiment : renvoie le suivant
    my ($segment_ref) = @_;

    #print "Dans last_\n";

    if ( $segment_ref->[LAST] ) {
        if ( $segment_ref->[LAST][SEEK_END] == $segment_ref->[SEEK_END] ) {
            return ( last_( $segment_ref->[LAST] ) );
        }
        else {
            my $line_ref;
            $line_ref->[PREVIOUS] = $segment_ref->[LAST];
            $line_ref->[SEEK_END] = $segment_ref->[SEEK_END];
            $line_ref->[PARENT]   = $segment_ref;
            return ( read_previous_($line_ref) );
        }
    }
    if ( $segment_ref->[TYPE] eq "line" ) {
        return ($segment_ref);
    }

    # On est sur un segment container mais ne contenant pas encore d'éléments
    if ( $segment_ref->[TYPE] eq "container" ) {

#print "On est dans un segment container\n";
# Il faut créer un nouveau segment : si le container est vide c'est que :
#   - soit le fichier est intact : création d'un segment "line"
#   - soit il n'y a pas de fichier (buffer vide), pas encore sauvegardé : aucune ligne à renvoyer
        if ( $segment_ref->[FILE_DESC] ) {
            if ( $segment_ref->[SEEK_START] != $segment_ref->[SEEK_END] ) {

                # Fichier intact
                my $line_ref;
                $line_ref->[SEEK_END] = $segment_ref->[SEEK_END];
                $line_ref->[PARENT]   = $segment_ref;
                return ( read_previous_($line_ref) );
            }
        }
        else {

            # Cas d'un buffer vide à faire ici
            return;
        }
    }
    if ( $segment_ref->[TYPE] eq "empty" ) {
        if ( $segment_ref->[PREVIOUS] ) {
            return ( last_( $segment_ref->[PREVIOUS] ) );
        }
        else {

            # On considère qu'un segment vide a toujours un parent
            return ( previous_( $segment_ref->[PARENT] ) );
        }
    }
}

sub read_previous_ {
    my ($line_ref) = @_;

    my ( $seek_start, $text ) =
      prev_line( $line_ref->[PARENT], $line_ref->[SEEK_END] );

    $line_ref->[TEXT] = $text;
    chomp $line_ref->[TEXT];

    # Suppression des retours chariots
    $line_ref->[TEXT] =~ s/\r//g;

    # Suppression des tabulations ...
    $line_ref->[TEXT] =~ s/\t/    /g;

    $line_ref->[SEEK_START] = $seek_start;

    return $line_ref;
}

sub save_line {

# Création d'une ligne dans la structure
# On crée la ligne à partir d'une structure ligne (pseudo "objet" : plus simple à passer en paramètre)
# Attention, NEXT et PREVIOUS du pseudo-objet ne sont pas forcément renseignés
    my ( $self, $line_ref ) = @_;

    my $ref;
    if ( !$line_ref->[REF] )
    {    # On ne fait pas de "création" si la ligne existe déjà
        $ref = get_next_ref($self);
    }
    else {
        $ref = $line_ref->[REF];
    }
    $line_ref->[REF]  = $ref;
    $line_ref->[TYPE] = "line";

    my $segment_ref = $line_ref->[PARENT];
    if (    $segment_ref->[FIRST]
        and $segment_ref->[FIRST][SEEK_START] > $line_ref->[SEEK_START] )
    {
        $line_ref->[NEXT]           = $segment_ref->[FIRST];
        $segment_ref->[FIRST]       = $line_ref;
        $line_ref->[NEXT][PREVIOUS] = $line_ref;
    }
    if ( !$segment_ref->[FIRST] ) {
        $segment_ref->[FIRST] = $line_ref;
    }
    if (    $segment_ref->[LAST]
        and $segment_ref->[LAST][SEEK_END] < $line_ref->[SEEK_END] )
    {
        $line_ref->[PREVIOUS]       = $segment_ref->[LAST];
        $segment_ref->[LAST]        = $line_ref;
        $line_ref->[PREVIOUS][NEXT] = $line_ref;
    }
    if ( !$segment_ref->[LAST] ) {
        $segment_ref->[LAST] = $line_ref;
    }
    if ( $line_ref->[PREVIOUS] ) {
        $line_ref->[PREVIOUS][NEXT] = $line_ref;
    }
    if ( $line_ref->[NEXT] ) {
        $line_ref->[NEXT][PREVIOUS] = $line_ref;
    }
    $self->[HASH_REF]{$ref} = $line_ref;
    return $ref;
}

sub get_ref_and_text_from_line_ref {
    my ($line_ref) = @_;

    #print "line_ref = $line_ref\n";
    return ( $line_ref->[REF], $line_ref->[TEXT] );
}

sub get_next_ref {
    my ($self) = @_;

    $self->[REF] += 1;
    return $self->[REF];
}

sub previous_line {
    my ( $self, $ref ) = @_;

    if ( !$ref ) {

        #print "Previous à blanc demandé\n";
        my $line_ref = last_( $self->[ROOT] );

        #print "line_ref trouvé = $line_ref\n";
        if ($line_ref) {
            my $ref = save_line( $self, $line_ref );
            return ( $ref, $line_ref->[TEXT] );
        }
        return 0;
    }

    #print "Previous de $ref demandé\n";
    # Utilisation de la référence pour connaître la position
    my $line_ref = $self->[HASH_REF]{$ref};

    my $previous_line_ref = previous_($line_ref);
    if ($previous_line_ref) {
        my $previous_ref = save_line( $self, $previous_line_ref );
        return ( $previous_ref, $previous_line_ref->[TEXT] );
    }
    return 0;
}

sub line_seek_start {
    my ( $self, $ref ) = @_;

    return if ( !$ref );
    my $line_ref = $self->[HASH_REF]{$ref};
    return if ( !defined $line_ref );
    return $line_ref->[SEEK_START];
}

sub get_ref_for_empty_structure {

# Fonction appelée sur fichier vide (par exemple, au démarrage, lors de la création)
    my ($self) = @_;

    my $line_ref;
    $line_ref->[PARENT] = $self->[ROOT];
    $line_ref->[TEXT]   = "";
    $line_ref->[TYPE]   = "line";
    my $ref = get_next_ref($self);
    $line_ref->[REF]        = $ref;
    $line_ref->[SEEK_START] = 0;
    $line_ref->[SEEK_END]   = 0;

    $line_ref->[PARENT][LAST]       = $line_ref;
    $line_ref->[PARENT][FIRST]      = $line_ref;
    $line_ref->[PARENT][SEEK_START] = 0;
    $line_ref->[PARENT][SEEK_END]   = 0;

    $self->[HASH_REF]{$ref} = $line_ref;

    return $ref;
}

sub clean {
    my ($segment_ref) = @_;

    #return;
    # Récupération du premier élément
    #print "Dans clean de file_manager, \n";
    my $first = $segment_ref;

    # NEXT, PREVIOUS, PARENT, FIRST, LAST
    my $still_segment;
    while ( $still_segment = $first->[FIRST] ) {
        $first = $still_segment;
    }
    while ( $first = delete_and_return_first($first) ) {
    }
}

sub delete_and_return_first {
    my ($segment_ref) = @_;

    my $first;
    if ( $first = $segment_ref->[NEXT] ) {
        $segment_ref->[PARENT][FIRST] = $first;
        $first->[PREVIOUS] = 0;
    }
    elsif ( $first = $segment_ref->[PARENT] ) {
        $first->[FIRST] = 0;
    }
    $segment_ref->[NEXT]     = 0;
    $segment_ref->[PREVIOUS] = 0;
    $segment_ref->[PARENT]   = 0;

    #$segment_ref->[LAST] = 0;
    return $first;
}

sub save_info {
    my ( $self, $info, $key ) = @_;

    if ( defined $key ) {
		$self->[SAVED_INFO]{$key} = $info;
    }
	else {
        $self->[SAVED_INFO] = $info;
    }
}

sub load_info {
    my ( $self, $key ) = @_;

    if ( defined $key ) {
		if ( ref ($self->[SAVED_INFO] ) eq 'HASH' ) {
		    return $self->[SAVED_INFO]{$key};
	    }
		else {
		    print STDERR "Saved_info in File_manager is not a hash\n";
			return;
	    }
    }
    return $self->[SAVED_INFO];
}

sub editor_number {
    my ( $self, $number, $options_ref ) = @_;
	
	print "Dans editor_number, reçu : NUMBER $number\n";

    my $check_every = 20;
	my $lazy;
	if ( defined $options_ref and ref $options_ref eq 'HASH' ) {
        $check_every = $options_ref->{'check_every'} || 20;
	    $lazy = $options_ref->{'lazy'};
    }

	my $indice = 0;
	# 'I' pour ne pas empiéter sur une autre utilisation directe par init_read, 'I' pour 'internal'
    my $who = 'I' . $indice;
    while  ( defined $self->[DESC]{$who} ) {
		$indice += 1;
		$who = 'I' . $indice;
    }
    $self->[DESC]{$who} = ();
	
    my $text = read_next($self, $who);

    $indice = 0;
    my $current;
    while ( defined($text) ) {
        $current += 1;
		$indice += 1;
        if ( $current == $number ) {
            my $new_ref = create_ref_current($self, $who);
			print "Texte de la ligne : |$text|\n";
            save_line_number( $self, $who, $new_ref, $number );
			# Désinit
			$self->[DESC]{$who} = undef;
            return $new_ref;
        }
		if ( $indice == $check_every ) {
		    $indice = 0;
			if ( defined $lazy and Text::Editor::Easy::Comm::anything_for( $lazy ) ) {
				return;
		    }
            if ( Text::Editor::Easy::Comm::anything_for_me() ) {
				#return if ( Text::Editor::Easy::Comm::have_task_done() );
				Text::Editor::Easy::Comm::have_task_done()
		    }
	    }
        $text = read_next($self, $who);
    }
}


sub editor_search {
    my ( $self, $regexp, $options_ref ) = @_;
	
    my $check_every = 20;
	my ( $lazy, $who, $start_line, $start_pos, $stop_line, $stop_pos );
	if ( defined $options_ref and ref $options_ref eq 'HASH' ) {
        $check_every = $options_ref->{'check_every'} || 20;
	    $lazy = $options_ref->{'lazy'};
		$who = $options_ref->{'thread'};
		$start_line = $options_ref->{'start_line'};
		$start_pos = $options_ref->{'start_pos'};
		$stop_line = $options_ref->{'stop_line'};
		$stop_pos = $options_ref->{'stop_pos'};
    }
	if ( ! defined $stop_line ) {
		$stop_line = $start_line;
    }

     if ( ! defined $who ) {
	    my $indice = 0;
	    # 'I' pour ne pas empiéter sur une autre utilisation directe par init_read, 'I' pour 'internal'
        $who = 'I' . $indice;
        while  ( defined $self->[DESC]{$who} ) {
		    $indice += 1;
		    $who = 'I' . $indice;
        }
    }
    $self->[DESC]{$who} = ();
	
    #my $text = read_next($self, $who, $start_line);
	my $line_ref = $self->[HASH_REF]{$start_line};
	return if ( ! defined $line_ref ); # Mauvaise référence
	$self->[DESC]{$who}[REF] = $line_ref;
	my $text = $line_ref->[TEXT];
	if ( ! defined $stop_pos ) {
		$stop_pos = length ( $text );
    }

    my $indice = 0;
    while ( defined($text) ) {
		$indice += 1;
		#print "Ligne lue : |$text|\n";
        while ( $text =~ m/($regexp)/g ) {
            my $length    = length($1);
            my $end_pos   = pos($text);
            my $start_pos = $end_pos - $length;
            my $new_ref = create_ref_current($self, $who);
			#print "Texte de la ligne : |$text|\n";
			if ( $new_ref != $start_line ) {
                save_line_number( $self, $who, $new_ref );
		    }
			if ( $new_ref != $start_line or $start_pos  > $options_ref->{'start_pos'} ) {
				$self->[DESC]{$who} = undef;
                return ( $new_ref, $start_pos, $end_pos);
		    }
        }
		if ( $indice == $check_every ) {
		    $indice = 0;
			if ( defined $lazy and Text::Editor::Easy::Comm::anything_for( $lazy ) ) {
				return;
		    }
            if ( Text::Editor::Easy::Comm::anything_for_me() ) {
				#return if ( Text::Editor::Easy::Comm::have_task_done() );
				Text::Editor::Easy::Comm::have_task_done()
		    }
	    }
        #$text = read_next($self, $who);
		$text = read_until2( $self, $who, { 'line_stop' => $stop_line } );
    }
	return;
}

=head1 FUNCTIONS

=head2 clean

=head2 close

=head2 create_ref_current

=head2 delete_and_return_first

=head2 delete_line

=head2 display

=head2 editor_number

Return the line of a Text::Editor::Easy instance given its number. This task may be long for the moment (with huge file), so lazy mode is possible. At the beginning, this task was done outside this module,
because sub "anything_for" was not written. Lazy processing can now be transmitted between threads : this means that one thread can stop its processing if another thread receives a new task.

=head2 editor_search

Return the line of a Text::Editor::Easy instance and the position (start and end) in this line that match the regexp given. This task may be long (with huge file), so lazy mode is possible.

=head2 empty_internal

=head2 empty_internal

=head2 first_

=head2 get_line_number_from_ref_internal

=head2 get_next_ref

=head2 get_ref_and_text_from_line_ref

=head2 get_ref_for_empty_structure

=head2 get_text_from_ref

=head2 init_file_manager

=head2 init_read

=head2 last_

=head2 line_seek_start

=head2 load_info

=head2 manage_requests

=head2 modify_line

=head2 new_line

=head2 next_

=head2 next_line

=head2 prev_line

=head2 previous_

=head2 previous_line

=head2 query_segments

=head2 read_

=head2 read_line_ref

=head2 read_next

=head2 read_previous_

=head2 read_until

=head2 read_until2

=head2 ref_of_read_next

=head2 revert_internal

=head2 save_info

=head2 save_internal

=head2 save_line

=head2 save_line_number

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
