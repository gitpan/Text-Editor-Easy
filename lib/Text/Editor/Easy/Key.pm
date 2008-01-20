package Key;
use strict;

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
      if ( !defined Key::left($self) )
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

    my @list = Editor->list;
    print "Liste des éditeur ", @list, "\n";
    $self->focus( $list[0] );
}

sub sel_second {
    my ($self) = @_;

    print "Liste des éditeur ", Editor->list, "\n";
    my @list = Editor->list;
    $self->focus( $list[1] );
}

1;
