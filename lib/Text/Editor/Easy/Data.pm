package Text::Editor::Easy::Data;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Data - Global common data shared by all threads.

=head1 VERSION

Version 0.3

=cut

our $VERSION = '0.3';

use Data::Dump qw(dump);
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
	CURRENT => 15,
	SEARCH => 16,

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
    C_INSTANCE => 6,
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

sub reference_editor {
    my ( $self, $ref, $options_ref ) = @_;

    my $zone_ref = $options_ref->{'zone'};
	my $file_name = $options_ref->{'file'};
	my $name = $options_ref->{'name'};
	
    print DBG "Dans reference_editor de Data : $self |$ref|$zone_ref|$file_name|$name|\n";
    my $zone;
    if ( defined $zone_ref ) {
        if (   ref $zone_ref eq 'HASH'
            or ref $zone_ref eq 'Text::Editor::Easy::Zone' )
        {
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

    #print DBG "Dans data_file_name $self|$ref|";
    my $file_name = $self->[INSTANCE]{$ref}{'file_name'};
    #print DBG "$file_name" if ( defined $file_name );
    #print DBG "|\n";
    return $self->[INSTANCE]{$ref}{'file_name'};
}

sub data_name {
    my ( $self, $ref ) = @_;

    return $self->[INSTANCE]{$ref}{'name'};
}

sub data_get_editor_from_name {
    my ( $self, $wanted_name ) = @_;

    my $instance_ref = $self->[INSTANCE];

    print DBG "Dans data_get...$self|$wanted_name|$instance_ref\n";
	#return if ( ref $instance_ref ne 'HASH');
    for my $key_ref ( keys %{$instance_ref} ) {
		print DBG "Dans boucle data...$key_ref|$instance_ref->{$key_ref}|\n";
		#return if ( ref $instance_ref->{$key_ref} ne 'HASH' );
        my $name = $instance_ref->{$key_ref}{'name'};
        if ( defined $name and $name eq $wanted_name ) {


            return $key_ref;
        }
    }
    return;
}

sub data_get_editor_from_file_name {
    my ( $self, $wanted_name ) = @_;

    my $instance_ref = $self->[INSTANCE];

    #print DBG "Dans data_get...$self|$wanted_name\n";
    for my $key_ref ( keys %{$instance_ref} ) {
        my $name = $instance_ref->{$key_ref}{'file_name'};

        #print DBG "Dans boucle data...$key_ref|$name\n";
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

sub init_data {
    my ( $self, $reference, $data_queue ) = @_;

    #print DBG "Dans init_data : $self, $reference, $data_queue\n";
    bless $self, 'Text::Editor::Easy::Data';

    #print "Data a été créé\n";
    $self->[COUNTER] = 0;         # PAs de redirection de print
    $self_global = $self;         # Mise à jour de la variable 'globale'
}

use IO::File;

my $name       = fileparse($0);
my $own_STDOUT = "tmp/${name}_trace.trc";
if ( $Text::Editor::Easy::Trace{'trace_print'} ) {
    open( ENC, ">$own_STDOUT" ) or die "ouverture de $own_STDOUT : $!\n";
    autoflush ENC;
}

Text::Editor::Easy::Comm::manage_debug_file( __PACKAGE__, *DBG );

# Traçage
my %function = (
    'print'    => \&trace_print,
    'call'     => \&trace_call,
    'response' => \&trace_response,
#    'new'      => \&trace_new,
    'start'    => \&trace_start,
);

sub trace {
    my ( $self, $function, @data ) = @_;
    
	print DBG "Dans sub trace pour fonction $function\n";
    $function{$function}->( $self, @data );
}

my $trace_print_counter;

sub trace_print {
    my ( $self, $dump_hash, @param ) = @_;

    #print DBG "Début trace_print $self, $dump_hash, @param\n";

    #Ecriture sur fichier
    my $seek_start = tell ENC;
    no warnings;    # @param peut contenir des élément undef
    print ENC @param;
    my $param = join( '', @param );
    use warnings;
    my $seek_end = tell ENC;

    # Traçage des print
    my %options;
    #print DBG "trace_print avant eval dump\n";
    if ( defined $dump_hash ) {
        %options = eval $dump_hash;
        return if ($@);
    }
    else {
        return;
    }
    #print DBG "trace_print après eval dump\n";
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
    #return if ( !defined $thread_ref );

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

        #print DBG "\t  Statut de $tid : ", $thread_ref->[STATUS][0] . "\n";
    }
    my $call_id_ref = $thread_ref->[CALL_ID_REF];
    my $call_id;
    if ( defined $call_id_ref ) {
        $call_id = $thread_ref->[CALL_ID];

        #print DBG "\tThread liste :\n";
        for my $thread_id ( sort keys %{ $call_id_ref->[THREAD_LIST] } ) {

            #print DBG "\t\t$thread_id\n";
        }

        #print DBG "\tMethod liste :\n";
        for my $method ( sort keys %{ $call_id_ref->[METHOD_LIST] } ) {

            #print DBG "\t\t$method\n";
        }
    }

    # Redirection éventuelle du print
    #print DBG "trace_print avant redirection\n";
    if ( my $hash_list_ref = $self->[REDIRECT] ) {

   #print DBG "REDIRECTION effective pour appel ", $thread_ref->[CALL_ID], "\n";
      RED: for my $redirect_ref ( values %{$hash_list_ref} ) {

            # Eviter l'autovivification
            next RED
              if ( !defined $call_id_ref
                and $tid != $redirect_ref->{'thread'} );

#print DBG "redirect_ref thread = ", $redirect_ref->{'thread'}, " (tid = $tid)\n";
            if ( $tid == $redirect_ref->{'thread'}
                or defined $call_id_ref->[THREAD_LIST]
                { $redirect_ref->{'thread'} } )
            {

                #print DBG "A ECRIRE : ", join ('', @param), "\n";
                my $excluded = $redirect_ref->{'exclude'};

       #print DBG "Excluded : ", $call_id_ref->[THREAD_LIST]{ $excluded }, "\n";
                next RED
                  if (  defined $excluded
                    and defined $call_id_ref->[THREAD_LIST]{$excluded} );
                Text::Editor::Easy::Async->ask2( $redirect_ref->{'method'},
                    $param );
# Redirection synchrone impossible : appel de méthode quasi-standard (ask2) donc demande
# de traçage de la méthode (trace_call, trace_start puis trace_response) au thread Data qui ne peut
# par conséquent pas attendre ici (sans quoi, il ne répondrait plus aux requêtes de traçage et tout se bloque...)

				# La seule façon d'être synchrone, ne plus activer la trace pour l'appel et ses successeurs et ne jamais
				# rien demander au thread 2 en synchrone jusqu'à la fin...
				# ==> paramètre supplémentaire à l'appel à passer à toute la chaîne d'appel (possible ? sans Data)
            }

           #print DBG "redirect_ref method = ", $redirect_ref->{'method'}, "\n";
        }
    }

    if ( !$self->[FULL_TRACE] ) {
        $self->[FULL_TRACE] = 1;
        Text::Editor::Easy->create_new_server(
            {
                'use'     => 'Text::Editor::Easy::Trace::Print',
                'package' => "Text::Editor::Easy::Trace::Print",
                'methods' => [ 'trace_full', 'get_info_for_display' ],
                'object'  => [],
                'init'    => [
                    'Text::Editor::Easy::Trace::Print::init_trace_print',
                    $own_STDOUT
                ],
            }
        );
    }
    Text::Editor::Easy::Async->trace_full( $seek_start, $seek_end, $tid,
        $call_id, $options{'calls'}, $param );
    #print DBG "Fin trace_print $self\n";
    return
      ;  # Eviter autre chose que le context void pour Text::Editor::Easy::Async
}

sub reference_print_redirection {
    my ( $self, $hash_ref ) = @_;

    if ( !defined $self->[COUNTER] ) {
        $self->[COUNTER] = 0;
    }
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

    print DBG "C|$call_id|$server|$seconds|$micro|$method\n";

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

    #print DBG "Dans trace_call, définition de \$call_id_ref |$call_id_ref| effectuée, call_id $call_id, tid", threads->tid, "\n";

    # Le thread client est peut-être déjà au service d'un call...
    if ( $call_id_ref->[SYNC] ) {

        #print DBG "$call_id synchrone ($context)\n";
        if ( my $previous_call_id_ref = $thread_ref->[CALL_ID_REF] ) {
			#if ( ref $previous_call_id_ref->[THREAD_LIST] ne 'HASH' ) {
			#	print DBG "PAs une référence de hachage pour thread client $client, call_id en cours $call_id\n" .
			#	 "\t|$previous_call_id_ref|$previous_call_id_ref->[THREAD_LIST]|, tid", threads->tid, "\n";
		    #}
            %{ $call_id_ref->[THREAD_LIST] } =
              %{ $previous_call_id_ref->[THREAD_LIST] };
            %{ $call_id_ref->[METHOD_LIST] } =
              %{ $previous_call_id_ref->[METHOD_LIST] };
            %{ $call_id_ref->[INSTANCE_LIST] } =
              %{ $previous_call_id_ref->[INSTANCE_LIST] };

#print DBG "Thread liste pour $call_id futur : ", keys %{$call_id_ref->[THREAD_LIST]}, "\n";
        }
        else {

            #print DBG "Pour $call_id, pas de récupération d'éléments\n";
            $call_id_ref->[THREAD_LIST]{$client} = 1;
        }
    }
    else
    { # En asynchrone, tant qu'il n'est pas démarré, personne (aucun thread) ne s'occupe de cette demande (call_id)
        $call_id_ref->[THREAD_LIST] = {};
    }

    #print DBG "THREAD_LIST de $call_id après CALL contexte $context :\n";
    #for ( sort keys %{$call_id_ref->[THREAD_LIST]} ) {
    #        print DBG "$_ ";
    #}
    #print DBG "\n";
    $call_id_ref->[METHOD_LIST]{$method}       = 1;
    $call_id_ref->[INSTANCE_LIST]{$unique_ref} = 1;
    $call_id_ref->[METHOD]                     = $method;
    $call_id_ref->[C_INSTANCE]                   = $unique_ref;

    my $thread_status = $self->[THREAD][$server][STATUS][0];
    if ( defined $thread_status and $thread_status =~ /^P/ ) {

        # deadlock possible
        print DBG
"DANGER client '$client' asking '$method' to server '$server', already pending : $thread_status\n";
    }
    $call_id_ref->[STATUS] = 'not yet started';

    $self->[CALL]{$call_id} = $call_id_ref;
    $self->[THREAD][$client] = $thread_ref;

    trace_display_calls(@calls);
}

sub trace_new {
    my ( $self, $from, $dump_array ) = @_;

    #print DBG "N:$from\n";
    my @calls = eval $dump_array;
    trace_display_calls(@calls) if ( !$@ );
}

sub trace_response {
    my ( $self, $from, $call_id, $method, $seconds, $micro, $response ) = @_;

    my $call_id_ref = $self->[CALL]{$call_id};
    return
      if ( !defined $call_id_ref )
      ;    # Cela arrive pour les méthodes d'initialisation de thread
     # ==> tant qu'elles ne sont pas appelées de façon standard (avec traçage du call)

	#print DBG "trace_response : début d'actions sur \$call_id_ref |$call_id_ref|, méthod $method call_id $call_id, tid", threads->tid, "\n";
	#if ( ! defined $method ) {
	#	print DBG "La méthode est non définie , tid", threads->tid, "\n";
    #}
	#else {
	#	print DBG "La méthode vaut $method, tid", threads->tid, "\n";
    #} 

    $self->[TOTAL][RESPONSES] += 1;

    if ( !defined $method ) {
        $method = "? (asynchronous call) : " . $call_id_ref->[METHOD];
        $call_id_ref->[STATUS] = 'ended';
        $self->[RESPONSE]{$call_id} = $response;
    }

    print DBG "R|$from|$call_id|$seconds|$micro|$method\n";

# Ne faudrait-il pas faire plutot un shift de "$self->[THREAD][$from][STATUS]" ?
# ==> permettre de tracer des requêtes interruptibles tout en traçant les requêtes internes
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
	#    print DBG "Chargement de \$call_id_client_ref |$call_id_client_ref|, tid", threads->tid, "\n";
    #}

#if ( defined $call_id_client_ref ) {
#        print DBG "Liste de threads avant ménage pour l'appelant (", $self->[THREAD][$client][CALL_ID], ")\n";
#        for ( sort keys %{$call_id_client_ref->[THREAD_LIST]} ) {
#            print DBG "$_ ";
#        }
#        print DBG "\n";
#}
#print DBG "Mise à zéro de la THREAD_LIST pour $call_id\n";

 # Ménage de CALL et RESPONSE (sauf si asynchrone avec récupération identifiant)
    if ( $call_id_ref->[SYNC] or $call_id_ref->[CONTEXT] eq 'AV' ) {    # Asynchronous Void
		#print DBG "trace_response : suppressions des listes pour \$call_id_ref |$call_id_ref| call_id $call_id, tid", threads->tid, "\n";
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
#        print DBG "Liste de threads restant pour l'appelant (", $self->[THREAD][$client][CALL_ID], ")\n";
#        for ( sort keys %{$call_id_client_ref->[THREAD_LIST]} ) {
#            print DBG "$_ ";
#        }
#        print DBG "\n";
#}
#if ( my $call_id_ref = $self->[CALL]{$call_id} ) {
#    print DBG "Status de call_id $call_id : ", $call_id_ref->[STATUS], "\n";
#}
#else {
#	print DBG "$call_id plus défini...\n";
#}


}

sub free_call_id {
    my ( $self, $call_id ) = @_;

    #print DBG "Dans free_call_id A libérer : $call_id\n";

    my $call_id_ref = $self->[CALL]{$call_id};

    #print DBG "   Context $call_id_ref->[CONTEXT]\n";

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
	
	#print DBG "Dans trace_start \$call_id_ref |$call_id_ref|, call_id $call_id, tid", threads->tid, "\n";

    $self->[TOTAL][STARTS] += 1;

    my $thread_ref = $self->[THREAD][$who];
    my $status_ref = $thread_ref->[STATUS];
    unshift @$status_ref, "R|$method|$call_id"; # Thread $who is running $method

    $call_id_ref->[STATUS] = 'started';

    print DBG "S|$who|$call_id|$seconds|$micro|$method\n";

    $call_id_ref->[THREAD_LIST]{$who} = 1;

    #print DBG "Ajout de $who pour la THREAD_LIST de $call_id\n\t";
    #print DBG "$call_id_ref ";
    #for ( sort keys %{$call_id_ref->[THREAD_LIST]} ) {
    #        print DBG "$_ ";
    #}
    #print DBG "\n";

    $call_id_ref->[THREAD]{$who} = 1;
    $self->[CALL]{$call_id}      = $call_id_ref;

    $thread_ref->[CALL_ID_REF] = $call_id_ref;
    $thread_ref->[CALL_ID]     = $call_id;

    $self->[THREAD][$who] = $thread_ref;

    #Débuggage du débuggage
    #my @imbriqued_calls = keys %{ $call_id_ref->[THREAD_LIST] };
    #if ( scalar @imbriqued_calls > 2 ) {
    #        for my $thread_id ( sort @imbriqued_calls ) {
    #print DBG "\tS!!! $thread_id|";
    #            for my $status ( @{ $self->[THREAD][$thread_id][STATUS] } ) {
    #print DBG " $status,";
    #            }
    #print DBG "\n";
    #        }
    #}
    # Vérification de la thread liste de l'appelant si synchrone  (debuggage)
    if ( $call_id_ref->[SYNC] ) {
        my ($client) = split( /_/, $call_id );
        my $thread_ref = $self->[THREAD][$client];

        #if ( defined $thread_ref and defined $thread_ref->[CALL_ID] ) {
        #print DBG "THREAD_LIST de l'appelant $thread_ref->[CALL_ID] :\n\t";
        #my $call_client_ref = $thread_ref->[CALL_ID_REF];
        #for ( sort keys %{$call_client_ref->[THREAD_LIST]} ) {
        #    print DBG "$_ ";
        #}
        #print DBG "\n";
        #}
    }
}

sub trace_display_calls {
    my @calls = @_;
    return;
    for my $indice ( 1 .. scalar(@calls) / 3 ) {
        my ( $pack, $file, $line ) = splice @calls, 0, 3;
        print DBG "\tF|$file|L|$line|P|$pack\n";
    }
}

sub async_status {
    my ( $self, $call_id ) = @_;

#print "Dans async_status $self|$call_id|", $self->[CALL]{$call_id}[STATUS], "\n";
#print DBG "Dans async_status $self|$call_id|", $self->[CALL]{$call_id}[STATUS], "\n";
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
    print DBG "Nombre de clé x 2 : ", scalar(@array), "\n";
    my $hash_ref = $self->[CALL];
    for ( sort keys %{ $self->[CALL] } ) {
        print DBG "\t$_|", $hash_ref->{$_}[CONTEXT], "|",
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
    print DBG "Dans data_substitute_eval_with_file : $self|$file|$number\n";
    my $call_id = $self->[THREAD][ threads->tid ][CALL_ID];
    print DBG
      "Dans data_substitute_eval_with_file : après récupération de call_id\n";
    my $calling_thread;
    if ( defined $call_id ) {
        print DBG "Call_id : $call_id\n";
        ($calling_thread) = split( /_/, $call_id );
        print DBG "Calling thread : $calling_thread\n";
        $self->[THREAD][$calling_thread][EVAL] = [ $file, $number ];
    }
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

sub save_current {
    my ( $self, $ref ) = @_;
	
    $self->[CURRENT] = $ref;	
}

sub data_last_current {
    my ( $self ) = @_;
	
    return $self->[CURRENT];
}

sub data_get_search_options {
		my ( $self, $ref ) = @_;
		
		return $self->[SEARCH]{$ref};
}

sub data_set_search_options {
		my ( $self, $ref, $options_ref ) = @_;
		
		$self->[SEARCH]{$ref} = $options_ref;
}

my %tab_editor;

sub update_conf {
    my ( $self, $ref, $options_ref ) = @_;
	
    my $ref_tab = $self->[INSTANCE]{$ref}{'tab'};
	if ( ! defined $ref_tab ) {
		print "L'éditeur n'est pas géré par un onglet\n";
		$self->[INSTANCE]{$ref}{'conf'} = $options_ref;
		return;
    }
	my $tab_editor = $tab_editor{$ref_tab};
	if ( ! defined $tab_editor ) {
		print "L'onglet n'a pas encore été créé dans Data\n";
        $tab_editor = bless \do { my $anonymous_scalar }, "Text::Editor::Easy";
        Text::Editor::Easy::Comm::set_ref( $tab_editor, $ref_tab);
        $tab_editor{$ref_tab} = $tab_editor;
    }
	#print "Dans update conf, reçu |$ref|$options_ref|\n";
	# On renvoie le 'call_id' de la dernière requête pour permettre un traitement synchrone par calc_conf appelant
	return $tab_editor->async->update_tab_config( $self->[INSTANCE]{$ref}{'name'}, $options_ref );
}

sub save_conf {
    my ( $self ) = @_;
	
	print "Dans save_conf\n";
	my $instance_ref = $self->[INSTANCE];
	my %saved_tab;
	while ( my ($key, $value_ref) = each %{$instance_ref} ) {
        if ( my $ref_tab = $value_ref->{'tab'} ) {
		    print "L'éditeur ", $value_ref->{'name'}, " est géré par un onglet\n";
			$saved_tab{$ref_tab} = 1;
	    }
		else {
		    print "L'éditeur ", $value_ref->{'name'}, " doit être sauvegardé de façon individuelle\n";
	    }
    }
	my %tab;
	TAB: for my $ref ( keys %saved_tab ) {
		my $name = $instance_ref->{$ref}{'name'};
		$tab{$ref} = $name;
		print DBG "Avant ouverture pour name = $name\n";
		my $tab = $tab_editor{$ref};
		next TAB if ( ! defined $tab );
	    #open (SES, ">editor.session_$name") or die "Impossible d'ouvrir editor.session_$name\n";
        #$tab->async->save_info_on_file("editor.session_$name");
    }
	return %tab;
}

sub link_editor_to_tab {
    my ( $self, $ref_editor, $ref_tab ) = @_;

    #print "Dans link_editor_to_tab : $ref_editor|$ref_tab\n";
	$self->[INSTANCE]{$ref_editor}{'tab'} = $ref_tab;
}


=head1 FUNCTIONS

=head2 async_response

=head2 async_status

=head2 data_file_name

=head2 data_get_editor_from_file_name

=head2 data_get_editor_from_name

=head2 data_get_search_options

Get the previously saved options of the search (regexp, initial positions) : not yet finished.

=head2 data_last_current

Get the Text::Editor::Easy reference that had focus when ctrl-f was pressed.

=head2 data_name

=head2 data_set_search_options

Set the search options (regexp, initial positions) : not yet finished.

=head2 data_substitute_eval_with_file

=head2 file_name_of_zone_order

=head2 find_in_zone

=head2 free_call_id

=head2 init_data

=head2 link_editor_to_tab

This sub shouldn't have been created. The link should always be made by the Zone object and a Zone event.

=head2 list_in_zone

=head2 name_of_zone_order

=head2 print_thread_list

=head2 reference_editor

=head2 reference_print_redirection

=head2 reference_zone

=head2 save_conf

Return Text::Editor::Easy configurations : first line on the screen, at which height, cursor position...

=head2 save_current

Save the reference of the Text::Editor::Easy instance that has the focus and in which a search begins.

=head2 size_self_data

=head2 trace

=head2 trace_call

=head2 trace_display_calls

=head2 trace_new

=head2 trace_print

=head2 trace_response

=head2 trace_start

=head2 update_conf

Action performed when a Text::Editor::Easy instance is losing the focus.

=head2 zone_list

=head2 zone_named

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
