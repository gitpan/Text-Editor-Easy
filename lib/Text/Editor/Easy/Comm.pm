use threads;
use threads::shared;

=head1 NAME

Text::Editor::Easy::Comm - Thread communication mecanism of "Text::Editor::Easy" module.

=head1 VERSION

Version 0.1

=cut

our $VERSION = '0.1';

=head1 SYNOPSIS

There are 2 (or 3 if we include the "Text::Editor::Easy::File_manager" module) complex modules in the "Text::Editor::Easy" tree.
This module and the "Text::Editor::Easy::Abstract" which handles graphics in an encapsulated way.

This module tries to make thread manipulation obvious with "Text::Editor::Easy" objects. Maybe this module could be adpated to be used
with other objects to facilitate thread creation and use. This is not my goal : my goal is to write a generator of applications that can be
modified dynamically (the Editor is the first part of that).

There are 2 main classes of threads : server and client.
A client thread is, for instance, your program that runs sequentially and, from time to time, ask a server thread for a service.
A server thread is a waiting thread that manages a particular service. From time to time, it's called by a client (which can be a real client
thread or another server thread : the calling server thread can be seen here as a client for our responding server), responds to the client and then
waits again. Of course, if the server is saturated with calls, it won't wait and will execute all the calls in the order they have been made. So, the clients (real
or other servers) may have to wait for the response of the server... but not always. Here come asynchronous calls : in an asynchronous call,
the client asks for something to the server (gets, if it wants, an identification of the call, the "call_id"), and can go on without waiting for the
response. But asynchronous calls are not always possible. Often, you have to make things in a certain order and be sure they have been
made before going on. So most calls to server threads (by client) will be synchronous and blocking.

Now that we have seen the 2 classes of threads let's talk more about server threads.
There are mainly 3 types of server threads : owned by an instance (let's call it OWNED thread), shared by all the instances with separate data
for all the instances (let's call it MULTIPLEXED thread), shared with all instances with no separate data (let's call it CLASS thread).
All these types of threads haven't been invented for theorical beauty, but just because I needed them. The OWNED thread is the "File_manager"
thread : each "Text::Editor::Easy" instance have a private one. The MULTIPLEXED thread is the graphic thread (number 0) : Tk is not
multi-threaded, so I had to put private data in only one thread. All other threads that I use are CLASS threads : the thread model, number 1, that
is only used to create new threads, the "Data" thread number 2, that shares common data such as "call_id" and asynchronous responses...

The thread system allows me to create all the types of threads defined previously (OWNED, MULTIPLEXED, and CLASS) but it allows me 
more. First, there is no real limit between the 3 types of threads (I can have a thread with a MULTIPLEXED and CLASS personnality...
or any other combination). Second, I'm able to define dynamic methods and have access to the code of all the methods to enable dynamic
modifications. The demo8 of version 0.01 gave me ideas about what I needed to increase my productivity in developping my Editor.

The "create_new_server" method can be called either with an instance, or with a class :
  my $tid = $editor->create_new_server ( {...} );
or
  my $tid = Text::Editor::Easy->create_new_server ( {...} );

For an OWNED or MULTIPLEXED type, use the instance call. For the CLASS type use the class call. "create_new_server" uses a
hash reference for parameters, and returns the "tid" ("thread identification" in the interpreted thread perl mecanism), which is an integer.
This interface may be changed : just given to see actual capabilities. Of course, the more I use this interface to create all my threads,
and the more I will be reluctant to change the interface.

Here are the parameters of the given hash to the "create_new_server" method :

  $editor->create_new_server ( {
		# optionnal, without this option, no new module is evaluated by the new created thread
		'use' => 'Module_name', 
		
		# optional, without this option, the "main" package is used for the following methods
		'package' => 'Package_name',
		
		# mandatory : methods to be added to the instance or to the class.
		# Calls to these methods will be served by the new created thread.
		# The names of the methods must correspond to the name of the subs to be called.
		# This limitation may be suppressed later (by including a hash ref in the elements
		# of the array)
		'methods' => [ 'method1', 'method2', 'method3', ... ],
		
		# optionnal but either 'object' or 'new' must be provided.
		# 'object' or 'new' specify the first parameter that the methods handled
		# by your thread will receive (the other parameters will be given by
		# the call itself : for instance "$editor->method1('param2', 'param3', ...)"
		'object' => ... (any "dumpable" reference for instance [], or {} ...),
		
		# optionnal but either 'object' or 'new' must be provided.
		# Method that will be called first by the new thread :
		# - must return the object that the thread will use for the methods call (first parameter)
		# - the return value of the method can contain non "dumpable" data (sub reference, file descriptor, ...)
		# The first value of the tab reference is the sub name (including the package),
		# the other values are "dumpable" parameters to be sent to the sub returning the object.
		# The first parameter received by 'package::sub_name' will be 'param1', the second 'param2' and so on
		'new' => [ 'package::sub_name', 'param1', 'param2', ... ],
		
		# optionnal, gives a sub that will initialize the object.
		# The sub does not need to return the object because the reference is given.
		# Be careful, the first parameter received by 'package::sub_name' is the reference
		# of the object that will be used to call the newly defined method (this is
		# what should be initialized)
		# AND THE SECOND PARAMETER is the "pseudo-reference" with which the "create_new_server"
		# has been called (either "a unique reference" for an instance call which is an integer that
		# uniquely identifies a "Text::Editor::Easy" object, or the class name)
		init => [ 'package::sub_name', 'param3', 'param4', ...],
		
		# optionnal (allows multiple OWNED threads to share code (one different tid for each instance)
		'name' => 'thread_name',
		
		# optionnal, put the tid of the thread in the shared hash %get_tid_from_instance_method
		# even if a name is given (could be used for MULTIPLEXED thread)
		'put_tid' => 1,
		
		# optionnal, indicates that the code of the methods won't be shared with other instances.
		# May be used for specific OWNED thread.
		# In short, some methods may be have the same name but different associated code according
		# to the instance calling the method
		'specific' => 1,
		
		# optionnal, indicates that no thread will be created, the calling client (true client)
		# will have to manage itself the defined methods (the client thread will have to 
		# use "anything_for_me" and "have_task_done" methods exported by "Text::Editor::Easy::Comm"
		# to respond to potential clients; it could also use "get_task_to_do" and "execute_this_task"
		# instead of "have_task_done" to have a better control over the client calls : see
		# 'Text::Editor::Easy::Abstract::examine_external_request' for that).
		# The tid returned by the "create_new_server" will be the tid of the calling client
		# This option and the desire to create interruptible methods are the only 2 reasons why you
		# should include "Text::Editor::Easy::Comm" in a private module
		'do_not_create' => 1,
  } );

Once your thread is created, you can change a little it's behaviour with the following calls. Again, you can use instance call or class call.

  Text::Editor::Easy->ask_thread('add_thread_method', 'tid', { ... } );
  
  $editor2->ask_thread('add_thread_object', 'tid', { ... } );
  
  $editor2->ask_thread('any_function_you_want', 'tid', 'param3', 'param4', 'param5' );

The difficult task achieved by "Text::Editor::Easy::Comm" module is to ask the good server thread for the "Text::Editor::Easy" method-call
that you've made (either instance or class call). As long as you provide the "tid" of the thread you want to ask for something when using "ask_thread",
you can specify anything for the method, even if it hasn't been declared as a method : still the fully qualified method should be known by the
thread (in a package contained by 'main' or by any other module that has already been evaluated by the thread : either with "create_new_server"
and  'use' option or by the "add_thread_method" and the 'use' option).

The 'add_thread_method' allows you to define a new method for the thread and not necessarily for the same reference that was initially used
for the thread creation. This "reference change" can modify slightly the "personnality" of your thread. The possible options for the hash are :
  'use' (evaluation of a new module for this method)
  'package'
  'method'
  'sub' (if the sub of the package has a different name of the method)
  'memory' (for dynamic designing : the code of the method to be executed is given and not on a file)

The 'add_thread_object' method allows you to add new objects in a MULTIPLEXED thread. The possible options for the hash are :
  'object' (see "create_new_server")
  'new' (see "create_new_server")
You don't add a new thread, but you ask an existing thread to handle a new instance with the same default methods that have been defined
by "create_new_server" (and possibly added by "add_thread_method" if the reference was the same as the first initially used with "create_new_server").

You may have a look at the tests included with "Text::Editor::Easy" if you want to understand by practise these explanations (for instance,
"multiplexed_without_thread_creation.t" is a good example for asynchronous calls and a client that acts as a server). You can also look
at all the "Text::Editor::Easy" modules of the tree directory.

=head1 EXPORT

There are only 2 reasons to include this module in a private module of yours. Either you've created a pseudo-server with
the "do_not_create" option during "create_new_server" call, or (a little more interesting), you wan't to create a server with
a "lazy behaviour" : that is to say, which implements interruptible tasks.

=head2 anything_for_me

As communication between threads uses the "Thread::Queue" mecanism, you can know if there is something waiting for you in the "Queue".
I encapsulate the "pending call" to the queue object in the "anything_for_me" function which does not accept any parameter.
"anything_for_me" returns true if there is another task for you, false otherwise.
If you look at my code, you'll see, in lots of my lazy graphical methods, the 
		return if anything_for_me;
This little line is magical. Before beginning a new heavy instruction, you check if something could invalidate your processing. Then, you may
see another reason to create thread : if you can separate the functions that lead to give up other ones, you can put these functions in a
single thread and write them in "lazy mode". No matter the memory used ! It's now cheap. But take into consideration the time of your
user : it's the most precious thing.

=head2 have_task_done

Another useful function exported is "have_task_done". Used with "anything_for_me", this allows you to implement "interruptible long task".
For me, what I have in mind is "counting the lines of a file that may be huge", or "parsing a file for contextual syntax highlighting". I really needed
that to go further in the development of my Editor. "have_task_done" does not accept any parameter. For the moment, it returns "true" only
if the thread should be stopped ("stop_thread" method already called).
So, to create an interruptible long task, you could write, from time to time, during your long process :
  while ( anything_for_me ) {
    return if ( have_task_done );
  }
The difference between "return if anything_for_me" is that your thread still is in your long interruptible task after having done a few more
urgent tasks. More over, you don't lose any of the values of your variables before the call. Except the "main shared object" that
some of your methods normally shares (it could have been modified by the urgent calls), nothing should have been changed.

=head2 get_task_to_do and execute_this_task

You can make your interruptible tasks a little more complex using "get_task_to_do" and "execute_this_task" as a replacement of
"have_task_done". If there is anything for you, you can get what is really for you with "get_task_to_do". The first parameter returned is the
method called, the second the "call_id". An example of this is the "examine_external_request" sub of the
"Text::Editor::Easy::Abstract" module. This allows my module to know if we're working responding to a graphical event or responding to
a client call. This is used to test "event conditions" before calling user callback after an Editor event occurs. This mecanism has still to be
improved (more events have to be added and tested...).

=cut

my $trace_queue;
share $trace_queue;

my $synchronous_trace : shared = 1;
my $data_thread : shared;

package Text::Editor::Easy::Comm::Trace;

use warnings;
use strict;

use Data::Dump qw(dump);
use Time::HiRes qw(gettimeofday);

sub TIEHANDLE {
    my ( $classe, $type ) = @_;

    my $array_ref;
    $array_ref->[0] = $type;
    bless $array_ref, $classe;
}

sub PRINT {
    my $self = shift;
    my $type = $self->[0];

    my $who = threads->tid;

    # Traçage de l'appel dans Data mais de façon asynchrone
    my @calls;
    my $indice = 0;
    while ( my ( $pack, $file, $line ) = caller( $indice++ ) ) {
        push @calls, ( $pack, $file, $line );
    }
    my $array_dump = dump @calls;
    my $hash_dump  = dump(
        'who'   => $who,
        'on'    => $type,
        'calls' => $array_dump,
        'time'  => scalar(gettimeofday)
    );
    if ( $synchronous_trace and defined $data_thread ) {
        my $string = '';
        for (@_) {
            if ( defined $_ ) {
                $string .= $_;
            }
        }
        Text::Editor::Easy->trace_print( $hash_dump, @_ );
    }
    else {
        my $string = '';
        for (@_) {
            if ( defined $_ ) {
                $string .= $_;
            }
        }
        my $trace =
          Text::Editor::Easy::Comm::encode( 'trace', $who, 'Text::Editor::Easy',
            'X', 'print', $hash_dump, @_ );
        $trace_queue->enqueue($trace);
    }
}

package Text::Editor::Easy::Comm::Null;

use warnings;
use strict;

sub TIEHANDLE {
    my ($classe) = @_;

    bless [], $classe;
}

sub PRINT {
    return;
}

package Text::Editor::Easy::Comm;

use warnings;
use strict;

require Exporter;
our @ISA = ("Exporter");

#  qw ( execute_this_task anything_for_me get_task_to_do ask2 verify_model_thread respond simple_context_call verify_graphic verify_motion_thread reference_event_conditions have_task_done);
our @EXPORT =
  qw ( execute_this_task anything_for_me ask2 get_task_to_do reference_event_conditions have_task_done);

our @EXPORT_OK =
  qw(get_anything_for_me get_task_to_do execute_this_task reference_event_conditions)
  ;    # symbols to export on request

use Data::Dump qw(dump);
use Time::HiRes qw(gettimeofday);

use threads;
use Thread::Queue;
use threads::shared;

my %free;
share(%free);

my %queue_by_tid
  ;    # Queue de réponse (queue cliente : un serveur la possède aussi)
share(%queue_by_tid);

my %server_queue_by_tid
  ; # Queue server, d'attente de tâche : un client l'a aussi car il est d'abord serveur en attente au départ
    # lors de la création de la grappe de thread
share(%server_queue_by_tid);

my %stop_dequeue_server_queue;
share(%server_queue_by_tid);

my %synchronize
  ; # indéfini tant que l'objet n'est pas correctement fini, 1 sinon (entrée, unique_ref)
share(%synchronize);

my %stop_server;
share(%stop_server);

# Nouvelle gestion des méthodes et des threads
my %ref_method;
my %use;    # Liste des modules utilisés par un thread
use constant {
    USE     => 0,
    PACKAGE => 1,
    SUB     => 2,
    MEMORY  => 3,
    REF     => 4,
    OTHER   => 5,
    COMPIL  => 6,
    EXEC    => 7,
};
my %thread_knowledge;

my %get_tid_from_class_method;
share(%get_tid_from_class_method);

my %get_tid_from_instance_method;
share(%get_tid_from_instance_method);

my %get_tid_from_thread_name;
share(%get_tid_from_thread_name);

sub add_thread_method {
    my ( $self_server, $reference, $options_ref ) = @_;

    my $initial_instance_ref = $thread_knowledge{'instance'};
    print "Dans add thread method : ", scalar( threads->list ), "\n";

    my $method = $options_ref->{'method'};
    return if ( !defined $method );
    my $method_ref;
    if ( my $program = $options_ref->{'memory'} ) {

        #Le code doit renvoyer une référence de sub
        $method_ref->[REF] = eval "$program";
        if ($@) {
            $method_ref->[COMPIL] = $@;
            print STDERR "Wrong code for method $method :\n$@\n";
        }
        $method_ref->[MEMORY] = $program;
    }
    else {
        my $use = $options_ref->{'use'};
        if ( defined $use ) {
            if ( !$use{$use} ) {
                eval "use $use";
                $use{$use}{'messages'} = $@;
            }
        }

        $method_ref->[USE] = $use;
        my $package = $options_ref->{'package'} || 'main';
        $method_ref->[PACKAGE] = $package;
        my $sub = $options_ref->{'sub'} || $method;
        $method_ref->[SUB] = $sub;
        $method_ref->[REF] = eval "\\&${package}::$sub";
    }
    if ( !$initial_instance_ref->{$reference} ) {
        print "Ajout pour la nouvelle classe/méthode $reference de $method\n";
        $ref_method{$method}[OTHER]{$reference} = $method_ref;
    }
    else {
        $ref_method{$method} = $method_ref;
    }

    # Mise à jour des méthodes gérées (hachages shared)
    if ( $reference =~ /^\d+$/ ) {    # spécific instance method
        my %hash;
        share(%hash);
        my $hash_ref = $get_tid_from_instance_method{$method};

        #print "Ajout d'une méthode d'instance pour '$instance $method'\n";
        if ( defined $hash_ref ) {
            %hash = %{$hash_ref};
        }
        $hash{$reference}                      = threads->tid;
        $get_tid_from_instance_method{$method} = \%hash;
    }
    else {                            # Class method
        my %hash;
        share(%hash);
        my $hash_ref = $get_tid_from_class_method{$method};
        if ( defined $hash_ref ) {
            %hash = %{$hash_ref};
        }
        $hash{$reference} = threads->tid;
        print "Ajout de la méthode $method pour la classe $reference\n";
        $get_tid_from_class_method{$method} = \%hash;
    }
    print "Fin de add thread method : ", scalar( threads->list ), "\n";
}

sub decode_message {
    my ($message) = @_;

    return if ( !defined $message );
    return eval $message;
}

sub encode {
    my @param = @_;

    #if ( $param[0] ne 'print_encode' ) {
    #		Text::Editor::Easy->print_encode( $param[0], $param[1] );
    #}
    return dump @param;
}

my $indice = 0;

my %com_unique;

sub simple_call {
    my ( $self, $sub, $call_id, $context, @param ) = @_;

    my ( $who, $id ) = split( /_/, $call_id );

    if ( !defined $self ) {
        print STDERR "Call to simple_call with no self object defined\n";
    }
    my $response =
      simple_context_call( $self, $sub, $call_id, $context, @param );

    if ( !defined $queue_by_tid{$who} ) {
        print DBG "!!!!!!!!!!!!Pas de définition pour who = |$who|\n";
        print DBG "=========>  Dans simple_call : $sub $who $context\n";
        return;
    }
    my $synchronous = 0;
    $synchronous = 1 if ( length $context == 1 );
    print DBG "Longueur de context |$context|\n";
    if ($synchronous) {
        return respond( $call_id, $context, @param, $response );
    }
    else {    # Appel asynchrone
        my $from = threads->tid;

# LEs traces sont synchrones donc pas de deep recursion si on revient d'une méthode asynchrone du thread data
#if ( $from ne $data_thread or $method !~ /^trace/ ) {	        # En cas d'appel asynchrone, il faut quand même répondre, mais à Data
        if ( $synchronous_trace and defined $data_thread ) {
            Text::Editor::Easy->trace_response( $from, $call_id, undef,
                gettimeofday(), $response );
        }
        else {
            my $trace = encode(
                'trace',              $who,
                'Text::Editor::Easy', 'X',
                'response',           $from,
                $call_id,             undef,
                gettimeofday(),       $response
            );
            $trace_queue->enqueue($trace);
        }

        #}
    }
}

sub respond {
    my ( $call_id, $context, @param ) = @_;

    my ( $who, $id ) = split( /_/, $call_id );

    my $response = pop @param;
    print DBG "RESPOND : $call_id\n";
    if ( threads->tid == $who and length($context) != 2 )
    {    # Même thread + appel synchrone
        my ( $return_call_id, $return_message ) = split( /;/, $response, 2 );
        return decode_message($return_message);
    }
    elsif ( $context ne 'X' ) { # Appel asynchrone de mode trace, pas de réponse
            #print DBG "CALL_ID $call_id, $context, @param\n";
        $queue_by_tid{$who}->enqueue($response);
    }
    else {

        #print "Appel asynchrone détecté...\n";
    }
}

sub simple_context_call {
    my ( $self, $sub_ref, $call_id, $context, @param ) = @_;

    my ( $who, $id ) = split( /_/, $call_id );

    my $response;
    my $sub_name = '';
    if ( CORE::ref $sub_ref eq 'ARRAY' ) {
        ( $sub_name, $sub_ref ) = @$sub_ref;
    }
    print DBG "SIMPLE_CONTEXT_CALL : $call_id|$sub_name|\n";
    if ( $context eq 'A' or $context eq 'AA' ) {
        my @return = $sub_ref->( $self, @param );
        $response = dump @return;
    }
    elsif ( $context eq 'S' or $context eq 'AS' ) {
        my $return = $sub_ref->( $self, @param );
        $response = dump $return;
    }
    else {    # $context = 'V' (void) ou 'X' (asynchrone)
        $sub_ref->( $self, @param );
        $response = dump;
    }
    return "$call_id;$response";
}

sub create_queue {
    my ($tid) = @_;

    if ( !$queue_by_tid{$tid} ) {
        $queue_by_tid{$tid} = Thread::Queue->new;
    }
}

sub get_response_from {
    my ($tid) = @_;

    return $queue_by_tid{$tid}->dequeue;
}

sub anything_for_me {
    my $who = threads->tid;
    return if ( defined $stop_dequeue_server_queue{$who} );
    return $server_queue_by_tid{$who}->pending;
}

sub get_message_for {
    my ( $who, $from, $method, $call_id, $context, $data ) = @_;

    #if ( length($context) == 2 ) {

    # Appel asynchrone, le simple call devra répondre à Data
    #  return $call_id;
    #}

    #print DBG "File d'attente pour WHO = $who\n";
    #my $data = $queue_by_tid{$who}->dequeue;

    # Traçage de l'appel dans Data mais de façon asynchrone
    #if ( $from ne $data_thread or $method !~ /^trace/ ) {
    if ( $method !~ /^trace/ ) {
        if ( $synchronous_trace and defined $data_thread ) {
            Text::Editor::Easy->trace_response( $from, $call_id, $method,
                gettimeofday(), $data );
        }
        else {
            my $trace = encode(
                'trace',        $who,  'Text::Editor::Easy', 'X',
                'response',     $from, $call_id,             $method,
                gettimeofday(), $data
            );
            $trace_queue->enqueue($trace);
        }
    }
    my ( $return_call_id, $return_message ) = split( /;/, $data, 2 );
    if ( $return_call_id ne $call_id and $method ne 'trace_print' ) {
        print DBG
          "Différence de call_id !! appel $call_id|retour $return_call_id\n";
        print DBG
          "\tFROM $from, méthode $method, contexte $context|$return_message\n";
    }
    return decode_message($return_message);
}

sub get_task_to_do {

    # Le thread serveur se bloque dans l'attente d'un nouveau travail à faire
    my $who = threads->tid;
    my $data;
    do {
        $data = $server_queue_by_tid{$who}->dequeue;
    } while ( defined $stop_dequeue_server_queue{$who} );

# Un nouveau travail a été dépilé de la file d'attente
# Réinitialiser ici la variable shared  à 0 : le thread recommence à travailler
# Mieux : repositionner une heure de départ pour savoir quelle durée l'action va couter
# On peut associer la fonction (decode_message qui suit) pour avoir des statistiques sur les durées des méthodes
#return decode_message($data);
    my ( $what, @param ) = decode_message($data);

    if ( $what =~ /^trace/ ) {
        return ( $what, @param );
    }
    elsif ( $synchronous_trace and defined $data_thread ) {
        print DBG
          "Avant appel trace_start de $what (call_id $param[0], tid $who)\n";
        Text::Editor::Easy->trace_start( $who, $param[0], $what,
            gettimeofday() );
        print DBG
          "Retour de l'appel trace_start de $what (call_id $param[0])\n";
    }
    else {
        my $trace = encode(
            'trace', $who, 'Text::Editor::Easy', 'X',
            'start', $who, $param[0],            $what,
            gettimeofday()
        );    # $param[0] = $call_id
        $trace_queue->enqueue($trace);
    }
    return ( $what, @param );
}

my %method;   # Permet de trouver le serveur qui gère une méthode éditeur donnée
share(%method);

my %standard_call;    # Méthode centrale d'appel inter-thread (non shared)

sub ref {
    my ($self) = @_;

    return $com_unique{ refaddr $self };
}

sub set_ref {
    my ( $self, $ref ) = @_;

    return if ( !defined $ref );
    $com_unique{ refaddr $self } = $ref;
}

my $call_order = 0;

sub ask2 {
    my ( $self, $method_server_tid, @data ) = @_;

    my ( $method, $server_tid ) = split( / /, $method_server_tid );

    if ( defined $server_tid ) {
        print DBG "method_server_tid defined : $method|$server_tid\n";
        print DBG "DATA = @data\n";
    }

#print ("Dans ask 2  |", $self->file_name, "|$self|", $self->ref, "|\n") if ( $method eq 'focus' );

    my $unique_ref;
    if ( !CORE::ref($self) ) {    # Appel d'une méthode de classe
        $unique_ref = '';
    }
    else {

        #print DBG "unblessed ? $self|", CORE::ref $self, "\n";
        $unique_ref = $com_unique{ refaddr $self };

        # A virer par la suite
        if ( !defined $unique_ref ) {
            $unique_ref = $self->get_unique_ref();
            $com_unique{ refaddr $self } = $unique_ref;
        }
    }
    my $client_tid = threads->tid;

    my $tid;
    my $package;
    if ($unique_ref) {
        my $hash_ref = $get_tid_from_instance_method{$method};
        $tid = $hash_ref->{$unique_ref};

        if ( !defined $tid ) {
            $tid = $hash_ref->{ CORE::ref($self) };
            if ( defined $tid and $tid =~ /\D/ ) {
                print DBG "Trouvé un appel nommé : méthode $method, nom $tid\n";
                my $hash_ref = $get_tid_from_thread_name{$tid};
                $tid = $hash_ref->{$unique_ref};
                print DBG "TID de l'appel nommé : $tid\n";
            }
            else {

                # Tester l'héritage ici (long) : fait ici de façon simplifiée
                $tid = $hash_ref->{'Text::Editor::Easy'};
                if ( defined $tid and $tid =~ /\D/ ) {
                    my $hash_ref = $get_tid_from_thread_name{$tid};
                    $tid = $hash_ref->{$unique_ref};
                }
            }
        }
    }
    else {
        my $hash_ref = $get_tid_from_class_method{$method};
        $tid = $hash_ref->{$self};

#print DBG "Récupération de get_tid_from_class_method de $method : $hash_ref pour $self\n";
# Tester l'héritage ici
        if ( !defined $tid ) {
            $tid = $hash_ref->{'Text::Editor::Easy'};

    #print DBG "Récupération de tid par l'ancêtre de base Text::Editor::Easy\n";
        }
    }
    if ( defined $tid ) {
        $server_tid = $tid;

        # pour appel de méthode dans le même thread
        if ( defined $ref_method{$method} ) {
            $package = $ref_method{$method}[PACKAGE];
        }

        #print "Dans ask2, méthode $method|$tid|$package\n";

        return new_ask( $self, $method, $unique_ref, $client_tid, $server_tid,
            $package, @data );
    }

    ($package) = $method{ $unique_ref . ' ' . $method };
    if ( !defined $package ) {

#print "La méthode $method n'est pas définie spécifiquement pour l'éditeur $unique_ref\n";
        ($package) = $method{$method};

        #if ( ! defined $package and ! defined $server_tid ) {
        if ( !defined $package )
        {    # Le package doit être défini même si l'on précise le thread
             # ==> A un thread, correspond un et un seul package mais un package peut être associé à de multiples threads
            if ( !defined $server_tid or !$server_queue_by_tid{$server_tid} ) {
                print STDERR "Method $method unknown for object $self\n";
                return;
            }
        }
    }

    #my $server_tid;
    print DBG
      "APPEL STANDARD : $package, method $method, unique_ref $unique_ref\n";
    print DBG "MEthode |$method| : PAckage appelé : $package\n";

    #print DBG "method_server_tid : $method_server_tid|package $package\n";
    if ( !defined $server_tid ) {
        if ( $package =~ /^shared_method:(.*)$/ ) {

            #print "La méthode $method est commune à tous les éditeurs\n";
            my $sub_ref = eval "\\&$1";
            return $sub_ref->( $self, @data );
        }
    }
    print STDERR "Can't handle method $method for object $self\n";
    return;
}

sub new_ask {
    my ( $self, $method, $unique_ref, $client_tid, $server_tid, $package,
        @data ) = @_;

    my $context = '';

    if ( CORE::ref($self) eq 'Text::Editor::Easy::Async'
        or $self eq 'Text::Editor::Easy::Async' )
    {
        print DBG "Appel asynchrone détecté pour la méthode $method\n";
        $context = 'A';
    }

    if ( $client_tid == $server_tid and $context ne 'A' ) {

        $call_order += 1;
        my $call_id     = $client_tid . '_' . $call_order;
        my $self_server = $thread_knowledge{'self_server'};
        if (wantarray) {
            $context .= 'A';
        }
        elsif ( defined(wantarray) ) {
            $context .= 'S';
        }
        else {
            $context .= 'V';
        }
        print DBG
"Contexte avant appel execute_task |$context| pour appel méthode $method\n";
        return execute_task( 'sync', $self_server, $method, $call_id,
            $unique_ref || $self,
            $context, @data );
    }

    #print DBG "SERVER _TID = $server_tid pour $method\n";
    my $queue = $server_queue_by_tid{$server_tid};

    if (wantarray) {
        $context .= 'A';
    }
    elsif ( defined(wantarray) ) {
        $context .= 'S';
    }
    else {
        $context .= 'V';
    }

    $call_order += 1;
    my $call_id = $client_tid . '_' . $call_order;
    ;  # Avoir toujours le client même si pas de trace (encode après if et push)

#if ( $server_tid ne $data_thread or $method !~ /^trace/ ) { # 2 serveurs pour les traces : ne plus tester le tid :
    if ( $method !~ /^trace/ )
    {    # 2 serveurs pour les traces : ne plus tester le tid :
            # toute méthode qui commencera par "trace" ne sera pas tracée...
            # Traçage de l'appel dans Data

        my @calls;
        my $indice = 0;
        while ( my ( $pack, $file, $line ) = caller( $indice++ ) ) {
            push @calls, ( $pack, $file, $line );
        }
        my @call_params = (
            $call_id, $server_tid,    $method, $unique_ref,
            $context, gettimeofday(), @calls
        );
        if ( $synchronous_trace and defined $data_thread ) {

            # Trace synchrone
            Text::Editor::Easy->trace_call(@call_params);
        }
        else {
            my $trace =
              encode( 'trace', $call_id, 'Text::Editor::Easy', 'X', 'call',
                @call_params );
            $trace_queue->enqueue($trace);
        }
    }

#if ( ! CORE::ref $self ) {
#	print "Appel de classe new_ask $self|",  $unique_ref || $self, "|$server_tid|\n";
#}

#print "Dans new_ask, avant appel par queue |$method| : ", scalar (threads->list), "\n";
    my $message =
      encode( $method, $call_id, $unique_ref || $self, $context, @data );

    my $reference_sent = $unique_ref || $self;
    print DBG
"APPEL $call_id|$method| reference sent $reference_sent, queue_by_tid de $client_tid\n";
    while ( $queue_by_tid{$client_tid}->pending ) {
        print DBG "   PROBLEME appel avec file perso déjà renseignée...\n";
        my $data = $queue_by_tid{$client_tid}->dequeue;
        print DBG "   Elle contenait\n\t$data\n";
    }
    print DBG "Après test pending\n";
    $queue->enqueue($message);

# Pour l'instant on ne traite pas les demandes synchrones ou asynchrones (pas de modification de who)
# Horrible verrue pour rendre "synchrone" le join de thread, par principe asynchrone
    if ( $method eq 'stop_thread' ) {

# Procédure qui bloque le thread appelant : à revoir (gérer l'erreur qui peut provenir de $message)
#print "Fin demandée pour le serveur $server_tid\n";
        while ( !$stop_server{$server_tid} ) {
        }
        my $call_id = $stop_server{$server_tid};

        #print "On va attendre la fin de la requête $call_id\n";
        # Récupération du message initial
        my $message =
          get_message_for( $client_tid, $server_tid, $method, $call_id,
            $context );
        my $status = Text::Editor::Easy->async_status($call_id);
        while ( $status ne 'ended' ) {
            print DBG "Statut reçu : $status\n";
            $status = Text::Editor::Easy->async_status($call_id);
        }
        my $response =
          Text::Editor::Easy->async_response($call_id)
          ;    # Obligatoire pour nettoyage (propre)
        delete $server_queue_by_tid{$server_tid};
        delete $queue_by_tid{$server_tid};
        print DBG
          "Le statut est a ended, on renvoie la main au thread appelant\n";
        return 1;
    }

    if ( length($context) == 2 ) {

        # Appel asynchrone, le simple call devra répondre à Data
        return $call_id;
    }
    $free{ threads->tid } = "$call_id|$server_tid";
    print_free( "Thread "
          . threads->tid
          . " bloqué par l'appel $call_id à $server_tid\n" );

    #print DBG "File d'attente pour WHO = $who\n";
    my $data = $queue_by_tid{$client_tid}->dequeue;
    $free{ threads->tid } = 0;
    return get_message_for( $client_tid, $server_tid, $method, $call_id,
        $context, $data );
}

sub ask_thread {
    my ( $self, $method, $server_tid, @data ) = @_;

    print DBG "Dans ask_thread : $method, $server_tid|",
      scalar( threads->list ), "\n";

    # En commun avec ask2 : à simplifier !!!
    my $unique_ref;
    if ( $self eq 'Text::Editor::Easy' or $self eq 'Text::Editor::Easy::Async' )
    {    # Appel d'une méthode de classe
        $unique_ref = '';
    }
    else {

        #print DBG "unblessed ? $self|", CORE::ref $self, "\n";
        $unique_ref = $com_unique{ refaddr $self };

        # A virer par la suite
        if ( !defined $unique_ref ) {
            $unique_ref = $self->get_unique_ref();
            $com_unique{ refaddr $self } = $unique_ref;
        }
    }

# Package uniquement utilisé pour appel dans le même thread... (valeur sans importance dans
# un appel entre 2 threads différents)
    my $package;
    if ( $ref_method{$method} ) {
        $package = $ref_method{$method}[PACKAGE];
    }
    my $client_tid = threads->tid;

# Attention, la première donnée de la fonction est $unique_ref || $self ==> cad la référence avec laquelle la méthode de thread
# a été appelée

    print DBG "Dans ask_thread, avant appel new_ask, $method : ",
      scalar( threads->list ), "\n";
    return new_ask( $self, $method, $unique_ref, $client_tid, $server_tid,
        $package, $unique_ref || $self, @data );
}

sub create_thread {
    my ( undef, @param ) = @_;

    #print "Dans create_thread : $unique_ref\n" if ( defined $unique_ref );

    my $thread = threads->new( \&verify_server_queue_and_wait, @param );

    # On ne peut pas sortir sans être sûr de pouvoir s'adresser au thread créé
    # ===> création de la file d'attente
    my $tid = $thread->tid;

    my $string =
        "Dans create thread, création de $tid ("
      . scalar( threads->list )
      . " threads actifs)\n";
    while ( my ( $pack, $file, $line ) = caller( $indice++ ) ) {
        $string .= "P|F|L|$pack|$file|$line|\n";
    }
    print DBG $string;

    if ( !$server_queue_by_tid{$tid} ) {
        $server_queue_by_tid{$tid} = Thread::Queue->new;
    }

    #print "Création du thread $tid finie\n";
    return $tid;
}
my $model_thread : shared;

use IO::File;
use File::Basename;
my $name = fileparse($0);

sub verify_model_thread {
    if ( !defined $trace_queue ) {
        $trace_queue = Thread::Queue->new;
    }
    else {

        # Appels éventuellement multi-thread...
        while ( !$model_thread ) {
        }

        # Tracer ici l'appel à "Text::Editor::Easy::new"
        return;
    }

#print "Dans Comm ", threads->tid, " |", $Text::Editor::Easy::Trace{'all'}, "|\n";
    $name =~ m/^([a-zA-Z0-9\._]+)$/
      ; # To suppress "taint error" => "Insecure dependency in open while running with -T switch at ..."

    manage_debug_file( __PACKAGE__, *DBG );
    print DBG
"\nThis is a multi-thread debug File as any thread knows Text::Editor::Easy::Comm\n\n";

    my $queue = $server_queue_by_tid{0};

    # Vérification de la queue serveur
    if ( !$queue ) {
        $queue = Thread::Queue->new;
        $server_queue_by_tid{0} = $queue;
    }

    # Vérification de la queue cliente
    if ( !$queue_by_tid{0} ) {
        $queue_by_tid{0} = Thread::Queue->new;
    }

    # Traçage des demandes de création (appels à la méthode new)
    my ( $package, $filename, $line ) = caller(1);

    # Traçage de l'appel dans Data mais de façon asynchrone
    my @calls;
    my $indice = 1;
    while ( my ( $pack, $file, $line ) = caller( $indice++ ) ) {
        push @calls, ( $pack, $file, $line );
    }
    my $array_dump = dump @calls;

    #my $trace      =
    #  encode( 'trace', threads->tid, 'X', 'new', threads->tid, $array_dump );
    #$trace_queue->enqueue($trace);

    return
      if ( defined $model_thread )
      ;    # La création de thread est déjà opérationnelle

    # Redirection des print sur STDERR et SDTOUT
    if ( $Text::Editor::Easy::Trace{'trace_print'} ) {
        tie *STDOUT, "Text::Editor::Easy::Comm::Trace", ('STDOUT');
        tie *STDERR, "Text::Editor::Easy::Comm::Trace", ('STDERR');
    }

# Maintenant, on ne peut pas rendre la main tant que la création de thread n'est pas opérationnelle
    my $thread = threads->new( \&thread_generator );
    my $tid    = $thread->tid;

    $queue = $server_queue_by_tid{$tid};
    while ( !$queue ) {
        $queue = $server_queue_by_tid{$tid};
    }

    $model_thread = $tid
      if ( !defined $model_thread )
      ;    # Création multi-thread possible : on n'est pas seul...
    if ( $model_thread != $tid ) {

    # Le model_thread a été créé par un autre éditeur, il faut éliminer le notre
        my $message = encode(undef);
        $queue->enqueue($message);

        $thread->join();

        # Suppression des queue (ou recyclage ?) à faire
    }
    else {
        $method{'explain_method'}   = ('shared_method:explain_method');
        $method{'display_instance'} = ('shared_method:display_instance');
        $method{'display_class'}    = ('shared_method:display_class');

        $method{'empty_queue'}          = ('shared_method:empty_queue');
        $method{'create_new_server'}    = ('shared_method:create_new_server');
        $method{'create_client_thread'} =
          ('shared_method:create_client_thread');
        $method{'ref'}              = ('shared_method:ref');
        $method{'set_synchronize'}  = ('shared_method:set_synchronize');
        $method{'get_synchronized'} = ('shared_method:get_synchronized');
        $method{'redirect'}         = ('shared_method:redirect');
        $method{'transform_hash'}   = ('shared_method:transform_hash');
        $method{'set_ref'}          = ('shared_method:set_ref');

        $method{'create_thread'} = ('shared_thread:Text::Editor::Easy::Comm');
        $method{'add_method'}    = ('shared_method:add_method');
        $method{'ask_thread'}    = ('shared_method:ask_thread');
        create_data_thread();
    }
}

sub manage_debug_file {
    my ( $package, $file ) = @_;

    my $suffix = $package;
    $suffix =~ s/::/_/g;
    my $tid = threads->tid;
    if ( $package ne __PACKAGE__ ) {
        print DBG "Dans manage_debug_file : reçu $package de la part de ",
          threads->tid, "\n";
    }
    if ( exists $Text::Editor::Easy::Trace{$package} ) {
        my $prefix = $Text::Editor::Easy::Trace{$package};
        if ( !defined $prefix ) {

            # Redirection
            tie $file, "Text::Editor::Easy::Comm::Null";
            print DBG
"Valeur spécifique pour $package non définie, il ne faut rien afficher\n";
        }
        else {

            # Ouverture
            my $data_trace = "${prefix}${name}__${tid}__${suffix}.trc";
            open( $file, ">$data_trace" )
              or die "Can't open debug file $data_trace : $!\n";
            autoflush $file;
            print DBG "Valeur $prefix spécifique trouvée pour $package\n";
            print DBG "Ouverture du fichier $data_trace pour $package / $tid\n";
        }
    }
    elsif ( my $prefix = $Text::Editor::Easy::Trace{'all'} ) {

        # Ouverture
        my $data_trace = "${prefix}${name}__${tid}__${suffix}.trc";
        open( $file, ">$data_trace" )
          or die "Can't open debug file $data_trace : $!\n";
        autoflush $file;
        print DBG
"Rien de spécifique pour $package mais un préfixe au niveau global : $prefix\n";
        print DBG "Ouverture du fichier $data_trace pour $package / $tid\n";
    }
    else {

        # Redirection
        tie $file, "Text::Editor::Easy::Comm::Null";
        print DBG
"Rien de spécifique pour $package, rien au niveau global : il faut rediriger\n";
    }
}

sub untie_print {
    untie *STDOUT if ( tied *STDOUT );
    untie *STDERR if ( tied *STDERR );

    #print "Fin de untie_print\n";
}

sub empty_queue {

# Arrêter l'exécution de requêtes asynchrones lorsque l'on sait qu'elles deviennent inutiles (voir eval_print)
    my ( $self, $tid ) = @_;

    #print DBG "Dans empty_queue self, tid = $self, $tid\n";
    $stop_dequeue_server_queue{$tid} = 1;
    while ( $server_queue_by_tid{$tid}->pending ) {
        my $data = $server_queue_by_tid{$tid}->dequeue;
        my ( $method, $call_id ) = decode_message($data);

# Problème subtil si appel en asynchrone (Text::Editor::Easy::Async) : à décortiquer
#   => piste ?, le thread 2 (Data) exécutant "free_call_id" est aussi responsable
#                   de la réception des requêtes asynchrones
#  Peut-on mélanger les appels synchrones et asynchrones vis-à-vis de ce thread ?
        Text::Editor::Easy->free_call_id($call_id)
          ; # call_id est en attente d'exécution, il faut libérer la mémoire occupée par Data
    }
    undef $stop_dequeue_server_queue{$tid};
}

sub create_data_thread {

# Maintenant, on ne peut pas rendre la main tant que la création de thread n'est pas opérationnelle

    my $tid = Text::Editor::Easy->create_new_server(
        {
            'use'     => 'Text::Editor::Easy::Data',
            'package' => 'Text::Editor::Easy::Data',
            'methods' => [
                'find_in_zone',
                'list_in_zone',
                'reference_editor',
                'file_name_of_zone_order',
                'name_of_zone_order',
                'data_file_name',
                'data_name',
                'trace_print',
                'trace_call',
                'trace_start',
                'trace_response',
                'async_status',
                'async_response',
                'reference_print_redirection',
                'size_self_data',
                'free_call_id',
                'print_thread_list',
                'data_get_editor_from_name',
                'data_get_editor_from_file_name',
                'data_substitute_eval_with_file',
                'reference_zone',
                'zone_named',
                'zone_list',
            ],
            'object' => [],
            'init'   => ['Text::Editor::Easy::Data::init_data'],
        }
    );

    my $queue = $server_queue_by_tid{$tid};
    while ( !$queue ) {
        $queue = $server_queue_by_tid{$tid};
    }

# On met la vraie queue pour trace_queue
# On suppose que l'on est seul à travailler : première demande de création d'un objet éditeur
# ======>  donc pas possible de faire dès maintenant un appel de méthode (à vérifier)
    while ( $trace_queue->pending ) {
        my $data = $trace_queue->dequeue;
        $queue->enqueue($data);
    }
    $trace_queue = $queue;

    $data_thread = $tid;
}

sub verify_graphic {
    my ( $hash_ref, $editor ) = @_;
    my $zone_ref = $hash_ref->{'zone'};

    #print "verify graphic : ZONE_REF $zone_ref\n";
    my $ref = refaddr $editor;
    $com_unique{$ref} = $ref;

    my $queue = $server_queue_by_tid{0};

    my $tid = threads->tid;

    if ( $tid == 0 ) {
        $editor->create_new_server(
            {
                'use'     => 'Text::Editor::Easy::Abstract',
                'package' => 'Text::Editor::Easy::Abstract',
                'new'     => [
                    'Text::Editor::Easy::Abstract::new',
                    'Text::Editor::Easy::Abstract',
                    $hash_ref, $editor, $ref
                ],
                'put_tid' => 1
                , # Multi-plexed ('put_tid' option useless because no 'name' option)
                'do_not_create' => 1,
                'methods'       => [
                    'test',

                    #	'exit',   class method
                    #	'abstract_join', class method
                    'insert',
                    'enter',
                    'erase',
                    'change_title',
                    'bind_key',
                    'wrap',
                    'display',
                    'empty',
                    'deselect',
                    'eval',
                    'save_search',
                    'focus',
                    'on_top',

                    #	'reference_zone_event', class method

                    'abstract_size',

                    'new_editor',
                    'editor_insert_mode',
                    'editor_set_insert',
                    'editor_set_replace',

                    'screen_first',
                    'screen_last',
                    'screen_number',
                    'screen_font_height',
                    'screen_height',
                    'screen_y_offset',
                    'screen_x_offset',
                    'screen_line_height',
                    'screen_margin',
                    'screen_width',
                    'screen_set_width',
                    'screen_set_height',
                    'screen_set_x_corner',
                    'screen_set_y_corner',
                    'screen_move',
                    'screen_wrap',
                    'screen_set_wrap',
                    'screen_unset_wrap',

                    'display_text',
                    'display_next',
                    'display_previous',
                    'display_next_is_same',
                    'display_previous_is_same',
                    'display_number',
                    'display_ord',
                    'display_height',
                    'display_abs',
                    'display_select',

                    'line_displayed',
                    'line_select',

                    'cursor_position_in_display',
                    'cursor_position_in_text',
                    'cursor_abs',
                    'cursor_virtual_abs',
                    'cursor_line',
                    'cursor_display',
                    'cursor_set',
                    'cursor_get',
                    'cursor_make_visible',

                    'load_search',
                ],
            }
        );
        Text::Editor::Easy->ask_thread(
            'add_thread_method',
            0,
            {
                'package' => 'Text::Editor::Easy::Abstract',
                'method'  => 'reference_zone_event',
            }
        );
        Text::Editor::Easy->ask_thread(
            'add_thread_method',
            0,
            {
                'package' => 'Text::Editor::Easy::Abstract',
                'method'  => 'exit',
            }
        );
        Text::Editor::Easy->ask_thread(
            'add_thread_method',
            0,
            {
                'package' => 'Text::Editor::Easy::Abstract',
                'method'  => 'abstract_join',
            }
        );
        Text::Editor::Easy->ask_thread(
            'add_thread_method',
            0,
            {
                'package' => 'Text::Editor::Easy::Abstract',
                'method'  => 'manage_event',
            }
        );
    }
    else {
        $editor->ask_thread(
            'add_thread_object',
            0,
            {
                'new' =>
                  [ 'Text::Editor::Easy::Comm::new_editor', $ref, $hash_ref ]
            }
        );
    }
}

sub new_editor {
    my ( $ref, $hash_ref ) = @_;

    print DBG "Dans new_editor $ref|$hash_ref\n";

    #print "\tREF $ref\n\tREF_HASH $hash_ref\n\tRESTE $reste\n";
    my $editor = bless \do { my $anonymous_scalar }, 'Text::Editor::Easy';
    $com_unique{ refaddr $editor } = $ref;

    #print "#### REFERENCEMENT avec $ref\n";
    $editor->reference($ref);
    print DBG "Dans new_editor, avant appel Abstract new\n";
    my $object = Text::Editor::Easy::Abstract->new( $hash_ref, $editor, $ref );
    print DBG "Fin de new_editor\n";

    #return ( $object, $server_queue_by_tid{0} );
    return $object;
}

sub create_client_thread {

    #print "Dans la méthode de création d'un thread client\n";
    my ( $self, $sub_name, $package ) = @_;

    my $ref        = refaddr $self;
    my $unique_ref = $com_unique{$ref};
    if ( !$unique_ref ) {

# Lorsque tous les threads seront créés par Comm, déclarer get_unique_ref ici et modifier ces 2 lignes
        $unique_ref = $self->get_unique_ref;

        # Mise à jour de la référence unique
        $com_unique{$ref} = $unique_ref;
    }

#print "... méthode de création d'un thread client : $unique_ref\n";
# Cette méthode de top bas niveau devrait être masquée de l'interface : juste un exemple de thread "shared" entre les éditeurs
    $package = 'main' if ( !defined $package );
    my $tid = create_thread( $self, $unique_ref, $package );

    #print "TID = $tid\n";
    my $queue = $server_queue_by_tid{$tid};

    my $message =
      encode( "${package}::$sub_name", threads->tid, "S", $unique_ref,
        $package );
    $queue->enqueue($message);

# Attention, le code retour devra être analysé en cas de problème : attente sur la queue cliente
# Pour l'instant, cela serai bloquant puisque thread_generator ne renvoie rien
# my $response = $queue_by_tid{threads->tid}->dequeue;
# return if ( ! defined $response );

    return $tid;
}

sub thread_generator {
    my $tid = threads->tid;

    if ( !$server_queue_by_tid{$tid} ) {
        $server_queue_by_tid{$tid} = Thread::Queue->new;
    }
    if ( !$queue_by_tid{$tid} ) {
        $queue_by_tid{$tid} = Thread::Queue->new;
    }
    while ( my ( $what, @param ) = get_task_to_do ) {
        last if ( !defined $what );

  # La seule chose que sait faire le thread_generator, c'est générer des threads
  #print "Dans thread générator : $what|@param\n";
        simple_call( 'not_undef_but_useless', \&create_thread, @param );
    }
}

sub verify_server_queue_and_wait {
    my ( $unique_ref, $package ) = @_;

    my $tid = threads->tid;

    print DBG "Création de queue_by_tid pour $tid\n";
    if ( !$queue_by_tid{$tid} ) {
        $queue_by_tid{$tid} = Thread::Queue->new;
    }

    my $queue = $server_queue_by_tid{$tid};

    # Il ne faut pas se mettre en attente sur une file non encore créée
    while ( !$queue ) {
        $queue =
          $server_queue_by_tid{ $tid
          }; # La création est faite en parallèle par le thread qui a créé celui-ci
    }

    #print "Mise en attente du thread $tid\n";
    my $data = $queue->dequeue;

    my ( $what, @param ) = decode_message($data);
    if ( defined $what ) {

        my $sub_ref = eval "\\&$what";

        #print "Utilisation du thread $tid et appel $what ($sub_ref)\n";

      # Appel seulement lorsque la file d'attente client existe (faire un while)
        if ( defined $unique_ref ) {    # Thread dédié à un éditeur
            my $editor;
            if ( $unique_ref =~ /\D/ ) {

                # Class call
                $editor = $unique_ref;
            }
            else {
                $editor = bless \do { my $anonymous_scalar },
                  "Text::Editor::Easy";

                #print "UNIQUE REF : $unique_ref\n";

                $com_unique{ refaddr $editor } = $unique_ref;
                $editor->reference($unique_ref);
            }

            #print "PARAM @param|", scalar(@param), "\n";

  # Attention l'instruction qui suit doit être mise dans un eval
  # En cas d'échec il faut sortir avec undef et renvoyer cela au thead demandeur
            shift @param;
            shift @param;
            $sub_ref->( $editor, @param );
        }
        else {    # Thread partagé entre tous les éditeurs
            shift @param;
            shift @param;

            $sub_ref->(@param);
        }

        #print "Dans Comm, mort du thread $tid\n";
    }
}

sub set_synchronize {
    my ($self) = @_;

    my $unique_ref = $com_unique{ refaddr $self };
    $synchronize{$unique_ref} = 1;
}

sub get_synchronized {
    my ($self) = @_;

    my $unique_ref = $com_unique{ refaddr $self };
    while ( !$synchronize{$unique_ref} ) {
    }
}

my %redirect = do "Text/Editor/Easy/Data/Events.pm";

my $motion_thread : shared;

sub verify_motion_thread {
    my ( $unique_ref, $hash_ref ) = @_;

    my $motion_thread_useful = 0;
    my %event                = ();

    #print "DANS VERIFY MOTION THREAD...$unique_ref|$motion_ref\n";
    #print DBG "Taille de \%event $unique_ref 0 :", scalar(%event), "\n";
    for my $event ( keys %$hash_ref ) {

        #print DBG "HASH_REF pour : $event ...\n";
        if ( $redirect{$event} ) {

            #print DBG "$event est un évènement !\n";
            my $event_ref = $hash_ref->{$event};
            if ( $event_ref->{'mode'} eq 'async' ) {

                #print DBG "Il est asynchrone !!!\n";
                $motion_thread_useful = 1;
                $event{$event} = $event_ref;

                #print DBG "Event trouvé pour $unique_ref : $event ...\n";
            }

            #print "COND CREATION $event $event_ref->{'only'} \n";
            #$redirect_condition{$event}{$unique_ref} = $event_ref->{'only'};
        }
    }

    #print DBG "Taille de \%event $unique_ref :", scalar(%event), "\n";
    if ( !defined $motion_thread and $motion_thread_useful ) {

        my $tid = Text::Editor::Easy->create_new_server(
            {
                'use'     => 'Text::Editor::Easy::Motion',
                'package' => 'Text::Editor::Easy::Motion',
                'methods' => [ 'reference_event', 'manage_events' ],
                'object'  => {}
            }
        );

        my $queue = $server_queue_by_tid{$tid};
        while ( !$queue ) {
            $queue = $server_queue_by_tid{$tid};
        }

        $motion_thread = $tid
          if ( !defined $motion_thread )
          ;    # Création multi-thread possible : on n'est pas seul...
        if ( $motion_thread != $tid ) {

    # Le model_thread a été créé par un autre éditeur, il faut éliminer le notre
            my $message = encode(undef);
            $queue->enqueue($message);

            threads->object($tid)->join();

            # Suppression des queue (ou recyclage ?) à faire
        }
    }

# Demande asynchrone de prise en compte de sub motion : cette demande ne devrait pas être asynchrone !!
#print "TID DU MOTION THREAD $motion_thread\n";
#print DBG "Taille de \%event $unique_ref 2 :", scalar(%event), "\n";
    for my $event ( keys %event ) {

        print DBG "Avant call de reference event $unique_ref : $event ...\n";

     #Text::Editor::Easy::Async->ask2( 'reference_event' . ' ' . $motion_thread,
     #    $event, $unique_ref, $event{$event} );

        Text::Editor::Easy->reference_event( $event, $unique_ref,
            $event{$event} );

    }
}

my %redirect_condition;

sub reference_event_conditions {    # Toujours exécuté dans le thread 0
    my ( $unique_ref, $hash_ref ) = @_;

    my %event;
    my $motion_thread_useful;

    #print "DANS VERIFY MOTION THREAD...$unique_ref|$motion_ref\n";
    for my $event ( keys %$hash_ref ) {
        if ( $redirect{$event} ) {
            my $event_ref = $hash_ref->{$event};
            if ( $event_ref->{'mode'} eq 'async' ) {
                $motion_thread_useful = 1;
                $event{$event} = $event_ref;
            }

            #print "COND CREATION $event $event_ref->{'only'} \n";
            $redirect_condition{$event}{$unique_ref} = $event_ref->{'only'};
        }
    }
}

sub redirect {
    my ( $self, $method, $abstract_ref, $hash_ref ) = @_;

    my $ref = $com_unique{ refaddr $self};
    if ( CORE::ref($method) ne 'CODE' ) {

        print DBG "Appel asynchrone avec la méthode $method, $ref...\n";
        if ( my $condition = $redirect_condition{$method}{$ref} ) {
            my $origin     = $hash_ref->{'origin'};
            my $sub_origin = $hash_ref->{'sub_origin'};

            print DBG "CONDITION : $condition\n\t$origin\n\t$sub_origin\n";
            if ( eval "$condition" ) {

                print DBG "\tCondition positive : $@\n";

                #async_call ($motion_thread, $method, $self->ref, $hash_ref );
                print( "dans REDIRECT de cOMM : zone = ",
                    $hash_ref->{'zone'}, "\n" )
                  if ( defined $hash_ref->{'zone'} );

                Text::Editor::Easy::Async->manage_events( $method, $ref,
                    $hash_ref );

                return;    # Garder un context Void sur "manage_event"
            }
            else {

                print DBG "\tFAUX (condition) : $@\n";
            }
        }
        else {             # Pas de condition, on exécute tout le temps
                #async_call ($motion_thread, $method, $self->ref, $hash_ref );
            return if ( !defined $motion_thread );

            #Text::Editor::Easy::Async->ask2( 'manage_events ' . $motion_thread,
            #    $method, $ref, $hash_ref );

            Text::Editor::Easy::Async->manage_events( $method, $ref,
                $hash_ref );

            return;    # Garder un context Void sur "manage_event"
        }
    }
    else {
        eval {
            $method->(
                $self, transform_hash( $self, $abstract_ref, $hash_ref )
            );
        };
        print DBG $@ if ($@);
    }
}

sub transform_hash {
    my ( $editor, $abstract_ref, $hash_ref ) = @_;

    my $ref_line = $hash_ref->{'line'};
    if ( defined $ref_line ) {
        my $line = Text::Editor::Easy::Line->new( $editor, $ref_line, );
        $hash_ref->{'line'} = $line;
    }
    my $ref_display = $hash_ref->{'display'};
    if ( defined $ref_display ) {
        my $display =
          Text::Editor::Easy::Display->new( $editor, $ref_display, );
        $hash_ref->{'display'} = $display;
    }

    #print "Dans transform hash\n";
    #print "Fin de line size\n";
    return $hash_ref;
}

sub init_server_thread {
    my ( $self_caller, $options_ref ) = @_;

#Bug à voir : comment est-ce que l'on peut déjà avoir une clé renseignée dans $thread_knowledge ?
    $thread_knowledge{'instance'} = {};

    while ( my ( $pack, $file, $line ) = caller( $indice++ ) ) {
        print DBG "P|F|L|$pack|$file|$line|\n";
    }
    %ref_method = ();

    my $use = $options_ref->{'use'};
    my $package = $options_ref->{'package'} || 'main';
    for my $method ( @{ $options_ref->{'methods'} } ) {
        print DBG "Ajout dans \%ref_method de $method (", threads->tid, ")\n";
        $ref_method{$method}[USE]     = $use;
        $ref_method{$method}[PACKAGE] = $package;
        $ref_method{$method}[SUB]     = $method;
        $ref_method{$method}[REF]     = eval "\\&${package}::$method";
    }
    if ( defined $use ) {
        print DBG "Dans manage_request2, évaluation de $use\n";
        eval "use $use";
        $use{$use}{'messages'} = $@;
        if ($@) {
            print DBG "Error while evaluating module $use :\n$@\n";
            print STDERR "Error while evaluating module $use :\n$@\n";
        }
        else {
            print DBG "Evaluation de $use correcte\n";
        }
    }

    # Recalcul de $self_server
    my $self_server = $options_ref->{'object'};
    if ( !defined $self_server ) {
        if ( my $new_ref = $options_ref->{'new'} ) {
            my ( $sub_name, @param ) = @$new_ref;
            my $sub_ref = eval "\\&$sub_name";
            print DBG "Avant appel new : |$sub_name|@param|$sub_ref|\n";
            $self_server = $sub_ref->(@param);
        }
    }

    $thread_knowledge{'package'} = $package;
    my $initial_reference;
    if ( CORE::ref $self_caller )
    {    # Actuellement, c'est toujours une référence d'objet Text::Editor::Easy
            # car verify_server_queue ... crée un objet Text::Editor::Easy
            # sans se soucier de ce qu'il était éventuellement au départ
            # Owned thread
        print DBG "OWNED THREAD : SELF caller $self_caller|",
          CORE::ref $self_caller, "|\n";
        $initial_reference = $com_unique{ refaddr $self_caller };
    }
    else {

        # Shared thread
        print DBG "SHARED THREAD : SELF caller $self_caller|",
          CORE::ref $self_caller, "|$self_server\n";
        $self_caller = 'Text::Editor::Easy'
          if ( $self_caller eq 'Text::Editor::Easy::Async' );
        $initial_reference = $self_caller;
    }
    $thread_knowledge{'instance'}{$initial_reference} = $self_server;
    print DBG "On met $self_server dans thread_knowledge de instance (tid ",
      threads->tid, ") de $initial_reference\n";
    $thread_knowledge{'self_server'} = $self_server;

    return $self_server;
}

sub manage_requests2 {
    my ( $self_caller, $options_ref ) = @_;

    my $self_server = init_server_thread( $self_caller, $options_ref );

    while ( my ( $method, $call_id, $reference, @param ) = get_task_to_do ) {
        print DBG "Dans manage2, avant appel execute $method|", scalar(@param),
          "|reference : $reference\n\t|";
        for my $indice ( 0 .. scalar(@param) - 1 ) {
            my $element = $param[ $indice - 1 ];
            if ( defined $element ) {
                print DBG $element, "|";
            }
            else {
                print DBG 'undef|',;
            }
        }
        print DBG "\n";
        if (
            execute_task(
                'async',  $self_server, $method,
                $call_id, $reference,   @param
            )
          )
        {
            last;
        }
    }
    print DBG "Fin du thread ", threads->tid, "\n";

    # Nettoyage

    $stop_server{ threads->tid } =
      Text::Editor::Easy::Async->abstract_join( threads->tid, "useless" )
      ;    # Préférable de faire un "auto-join" pour éviter les blocages
}

sub execute_task {
    my ( $call, $self_server, $method, $call_id, $reference, @param ) = @_;

    print DBG "Appel request2: ", threads->tid,
      "|$method|$call_id|$reference|context $param[0]|", threads->tid, "\n";
    my $initial_reference_ref = $thread_knowledge{'instance'};

    my $string =
        "CLES de \$thread_knowledge{'instance'} : "
      . threads->tid
      . " ($method) dans execute_task\n";
    for my $key ( keys %$initial_reference_ref ) {
        $string .= "\t$key|" . $initial_reference_ref->{$key} . "|\n";
    }
    print DBG $string;

    $reference = 'Text::Editor::Easy'
      if ( $reference eq 'Text::Editor::Easy::Async' );

    # Problème sous Windows, undef obligatoire (bug perl ?)
    my $method_ref = undef
      ;    # Bug subtil sans le "= undef" ... ==> parfois défini et tout déconne

    my $object = $initial_reference_ref->{$reference};

    print DBG "On a récupéré ( tid ", threads->tid,
      ", méthode : $method) dans thread_knowledge de instance de $reference |";
    print DBG "\$object défini => |$object" if ( defined $object );
    print DBG "|\n";
    if ( defined $object ) {
        print DBG "Avant définition de \$method_ref\n";
        $self_server = $object;
        $method_ref  = $ref_method{$method};
        my $string = "Appel avec une référence initale |$method|";
        if ( defined $method_ref ) {
            $string .=
              "\$method_ref défini => |$method_ref|" . $method_ref->[REF];
        }
        $string .= "|\n";
        print DBG $string;
    }
    else {
        print DBG "Appel avec autre ref : |$reference|$method\n";

# Problème sous Linux ($method_ref devient défini de façon magique ?  bug perl ?)
        $method_ref = undef;

        if ( my $ref = $ref_method{$method} ) {
            print DBG "REF = $ref\n";
            if ( my $other_ref = $ref->[OTHER] ) {
                $method_ref = $ref_method{$method}[OTHER]{$reference};
            }
        }
        if ( !defined $method_ref and $reference =~ /\D/ )
        {    # Méthode de classe non définie
                # On force (héritage) Text::Editor::Easy pour la classe
            print DBG
"Dans manage_...2 : on force la méthode de classe Text::Editor::Easy pour $method\n";
            if ( $initial_reference_ref->{'Text::Editor::Easy'} )
            {    # Shared thread
                $method_ref = $ref_method{$method};
                print DBG
"méthode de classe Text::Editor::Easy trouvée en standard...$method_ref\n";
            }
            elsif ( my $ref = $ref_method{$method} ) {    # Owned thread
                print DBG "OWNED THREAD...\n";
                if ( my $other_ref = $ref->[OTHER] ) {
                    print DBG "Trouvé other_ref : $other_ref pout $method\n";
                    $method_ref = $other_ref->{'Text::Editor::Easy'};
                }
            }
        }
    }

    #print "Dans manage_request2 avant tests |$method|$method_ref|\n";
    if ( !defined $method_ref )
    {    # Methode de thread : eval, add_method, overload_method ...
         # Tester l'appartenance à un sous-ensemble de méthodes autorisées => il ne faut pas lancer n'importe quoi
         # en cas d'erreur réelle
        print DBG "Appel d'une fonction non définie par défaut : $method\n";
        my $ref_sub = eval "\\&$method";
        eval {

            #simple_call( $self_server, $ref_sub, $call_id, @param );
            simple_call( $self_server, [ $method, $ref_sub ], $call_id, @param )
              ;    # Modifier ask_thread et le fichier test "...add_method.t"
             # La procédure d'init passe aussi par ici et elle doit récupérer l'objet standard qui sera utilisé
             # pour tous les appels suivants (init = initialisation de cet objet => voir file_manager)
        };
        if ( $@ and $method !~ /^trace/ )
        {    # A supprimer... même les traces de départ doivent être traitées
            print STDERR "Wrong execution of pseudo-method $method :\n$@\n";
        }

        #print "Fin de l'appel spécial de $method\n";
    }
    elsif ( my $sub_ref = $method_ref->[REF] ) {
        print DBG "Appel standard simple_call pour $method\n";
        if ( $call eq 'sync' ) {
            return simple_call( $self_server, [ $method, $sub_ref ],
                $call_id, @param );
        }
        else {
            simple_call( $self_server, [ $method, $sub_ref ], $call_id,
                @param );
        }
    }
    else
    {    # Ne devrait jamais servir : évaluer toujours lors de l'initialisation
        print DBG "Appel à vérifier : $method (", threads->tid, ")\n";

        # Si utilisé, alors traiter [MEMORY] avant
        my $package = $method_ref->[PACKAGE];
        my $sub     = $method_ref->[SUB];
        if ( defined $sub and defined $package ) {
            my $sub_ref = eval "\\&${package}::$sub";
            simple_call( $self_server, [ $sub, $sub_ref ], $call_id, @param );
        }
        else {
            print DBG "SUB et PACKAGE indéfinis...|", $method_ref->[REF], "|\n";
        }
    }
    return $thread_knowledge{'stop_wanted'};
}

sub stop_thread {
    my ( $self_server, $reference, $options_ref ) = @_;

    $thread_knowledge{'stop_wanted'} = 1;
}

sub add_thread_object {    # Permet de rendre un thread multi-plexed
    my ( $self_server, $reference, $options_ref ) = @_;

    my $initial_instance_ref = $thread_knowledge{'instance'};
    if ( $initial_instance_ref->{$reference} ) {
        print STDERR
"Can't add object to thread for the already existing reference $reference\n";
        return;
    }
    if ( my $object = $options_ref->{'object'} ) {
        $initial_instance_ref->{$reference} = $object;
        return;
    }
    if ( my $new_ref = $options_ref->{'new'} ) {
        my ( $sub_name, @param ) = @$new_ref;
        my $sub_ref = eval "\\&$sub_name";
        $initial_instance_ref->{$reference} = $sub_ref->(@param);
        return;
    }
}

sub explain_method {
    my ( $self, $method ) = @_;

    print "Dans explain_method : $self, $method\n";
}

sub add_method {
    my ( $self, $method, $options_ref ) = @_;

    # Add method without thread association
    # ==> the method will be executed by the calling thread itself
    return if ( !defined $method );

    my $key;

    #if ( $options_ref->{'use'}
    my $package = 'main' || $options_ref->{'package'};
    my $name = $options_ref->{'sub'} || $method;

    #my $name = $method;
    #$name = $options_ref->{'sub'} if ( defined $options_ref->{'sub'} );
    if ( CORE::ref $self ) {

        # instance method (adding it for only one Text::Editor::Easy object)
        print "Adding method $method to object $self\n";
        $key = $self->ref . ' ' . $method;
    }
    else {

        # class method (adding it for all Text::Editor::Easy objects)
        print "Adding method $method to all Text::Editor::Easy objects\n";
        $key = $method;
    }
    $method{$key} = "shared_method:${package}::$name";
}

sub create_new_server {
    my ( $self, $options_ref ) = @_;

    my $package         = $options_ref->{'package'} || 'main';
    my $tab_methods_ref = $options_ref->{'methods'};
    my $self_server     = $options_ref->{'object'};

    #print DBG "Dans create_new_server $package $self_server\n";

    my $unique_ref;
    if ( defined $self and CORE::ref($self) ) {
        my $ref = refaddr $self;
        $unique_ref = $com_unique{$ref};
        if ( !$unique_ref ) {

# Lorsque tous les threads seront créés par Comm, déclarer get_unique_ref ici et modifier ces 2 lignes
            $unique_ref = $self->get_unique_ref;

            # Mise à jour de la référence unique
            $com_unique{$ref} = $unique_ref;
        }
    }
    my $self_caller;
    if ( !$unique_ref ) {
        $self_caller = $self;    # Class call => shared thread expected
    }
    else {
        $self_caller = $unique_ref;
    }
    my $tid = threads->tid;
    if ( !$options_ref->{'do_not_create'} ) {
        $tid = create_thread( $self, $self_caller, $package );
    }
    {
        my $key;
        if ($unique_ref) {       # Appel d'instance ($self est un objet)

            my $class    = CORE::ref $self;
            my $name     = $options_ref->{'name'};
            my $name_tid = $name || $tid;
            $name_tid = $tid if ( $options_ref->{'put_tid'} );
            if ( $options_ref->{'specific'} ) {
                $key = $unique_ref;
            }
            else {
                $key = $class;
            }
            if ( $name and !$options_ref->{'put_tid'} ) {
                my $hash_ref = $get_tid_from_thread_name{$name};
                my %hash;
                share(%hash);
                if ( defined $hash_ref ) {
                    %hash = %{$hash_ref};
                }
                $hash{$unique_ref}               = $tid;
                $get_tid_from_thread_name{$name} = \%hash;
            }
            for my $method ( @{$tab_methods_ref} ) {
                print DBG
"Ajout dans \%get_tid_from_instance_method de $method (name_tid $name_tid)\n";
                my $hash_ref = $get_tid_from_instance_method{$method};
                my %hash;
                share(%hash);
                if ($hash_ref) {
                    %hash = %{$hash_ref};
                }
                $hash{$key}                            = $name_tid;
                $get_tid_from_instance_method{$method} = \%hash;
            }
        }
        else
        { # Appel de classe ($self est une chaine de caractères représentant la classe)
            for my $method ( @{$tab_methods_ref} ) {
                print DBG "Ajout dans \%get_tid_from_class_method de $method\n";
                my $hash_ref = $get_tid_from_class_method{$method};
                my %hash;
                share(%hash);
                if ($hash_ref) {
                    %hash = %{$hash_ref};
                }
                $hash{$self}                        = $tid;
                $get_tid_from_class_method{$method} = \%hash;
            }
        }
    }

    if ( !$options_ref->{'do_not_create'} ) {
        my $queue = $server_queue_by_tid{$tid};

        my $message = encode(
            "Text::Editor::Easy::Comm::manage_requests2",
            threads->tid,
            "S",
            {
                'package' => $package,
                'methods' => $tab_methods_ref,
                'use'     => $options_ref->{'use'},
                'new'     =>
                  $options_ref->{'new'},    # $self_server vaut peut être undef
                'object' => $options_ref->{'object'},
            }
        );
        $queue->enqueue($message);
    }
    else {
        init_server_thread(
            $self_caller,
            {
                'package' => $package,
                'methods' => $tab_methods_ref,
                'use'     => $options_ref->{'use'},
                'new'     =>
                  $options_ref->{'new'},    # $self_server vaut peut être undef
                'object' => $options_ref->{'object'},
            }
        );
    }

# Attention, le code retour devra être analysé en cas de problème : attente sur la queue cliente
# Pour l'instant, cela serait bloquant puisque thread_generator ne renvoie rien
# my $response = $queue_by_tid{threads->tid}->dequeue;
# return if ( ! defined $response );

    print DBG "Create_new_server_thread : Je renvoie $tid\n";
    if ( my $init_sub_ref = $options_ref->{'init'} ) {
        my ( $what, @param ) = @$init_sub_ref;

#print DBG "Je devrais appeler $what avec tid $tid params @param\n";
# C'est "$unique_ref || $self" qui serait appelé dans un appel de méthode standard (cad $self_caller)

        Text::Editor::Easy::Async->ask_thread( $what, $tid, @param );
    }

    print DBG "Fin de create_new_server $tid\n";
    return $tid;
}

sub comm_eval {
    my ( $self, $program ) = @_;

    no warnings;    # Make visible "global lexical variables" in eval
    %get_tid_from_class_method;
    %get_tid_from_instance_method;
    %get_tid_from_thread_name;
    use warnings;

    my @return;
    my $return;
    if (wantarray) {
        @return = eval $program;
    }
    else {
        $return = eval $program;
    }
    if ($@) {
        print $@, "\n";
        return;
    }
    if (wantarray) {
        return @return;
    }
    else {
        return $return;
    }
}

sub have_task_done {

# Called from an interruptible long task
# the (long) interruptible task has to call explicitly "have_task_done" from time to time
#  ==> there is no pre-emption (use another thread or another process for that)
# Generally, long interruptible task will be called asynchronously (but not mandatory :
# blocking the calling thread with a synchronous call does not prevent other threads
# from making calls to the executing thread)

# If a long interruptible task launch another long interruptible task, the first
# task will recover CPU only when the 2nd launched task is over
    my $self_server = $thread_knowledge{'self_server'};
    my ( $method, $call_id, $reference, @param ) = get_task_to_do;
    execute_task( 'async', $self_server, $method, $call_id, $reference,
        @param );
}

sub execute_this_task {
    my ( $method, $call_id, $reference, @param ) = @_;
    my $self_server = $thread_knowledge{'self_server'};
    execute_task( 'async', $self_server, $method, $call_id, $reference,
        @param );
}

sub print_free {
    my ($string) = @_;
    for ( sort keys %free ) {
        if ( $free{$_} ) {
            $string .= "\t$_\t$free{$_}\n";
        }
    }
    print DBG $string;
}

=head1 FUNCTIONS

=head2 add_method

=head2 add_thread_method

=head2 add_thread_object

=head2 ask2

=head2 ask_common

=head2 ask_thread

=head2 comm_eval

=head2 create_client_thread

=head2 create_data_thread

=head2 create_new_server

=head2 create_queue

=head2 create_thread

=head2 decode_message

=head2 empty_queue

=head2 encode

=head2 execute_task

=head2 explain_method

=head2 get_message_for

=head2 get_response_from

=head2 get_synchronized

=head2 init_server_thread

=head2 manage_requests2

=head2 new_ask

=head2 new_editor

This sub is called only in the graphic thread context (with the thread that has tid 0).
It initializes new graphical data for the new "Text::Editor::Easy" object as well as reference this object for
thread communication.

=head2 print_free

=head2 manage_debug_file

Quick mecanism to display or to hide debug information from a package / thread. Don't need to remove
all the "print DBG" everywhere.

=head2 redirect

=head2 ref

=head2 reference_event_conditions

=head2 respond

=head2 set_ref

=head2 set_synchronize

=head2 simple_call

=head2 simple_context_call

=head2 stop_thread

=head2 thread_generator

=head2 transform_hash

=head2 untie_print

=head2 verify_graphic

=head2 verify_model_thread

=head2 verify_motion_thread

=head2 verify_server_queue_and_wait

=head1 AUTHOR

Sebastien Grommier, C<< <sgrommier at free.fr> >>

=head1 BUGS

Besides the numerous bugs installed maybe for years in this code, there is one which I think about. It's deadlock.
This, of course, is not a bug of my module, but a bug in the conception of the server thread calls.
For the moment, I just print "DANGER client '$client' asking '$method' to server '$server', already pending : $thread_status" when a thread
is called whereas it's already busy. See "Text::Editor::Easy::Data" for this warning.
Well, in the future, I will handle deadlocks : when circular calls will be noticed, I will give up one of the call made to free other calls. Of course,
the response of the given up call will be "undef" and not correct. But you're supposed to test it and it'll be always better than not to respond
any more to any other requests... Still, this situation should never happened in a good thread organisation (I sometimes had to debug
deadlocks for now, but not really much : I often use asynchronous calls to avoid that).

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
