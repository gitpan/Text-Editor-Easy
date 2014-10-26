package Text::Editor::Easy::Motion;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Motion - Manage various user events on "Text::Editor::Easy" objects.

=head1 VERSION

Version 0.44

=cut

our $VERSION = '0.44';

use threads;
use Text::Editor::Easy::Comm;
use Devel::Size qw(size total_size);

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
        #print "FALSE METHOD ", $false_method . ' ' . threads->tid,
        #  "|$unique_ref|", join( "|", @param ), "\n";

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

        #print "Ev�nement $what r�f�renc� size ", total_size($self), "\n";
        my ( $ref_editor, $hash_ref, @other ) = @param;
        if ( !defined $referenced{$what}{$ref_editor} ) {
            print STDERR
"L'�v�nement $what n'a pas �t� r�f�renc� pour l'�diteur $ref_editor\n";
            return;
        }

        #print "OK ===> $what r�f�renc� pour $ref_editor\n";
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

    #print "DANS INIT_MOVE $self, $unique_ref, $ref_editor, $zone\n";
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
my @selected;       # Ligne s�lectionn�e de la sortie
my %line_number;    # Sauvegarde des recherches, fuite m�moire pas important ici

sub move_over_eval_editor {
    my ( $unique_ref, $editor, $hash_ref ) = @_;
    
    $hash_ref->{'editor'} = 'eval';
    move_over_out_editor ( $unique_ref, $editor, $hash_ref );
}

sub move_over_external_editor {
    my ( $unique_ref, $editor, $hash_ref ) = @_;
    
    $hash_ref->{'editor'} = 'external';
    move_over_out_editor ( $unique_ref, $editor, $hash_ref );
}

sub move_over_out_editor {
    my ( $unique_ref, $editor, $hash_ref ) = @_;

    return if (anything_for_me);
    
    $editor->async->unset_at_end;

    #print "DANS MOVE_OVER_OUT_FILE $editor, $hash_ref\n";

    my $line_of_out = $hash_ref->{'line'};
    return if ( !$line_of_out );
    my $seek_start = $line_of_out->seek_start;

    return if (anything_for_me);

    #print "Avant appel get_info:  $seek_start\n";
    my $pos = $hash_ref->{'line_pos'};

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
            print "Dans motion, j'ai bien re�u ref_first = $ref_first\n";
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
        print "Re�u de get_info_for_display $ref_first et $pos_first\n";
    }

    return if (anything_for_me);    # Abandonne si autre chose � faire

    $show_calls_editor->deselect;
    return if (anything_for_me);    # Abandonne si autre chose � faire
    $show_calls_editor->empty;
    return if (anything_for_me);    # Abandonne si autre chose � faire

    #print "ENREG 1 = $enreg[1]\n";
    
    my ( $info ) = $enreg[1] =~ /^\t(.+)/;
    
    my ( $file, $number, $package ) = split( /\|/, $info );
    chomp $package;                 # En principe inutile

    return if (anything_for_me);    # Abandonne si autre chose � faire

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
    
    #print "Dans motion, je s�lectionne $ref_first de $pos_first � $pos_last\n";
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
    #    print "Dans move over out, t�che re�ue : @param\nFin de param�tres\n";
    #}

    return if (anything_for_me);    # Abandonne si autre chose � faire
         # S�lection de la ligne que l'on va traiter : la premi�re
    #$first_line = $show_calls_editor->first;
    #$show_calls_editor->display( $first_line, { 'at' => 'top' } );
    $first_line->select( undef, undef, 'orange' );
}

sub manage_eval {
    my ( $eval, $number ) = @_;
    
    return if ( $eval !~ /eval (.+)$/ );
    
    my @code = Text::Editor::Easy->get_code_for_eval( $1 );
    #print "Gestion de l'eval dans motion : re�u ", join ("\n", @code), "\n";
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
                }
            );
        $editor{''} = $new_editor;
    }
    else {
        $new_editor->on_top;
    }
    $new_editor->empty;
    for ( @code ) {
        $new_editor->insert( "$_\n" );
    }
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
                    'config' => {
                        'first_line_number' => $number,
                        'first_line_at' => 'middle',
                    },
                }
            );
        }
        $editor{$file} = $new_editor;
        $line = $new_editor->number($number);
        return if ( ! defined $line );
        $line_number{$file}{$number} = $line;
    }
    else {
        return if (anything_for_me);    # Abandonne si autre chose � faire
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
        $new_editor->on_top;
        $new_editor->async->display( $line, { 'at' => 'middle' } );
    }
    return ( $new_editor, $line );
}

sub init_set {
    my ( $self, $reference, $unique_ref, $zone ) = @_;

    #print "Dans init_set $self, $zone\n";
    $display_zone = $zone->{'name'};
}

sub cursor_set_on_who_file {
    my ( $unique_ref, $editor, $hash_ref ) = @_;

    return if (anything_for_me);
    $editor->async->make_visible;
    return if (anything_for_me);
# Pris en charge par "move_over_out_file" dans le cas "cursor_set" pour des questions de rapidit�
    my $hash_ref_line = $hash_ref->{'line'};
    return if ( !$hash_ref_line );
    my $text = $hash_ref_line->text;
    return if (anything_for_me);    # Abandonne si autre chose � faire

    return if ( $text !~ /^File (.+)\|Line (\d+)\|Package (.+)/ );
    my ( $file, $number, $package ) = ( $1, $2, $3 );

    my ( $new_editor, $line );
    if ( ! -f $file ) {
        # gestion de l'eval...
        ( $new_editor, $line ) = manage_eval ( $file, $number );
    }
    else {
        ( $new_editor, $line ) = manage_file ( $file, $number );        
    }
       
    return if ( ! defined $new_editor );
        
    $line->select( undef, undef, 'white' );
    $editor->deselect;
    $hash_ref->{'line'}->select( undef, undef, 'orange' );
}

sub zone_resize {
    my ( $self, $zone_name, $where, $options_ref ) = @_;
    
    print "Dans zone resize de $zone_name, tid = ", threads->tid, " - where = $where|$options_ref\n";
    my $zone = Text::Editor::Easy::Zone->whose_name( $zone_name );
    return if ( anything_for_me );
    print "Objet zone ? : $zone\n";
    my @zone_coord = $zone->coordinates;
    return if ( anything_for_me );
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



