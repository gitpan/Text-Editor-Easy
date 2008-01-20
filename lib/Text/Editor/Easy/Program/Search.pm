package Easy::Program::Search;

#use Easy::Comm;
use Comm;

#sub anything_for_me {};
use strict;
use warnings;

my $out;
my $eval_thread;
my $eval_print;

sub init_eval {
    my ( $self, $other_ref, $unique_ref ) = @_;
    print "============>INIT de Search .. $self, $unique_ref\n";
    $out = bless \do { my $anonymous_scalar }, "Editor";
    $out->reference($unique_ref);

    #$out->insert('Bonjour');
    #$self, $package, $tab_methods_ref, $self_server
    my $eval_thread =
      Editor->create_standard_server_thread( "Easy::Program::Eval::Exec",
        [ 'exec_eval', 'idle_eval_exec' ], [] );

    #print "EVAL _TJREAD = $eval_thread\n";
    #Editor->exec_eval('Bonjour');
    $eval_print =
      Editor->create_standard_server_thread( "Easy::Program::Eval::Print",
        [ 'print_eval', 'init_print_eval', 'idle_eval_print' ], [] );
    Editor->init_print_eval($unique_ref);
    print "FIN DE INIT EVAL = $eval_thread\n";

    # Référencer dans Data le thread $eval_thread en arborescence...
    my $redirect_id = Editor->reference_print_redirection(
        {
            'thread'  => $eval_thread,
            'type'    => 'tree',
            'method'  => 'print_eval',
            'exclude' => $eval_print,
        }
    );

    #Async_Editor->exec_eval('Après redirection : bonjour');
}

sub modify_pattern {
    my ( $unique_ref, $editor, $hash_ref ) = @_;

    #return;
    #print "Dans modify_pattern...$hash_ref->{'text'}\n";
    Async_Editor->idle_eval_exec($eval_print);
    return if ( anything_for_me() );
    my $line    = $editor->first;
    my $program = $line->text;
    return if ( anything_for_me() );
    while ( $line = $line->next ) {
        $program .= "\n" . $line->text;
        return if ( anything_for_me() );
    }
    return if ( anything_for_me() );
    my @array;

# Avant de faire le ménage il faut :
# ----------------------------------
# 1 - être sûr que le thread 10 ne tourne plus et ne génère pas de nouveaux print pour eval_print
    Editor->idle_eval_exec($eval_print);
    return if ( anything_for_me() );

# 2 - être sûr qu'il ne reste plus aucun print asynchrones à afficher (on vide tout ceux qui sont en attente)
    Editor->empty_queue($eval_print)
      ;    # Attention, ne faire des empty_queue que sur des threads ne faisant
           # pas l'objet de requêtes synchrones (sinon threads bloqués)
    return if ( anything_for_me() );

   # 3 - être sur que eval_print n'est pas en train d'éditer à nouveau une ligne
    Editor->idle_eval_print;
    return if ( anything_for_me() );

    $out->empty;
    return if ( anything_for_me() );

    $out->async->on_top;
    Async_Editor->exec_eval($program);
    return;
}

sub insert_out {
    my ( $self, $sentence ) = @_;

    $out->insert($sentence);
}

sub print_b {
    my ($self) = @_;

    print " Dans print_b\n";
    $self->insert('b');
}

sub print_toto {
    my ($self) = @_;

    print " Dans print_toto\n";
    $self->insert('toto');
}

sub search {
    my ( $ind, $exp ) = @_;

    print "IND $ind, EXP $exp\n";
    my @search = Editor->list_in_zone('zone1');
    my $search = bless \do { my $anonymous_scalar }, "Editor";
    $search->reference( $search[$ind] );

    # Recherche dans l'écran
    return if ( anything_for_me() );
    $search->deselect;
    return if ( anything_for_me() );
    my $start = $search->screen->first->line;
    return if ( anything_for_me() );
    my $stop = $search->screen->last->line;
    return if ( anything_for_me() );
    my $next = $stop->next;
    $stop = $next if ( defined $next );
    my $pos_start = 0;
    my $line      = $start;
  MATCH: while (1) {
        print "line start : ", $line->text, "\n";
        last MATCH if ( !defined $line );
        return     if ( anything_for_me() );
        my ( $found, $start_pos, $end_pos ) = $search->regexp(
            $exp,
            {
                'line_start' => $line,
                'pos_start'  => $pos_start,
                'line_stop'  => $stop,
            }
        );
        return     if ( anything_for_me() );
        last MATCH if ( !defined $found );

        #print "FOUND $found\n";

        my ($dis) = $found->displayed;
        return     if ( anything_for_me() );
        last MATCH if ( !defined $dis );       # Normalement pas possible...
        $dis->select( $start_pos, $end_pos );
        return if ( anything_for_me() );
        $line      = $found;
        $pos_start = $end_pos;
    }

  # Recherche dans le reste du fichier sans surlignage (pour gagner du temps...)
    my ( $found, $start_pos, $end_pos ) = $search->regexp(
        $exp,
        {
            'line_start' => $stop,
            'pos_start'  => 0,
            'line_stop'  => $start,
        }
    );
    return if ( anything_for_me() );
    if ($found) {
        print "Trouvé : ", $found->text, "\n";
    }
}

1;
