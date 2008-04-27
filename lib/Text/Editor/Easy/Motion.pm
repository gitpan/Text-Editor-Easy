package Text::Editor::Easy::Motion;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Motion - Manage various user events on "Text::Editor::Easy" objects.

=head1 VERSION

Version 0.2

=cut

our $VERSION = '0.2';

use Text::Editor::Easy::Comm;
use Devel::Size qw(size total_size);

my $self_global;

sub return_self {
    return $self_global;
}

my %ref_init;
my %referenced;

sub reference_event {
    my ( $self, $event, $unique_ref, $motion_ref ) = @_;

    #print "Dans reference de Motion : $event\n";
    #print "USE $motion_ref->{use}\n";
    #print "PACKAGE $motion_ref->{package}\n";
    #print "SUB $motion_ref->{sub}";
    #print "toto";
    #print "mimi\n\nmama\nmomo\ntres";
    #print "zaza\n";
    #print "INIT $motion_ref->{init}\n";
    eval "use $motion_ref->{use}";
    my $init_ref = $motion_ref->{'init'};

    if ( defined $init_ref ) {
        my $what = $init_ref->[0];

        #print "WHAT $what\n";
        $ref_init{$what}{$unique_ref} = eval "\\&$motion_ref->{package}::$what";

        #async_call (threads->tid, @$init_ref );
        my ( $false_method, @param ) = @$init_ref;
        print "FALSE METHOD ", $false_method . ' ' . threads->tid,
          "|$unique_ref|", join( "|", @param ), "\n";

        #Text::Editor::Easy::Async->ask2( 'init ' . threads->tid,
        #    $false_method, $unique_ref, @param );
        Text::Editor::Easy::Async->ask_thread( "$motion_ref->{package}::$what",
            threads->tid, $unique_ref, @param );
    }
    $referenced{$event}{$unique_ref} =
      eval "\\&$motion_ref->{package}::$motion_ref->{sub}";
}

sub init {
    my ( $self, $what, $unique_ref, @param ) = @_;

    print "Dans init de motion : $what|@param\n";

    $ref_init{$what}{$unique_ref}->( $self, $unique_ref, @param );
}

sub manage_events {
    my ( $self, $what, @param ) = @_;

    if ( $referenced{$what} ) {

        #print "Evènement $what référencé size ", total_size($self), "\n";
        my ( $ref_editor, $hash_ref, @other ) = @param;
        if ( !defined $referenced{$what}{$ref_editor} ) {
            if ( $what eq 'motion_last' ) {

             # Pas référencé mais OK : on a voulu interrompre mon fonctionnement
                return;
            }
            print STDERR
"L'évènement $what n'a pas été référencé pour l'éditeur $ref_editor\n";
            return;
        }

        #print "OK ===> $what référencé pour $ref_editor\n";
        my $editor = $self->{$ref_editor};
        if ( !defined $editor ) {
            $editor = bless \do { my $anonymous_scalar }, "Text::Editor::Easy";
            Text::Editor::Easy::Comm::set_ref( $editor, $ref_editor);
            $self->{$ref_editor} = $editor;
        }
        $editor->transform_hash( undef, $hash_ref );
        $referenced{$what}{$ref_editor}
          ->( $ref_editor, $editor, $hash_ref, @other );
    }
}

my $show_calls_editor;
my $display_zone;

sub init_move {
    my ( $self, $reference, $unique_ref, $ref_editor, $zone ) = @_;

    print "DANS INIT_MOVE $self, $unique_ref, $ref_editor, $zone\n";
    $show_calls_editor = bless \do { my $anonymous_scalar },
      "Text::Editor::Easy";
    Text::Editor::Easy::Comm::set_ref( $show_calls_editor, $ref_editor);
    $display_zone = $zone;
}

my $info;      # Descripteur de fichier du fichier info
my %editor;    # Editeurs de la zone d'affichage, par nom de fichier

#my %saved; # Sauvegarde du dernier motion

use File::Basename;
my $name      = fileparse($0);
my $file_name = "tmp/${name}_trace.trc.info";
my @selected;       # Ligne sélectionnée de la sortie
my %line_number;    # Sauvegarde des recherches, fuite mémoire pas important ici

sub move_over_out_editor {
    my ( $unique_ref, $editor, $hash_ref ) = @_;

    return if (anything_for_me);

    #print "DANS MOVE_OVER_OUT_FILE $editor, $hash_ref\n";

    my $line_of_out = $hash_ref->{'line'};
    return if ( !$line_of_out );
    my $seek_start = $line_of_out->seek_start;

    return if (anything_for_me);

    #print "Avant appel get_info:  $seek_start\n";
    my ( $info_seek, $info_size ) =
      Text::Editor::Easy->get_info_for_display($seek_start);

    #print "Après appel get_info:  $info_seek\n";
    return if ( !defined $info_seek );

    #$saved{'info_seek'} = $info_seek;

    my $pos         = $hash_ref->{'line_pos'};
    my $seek_search = $seek_start + $pos;

    #print "\n\n\nOVER OUT FILE $line_of_out|$seek_start|$pos\n\n\n";
    return if (anything_for_me);

    if ( $info and tell $info != $info_size ) {
        close $info;
        if ( !open( $info, "$file_name" ) ) {
            print STDERR "Impossible d'ouvrir $file_name : $!\n";
            return;
        }
    }
    elsif ( !defined $info ) {

        #print "INFO pas ouvert\n";
        if ( !open( $info, "$file_name" ) ) {
            print STDERR "Impossible d'ouvrir $file_name : $!\n";
            return;
        }
    }

    #print "Seek à chercher dans info $seek_search\n";
    return if ( !seek $info, $info_seek, 0 );

    #print "Positionnement à $info_seek OK\n";
    my ( $first, $last );
    my @enreg;
  INF: while ( my $enreg = readline $info ) {

        #print "LIGNE DE INFO LUE : $enreg";
        if ( $enreg =~ /^(\d+)\|(\d+)$/ ) {
            return if (anything_for_me);    # Abandonne si autre chose à faire
            if ( $seek_search < $2 and $seek_search >= $1 ) {

                #print "Trouvé : $_";
                $first = $1;
                $last  = $2;

                #print "Trouvé !!! : $enreg|", $line_of_out->text, "\n";
                $enreg = readline $info;
                while ( defined $enreg and $enreg =~ /^\t(.*)$/ ) {
                    push @enreg, $1;

                    #print $enreg;
                    $enreg = readline $info;
                }
                last INF;
            }
        }
    }
    return if (anything_for_me);    # Abandonne si autre chose à faire

    $show_calls_editor->deselect;
    return if (anything_for_me);    # Abandonne si autre chose à faire
    $show_calls_editor->empty;
    return if (anything_for_me);    # Abandonne si autre chose à faire

    my ( $file, $number, $package ) = split( /\|/, $enreg[1] );
    chomp $package;                 # En principe inutile

    return if (anything_for_me);    # Abandonne si autre chose à faire

    my $new_editor = $editor{$file};
    return if ( !-f $file );        # Eval non géré...

    #print "move over out file : AVANT new_editor : $file\n";
    if ( !$new_editor ) {
        $new_editor = Text::Editor::Easy->whose_file_name($file);
        if ( !$new_editor ) {
            $new_editor = Text::Editor::Easy->new(
                {
                    'file'      => $file,
                    'zone'      => $display_zone,
                    'highlight' => {
                        'use'     => 'Text::Editor::Easy::Syntax::Perl_glue',
                        'package' => 'Text::Editor::Easy::Syntax::Perl_glue',
                        'sub'     => 'syntax',
                    },
                }
            );
        }
        $editor{$file} = $new_editor;
    }
    else {
        return if (anything_for_me);    # Abandonne si autre chose à faire
        $new_editor->on_top;
    }

    #print "move over out file : AVANT number : $number\n";
    my $line = $line_number{$file}{$number};
    if ( !$line ) {
        $line = $new_editor->number($number, {
				'lazy' => threads->tid,
				'check_every' => 20,
		});
    }
    if ( !defined $line or ref $line ne 'Text::Editor::Easy::Line' ) {
        return;
    }
    $line_number{$file}{$number} = $line;

    # Bloquant maintenant
    $new_editor->async->display( $line,
        { 'at' => 'middle', 'from' => 'bottom' } );

    #return if (anything_for_me); # Abandonne si autre chose à faire

    #print "AVA?T DISPLAYED\n";
    #print "APRES DISPLAYED\n";
    #return if ( anything_for_me );

    $editor->deselect;
    my $left;
    my $right;
    my $length_text = length( $line_of_out->text );

#if ( $first >= $seek_start  ) { # line_select devra gérer les entrées négatives et supérieures à la longueur

    my $start;
    my $length_to_select;    # = $last - $first;
    my $save_seek_start = $seek_start;
    if ( $first < $seek_start )
    {   # A gérer à cause de la différence de taille du \n entre Windows et Unix
        $start = 0;
        my $previous_line = $line_of_out->previous;
        $seek_start = $previous_line->seek_start;
        $start -= length $previous_line->text;
        $length_to_select += length $previous_line->text;
        while ( $first < $seek_start ) {
            $previous_line = $previous_line->previous;
            $seek_start    = $previous_line->seek_start;
            $start -= length $previous_line->text;
            $length_to_select += length $previous_line->text;
        }
    }
    $start += $first - $seek_start;

    $seek_start = $save_seek_start;
    my $end;
    my $current_line = $line_of_out;
    while ( $last > ( $seek_start + $length_text ) ) {
        $end += $length_text;
        $current_line = $current_line->next;
        return if ( !defined $current_line );    # A revoir...
        $length_text = length( $current_line->text );
        $seek_start  = $current_line->seek_start;
    }
    $end += $last - $seek_start;

    # Reprise
    $new_editor->deselect;
    $line->select( undef, undef, 'white' );
    $line_of_out->select( $start, $end, 'pink' );

    return if (anything_for_me);

    my $string_to_insert;
    for my $indice ( 1 .. $#enreg ) {

        #print "ICI:$_\n";
        my ( $file, $line, $package ) = split( /\|/, $enreg[$indice] );

      #          return if (anything_for_me); # Abandonne si autre chose à faire

        $string_to_insert .= "Package $package|File $file|Line $line\n";
    }
    chomp $string_to_insert;
    $show_calls_editor->insert($string_to_insert);

    #if ( anything_for_me ) {
    #    my @param = get_task_to_do;
    #    print "Dans move over out, tâche reçue : @param\nFin de paramêtres\n";
    #}

    return if (anything_for_me);    # Abandonne si autre chose à faire
         # Sélection de la ligne que l'on va traiter : la première
    my $first_line = $show_calls_editor->first;
    $show_calls_editor->display( $first_line, { 'at' => 'top' } );
    $first_line->select( undef, undef, 'orange' );
}

sub init_set {
    my ( $self, $reference, $unique_ref, $zone ) = @_;

    #print "Dans init_set $self, $zone\n";
    $display_zone = $zone;
}

sub cursor_set_on_who_file {
    my ( $unique_ref, $editor, $hash_ref ) = @_;

    #if ( $hash_ref->{'origin'} eq 'graphic'
    #or $hash_ref->{'sub_origin'} eq 'cursor_set' ) {
    #    $editor->deselect;
    #    return if (anything_for_me); # Abandonne si autre chose à faire
    #sleep 1;
    #     return if (anything_for_me); # Abandonne si autre chose à faire

    #}

# Pris en charge par "move_over_out_file" dans le cas "cursor_set" pour des questions de rapidité
    my $hash_ref_line = $hash_ref->{'line'};
    return if ( !$hash_ref_line );
    my $text = $hash_ref_line->text;
    return if (anything_for_me);    # Abandonne si autre chose à faire
    if ( my ( $package, $file, $number ) =
        $text =~ /^Package (.+)\|File (.+)\|Line (\d+)$/ )
    {

        #print "P $1, $2, $3\n";

        #my @ref_editors = Text::Editor::Easy->
        my $new_editor = $editor{$file};
        if ( !$new_editor ) {
            return if (anything_for_me);    # Abandonne si autre chose à faire
            $new_editor = Text::Editor::Easy->new(
                {
                    'file'      => $file,
                    'zone'      => $display_zone,
                    'highlight' => {
                        'use'     => 'Text::Editor::Easy::Syntax::Perl_glue',
                        'package' => 'Text::Editor::Easy::Syntax::Perl_glue',
                        'sub'     => 'syntax',
                    },
                }
            );
            $editor{$file} = $new_editor;
        }
        else {
            $new_editor->on_top;
        }
        return if (anything_for_me);    # Abandonne si autre chose à faire
        $new_editor->deselect;
        $editor->deselect;
        return if (anything_for_me);    # Abandonne si autre chose à faire
        my $line = $line_number{$file}{$number};
        if ( !$line ) {
            $line = $new_editor->number($number, {
				'lazy' => threads->tid,
				'check_every' => 20,
		    });
        }
        if ( !defined $line or ref $line ne 'Text::Editor::Easy::Line' ) {
            return;
        }
        $line_number{$file}{$number} = $line;
        return if (anything_for_me);    # Abandonne si autre chose à faire
        if ( !defined $line or ref $line ne 'Text::Editor::Easy::Line' ) {
            print STDERR "Problème pour la récupération de number\n";
            return;
        }
        $new_editor->display( $line, { 'at' => 'middle', 'from' => 'bottom' } );
        return if (anything_for_me);    # Abandonne si autre chose à faire
        $line->select( undef, undef, 'white' );
        $hash_ref->{'line'}->select( undef, undef, 'orange' );
    }
}

=head1 FUNCTIONS

=head2 cursor_set_on_who_file

=head2 init

=head2 init_move

=head2 init_set

=head2 manage_events

=head2 move_over_out_editor

=head2 reference_event

=head2 return_self

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
