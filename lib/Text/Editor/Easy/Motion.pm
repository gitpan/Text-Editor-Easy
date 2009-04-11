package Text::Editor::Easy::Motion;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Motion - Manage various user events on "Text::Editor::Easy" objects.

=head1 VERSION

Version 0.45

=cut

our $VERSION = '0.45';

use threads;
use Text::Editor::Easy::Comm;
use Devel::Size qw(size total_size);

my $show_calls_editor;
my $display_zone;

sub init_move {
    my ( $self, $reference, $ref_editor, $zone ) = @_;

    print "DANS INIT_MOVE $self, $ref_editor, $zone\n";
    $show_calls_editor = bless \do { my $anonymous_scalar },
      "Text::Editor::Easy";
    Text::Editor::Easy::Comm::set_ref( $show_calls_editor, $ref_editor);
    $display_zone = $zone->{'name'};
}

my $info;      # Descripteur de fichier du fichier info
my %editor;    # Editeurs de la zone d'affichage, par nom de fichier

#my %saved; # Sauvegarde du dernier motion

use File::Basename;
my $name      = fileparse($0);
my $file_name = "tmp/${name}_trace.trc.print_info";
my @selected;       # Ligne sélectionnée de la sortie
my %line_number;    # Sauvegarde des recherches, fuite mémoire pas important ici

sub move_over_eval_editor {
    my ( $editor, $hash_ref ) = @_;

    print "Dans move_over_eval_editor\n";
    
    my $unique_ref = $editor->get_ref;
    $hash_ref->{'editor'} = 'eval';
    move_over_out_editor ( $editor, $hash_ref );
}

sub move_over_external_editor {
    my ( $editor, $hash_ref ) = @_;
    
    $hash_ref->{'editor'} = 'external';
    move_over_out_editor ( $editor, $hash_ref );
}

sub move_over_out_editor {
    my ( $editor, $hash_ref ) = @_;

    return if (anything_for_me);
    
    $editor->async->unset_at_end;

    #print "DANS MOVE_OVER_OUT_FILE $editor, $hash_ref\n";

    my $line_of_out = $hash_ref->{'line'};
    return if ( !$line_of_out );
    my $seek_start = $line_of_out->seek_start;

    return if (anything_for_me);

    #print "Avant appel get_info:  $seek_start\n";
    my $pos = $hash_ref->{'pos'};

    my ( $first, $last, @enreg, $ref_first, $pos_first, $ref_last, $pos_last);
    if ( my $type = $hash_ref->{'editor'} ) {
        if ( $type eq 'external' ) { # log of external program
            ( $ref_first, $pos_first, $ref_last, $pos_last, @enreg ) 
             = Text::Editor::Easy->get_info_for_extended_trace (
                 $line_of_out->seek_start,
                 $pos,
                 $editor->get_ref,
                 $line_of_out->ref,
               );
            return if ( ! defined $ref_first );            
        }
        else { # $type eq 'eval', log of macro instructions
            ( $ref_first, $pos_first, $ref_last, $pos_last, @enreg ) 
             = Text::Editor::Easy->get_info_for_eval_display (
                 $editor->get_ref,
                 $line_of_out->ref,
                 $pos
               );
            return if ( ! defined $ref_first );
            print "Dans motion, j'ai bien reçu ref_first = $ref_first\n";
        }
    }
    else { # Editor (internal log)
        ( $ref_first, $pos_first, $ref_last, $pos_last, @enreg ) 
         = Text::Editor::Easy->get_info_for_display (
             $seek_start,
             $pos,
             $editor->get_ref,
             $line_of_out->ref,
           );
        print "Reçu de get_info_for_display $ref_first et $pos_first\n";
    }

    return if (anything_for_me);    # Abandonne si autre chose à faire

    $show_calls_editor->deselect;
    return if (anything_for_me);    # Abandonne si autre chose à faire
    $show_calls_editor->empty;
    return if (anything_for_me);    # Abandonne si autre chose à faire

    #print "ENREG 1 = $enreg[1]\n";
    
    my ( $info ) = $enreg[1] =~ /^\t(.+)/;
    
    my ( $file, $number, $package ) = split( /\|/, $info );
    chomp $package;                 # En principe inutile

    return if (anything_for_me);    # Abandonne si autre chose à faire

   my ( $new_editor, $line );
    if ( ! -f $file ) {
        # gestion de l'eval...
        ( $new_editor, $line ) = manage_eval ( $file, $number );
    }
    else {
        ( $new_editor, $line ) = manage_file ( $file, $number );        
    }
    return if ( ! defined $new_editor );

    #print "AVA?T DISPLAYED\n";
    #print "APRES DISPLAYED\n";
    #return if ( anything_for_me );

    $editor->deselect;
    
    #print "Dans motion, je sélectionne $ref_first de $pos_first à $pos_last\n";
    if ( $ref_first == $ref_last ) {
        $editor->line_select( $ref_first, $pos_first, $pos_last, 'pink' );
    }
    else {
        $editor->line_select( $ref_first, $pos_first, undef, 'pink' );
        my ( $new_ref ) = $editor->next_line( $ref_first );
        while ( $new_ref != $ref_last ) {
            $editor->line_select( $new_ref, undef, undef, 'pink' );
            ( $new_ref ) = $editor->next_line ( $new_ref );
        }
        $editor->line_select( $ref_last, 0, $pos_last, 'pink' );
    }

    # Reprise
    $new_editor->deselect;
    $line->select( undef, undef, {'force' => 1, 'color' => 'white'} );


    #return if (anything_for_me);
    if ( anything_for_me() ) {
        my ( $what, @param ) = get_task_to_do();
        print "Dans motion avant affichage stack_call =>\n\tWHAT = $what\n";
        execute_this_task( $what, @param );
        return if ( $what ne 'reference_event' );
    }

    my $string_to_insert;
    for my $indice ( 0 .. $#enreg ) {

        #print "ICI:$_\n";
        if ( $enreg[$indice] =~ /^\t(.+)\|(.+)\|(.+)/ ) {
            $string_to_insert .= "File $1|Line $2|Package $3\n";
        }
        else {
            $string_to_insert .= $enreg[$indice] . "\n";
        }
    }
    chomp $string_to_insert;
    my $first_line = $show_calls_editor->first;
    #$display_options = [ $ref, { 'at' => $top_ord, 'from' => 'top' } ];
    $show_calls_editor->insert($string_to_insert, { 
        'cursor' => 'at_start',
        'display' => [
            $first_line,
            { 'at' => 'top', 'from' => 'top' },
        ]
    } );

    #if ( anything_for_me ) {
    #    my @param = get_task_to_do;
    #    print "Dans move over out, tâche reçue : @param\nFin de paramêtres\n";
    #}

    return if (anything_for_me);    # Abandonne si autre chose à faire
         # Sélection de la ligne que l'on va traiter : la première
    #$first_line = $show_calls_editor->first;
    #$show_calls_editor->display( $first_line, { 'at' => 'top' } );
    $first_line->select( undef, undef, 'orange' );
}

sub manage_eval {
    my ( $eval, $number ) = @_;
    
    return if ( $eval !~ /eval (.+)$/ );
    
    my @code = Text::Editor::Easy->get_code_for_eval( $1 );
    #print "Gestion de l'eval dans motion : reçu ", join ("\n", @code), "\n";
    return if ( anything_for_me );
    my $new_editor = $editor{''};
    if ( ! $new_editor ) {
            $new_editor = Text::Editor::Easy->new(
                {
                    'zone' => $display_zone,
                    'name' => 'eval*',
                    'highlight' => {
                        'use'     => 'Text::Editor::Easy::Syntax::Perl_glue',
                        'package' => 'Text::Editor::Easy::Syntax::Perl_glue',
                        'sub'     => 'syntax',
                    },
                    'events' => {
                        'motion' => {
                            'action' => 'nop',
                            'thread' => 'Motion',
                        }
                    },
                    'focus' => 'no',
                }
            );
        $editor{''} = $new_editor;
    }
    else {
        $new_editor->empty;
    }
    return if ( anything_for_me );

    for ( @code ) {
        $new_editor->insert( "$_\n" );
    }
    return if ( anything_for_me );
    
    my $line = $new_editor->number($number);
    return if ( ! defined $line );
    return ( $new_editor, $line );
}

sub manage_file {
    my ( $file, $number ) = @_;
    
    my $new_editor = $editor{$file};
    #print "move over out file : AVANT new_editor : $file\n";
    my $line;
    if ( !$new_editor ) {
        $new_editor = Text::Editor::Easy->whose_file_name($file);
        return if ( anything_for_me );
        if ( !$new_editor ) {
            my $conf_ref = {
                'file'      => $file,
                'zone'      => $display_zone,
                'highlight' => {
                    'use'     => 'Text::Editor::Easy::Syntax::Perl_glue',
                    'package' => 'Text::Editor::Easy::Syntax::Perl_glue',
                    'sub'     => 'syntax',
                },
                'config' => {
                    'first_line_number' => $number,
                    'first_line_at' => 'middle',
                },
                'events' => {
                    'motion' => {
                        'action' => 'nop',
                        'thread' => 'Motion',
                    }
                },
                'focus' => 'no',
            };

            $new_editor = Text::Editor::Easy->new( $conf_ref );
            $new_editor->save_info($conf_ref, 'conf');
        }
        
        # Peut-on être sûr que la liste "file_list_ref" sauvegardée dans 'info' du thread File_manager du Tab est mise à jour ?
        
        $editor{$file} = $new_editor;
        return if ( anything_for_me );
        $line = $new_editor->number($number, {
            'lazy' => threads->tid,
            'check_every' => 20,
        });
        return if ( ! defined $line or ref $line ne 'Text::Editor::Easy::Line' );
        $line_number{$file}{$number} = $line;
    }
    else {
        return if (anything_for_me);    # Abandonne si autre chose à faire
        #print "move over out file : AVANT number : $number\n";
        $line = $line_number{$file}{$number};
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
        $new_editor->async->display( $line, { 'at' => 'middle' } );
    }
    return ( $new_editor, $line );
}

sub init_set {
    my ( $self, $reference, $zone ) = @_;

    print "Dans init_set $self, $zone\n";
    $display_zone = $zone->{'name'};
}

sub cursor_set_on_who_file {
    my ( $editor, $hash_ref ) = @_;

    return if (anything_for_me);
    $editor->async->make_visible;
    return if (anything_for_me);
# Pris en charge par "move_over_out_file" dans le cas "cursor_set" pour des questions de rapidité
    my $hash_ref_line = $hash_ref->{'line'};
    return if ( !$hash_ref_line );
    my $text = $hash_ref_line->text;
    return if (anything_for_me);    # Abandonne si autre chose à faire

    return if ( $text !~ /^File (.+)\|Line (\d+)\|Package (.+)/ );
    my ( $file, $number, $package ) = ( $1, $2, $3 );

    my ( $new_editor, $line );
    print "Dans cursor_set_on_who_file : avant manage_..., thread", threads->tid, "\n";
    return if (anything_for_me);    # Abandonne si autre chose à faire
    if ( ! -f $file ) {
        # gestion de l'eval...
        ( $new_editor, $line ) = manage_eval ( $file, $number );
    }
    else {
        ( $new_editor, $line ) = manage_file ( $file, $number );        
    }

    return if ( ! defined $new_editor );

    print "Appel on top pour new_editor ", $new_editor->name, "\n";
    $new_editor->on_top;
    print "Fin appel on top pour new_editor\n";
    $line->select( undef, undef, 'white' );
    $editor->deselect;
    $hash_ref->{'line'}->select( undef, undef, 'orange' );
}

sub zone_resize {
    my ( $zone_name, $where, $options_ref ) = @_;
    
    my $zone = Text::Editor::Easy::Zone->whose_name( $zone_name );
    my @zone_coord = $zone->coordinates;
#    print "Appel de zone resize...\n";
    $zone->resize( 
        $where,
        $options_ref,
        @zone_coord
    );
}

sub nop {
    # Just to stop other potential useless processing
    return if ( anything_for_me );
    
    my ( $unique_ref, $editor ) = @_;
    $editor->async->make_visible;
}

=head1 FUNCTIONS

=head2 cursor_set_on_who_file

=head2 init

=head2 init_move

=head2 init_set

=head2 manage_events

=head2 move_over_out_editor

=head2 reference_event

=cut

=head1 COPYRIGHT & LICENSE

Copyright 2008 - 2009 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut


1;

















