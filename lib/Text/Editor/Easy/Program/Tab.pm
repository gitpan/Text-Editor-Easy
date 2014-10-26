package Text::Editor::Easy::Program::Tab;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Program::Tab - Tab simulation with just a Text::Editor::Easy object.

=head1 VERSION

Version 0.2

=cut

our $VERSION = '0.2';

use Text::Editor::Easy::Comm;

#sub anything_for_me {};
use File::Basename;

use Data::Dump qw(dump);

my %tab_object;

sub on_main_editor_change {
    my $name = on_top_editor_change(@_);
    print "On main editor change : $name\n";
    $_[0]->change_title($name);
}

sub on_top_editor_change {
    my ( $new_on_top_editor, $tab_ref, $hash_ref ) = @_;

#print "\n\nDans on_top_editor_change de Tab : $new_on_top_editor, $tab_ref\n";
#print "Nom du nouveau fichier on_top : |", $new_on_top_editor->file_name, "|\n";
    my $tab_editor = $tab_object{$tab_ref};
    if ( !$tab_editor ) {
        print "Cr�ation locale l'�diteur correspondant au Tab $tab_ref\n";
        $tab_editor = bless \do { my $anonymous_scalar }, "Text::Editor::Easy";
        Text::Editor::Easy::Comm::set_ref( $tab_editor, $tab_ref);
        $tab_object{$tab_ref} = $tab_editor;
    }
    my $info_ref      = $tab_editor->load_info;
    my $file_list_ref = $info_ref->{'file_list'};

    print "Dans on_top_editor_change avant appel file_name\n";

    # Attention, file_name peut �tre ind�fini, il faut �galement tester name...
    my $file_name = $new_on_top_editor->file_name;
    print "Dans on_top_editor_change apr�s appel file_name $file_name\n";
    my $indice = 0;
    my $start  = 0;
    my $end;
    my $found_ref;
    my $tab_line = "";
  FILE: for my $file_conf_ref ( @{$file_list_ref} ) {
        $indice += 1;
        my $name = $file_conf_ref->{'name'};
        $end += length($name);
        $tab_line .= $name . ' ';
        if ( $file_conf_ref->{'file'} eq $file_name ) {
            print "Trouv� $file_name en position $indice, de $start � $end\n";
            $found_ref = [ $start, $end ];

            #last FILE;
        }
        $start += length( $file_conf_ref->{'name'} ) + 1;
        $end   += 1;
    }
    print "Dans on_top_editor_change apr�s appel file_name\n";
    if ( !$found_ref ) {
        print "PAs trouv� le nom de $file_name\n";
        my @highlight = ();
        my @file      = ();
        my $name;

        if ( defined $hash_ref ) {
            if ( my $highlight = $hash_ref->{'highlight'} ) {
                @highlight = ( 'highlight', $highlight );
            }
            my $file;
            if ( $file = $hash_ref->{'file'} ) {
                @file = ( 'file', $file );
            }
            $name = $hash_ref->{'name'};
            if ( !defined $name ) {
                if ( defined $file ) {    # Redondance avec Data : � voir ...
                    $name = fileparse($file);
                }
                else {
                    $name = 'buffer';
                }
            }
        }
        else {
            $name = 'buffer';
        }
        push @{$file_list_ref}, { @highlight, @file, 'name' => $name };
        $found_ref = [ $start, $end + length($name) ];
        $tab_line .= $name . ' ';

        $info_ref->{'file_list'} = $file_list_ref;    # Utile ?
        $tab_editor->save_info($info_ref);
    }

    print "For�age de la ligne 1 de tab_editor � $tab_line\n";
    my $first = $tab_editor->first;
    print "On top editor change, premi�re ligne de l'onglet : |", $first->text,
      "|\n";
    if ( !$first ) {
        ($first) = $tab_editor->insert($tab_line);
        if ( !$first ) {
            print STDERR "Probl�me de cr�ation de la premi�re ligne pour Tab\n";
        }
    }
    else {
        my $text = $first->text;
        if ( $text ne $tab_line ) {

            #$first->set($tab_line);
            $tab_editor->cursor_set(0);
            $tab_editor->erase( length($text) );
            $tab_editor->insert($tab_line);
        }
    }
    print "On top editor change 2 (", $tab_editor->get_ref,
      ") premi�re ligne de l'onglet : |", $tab_editor->first->text, "|\n";
    $tab_editor->deselect;

    #print "First $first\n";
    return $first->select( $found_ref->[0], $found_ref->[1],
        $info_ref->{'color'} );
}

sub motion_over_tab {
    my ( $unique_ref, $editor, $hash_ref ) = @_;

 #print "Dans motion_over_tab $unique_ref|$editor|", $hash_ref->{'line'}, "|\n";
  # V�rification que l'on est bien sur la premi�re ligne
    return if ( anything_for_me() );

    my $first_line = $editor->first;
    print "First line $first_line\n";
    my $pointed_line = $hash_ref->{'line'};
    return if ( $first_line != $pointed_line );

    my $pos = $hash_ref->{'line_pos'};

    return if ( anything_for_me() );
    my $info_ref = $editor->load_info;
    return if ( anything_for_me() );
    my $file_list_ref = $info_ref->{'file_list'};

    my $file_ref      = 0;
    my $current_left  = 0;
    my $current_right = 0;
    my $name;
  FILE: for my $file_conf_ref ( @{$file_list_ref} ) {
        $name = $file_conf_ref->{'name'};
        my $length = length($name);
        $current_right += $length;
        if ( $pos >= $current_left and $pos <= $current_right ) {

            #print "POS $pos|$name| left $current_left, right $current_right\n";
            $file_ref = $file_conf_ref;
            last FILE;
        }
        return if ( anything_for_me() );
        $current_left  += $length + 1;
        $current_right += 1;
    }
    return if ( anything_for_me() );
    if ( !defined $file_ref or ref $file_ref ne 'HASH' ) {

        # Bug � voir
        $file_ref = {};
    }

    #print "FILE _ref |$name|$file_ref->{'file'}\n";
    my $new_on_top = Text::Editor::Easy->whose_name($name);
    if ( !$new_on_top ) {

   # L'�diteur n'existe pas on le cr�e � la vol�e
   #print "Cr�ation d'un �diteur par motion sur tab : ", dump ($file_ref), "\n";
        return if ( !$file_ref->{'zone'} );
        $file_ref->{'focus'} = 'yes';

        #$new_on_top = Text::Editor::Easy->new($file_ref);

# Appel asynchrone obligatoire : la cr�ation d'un �diteur peut obliger le thread 0 � appeler le thread motion
# de fa�on synchrone si des �v�nements sont "� r�f�rencer de fa�on asynchrone"
# ==> et en cas d'appel synchrone ici, on aurait un deadlock : 3 en attente de 0, lui-m�me en attente de 3
        Text::Editor::Easy::Async->new($file_ref);
    }
    else {

#$new_on_top->focus;
        $new_on_top->async->focus;
    }

}

=head1 FUNCTIONS

=head2 motion_over_tab

=head2 on_main_editor_change

=head2 on_top_editor_change

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
