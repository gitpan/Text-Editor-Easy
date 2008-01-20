package Data;

#use Easy::Comm;
use Comm;

#sub get_task_to_do {};
#sub anything_for_me {};
use Data::Dump qw(dump);

use strict;
use threads;
use Thread::Queue;

use Devel::Size qw(size total_size);
use File::Basename;

my $self_global;

use constant {

    #------------------------------------
    # LEVEL 1 : $self->[???]
    #------------------------------------
    ZONE_ORDER     => 0,
    FILE_OF_ZONE   => 1,
    EDITOR_OF_ZONE => 2,
    FILE_NAME      => 3,
    THREAD         => 4,
    CALL           => 5,
    RESPONSE       => 6,
    REDIRECT       => 7,    # Redirection des print
    COUNTER        => 8,
    TOTAL          => 9,
    NAME_OF_ZONE   => 10,
    NAME           => 11,
    INSTANCE       => 12,
    FULL_TRACE     => 13,
    ZONE           => 14,

    #------------------------------------
    # LEVEL 2 : $self->[TOTAL][???]
    #------------------------------------
    CALLS     => 0,
    STARTS    => 0,
    RESPONSES => 0,

    #------------------------------------
    # LEVEL 3 : $self->[CALL]{$call_id}[???]
    #------------------------------------
    STATUS        => 0,
    THREAD_LIST   => 1,
    METHOD_LIST   => 2,
    INSTANCE_LIST => 3,

    #THREAD => 4,
    METHOD   => 5,
    INSTANCE => 6,
    PREVIOUS => 7,
    SYNC     => 8,
    CONTEXT  => 9,

    #------------------------------------
    # LEVEL 3 : $self->[THREAD]{$tid}[???]
    #------------------------------------
    STATUS      => 0,
    CALL_ID     => 1,
    CALL_ID_REF => 2,
    EVAL        => 3,
};

sub return_self {
    return $self_global;
}

sub manage_requests {
    my ($data_queue) = @_;

    my $self = bless [], 'Data';

    #print "Data a été créé\n";
    $self->[COUNTER] = 0;    # PAs de redirection de print
    my $secondary_task_queue = Thread::Queue->new;

    $self_global = $self;    # Mise à jour de la variable 'globale'

    my $secondary_cpt = 0;
    while ( my ( $what, @param ) = Comm::get_task_to_do() ) {
        last if ( !defined $what );
        if ( $what eq 'trace' ) {
            my @dup_param_1 = @param;
            $secondary_task_queue->enqueue( join( '~@', @dup_param_1 ) );
            $secondary_cpt += 1;
            my $not_finished = 1;
            while ($not_finished) {
                while ( Comm::anything_for_me() ) {
                    ( $what, @param ) = Comm::get_task_to_do();
                    if ( $what ne 'trace' ) {

                        #print "DATA : $what est plus urgent\n";
                        execute( $self, $what, @param );
                    }
                    else {
                        my @dup_param_2 = @param;
                        $secondary_task_queue->enqueue(
                            join( '~@', @dup_param_2 ) );
                        $secondary_cpt += 1;
                    }
                }
                if ( $secondary_cpt > 0 ) {

             #print "DATA : traitement de trace, moins urgent $secondary_cpt\n";
                    $secondary_cpt -= 1;
                    my @tab = split( /~@/, $secondary_task_queue->dequeue );
                    execute( $self, 'trace', @tab );
                }
                else {
                    $not_finished = 0;
                }
            }
        }
        else {
            execute( $self, $what, @param );
        }
    }
}

my %ref_sub
  ;  # Stockage des méthodes appelées pour éviter l'évaluation dès le 2ème appel

sub execute {
    my ( $self, $what, @param ) = @_;

    if ( !$ref_sub{$what} ) {
        my $ref_sub = eval "\\&$what";
        my $response;
        eval {
            $response = Comm::simple_context_call( $self, $ref_sub, @param );
        };
        if ($@) {
            print STDERR
"La fonction $what n'est pas correctement implémentée dans le package ",
              __PACKAGE__, " $@\n";
            print STDERR $@;
            Comm::respond( @param, undef );
        }
        else {
            Comm::respond( @param, $response );
            $ref_sub{$what} = $ref_sub;
        }
    }
    else {
        Comm::simple_call( $self, $ref_sub{$what}, @param );
    }
}

sub reference_editor {
    my ( $self, $ref, $zone_ref, $file_name, $name ) = @_;

  #print "Dans reference_editor de Data : $ref, |$zone_ref|$file_name|$name|\n";
    my $zone;
    if ( defined $zone_ref ) {
        if ( ref $zone_ref eq 'HASH' or ref $zone_ref eq 'Zone' ) {
            $zone = $zone_ref->{'name'};
        }
        else {
            $zone = $zone_ref;
        }
    }

    #print "...suite reference de Data : |$zone|\n";
    # Bogue à voir
    return if ( !defined $zone );
    my $order = $self->[ZONE_ORDER]{$zone};
    $order = 0 if ( !defined $order );
    if ( defined $file_name ) {
        push @{ $self->[FILE_OF_ZONE]{$zone}{$file_name} }, $order;
    }
    if ( !defined $name and defined $file_name ) {
        $name = fileparse($file_name);
    }
    if ( defined $name ) {
        push @{ $self->[NAME_OF_ZONE]{$zone}{$name} }, $order;
    }
    $self->[EDITOR_OF_ZONE]{$zone}[$order] = $ref;
    $self->[FILE_NAME]{$zone}[$order]      = $file_name;
    $self->[NAME]{$zone}[$order]           = $name;
    $self->[INSTANCE]{$ref}{'name'}        = $name;
    $self->[INSTANCE]{$ref}{'file_name'}   = $file_name;
    $self->[ZONE_ORDER]{$zone} += 1;    # Valeur de retour, ordre dans la zone
}

sub data_file_name {
    my ( $self, $ref ) = @_;

    return $self->[INSTANCE]{$ref}{'file_name'};
}

sub data_name {
    my ( $self, $ref ) = @_;

    return $self->[INSTANCE]{$ref}{'name'};
}

sub data_get_editor_from_name {
    my ( $self, $wanted_name ) = @_;

    my $instance_ref = $self->[INSTANCE];

    #print DAT "Dans data_get...$self|$wanted_name\n";
    for my $key_ref ( %{$instance_ref} ) {
        my $name = $instance_ref->{$key_ref}{'name'};
        if ( defined $name and $name eq $wanted_name ) {

            #print "Dans boucle data...$key_ref|$name|$wanted_name\n";
            return $key_ref;
        }
    }
    return;
}

sub data_get_editor_from_file_name {
    my ( $self, $wanted_name ) = @_;

    my $instance_ref = $self->[INSTANCE];

    #print DAT "Dans data_get...$self|$wanted_name\n";
    for my $key_ref ( %{$instance_ref} ) {
        my $name = $instance_ref->{$key_ref}{'file_name'};

        #print DAT "Dans boucle data...$key_ref|$name\n";
        return $key_ref if ( defined $name and $name eq $wanted_name );
    }
    return;
}

sub find_in_zone {
    my ( $self, $zone, $file_name ) = @_;

    #print "Dans find_in_zone de Data : $self, $zone, $file_name\n";
    my $tab_of_file_ref = $self->[FILE_OF_ZONE]{$zone}{$file_name};
    my @ref_editor;
    my $tab_of_zone_ref = $self->[EDITOR_OF_ZONE]{$zone};
    for my $order (@$tab_of_file_ref) {

        #print "Trouvé à la position $order de la zone $zone\n";
        push @ref_editor, $tab_of_zone_ref->[$order];
    }
    return @ref_editor;
}

sub list_in_zone {
    my ( $self, $zone ) = @_;

    #print "Dans Liste_in_zone : $zone\n";
    my $tab_of_zone_ref = $self->[EDITOR_OF_ZONE]{$zone};
    my @ref_editor;
    for (@$tab_of_zone_ref) {
        push @ref_editor, $_;
    }
    return @ref_editor;
}

sub file_name_of_zone_order {
    my ( $self, $zone, $order ) = @_;

    my $zone_ref = $self->[FILE_NAME]{$zone};
    if ( defined $zone_ref ) {    # Pas d'autovivification
        return $zone_ref->[$order];
    }
}

sub name_of_zone_order {
    my ( $self, $zone, $order ) = @_;

    #print "Dans name_of_zone_order $zone|$order\n";
    my $zone_ref = $self->[NAME]{$zone};
    if ( defined $zone_ref ) {    # Pas d'autovivification
        return $zone_ref->[$order];
    }
}

use IO::File;

my $name       = fileparse($0);
my $own_STDOUT = "tmp/${name}_trace.trc";
open( ENC, ">$own_STDOUT" ) or die "ouverture de $own_STDOUT : $!\n";
autoflush ENC;

my $data_trace = "tmp/${name}_Data.trc";
open( DAT, ">$data_trace" ) or die "ouverture de $data_trace : $!\n";
autoflush DAT;

# Traçage
my %function = (
    'print'    => \&trace_print,
    'call'     => \&trace_call,
    'response' => \&trace_response,
    'new'      => \&trace_new,
    'start'    => \&trace_start,
);

sub trace {
    my ( $self, $function, @data ) = @_;

    $function{$function}->( $self, @data );
}

sub trace_print {
    my ( $self, $dump_hash, @param ) = @_;

    #Ecriture sur fichier
    my $seek_start = tell ENC;
    no warnings;    # @param peut contenir des élément undef
    print ENC @param;
    my $param = join( '', @param );
    use warnings;
    my $seek_end = tell ENC;

    # Traçage des print
    my %options = eval $dump_hash;
    return if ($@);

    my @calls = eval $options{'calls'};
    trace_display_calls(@calls) if ( !$@ );
    my $tid = $options{'who'};

    my $thread_ref = $self->[THREAD][$tid];

    #        my $seek_start = tell ENC;
    #        no warnings; # @param peut contenir des élément undef
    #        {
    #            my $call_id = "";
    #            $call_id = $thread_ref->[CALL_ID] if ( defined $call_id );
    #            print ENC $tid, "|", $call_id, ":", @param;
    #        }
    #        my $param = join ('', @param);
    #        use warnings;
    #        my $seek_end = tell ENC;
    return if ( !defined $thread_ref );

    if ( my $eval_ref = $thread_ref->[EVAL] ) {
        for my $indice ( 1 .. scalar(@calls) / 3 ) {
            my $file = $calls[ 3 * $indice - 2 ];

         #print ENC "evaluated file $eval_ref->[0]|$eval_ref->[1]|FILE|$file\n";
            if ( $file =~ /\(eval (\d+)/ ) {
                if ( $1 >= $eval_ref->[1] ) {
                    $calls[ 3 * $indice - 2 ] = $eval_ref->[0];
                }
            }
        }
        $options{'calls'} = dump @calls;
    }

    if ( defined $thread_ref->[STATUS] ) {

        #print DAT "\t  Statut de $tid : ", $thread_ref->[STATUS][0] . "\n";
    }

    my $call_id_ref = $thread_ref->[CALL_ID_REF];
    my $call_id;
    if ( defined $call_id_ref ) {
        $call_id = $thread_ref->[CALL_ID];

        #print DAT "\tThread liste :\n";
        for my $thread_id ( sort keys %{ $call_id_ref->[THREAD_LIST] } ) {

            #print DAT "\t\t$thread_id\n";
        }

        #print DAT "\tMethod liste :\n";
        for my $method ( sort keys %{ $call_id_ref->[METHOD_LIST] } ) {

            #print DAT "\t\t$method\n";
        }
    }

    # Redirection éventuelle du print
    if ( my $hash_list_ref = $self->[REDIRECT] ) {

   #print DAT "REDIRECTION effective pour appel ", $thread_ref->[CALL_ID], "\n";
      RED: for my $redirect_ref ( values %{$hash_list_ref} ) {

            # Eviter l'autovivification
            next RED
              if ( !defined $call_id_ref
                and $tid != $redirect_ref->{'thread'} );

#print DAT "redirect_ref thread = ", $redirect_ref->{'thread'}, " (tid = $tid)\n";
            if ( $tid == $redirect_ref->{'thread'}
                or defined $call_id_ref->[THREAD_LIST]
                { $redirect_ref->{'thread'} } )
            {

                #print DAT "A ECRIRE : ", join ('', @param), "\n";
                my $excluded = $redirect_ref->{'exclude'};

       #print DAT "Excluded : ", $call_id_ref->[THREAD_LIST]{ $excluded }, "\n";
                next RED
                  if (  defined $excluded
                    and defined $call_id_ref->[THREAD_LIST]{$excluded} );
                Async_Editor->ask2( $redirect_ref->{'method'}, $param );

# Danger redirection synchrone devrait être possible si le thread 0 ne fait pas partie de la liste...
# Editor->ask2( $redirect_ref->{'method'}, join ('', @param) );
            }

           #print DAT "redirect_ref method = ", $redirect_ref->{'method'}, "\n";
        }
    }
    if ( !defined $self->[FULL_TRACE] ) {
        $self->[FULL_TRACE] =
          Editor->create_standard_server_thread( "Easy::Trace::Print",
            [ 'trace_full', 'init_trace_print', 'get_info_for_display' ], [] );
        Async_Editor->init_trace_print($own_STDOUT);
    }
    Async_Editor->trace_full( $seek_start, $seek_end, $tid, $call_id,
        $options{'calls'}, $param );

    return;    # Eviter autre chose que le context void pour Async_Editor
}

sub reference_print_redirection {
    my ( $self, $hash_ref ) = @_;

    my $counter = $self->[COUNTER] + 1;
    $self->[REDIRECT]{$counter} = $hash_ref;
    $self->[COUNTER] = $counter;
    return $counter;
}

sub trace_call {
    my (
        $self,    $call_id, $server, $method, $unique_ref,
        $context, $seconds, $micro,  @calls
      )
      = @_;

    $self->[TOTAL][CALLS] += 1;

    #print DAT "C|$call_id|$server|$seconds|$micro|$method\n";

    my ( $client, $id ) = split( /_/, $call_id );
    my $thread_ref  = $self->[THREAD][$client];
    my $call_id_ref = $self->[CALL]{$call_id};
    $call_id_ref->[CONTEXT] = $context;
    if ( length($context) == 1 )
    {    # Appel synchrone, donc le thread appelant se met en attente
        unshift @{ $thread_ref->[STATUS] }, "P|$call_id|$server|$method"
          ;    # Thread $client pending for $server ($method)
        $call_id_ref->[SYNC] = 1;
    }
    else {
        $call_id_ref->[SYNC] = 0;
    }

    # Le thread client est peut-être déjà au service d'un call...
    if ( $call_id_ref->[SYNC] ) {

        #print DAT "$call_id synchrone ($context)\n";
        if ( my $previous_call_id_ref = $thread_ref->[CALL_ID_REF] ) {

#print DAT "Pour $call_id, récupération d'éléments de ", $thread_ref->[CALL_ID], "\n";
#$call_id_ref->[PREVIOUS] = $previous_call_id_ref;

            # Copies des valeurs, nouvelle références
            %{ $call_id_ref->[THREAD_LIST] } =
              %{ $previous_call_id_ref->[THREAD_LIST] };
            %{ $call_id_ref->[METHOD_LIST] } =
              %{ $previous_call_id_ref->[METHOD_LIST] };
            %{ $call_id_ref->[INSTANCE_LIST] } =
              %{ $previous_call_id_ref->[INSTANCE_LIST] };

#print DAT "Thread liste pour $call_id futur : ", keys %{$call_id_ref->[THREAD_LIST]}, "\n";
        }
        else {

            #print DAT "Pour $call_id, pas de récupération d'éléments\n";
            $call_id_ref->[THREAD_LIST]{$client} = 1;
        }
    }
    else
    { # En asynchrone, tant qu'il n'est pas démarré, personne (aucun thread) ne s'occupe de cette demande (call_id)
        $call_id_ref->[THREAD_LIST] = {};
    }

    #print DAT "THREAD_LIST de $call_id après CALL contexte $context :\n";
    #for ( sort keys %{$call_id_ref->[THREAD_LIST]} ) {
    #        print DAT "$_ ";
    #}
    #print DAT "\n";
    $call_id_ref->[METHOD_LIST]{$method}       = 1;
    $call_id_ref->[INSTANCE_LIST]{$unique_ref} = 1;
    $call_id_ref->[METHOD]                     = $method;
    $call_id_ref->[INSTANCE]                   = $unique_ref;

    my $thread_status = $self->[THREAD][$server][STATUS][0];
    if ( defined $thread_status and $thread_status =~ /^P/ ) {

        # deadlock possible
        print DAT
"DANGER client '$client' asking '$method' to server '$server', already pending : $thread_status\n";
    }
    $call_id_ref->[STATUS] = 'not yet started';

    $self->[CALL]{$call_id} = $call_id_ref;
    $self->[THREAD][$client] = $thread_ref;

    trace_display_calls(@calls);
}

sub trace_new {
    my ( $self, $from, $dump_array ) = @_;

    #print DAT "N:$from\n";
    my @calls = eval $dump_array;
    trace_display_calls(@calls) if ( !$@ );
}

sub trace_response {
    my ( $self, $from, $call_id, $method, $seconds, $micro, $response ) = @_;

    my $call_id_ref = $self->[CALL]{$call_id};
    return if ( !defined $call_id_ref );

    $self->[TOTAL][RESPONSES] += 1;

    if ( !defined $method ) {
        $method = "? (asynchronous call) : " . $call_id_ref->[METHOD];
        $call_id_ref->[STATUS] = 'ended';
        $self->[RESPONSE]{$call_id} = $response;
    }

    #print DAT "R|$from|$call_id|$seconds|$micro|$method\n$response\n";

    $self->[THREAD][$from] = ();
    $self->[THREAD][$from][STATUS][0] = "idle|$call_id";

    my ($client) = split( /_/, $call_id );

    my $status_ref = $self->[THREAD][$client][STATUS];
    if ( $call_id_ref->[SYNC] ) {
        if ( scalar(@$status_ref) < 2 ) {

         # Cas d'un thread client, pas vraiment idle mais on ne peut rien savoir
            $status_ref->[0] = 'idle';
        }
        else {
            shift @$status_ref;
        }
    }
    $self->[THREAD][$client][STATUS] = $status_ref;

    # Ménage de THREAD (systématique)
    #$self->[THREAD][$from][CALL_ID_REF] = ();
    #undef $self->[THREAD][$from][CALL_ID];

    my $call_id_client_ref = $self->[THREAD][$client][CALL_ID_REF];

#if ( defined $call_id_client_ref ) {
#        print DAT "Liste de threads avant ménage pour l'appelant (", $self->[THREAD][$client][CALL_ID], ")\n";
#        for ( sort keys %{$call_id_client_ref->[THREAD_LIST]} ) {
#            print DAT "$_ ";
#        }
#        print DAT "\n";
#}
#print DAT "Mise à zéro de la THREAD_LIST pour $call_id\n";

 # Ménage de CALL et RESPONSE (sauf si asynchrone avec récupération identifiant)
    if ( $call_id_ref->[SYNC] or $call_id_ref->[CONTEXT] eq 'AV' )
    {    # Asynchronous Void
        %{ $call_id_ref->[THREAD_LIST] }   = ();
        %{ $call_id_ref->[METHOD_LIST] }   = ();
        %{ $call_id_ref->[INSTANCE_LIST] } = ();

        #$call_id_ref->[PREVIOUS] = 0;
        $self->[CALL]{$call_id} = $call_id_ref;
        @{ $self->[CALL]{$call_id} } = ();
        delete $self->[CALL]{$call_id};
        delete $self->[RESPONSE]{$call_id};
    }
    $call_id_client_ref = $self->[THREAD][$client][CALL_ID_REF];

#if ( defined $call_id_client_ref ) {
#        print DAT "Liste de threads restant pour l'appelant (", $self->[THREAD][$client][CALL_ID], ")\n";
#        for ( sort keys %{$call_id_client_ref->[THREAD_LIST]} ) {
#            print DAT "$_ ";
#        }
#        print DAT "\n";
#}
}

sub free_call_id {
    my ( $self, $call_id ) = @_;

    #print DAT "Dans free_call_id A libérer : $call_id\n";

    my $call_id_ref = $self->[CALL]{$call_id};

    #print DAT "   Context $call_id_ref->[CONTEXT]\n";

    %{ $call_id_ref->[THREAD_LIST] }   = ();
    %{ $call_id_ref->[METHOD_LIST] }   = ();
    %{ $call_id_ref->[INSTANCE_LIST] } = ();

    #$call_id_ref->[PREVIOUS] = 0;
    $self->[CALL]{$call_id} = $call_id_ref;
    @{ $self->[CALL]{$call_id} } = ();
    delete $self->[CALL]{$call_id};
}

sub trace_start {
    my ( $self, $who, $call_id, $method, $seconds, $micro ) = @_;

    my $call_id_ref = $self->[CALL]{$call_id};
    return if ( !defined $call_id_ref );

    $self->[TOTAL][STARTS] += 1;

    my $thread_ref = $self->[THREAD][$who];
    my $status_ref = $thread_ref->[STATUS];
    unshift @$status_ref, "R|$method|$call_id"; # Thread $who is running $method

    $call_id_ref->[STATUS] = 'started';

    #print DAT "S|$who|$call_id|$seconds|$micro|$method\n";

    $call_id_ref->[THREAD_LIST]{$who} = 1;

    #print DAT "Ajout de $who pour la THREAD_LIST de $call_id\n\t";
    #print DAT "$call_id_ref ";
    #for ( sort keys %{$call_id_ref->[THREAD_LIST]} ) {
    #        print DAT "$_ ";
    #}
    #print DAT "\n";

    $call_id_ref->[THREAD]{$who} = 1;
    $self->[CALL]{$call_id}      = $call_id_ref;

    $thread_ref->[CALL_ID_REF] = $call_id_ref;
    $thread_ref->[CALL_ID]     = $call_id;

    $self->[THREAD][$who] = $thread_ref;

    #Débuggage du débuggage
    #my @imbriqued_calls = keys %{ $call_id_ref->[THREAD_LIST] };
    #if ( scalar @imbriqued_calls > 2 ) {
    #        for my $thread_id ( sort @imbriqued_calls ) {
    #print DAT "\tS!!! $thread_id|";
    #            for my $status ( @{ $self->[THREAD][$thread_id][STATUS] } ) {
    #print DAT " $status,";
    #            }
    #print DAT "\n";
    #        }
    #}
    # Vérification de la thread liste de l'appelant si synchrone  (debuggage)
    if ( $call_id_ref->[SYNC] ) {
        my ($client) = split( /_/, $call_id );
        my $thread_ref = $self->[THREAD][$client];

        #if ( defined $thread_ref and defined $thread_ref->[CALL_ID] ) {
        #print DAT "THREAD_LIST de l'appelant $thread_ref->[CALL_ID] :\n\t";
        #my $call_client_ref = $thread_ref->[CALL_ID_REF];
        #for ( sort keys %{$call_client_ref->[THREAD_LIST]} ) {
        #    print DAT "$_ ";
        #}
        #print DAT "\n";
        #}
    }
}

sub trace_display_calls {
    my @calls = @_;
    return;
    for my $indice ( 1 .. scalar(@calls) / 3 ) {
        my ( $pack, $file, $line ) = splice @calls, 0, 3;
        print DAT "\tF|$file|L|$line|P|$pack\n";
    }
}

sub async_status {
    my ( $self, $call_id ) = @_;

    return $self->[CALL]{$call_id}[STATUS];
}

sub async_response {
    my ( $self, $call_id ) = @_;

    my $call_id_ref = $self->[CALL]{$call_id};
    return if ( !defined $call_id_ref );
    if ( $call_id_ref->[STATUS] eq 'ended' ) {
        my $response = $self->[RESPONSE]{$call_id};

        # Ménage : la réponse ne peut être récupérée qu'une seule fois
        %{ $call_id_ref->[THREAD_LIST] }   = ();
        %{ $call_id_ref->[METHOD_LIST] }   = ();
        %{ $call_id_ref->[INSTANCE_LIST] } = ();

        #$call_id_ref->[PREVIOUS] = 0;
        $self->[CALL]{$call_id} = $call_id_ref;
        @{ $self->[CALL]{$call_id} } = ();
        delete $self->[CALL]{$call_id};
        delete $self->[RESPONSE]{$call_id};
        return eval $response;
    }
    return;
}

sub size_self_data {
    my ($self) = @_;

    print "DATA self size ", total_size($self), "\n";
    print "   THREAD   : ", total_size( $self->[THREAD] ), "\n";
    print "   CALL     : ", total_size( $self->[CALL] ),   "\n";
    my @array = %{ $self->[CALL] };
    print "Nombre de clé x 2 : ", scalar(@array), "\n";
    print DAT "Nombre de clé x 2 : ", scalar(@array), "\n";
    my $hash_ref = $self->[CALL];
    for ( sort keys %{ $self->[CALL] } ) {
        print DAT "\t$_|", $hash_ref->{$_}[CONTEXT], "|",
          $hash_ref->{$_}[METHOD], "\n";
    }
    print "   RESPONSE : ", total_size( $self->[RESPONSE] ), "\n";
    print "   DATA THREAD :", total_size( threads->self() ), "\n";
    print "   TOT CALLS   :", $self->[TOTAL][CALLS],     "\n";
    print "   TOT STARTS  :", $self->[TOTAL][STARTS],    "\n";
    print "   TOT RESPONS :", $self->[TOTAL][RESPONSES], "\n";
}

sub print_thread_list {
    my ( $self, $tid ) = @_;

    return if ( !defined $tid );
    my $string = "Thread liste :";

    my $thread_ref = $self->[THREAD][$tid];
    if ( !defined $thread_ref ) {
        $string .= "\n\t|$tid";
    }
    else {
        my $call_id_ref = $thread_ref->[CALL_ID_REF];

        if ( defined $call_id_ref ) {
            $string .= " ($thread_ref->[CALL_ID])\n\t";
            for my $thread_id ( sort keys %{ $call_id_ref->[THREAD_LIST] } ) {
                $string .= "|$thread_id";
            }
        }
        else {
            $string .= "\n\t|$tid";
        }
    }
    print $string, "|\n";
}

sub data_substitute_eval_with_file {
    my ( $self, $file, $number ) = @_;

    # Récupération du thread ayant appelé cette procédure
    my $call_id = $self->[THREAD][ threads->tid ][CALL_ID];
    my ($calling_thread) = split( /_/, $call_id );

    #print "Calling thread : $calling_thread\n";

    $self->[THREAD][$calling_thread][EVAL] = [ $file, $number ];
}

sub reference_zone {
    my ( $self, $hash_ref ) = @_;

    my $name = $hash_ref->{'name'};
    return if ( !defined $name );
    $self->[ZONE]{$name} = $hash_ref;
}

sub zone_named {
    my ( $self, $name ) = @_;

    return $self->[ZONE]{$name};
}

sub zone_list {
    my ($self) = @_;

    return keys %{ $self->[ZONE] };
}

1;
