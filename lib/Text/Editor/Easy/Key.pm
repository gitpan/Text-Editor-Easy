package Text::Editor::Easy::Key;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Key - Key functions using object-oriented interface of "Text::Editor::Easy".

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

sub left {
    my ($self) = @_;

    my $cursor = $self->cursor;
    if ( my $position = $cursor->get ) {
        my $new_position = $cursor->set( $position - 1 );
        $cursor->make_visible;
        return $new_position;
    }

    # Curseur en début de ligne
    my $line = $cursor->line->previous;
    if ($line) {
        my $new_position = $cursor->set( length( $line->text ), $line );
        $cursor->make_visible;
        return $new_position;
    }

    # Curseur en début de fichier (utilisé par la touche 'backspace')
    return;
}

sub right {
    my ($self) = @_;

    my $cursor   = $self->cursor;
    my $position = $cursor->get;
    my $line     = $cursor->line;
    if ( $position < length( $line->text ) ) {
        $cursor->set( $position + 1 );
        $cursor->make_visible;
        return;
    }

    # Curseur en fin de ligne
    if ( my $next = $line->next )
    {    # Test car risque de retour à 0 sur la dernière ligne
        $cursor->set( 0, $next );
        $cursor->make_visible;
    }
    return;
}

sub up {
    my ($self) = @_;

    my $cursor = $self->cursor;
    $cursor->make_visible;
    my $display  = $cursor->display;
    my $previous = $display->previous;
    if ( defined $previous ) {
        $cursor->set(
            {
                'x'            => $cursor->virtual_abs,
                'display'      => $previous,
                'keep_virtual' => 1,
            }
        );
        $cursor->make_visible;
    }
}

sub down {
    my ($self) = @_;

    my $cursor = $self->cursor;
    $cursor->make_visible;
    my $display = $cursor->display;
    my $next    = $display->next;
    if ( defined $next ) {
        $cursor->set(
            {
                'x'            => $cursor->virtual_abs,
                'display'      => $next,
                'keep_virtual' => 1,
            }
        );
        $cursor->make_visible;
    }
}

sub move_down {
    my ($self) = @_;

    $self->screen->move( 0, -1 );
}

sub move_up {
    my ($self) = @_;

    $self->screen->move( 0, 1 );
}

sub backspace {
    my ($self) = @_;

    return
      if ( !defined Text::Editor::Easy::Key::left($self) )
      ;    # left_key renvoie undef si on est au début du fichier

    # Améliorer l'interface de erase en autorisant les nombres négatifs ==>
    #    $self->erase(-1)
    $self->erase(1);
}

sub home {
    my ($self) = @_;

    my $cursor  = $self->cursor;
    my $display = $cursor->display;
    if ( $cursor->position_in_display ) {
        $cursor->set( 0, $display );
        $cursor->make_visible;
    }
    elsif ( $display->previous_is_same ) {
        $cursor->set( 0, $display->previous );
        $cursor->make_visible;
    }
    return;
}

sub end {
    my ($self) = @_;

    my $cursor  = $self->cursor;
    my $display = $cursor->display;
    if ( $cursor->position_in_display == length( $display->text ) ) {
        if ( $display->next_is_same ) {
            my $next = $display->next;
            $cursor->set( length( $next->text ), $next );
            $cursor->make_visible;
        }
    }
    else {
        $cursor->set( length( $display->text ), $display );
        $cursor->make_visible;
    }
    return;
}

sub end_file {
    my ($self) = @_;

    my $last = $self->last;

    $self->display( $last, { 'at' => 'bottom', 'from' => 'bottom' } );
    my $cursor = $self->cursor;
    $cursor->set( length( $last->text ), $last );
    $cursor->make_visible;
}

sub top_file {
    my ($self) = @_;

    my $first = $self->first;

    $self->display( $first, { 'at' => 'top', 'from' => 'top' } );
    my $cursor = $self->cursor;
    $cursor->set( 0, $first );
    $cursor->make_visible;
}

sub jump_right {
    my ($self) = @_;

    my $cursor   = $self->cursor;
    my $position = $cursor->position_in_display;
    my $display  = $cursor->display;
    if ( $position + 6 > length( $display->text ) ) {
        return $cursor->set( length( $display->text ), $display );
    }
    else {
        return $cursor->set( $position + 6, $display );
    }
}

sub jump_left {
    my ($self) = @_;

    my $cursor   = $self->cursor;
    my $position = $cursor->position_in_display;
    my $display  = $cursor->display;
    if ( $position > 6 ) {
        return $cursor->set( $position - 6, $display );
    }
    else {
        return $cursor->set( 0, $display );
    }
}

sub jump_up {
    my ($self) = @_;

    my $cursor = $self->cursor;
    $cursor->make_visible;
    my $display = $cursor->display;
    my $jump    = 6;
    my $previous;
    while ( $display = $display->previous and $jump ) {
        $cursor->set(
            {
                'x'            => $cursor->virtual_abs,
                'display'      => $display,
                'keep_virtual' => 1,
            }
        );
        $cursor->make_visible;
        $jump -= 1;
    }
}

sub jump_down {
    my ($self) = @_;

    my $cursor = $self->cursor;
    $cursor->make_visible;
    my $display = $cursor->display;
    my $jump    = 6;
    my $next;
    while ( $display = $display->next and $jump ) {
        $cursor->set(
            {
                'x'            => $cursor->virtual_abs,
                'display'      => $display,
                'keep_virtual' => 1,
            }
        );
        $cursor->make_visible;
        $jump -= 1;
    }
}

# Pour les 2 fonctions suivantes, il manque :
#		- la gestion du curseur
#		- le recentrage
sub page_down {
    my ($self) = @_;

    my $screen = $self->screen;
    my $last   = $screen->number( $screen->number );
    print "LAST text :", $last->text, "\n";
    $self->display( $last, { 'at' => 'top' } );
}

sub page_up {
    my ($self) = @_;

    my $first = $self->screen->number(1);
    print "FIRST text :", $first->text, "\n";
    $self->display( $first, { 'at' => 'bottom', 'from' => 'bottom' } );
}

sub new_a {
    my ($self) = @_;

    $self->insert('bc');
}

sub query_segments {
    my ($self) = @_;

    return $self->query_segments;
}

sub save {
    my ($self) = @_;

# Si aucun nom n'existe pour l'éditeur courant, faire apparaître une fenêtre le demandant
# => accès à un gestionnaire de fichier
    return $self->save;
}

sub print_screen_number {
    my ($self) = @_;

    my $screen = $self->screen;
    print "Screen number = ", $screen->number, "\n";
    my $display = $screen->first;
    while ($display) {
        print $display->number, "|", $display->text, "\n";
        $display = $display->next;
    }
}

sub display_cursor_display {
    my ($self) = @_;

    my $display = $self->cursor->display;
    print "\nT|", $display->ord - $display->height, "\n";
    print "H|", $display->height, "\n";
    print "O|", $display->ord,    "\n";

}

my $buffer;

sub copy_line {
    my ($self) = @_;

    $buffer = $self->cursor->line->text . "\n";
}

sub cut_line {
    my ($self) = @_;

    my $cursor = $self->cursor;
    my $line   = $cursor->line;
    $buffer = $line->text;
    $cursor->set(0);
    $self->erase( length( $line->text ) + 1 );
}

sub paste {
    my ($self) = @_;

    $self->insert($buffer);
}

sub wrap {
    my ($self) = @_;

    my $screen = $self->screen;
    if ( $screen->wrap ) {
        $screen->unset_wrap;
    }
    else {
        $screen->set_wrap;
    }
}

sub inser {
    my ($self) = @_;

    if ( $self->insert_mode ) {
        $self->set_replace;
    }
    else {
        $self->set_insert;
    }
}

sub list_display_positions {
    my ($self) = @_;

    my $display = $self->cursor->display;
    print "Abscisses pour $display->text\n";
    for ( 0 .. length( $display->text ) ) {
        print "\t$_ : ", $display->abs($_), "\n";
    }
}

sub sel_first {
    my ($self) = @_;

    my @list = Text::Editor::Easy->list;
    print "Liste des éditeur ", @list, "\n";
    $self->focus( $list[0] );
}

sub sel_second {
    my ($self) = @_;

    print "Liste des éditeur ", Text::Editor::Easy->list, "\n";
    my @list = Text::Editor::Easy->list;
    $self->focus( $list[1] );
}

=head1 FUNCTIONS

=head2 backspace

=head2 copy_line

=head2 cut_line

=head2 display_cursor_display

=head2 down

=head2 end

=head2 end_file

=head2 home

=head2 inser

=head2 jump_down

=head2 jump_left

=head2 jump_right

=head2 jump_up

=head2 left

=head2 list_display_positions

=head2 move_down

=head2 move_up

=head2 new_a

=head2 page_down

=head2 page_up

=head2 paste

=head2 print_screen_number

=head2 query_segments

=head2 right

=head2 save

=head2 sel_first

=head2 sel_second

=head2 top_file

=head2 up

=head2 wrap

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
