package Text::Editor::Easy::Events;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Events - Manage events linked to user code : specific code is referenced and called here.

=head1 VERSION

Version 0.48

=cut

our $VERSION = '0.48';

=head1 INTRODUCTION

'Editor' instances will stand for 'Text::Editor::Easy' instances.

'Editor' instances have already a default management for a few events : mouse clic (set new cursor position), key press (insert or delete text),
mouse drag (select text), resize.... What you may want to do when you define your special code in response to events must be explained :

=over 4

=item *

Link code to an event not managed by default (for instance, the mouse motion)

=item *

Add an action to an already managed event

=item *

Inhibit the default action and make your own instead

=item *

Just inhibit the default action (here you don't write code)

=item *

Have your specific code executed in an asynchronous way (by a specific thread) in order to make a non freezing huge task

=item *

Have you specific code executed by a specific thread in a synchronous way

=item *

Have all these possibilities defined during the 'editor' instance creation or later.

=item *

Link more code to an already linked event (more than one specific sub for only one event) ...

=back

As you see, event management is a nightmare. What could be the interface that would enable all this and would still be usable ?

As usual, easy things should be done lazily but difficult tasks should always be possible with, of course, a little more options to learn.

=head1 EASY THINGS

 my $editor = Text::Editor::Easy->new( 
    {                                     # start of editor new options
        'file'   => 'my_file.t3d',        # option 'file' has nothing to do with event management
        'events' => {                     # events declaration
            'clic' => {                   # first specific management, 'clic' event
                'sub' => 'my_clic_sub',
            },                            # end of clic event
            'motion' => {                 # second specific management, 'motion' event
                'sub' => 'my_motion_sub',
                'use' => 'My_module',     # as in perl 'use My_module' : without .pm extension
            },                            # end of motion event
        }                                 # end of events declaration
    }                                     # end of editor new options
 );                                       # end of new
 
 [...]
 
 sub my_clic_sub {
     my ( $editor, $clic_info_ref ) = @_;
 
     [...]
 }


=head2 'events' option

You can link your subs to events during the 'editor' instance creation with the 'events' option. This option takes a hash as a value. The keys of
this hash are the name of the events : in the example, 'clic' and 'motion' events are managed. So, the first thing you have to know is the
name of the events : 

=over 4

=item *

'clic', modifier keys (alt, ctrl and/or shift) can be used

=item *

'motion', mouse move, modifier keys can be used

=item *

'drag', mouse move with left mouse button pressed, modifier keys can be used

=item *

'change', happens when the text of the editor is changed (text added, deleted or replaced).

=item *

'cursor_set', happens when the cursor position is changed.

=back

For complex things, L<here is the complete list|/EVENT LIST> but read first L</EVENT NAMES AND LABELS>.

=head2 'sub', 'use' and 'package' options of  one particular event in 'events' option

For each event managed, you have another hash which will contain, at least, the 'sub' option. Yes, this makes quite a lot of hashes, but they are
the best way to make easy interfaces : you don't have to learn arbitrary positions (just think of other major langages), if the key names are well
chosen, you learn the interface just reading an example and your code is auto-documented. I wonder how can other langages still exist without hashes...

Now, if you give nothing more than the 'sub' option, your sub should be visible and in the 'main' package. This point could be explained further.
For simple things, you write your 'sub' in the same perl program file that makes the 'Text::Editor::Easy' calls and you don't use perl package instruction.

If your program is more complex with more than one file, you can add the 'use' option which should indicate the name of a module that contains your sub.
Be careful ! The default package is now assumed to have the same value as the module. If this is not true, you'll have to add 'package' option too :

    'motion' => {                     # 'motion' event of 'events' option
        'sub'     => 'my_motion_sub',
        'use'     => 'My_module',
        'package' => 'My_package',    # sub 'my_motion_sub' of 'My_module' is
                                      #     after a 'package My_package;' declaration
    },                                # end of 'motion' event

If you have used the perl 'package' instruction in your main program, you may use only the 'package' option without the 'use' option (in order not to
have the 'main' default package assumed).

=head2 What about your specific 'sub' ?

Here are the 2 remaining things that have to be known :

=over 4

=item *

What will your sub receive ?

=item *

What should return your sub ?

=back

=head3 received information

    sub my_clic_sub {
        my ( $editor, $info_ref ) = @_;             # $info_ref is a hash reference
 
        $editor->insert(
            ' useless text ',
            {
                'line' => $info_ref->{'line'},      # The insertion point will be
                'pos'  => $info_ref->{'pos'},       # the mouse clic position
            }
        );                                          # End of insert call
    }

You always receive 2 parameters :

=over 4

=item *

The 'editor' instance that has received the event.

=item *

A hash reference that contains information relative to the event.

=back

Of course, you can't expect the information to be the same for a key press and for a mouse motion. The number and names of the hash keys 
will then depend on the event itself. L<All keys are explained for each event here|/EVENT LIST>. But it's easier to see all the possibilities for
the keys and guess what you'll get for your event :

=over 4

=item *

'line' : a L<'line' instance|Text::Editor::Easy::Line>.

=item *

'pos' : a position in that line

=item *

'x' : an absisse (for 'hard' events)

=item *

'y' : an ordinate (for 'hard' events)

=back

=head3 return value, 'action' option introduction

For easy things, your return value is not used. After your specific sub has been executed, the default management will be done (if any) with the
same event information ($info_ref hash) that you have received.

But if you want you sub to be the last thing to be done in response to the event, you can add the 'action' option with the 'exit' value :

    my $editor = Text::Editor::Easy->new(
        {
            'events' => {
                'clic' => {
                    'sub'    => 'my_clic_sub',
                    'action' => 'exit',            # nothing will be done after 'my_clic_sub'
                },
            }
        }
    );

In this case, your sub will B<always> be the last executed action. Sometimes, you would like to decide, according to the event information (so
dynamically), if you want to go on or not. See here for L<dynamic exit|/MORE ON 'ACTION' OPTION>.

In a more vicious way, you may want to change the values of the event information in order to change the data on which the default management
will work. Again, the L<'action' option|/MORE ON 'ACTION' OPTION> gives you the power to lie.

A good easy thing would be that if 'action' option (with 'exit value) is present without the 'sub' option, then nothing is executed, just an exit is made :

    'events' => {
        'clic' => {
            'action' => 'exit',         # nothing will be done, no 'sub' option
        },
    }                                   # end of events declaration

As you see, 'sub' option is, in fact, not mandatory.

=head2 easy things conclusion

Nothing has been said about threads and dynamic event linking, but this is quite normal for the easy part of the interface.
Still you can do most of what has been introduced at L<the beginning|/INTRODUCTION>.

In an easy way, all events are done synchronously by the 'Graphic' thread : the 'Graphic' thread will have to complete your sub. So you may
feel desperate if you have a huge task to do in response to a user event and if you still want your application to remain responsive : which seems
incompatible, but...

=head1 EVENT NAMES AND LABELS

For a single user event, there can be lots of 'Text::Editor::Easy' events generated. Let's take the 'clic' example. For a single mouse clic, you have
'basically' the 3 following 'Text::Editor::Easy' events :

=over 4

=item *

hard_clic (send 'x' and 'y' coordinates to your specific sub)

=item *

clic (send 'line' and 'pos' to your specific sub : an editor point of view of 'x' and 'y')

=item *

after_clic (cursor has been moved to 'line' and 'pos' by default management, still send 'line' and 'pos' to your sub)

=back

Now this is true only if no 'meta-key' was pressed during the clic : 'alt', 'ctrl' or 'shift'. As you may know, these keys or any combination of these 
keys can be associated with a standard key press, mouse clic, mouse motion, ... and you could think of that in 2 ways :

=over 4

=item *

the event mixed with a meta-key is the same, there is just more information

=item *

the event mixed with a meta-key is another one and should be named differently

=back

As a programmer, the first approach can lead to single sub managing different events (which is not very clear), but the second one can lead
to multi-declaration pointing to the same sub, which is too verbose (and not very clear in the end).

So let's have the 2 possible ways : it's your business to choose the one that is the more efficient according to your wish. For any combination of
'meta-keys', you'll have to add B<any_> prefix. For a particular combination, you'll have to add the 'combination string' as prefix, for instance 
B<alt_> or B<ctrl_shift_>. Note that in the 'combination string', 'meta-keys' are listed in alphabetic order : 'alt', 'ctrl' and then 'shift'.

Let's sum up. The 'hard_clic' event is, in fact, the first 'Text::Editor::Easy' clic event (returning 'x' and 'y') with no 'meta-key' pressed. 
The 'any_hard_clic' event is the first 'Text::Editor::Easy' clic event whatever the 'meta-keys' combination (none pressed or more).
For a given combination of 'meta-keys' (let's take 'shift_'), there are 6 'Text::Editor::Easy' events generated in the following order :

=over 4

=item *

any_hard_clic

=item *

shift_hard_clic

=item *

any_clic

=item *

shift_clic

=item *

any_after_clic

=item *

shift_after_clic

=back

Each of these names corresponds to :

=over 4

=item *

an event name usable in the 'events' option of the new method

=item *

a 'label', which is a precise moment of the 'clic' management

=back

When a default management is defined for a label, the order of execution is, first, the event associated with that label (if any), then, the default
management.

=head1 MORE ON 'ACTION' OPTION

We've seen the 'exit' value of 'action' option that ends the event management. There are 2 other possible values :

=over 4

=item *

'change' to change event values or exit dynamically

=item *

'jump' to go straight to a precise L<event label|/EVENT NAMES AND LABELS>

=back

With any of these 2 values, the B<return value of your specific sub is used and is very important !>

=head2 'change' value

 my $editor = Text::Editor::Easy->new( 
     {
         'file'   => 'my_file.t3d',
         'events' => {
             'clic' => {
                 'sub'    => 'my_clic_sub',
                 'action' => 'change',     # event information can be changed by 'my_clic_sub'
             },
         }
     }
 );                                        # end of new
 
 [...]
 
 sub my_clic_sub {
     my ( $editor, $info_ref ) = @_;
 
     $info_ref->{'pos'} = 0;  # setting position to the beginning of the line
     return $info_ref;        # Returning a hash reference with the same keys,
                              #     'pos' value probably changed (was perhaps already 0)
 }

With 'change' value you can modify if you wish the values of the hash reference $info_ref which contains your event information. The default 
management and the possible following events will use your new values. If you don't provide a hash with exactly the same keys as you have
received, then an exit will be done. This can be used to exit dynamically : all you have to do in order to exit is a simple "return;" ('undef' value is 
not a hash...) as long as you have the 'action' options set to 'change'.

=head2 'jump' value

 my $editor = Text::Editor::Easy->new( 
     {
         'file'   => 'my_file.t3d',
         'events' => {
             'hard_clic' => {
                 'sub'    => 'my_hard_clic_sub',
                 'action' => 'jump',             # a jump can be done
             },
         }
     }
 );
 
 [...]
 
 sub my_hard_clic_sub {
     my ( $editor, $info_ref ) = @_;
 
     if ( $info_ref->{'x'} < ( $editor->width / 2 ) ) {
         return $info_ref;                               # no jump, values unchanged
     }
     my %new_info = ( 
         'line' => $editor->first,
         'pos'  => int( 20 * $info_ref->{'y'} / $editor->height ),
     );
                                                         # jump to 'clic' label
     return [ 'clic', \%new_info ];                      # providing the hash required
 }

The difficult point is that, at a precise label, default management or other events expect to find a precise C<$info_ref> hash with precise keys
in order to work. So if you want to make a jump to a particular label, you have to provide yourself this C<$info_ref> hash.

You may return from your specific sub managing a 'jump' action in 3 different ways :

=over 4

=item *

returning undef will exit the event management : 'dynamic exit' remains possible with a jump

=item *

returning a hash reference will just make a 'change' action with no jump. The hash given will be taken as the new <$info_ref> hash 
(for default management...) : a 'jump' action can encapsulate a 'change' action

=item *

returning an array reference will make a jump : the first position of the array is the label where to jump, the second one is the new C<$info_ref> hash
B<needed at that label>.

=back

If the 'jump' action includes the 'change' action, why should we keep the 'change' action ?
In fact, at first, I didn't think of the 'action' option. I just wanted to analyse the return value of the specific sub. But it's not very clear. Complex
mecanism are hidden in specific code. With the 'action' option, you have a warning reading the code of the instance creation and this warning
can be saved as dynamic configuration and inquired later. Keeping 'jump' with 'change' gives this warning different levels : I think it's a little better.

=head3 smallest possible 'jump'

As you may L<link more than one sub|/'MULTI-SUB' DECLARATION> to one event, the smallest possible jump is done when you give the label
following your own one (here the information hash should contain the same keys as those you have received). In this case, what you have jumped
are the possible other subs that were linked to the same label event as yours, these subs should have been done after your own one (if no jump has
been made).

=head1 THREADS CONTRIBUTION

Just imagine the future : computers with more than one CPU... No sorry, that's just present : as for me, I have a dual core. But imagine that, as a
programmer, you could use your 2 (or maybe more) CPU very easily : for instance, just using threads...

As you can L<add threads|Text::Editor::Easy::Comm> to manage new methods with 'Text::Editor::Easy' objects, you can use (or create) as many
threads as you want to manage events. Of course, dividing a precisely defined job into more pieces than you have CPU won't be more efficient.
But very often, with interactive applications, we don't have a precise job to do : tasks to be done change sometimes so fast, depending on
user actions, that what was interesting to do at one moment could be useless just a few milliseconds later. With a multi-thread application, you not
only give yourself the power to use all of your CPU, but you also give yourself the power to interrupt useless tasks.

When you use the 'Graphic' default thread, your event sub is synchronous, that is the code of your event will freeze the user interface :
you should not use it for heavy tasks. For little tasks, this freeze won't be noticed.
If you have a huge task to do in response to an event, you can use another thread than the 'Graphic' one. In this case, the 'Graphic' thread 
still receive the initial event (you can't change that !) but as soon as enough information has been collected, your thread is called asynchronously
by the 'Graphic' thread (the 'Graphic' thread won't wait for your thread response). And here, if you make a heavy task, the user interface won't 
be freezed.

Still, with any thread, you should work in an interruptible way rather than make a huge task at once. Why ? Because the principle of
events is that you can't know when they occur and how many. Suppose your code responds to the mouse motion event : when the user
moves his mouse from left to right of your editor, you can have more than 10 mouse motion events generated in one second. And a perfect
response to the first event can be useless as soon as the second event has occured. Moreover, the 'Graphic' thread will send all asynchronous events
to your thread, even if it is busy working. Events will stack in a queue if your thread can't manage them quickly. If your code makes, in the end,
a graphical action visible by the user, there could be a long delay between the last event and its visible action.
And the user would consider your code as very slow. On the contrary, if you work in an interruptible way, that is, if you insert, from time to time,
little code like that :

    return if (anything_for_me); # "me" stands for your thread executing your code

the user could have the feeling that your code is very fast : this is because you empty your thread queue more quickly and thus decrease the delay
between the last event and its answer. But you should add this line (that is, check your thread queue) when you are in a proper
state : just imagine that there is really something for you and that your code will be stopped and executed another time from the start.

The conclusion is :  "A good way to be fast is to give up useless tasks" and using more than one thread allows you to give up, so don't hesitate
to give up. This is the very power of multi-threaded applications : the ability to make huge tasks while remaining responsive. This does not mean
that programmers can still be worse than they are now (me included !) : they have to know where to interrupt.

=head2 'thread' option

    my $tid = Text::Editor::Easy->create_new_server(
        {
            ... # see Text::Editor::Easy::Comm for mandatory options
            'name' => 'My_thread_name',
        }
    );
    my $editor = Text::Editor::Easy->new( 
        {
            'file'   => 'my_file.t3d',
            'events' => {
                'clic' => {
                    'sub'    => 'my_clic_sub',
                    'thread' => 'My_thread_name',    # $tid could have been used instead of 'My_thread_name'
                },
            }
        }
    );

The value of the 'thread' option is the name of the thread you have chosen (should contain at least one letter), or the 'tid' 
(thread identification in perl ithread mecanism) that the program has chosen for you (it's an integer).

Note that by default, if you give the 'thread' option, an asynchronous call is assumed. The 'Graphic' thread asks your thread to execute your sub
but doesn't wait for its response.

=head2 'create' option

In the L<'thread' option example|/'thread' option>, the thread had already been created, but if you use 'thread' option with a name that is unknown, a new thread
will be created on the fly and will be named accordingly.

On the contrary, if you have written a bad name by mistake, you may want to prevent this auto-creation. The 'create' options has 3 possible values :

=over 4

=item *

'warning' : if the thread does not exist yet, the thread is created but a display is made on STDERR

=item *

'unlink' : if the thread does not exist yet, the thread is not created, the event is not linked to your sub but the 'editor' instance is still created

=item *

'error' (or any value different from 'warning' and 'unlink') : if the thread does not exist, the thread is not created, the 'editor' instance is not created

=back

Maybe you feel that the 'create' option should have been used to enable creation not to prevent it. But you are a perl programmer and should
feel responsible : the more irresponsible the languages assume the programmer is, the more verbose your programs have to be and the less
accessible the languages are. Langages should definitely consider programmers as responsible persons.

So you don't have to use the 'create' option if you want an auto-creation and that could be called lazyness or responsability.

=head2 'sync' option

 'events' => {
     'clic' => {
         'sub'    => 'my_clic_sub',
         'thread' => 'My_thread_name',
         'sync'   => 'true',              # A 'true' value : the call will be synchronous
     },
 }

Well, the benefit of threads seems to be brought only by asynchronous calls, but there is a reason why you could wish a synchronous call.
You may want to initialize data in your thread while changing values for the default event management. And the initialized data will be used
after the default management in an asynchronous way. So you don't have to share variables between threads just because you want some
events to be synchronous : variable 'scope' can then be limited. Read carefully the L<deadlock possibility|/deadlocks, 'pseudo' value for 'sync' option>
if you use this option.

This point is easier to understand when you know that, for instance, for a single mouse clic, you can L<manage up to 3 different events|/EVENT NAMES AND LABELS>.

Now what about the 'sync' option with a 'false' value ?
You will force an asynchronous call and this could be used ... for the 'Graphic' thread ! This trick won't prevent you from freezing the user
interface if your code is huge, but if you know what you are doing...

 'events' => {
     'clic' => {
         'sub'    => 'my_clic_sub',
         'sync'   => 'false',           # the 'Graphic' thread will execute 'my_clic_sub' asynchronously
     },
 }

The 'Graphic' thread asks a task to itself (puts it in its thread queue) but doesn't execute it immediately : first it has to end this event management.
Once finished, it will execute its tasks in the order they have been queued... as well as manage other possible user events. Yes, the 'Graphic' thread
is very active and it's very difficult to know when it will have a little time for you.

You would get the same result with this :

 'events' => {
     'clic' => {
         'sub'    => 'my_clic_sub',
         'thread' => 'Graphic',         # 'thread' option present => asynchronous call assumed
     },
 }

=head2 'sync', 'thread' and 'action' incompatibilities

When you work in an asynchronous way, the 'Graphic' thread doesn't wait for your answer. Then it can't receive a label for a 'jump' action or a return
value for a 'change' action. So, only the 'exit' value of 'action' option is valid with asynchronous call.

=head2 deadlocks, 'pseudo' value for 'sync' option

When you use a thread in a synchronous way in an event management, you should understand what the 2 implied threads are doing :

=over 4

=item *

the 'Graphic' thread is pending, waiting for your thread response

=item *

your thread is working hard, trying to slow down the least it can the 'Graphic' thread

=back

So there is a very bad thing that could happen : if your thread asks for a service that is managed by the 'Graphic' thread... you know what follows...
As the 'Graphic' thread is waiting for your answer (synchronous call), it can't serve your request so your thread waits endlessly for
the 'Graphic' thread response and the 'Graphic' thread waits endlessly for your thread response. Everything is freezed forever (in fact some other
threads are still working, but the 'Graphic' thread is the visual one and the only one versus the window manager).

So, synchronous calls initiated by the 'Graphic' thread can't use a 'Graphic' service. This is quite limiting but you could have to work with this
limitation and find a solution : in the end, this is your job as a programmer.

Note that this is a general problem of multi-thread programmation : when a server thread asks another thread for a synchronous task, the executing
thread can't use any service of the calling thread. The limitation is not linked to graphics.

=head3 tracking deadlock

That kind of deadlocks could be checked and will be managed like that :

=over 4

=item *

a warning message, including the stack call, will be printed on STDERR

=item *

the executing thread will receive undef as an anwser : of course nothing will have been done by the initial calling server thread.

=back

...but it's not yet managed. So in case you have a permanent freeze, you'll have to guess from which call the deadlock was introduced. Of course
such a management will not be provided as a solution but as a help during development : this situation reveals a problem in conception.

=head3 'pseudo' value for 'sync' option

There is already a solution that could suit you : the 'Graphic' thread can make a 'pseudo-synchronous' call. It calls your thread
asynchronously getting the 'call_id' (see L<Text::Editor::Easy::Comm>). Then the 'Graphic' thread enters a loop where it checks 2 things
at the same time :

=over 4

=item *

I<Is there any task for me in the queue ?> If true, then I execute it. These queued tasks do not include other user events coming
from the window manager which will still remain pending.

=item *

I<Is the asynchronous call that I have asked for ended ?> Which means : I<is your event sub ended ?> If true, I exit the loop, get the answer and
go on with the event management.

=back

In order to have such a permissive management, you just have to use the 'pseudo' value for the 'sync' option :

    'events' => {
        'clic' => {
            'sub'    => 'my_clic_sub',
            'thread' => 'My_thread',
            'sync'   => 'pseudo',            # 'My_thread' can make calls to the 'Graphic' thread
            'action' => 'change',            #   ... and can return a value to the 'Graphic' thread
        },
    }

So why should we keep the 'true' synchronous call ? Because with a pseudo-synchronous call, there is quite a big indetermination in the
order of execution of the different tasks and maybe there is a chance that your deterministic program produces, sometimes, chaotic results.
So 'pseudo' value for 'sync' option is provided but may lead, from time to time, to unexpected results, you are warned.

Note that chaotic reponses can be obtained with asynchronous calls too. Maybe a good thing to do is to change 'common data' thanks to
synchronous calls and only. Asynchronous calls should only be used for displaying common data or changing private data (private to a thread).
So using $editor->display or $line->select in an asynchronous called sub is OK but using $editor->insert or $line->set can lead to a race
condition with unpredictible result, see L<perlthrtut/"Thread Pitfalls: Races">. In fact, 'Text::Editor::Easy' manages editor data in a private way (only
'File_manager' thread knows about the file being edited) but as methods can be called by any thread, these data should be considered as shared :
if the cursor position is not the same when the event occurs as when you make your $editor->insert in your event sub (because an other thread
have changed this position between the event and your asynchronous sub), the result may look funny (still worse if a delete has removed 
the line you were expecting to work on !).

=head1 'MULTI-SUB' DECLARATION

You can link more than one sub to a single event. This can be interesting if you want to mix 
L<synchronous and asynchronous responses|/THREADS CONTRIBUTION> or just if you
have 2 very different things to do and don't want to hide them in a bad named sub.

 my $editor = Text::Editor::Easy->new( 
     {                                          # start of editor new options
         'events' =>                            # 'events' option
         {
             'clic' =>                          # 'clic' event management
             [                                  # array reference : more than one sub possible
                 {
                     'sub' => 'my_clic_sub_1',  # first sub to execute in response to 'clic' event
                 },
                 {
                     'sub' => 'my_clic_sub_2',  # second sub to execute in response to 'clic' event
                 },
             ],                                 # end of clic event
             'motion' =>
             {                                  # hash reference : single sub management
                 'sub' => 'my_motion_sub',
             },
         }                                 # end of 'events' option
     }                                     # end of editor new options
 );                                        # end of new

The sub declaration order is very important in your array : subs are called in this order. So, if you use the 'action' option in the first event, other
events could work with modified event information or could just be jumped.

=head1 DYNAMIC CONTRIBUTION, part 1, updating events

Suppose that your program have several 'Text::Editor::Easy' instances running.
We've seen that you can add new instances with specific event management.
Thanks to 'dynamic contribution', you can change event management of already
running instances.
A generalization of this 'dynamic contribution' is to have a default set
of events used for future created instances.

The dynamic interface let you modify :

=over 4

=item *

A single event management of a single instance (instance call)

=item *

All events of a single instance (instance call)

=item *

A single event of a all instances (class call)

=item *

All events of all instances (class call)

=back

'Modify' event management should be understood as one of these possibilities :

=over 4

=item *

Adding an new event (no management before)

=item *

Changing an old event

=item *

Deleting an old event

=back

=head2 Single event versus all events

There are 2 distinct methods :

=over 4

=item *

B<set_event> will change only one event

=item *

B<set_events> will change all the eventB<s>, note that the last B<"s"> makes all the difference.

=back

=head3 set_event method

    Text::Editor::Easy->set_event( 
        'clic',                           # first parameter
        {                                 # second parameter, hash
            'sub'    => 'my_clic_sub',
            'thread' => 'My_thread',
        },
    };

In the previous example, the 'clic' event of 'all instances' (class call) will be changed.

The 'set_event' method accepts from 1 to 3 parameters :

=over 4

=item *

The first is the name of the event to be changed

=item *

The second contains the information that should have been given during the instance creation :
the interface is the same (you can create threads, eval a new module, ...).

This second parameter can then be a hash reference (for a single action linked to this event) 
or an array reference (for L<multiple actions|/'MULTI-SUB' DECLARATION>).

If there is no second parameter (or an undef value), the event will be deleted.

=item *

L<A third optional parameter|/Single instance versus 'all instances', options for class calls> 
can add conditions to define if the event should be changed or not. These conditions
should be used with class calls.

=back

=head3 set_events method

    $editor->set_events( 
        {
            'clic', {
                'sub'    => 'my_clic_sub',
                'thread' => 'My_thread',
            },
            'motion', {
                'sub'    => 'my_motion_sub',
            },
        }
    };

In the previous example, B<all> specific event management have been re-set for the existing 
instance $editor. Of course, only 'clic' and 'motion' events are defined here, but if the 
'drag' or 'change' events were linked to specific subs, these old links are cut. If you want
to keep an old specific management with 'set_events' method, you'll have to repeat it in order not
to erase it.

The 'set_events' method accepts 1 parameter which exactly corresponds to the 'events' option
used during the instance creation. For class call of 'set_events', 
L<an optional second parameter|/Single instance versus 'all instances', options for class calls>
is possible.

Calling 'set_events' with no parameter (or an empty hash) will delete any specific event management.

=head2 Single instance versus 'all instances', options for class calls

If you've read carefully the 2 previous examples, you already know that
an instance call changes only one instance and a class call changes 'all
 instances'.

But 'all instances' is not very clear : only existing instances, only the
ones that will be created from now, both, ... ?

Here, we're talking of class calls of 'set_event' and 'set_events' methods and we want to
precise the subset of instances to which the changes will apply.

    # 'set_event' class call example with options
    
    Text::Editor::Easy->set_event( 
        'clic',                             # First parameter
        {                                   # Second parameter
            'sub'    => 'my_clic_sub',
            'thread' => 'My_thread',
        },
        {                                   # Third optional parameter
            'instances' => 'future',
            'values'    => 'undefined',
        }                                   # End of third parameter
    };


    # 'set_events' class call example with options
    
    Text::Editor::Easy->set_events( 
        { 'clic' =>                         # First parameter
            {
                'sub'    => 'my_clic_sub',
                'thread' => 'My_thread',
            },
        }
        {                                   # Second parameter
            'names' => qr/\.pl$/,           # 'Regexp' object
        }                                   # End of second parameter
    };


You can add a third parameter to 'set_event' method or a second parameter
to 'set_events' method. This last parameter is an optional hash with the following keys :

=over 4

=item *

'instances'

=item *

'values'

=item *

'names'

=back

=head3 'instances' key

Possible values are :

=over 4

=item *

'existing', will affect only existing instances but not the ones to come.

=item *

'future', will affect only instances to come but not existing ones.

=item *

'all', will affect all instances, this is the default option.

=back

=head3 'values' option

Possible values are :

=over 4

=item *

'undefined', will affect only undefined event(s) : won't override existing
management

=item *

'defined', will affect only defined event(s) : replace existing management,
but don't add management where there wasn't any.

=item *

'all', no matter if event(s) were defined before : this is the default option

=back

With a 'set_event' call (that is, when you define a particular named event,
for example, 'clic'), 'undefined' value means that, for each instance, a test
will be done : if a 'clic' event already exists for the tested instance,
it won't be updated.

With a 'set_events' call (when you want to set all events at once), 
'undefined' value means that there is not a single event managed in a 
specific way. You don't have used 'events' option during creation, or you
have deleted all events afterwards.

=head3 'names' option

This option accepts a 'Regexp' object that you can obtain with the qr// syntax.

If the name of an 'Editor instance' matches the regexp, the change will apply.

=head2 'values' options with instance call

You can use the 'values' option with an instance call if you are too lazy to check what you've done before.

=head2 endless complexity with optional parameters and new instances

If you have made several class calls with 'set_event' and / or 'set_events' methods that affects new created
instances, what will happen when a new instance will be created ? Which tests will be made, in which order ...?

The answer is : all tests will be done and in the order you have made the calls. As a joke, if you make
calls (to 'set_event' and / or 'set_events' methods) from different threads, the order will be undefined !

This is a very complex mecanism of default event management. The interface to get all these
default actions (done at each instance creation) or set or unset all these default actions in just
one call is not provided.

=head1 DYNAMIC CONTRIBUTION, part 2, dynamic designing

Perl is dynamic : you can 'eval' new code during execution and in the context of the running program.

Suppose your program is (or contains) an editor, that sounds great ! Your program can ask you for new 
code to edit (or old one to change) and will go on running using this very code ! You can call that the
way you want : a 'dynamic application', a limitless 'macro langage', the best configuration tool ever,
or the most dangerous thing (it's true that powerful things put in bad hands are dangerous, but skilled
people shouldn't be limited because of unskilled ones).

=head2 'code' option

This option can replace 'sub', 'use' and 'package' options in L<standard and static
event definition|/'sub', 'use' and 'package' options of one particular event in 'events' option>.

This option accepts a string that represents the code of the event.

Note that you must not start your code with 'sub { ...' : you should consider yourself
already inside an unnamed sub.

 $editor->set_event( 
     'clic', { 
         'code' => 'print "Hello\n"';
     },
 );
 
 # is almost equivalent to
 
 $editor->set_event( 
     'clic', { 
         'sub' => 'hello';
     },
 );
 
 sub hello {
     print "Hello\n";
 }

About the differences :

=over 4

=item *

to use the 'sub' option, you need a named sub written somewhere in your program or in a module whereas
the 'code' option let you have your code in memory and nowhere else.

=item *

with the 'code' option, your code is 'checked' (or compiled) during the 'set_event'
call (with an eval). Moreover, for each event, the code is executed in an 'eval'. So, the
'code' option is dynamic but slower : you have nothing without nothing ! But 'dynamic
designing' should be considered as a faster way to design with a future possibility to
migrate 'dynamic tested code' to 'static code'. 

=back

On the paper, this 'code' option seems useless because you have to write the code anyway. But
if the code is written after you have started your application ... and by the user himself :
see 'demo12' provided with the 'Editor.pl' program to understand.

=head1 DYNAMIC CONTRIBUTION, part 3, saving

Suppose you've done complex things with the event management. Some events of a few instances are managed
in a static way with subs written in different modules but other events are managed in a dynamic way
with code in memory but saved nowhere... 

This is a real mess but that costed you a lot to come to this ugly point and you wouldn't like
to lose everything when your program will stop : either in a proper way or by a crash due to numerous
bugs.

The session management will help you save everything of your instances in order to get the 'same' 
state (at least, we'll try) that you've had before quitting.

=head1 EVENT LIST

At present, only the 'clic' subset is integrated in the new event management. 

=head2 'clic' subset

There are 27 'clic' event labels (3 x 9) given the 3 following suffixes :

=over 4

=item *

hard_clic

=item *

clic

=item *

after_clic

=back

and the 9 possible prefixes :

=over 4

=item *

no prefix ('' = empty string = q{})

=item *

any_

=item *

alt_

=item *

ctrl_

=item *

shift_

=item *

alt_ctrl_

=item *

alt_shift_

=item *

ctrl_shift_

=item *

alt_ctrl_shift_ (applications designed for pianists only !)

=back

The suffix is associated to a precise moment in the clic sequence, the prefix to the modifier keys pressed during the clic. Here are 3 examples of
event label among the 27 possible :

=over 4

=item *

any_hard_clic

=item *

shift_clic

=item *

alt_ctrl_after_clic

=back

A true mouse clic event generates 6 events as explained in L</EVENT NAMES AND LABELS>. In fact, if we include the default actions,
there are 9 steps in a complete clic sequence :

=over 4

=item *

'any_hard_clic' event sub(s)

=item *

'${meta}hard_clic' event sub(s)

=item *

'hard_clic' default management (if no modifier key pressed or if label is 'hard_clic') : drag initiation for resize management

=item *

'${meta}hard_clic' default transform : transform 'x' and 'y' coordinates to 'line' and 'pos'

=item *

'any_clic' event sub(s)

=item *

'${meta}clic' event sub(s)

=item *

'clic' default management (if no modifier key pressed or if label is 'clic') : set cursor position

=item *

'any_after_clic' event sub(s)

=item *

'${meta}after_clic' event sub(s)

=back

These 9 steps should be understood if you plan to use L<a 'jump' action|/'jump' value>. For instance, if you are in a "${meta}hard_clic" event sub, the smallest
jump you could do would be to give the label 'hard_clic' (you will have the default 'hard_clic' management executed even if a modifier key is
pressed). But you could end your sub giving the same label of your event, "${meta}hard_clic" : in this case, the default 'hard_clic' management 
will be done as usual (that is, only if no modifier key was pressed), then the default ${meta}hard_clic transformation will be done, followed by 'any_clic'
events and so on...

Parameters received by your specific sub and needed at specific labels depends only on the suffix. So only suffixes are described.

=head3 'hard_clic' suffix

First couple of events generated in the 'clic' sequence. There is a default management (when no modifier key is pressed) which initiates a drag 
sequence if the cursor shape is a resize arrow (in this particular case, nothing is done afterwards : no 'clic' and 'after_clic' management).

The information received by your sub is a hash containing the following keys :

=over 4

=item *

'x', abscisse of the clic

=item *

'y', ordinate of the clic

=item *

'meta_hash', hash containing the keys 'alt', 'ctrl' and 'shift' : values are true if the corresponding modifier key was pressed.

=item *

'meta', string containing the modifier key combination ('', 'shift_', 'alt_ctrl_', ...)

=back

'meta_hash' and 'meta' are interesting only for 'any_hard_clic' event :

 my $editor = Text::Editor::Easy->new( 
    {
        'file'   => 'my_file.t3d',
        'events' => {
            'any_hard_clic' => {              # hard_clic for any modifier key combination
                'sub'    => 'my_hard_clic_sub',
            },                         
        }                                     # end of events declaration
    }
 );
 
 [...]
 
 sub my_hard_clic_sub {
     my ( $editor, $info_ref ) = @_;
 
     if ( $info_ref->{'meta_hash'}{'alt'} ) {
         print "You pressed the alt key during the clic\n";
     }
     print "Meta combination string is ", $info_ref->{'meta'}, "\n";
 }

=head3 'clic' suffix

Second couple of events generated in the 'clic' sequence. There is a default management  (when no modifier key is pressed) which makes the 
following actions :

=over 4

=item *

sets the cursor to the position pointed by the mouse clic

=item *

deselects any previously selected area

=item *

set focus to the editor which has received the clic event

=item *

a little visual adjustment is also possible if the new cursor position is on the first or last displayed line

=back

The information received by your sub is a hash containing the following keys :

=over 4

=item *

'line', the L<line instance|Text::Editor::Easy::Line> where the clic was done

=item *

'pos', the position in that line

=item *

'meta_hash', hash containing the keys 'alt', 'ctrl' and 'shift' : values are true if the corresponding modifier key was pressed : interesting for 'any_clic' event

=item *

'meta', string containing the modifier key combination ('', 'shift_', 'alt_ctrl_', ...) :  interesting for 'any_clic' event

=back

=head3 'after_clic' suffix

Third and last couple of events generated in the 'clic' sequence. There is no default management.
The information received by your sub is a hash containing the following keys (the same keys as the 'clic' event) :

=over 4

=item *

'line', the L<line instance|Text::Editor::Easy::Line> where the clic was done

=item *

'pos', the position in that line

=item *

'meta_hash', hash containing the keys 'alt', 'ctrl' and 'shift' : values are true if the corresponding modifier key was pressed (for 'any_after_clic')

=item *

'meta', string containing the modifier key combination ('', 'shift_', 'alt_ctrl_', ...),  for 'any_after_clic'

=back

=head2 'motion' subset

=head1 EVENTS LINKED TO A ZONE INSTANCE

Events can be linked to a L<'zone' instance|Text::Editor::Easy::Zone> rather than to a 
'Text::Editor::Easy' instance.

2 events are acessible for a 'zone' instance :

=over 4

=item *

top_editor_change : happens each time a new 'editor' instance is on top of the zone.

=item *

editor_destroy : happens each time a 'editor' instance belonging to the zone is destroyed.

=back

=head1 CONCLUSION

Maybe the interface seems a little complex in the end, still complexity have not been added freely. If this interface is adapted to programs
that change, then the goal will be reached : 

=over 4

=item *

first, you use synchronous events executed by the 'Graphic' thread

=item *

second, your application is growing (and your event code too), becoming more interesting and ... slower

=item *

Then you add threads where you feel it would help, keeping your code and your declarations but adding a few 'thread' options and and a few
C<return if anything_for_me;> instructions.

=back

=cut

require Exporter;
our @ISA = ("Exporter");
our @EXPORT_OK = qw(execute_events);

use threads;
use Text::Editor::Easy::Comm qw(anything_for_me have_task_done);
use Devel::Size qw(size total_size);

use constant {
    SUB_REF => 0,
    PACKAGE => 1, 
    MODULE => 2,
    SUB => 3,
};

sub reference_events {
    my ( $id, $events_ref ) = @_;
    
    # print "Dans reference_events events = $events_ref\n";
    if ( ! ref $events_ref or ref $events_ref ne 'HASH' ) {
        print STDERR "'events' option should be a hash reference\n";
        return;
    }
    for my $event_name ( keys %$events_ref ) {
        my $event_list_ref = $events_ref->{$event_name};
        if ( ref $event_list_ref eq 'HASH' ) {
            #print "Single event declaration\n";
            $event_list_ref->{'name'} = $event_name;
            my $answer = reference_event($id, $event_list_ref);
            if ( ! ref $answer ) {
                return if ( $answer eq 'error' );
                delete $events_ref->{$event_name};
            }
            else {
                $events_ref->{$event_name} = $answer;
            }
        }
        else {
            if ( ref $event_list_ref ne 'ARRAY' ) {
                print STDERR "Can't manage event $event_name : should be array or hash reference\n";
                return;
            }
            #print "Multiple event declaration\n";
            my @new_list;
            while ( my $event_ref = shift @$event_list_ref ) {
                $event_ref->{'name'} = $event_name;
                my $answer = reference_event($id, $event_ref);
                if ( ! ref $answer ) {
                    return if ( $answer eq 'error' );
                }
                else {
                    push @new_list, $answer;
                }
            }
            $events_ref->{$event_name} = \@new_list;
        }
    }
    return $events_ref;
}

my %possible_action = (
    'exit'    => 1,
    'change' => 1,
    'jump'    => 1,
    'nop'      => 1,
);

my %possible_sync = (
    'true'     => 1,
    'false'    => 1,
    'pseudo'   => 1,
);


sub reference_event {
    my ( $id, $event_ref ) = @_;
    
    my $package = 'main';
    #print "REF de event_ref : ", ref $event_ref, "\n";
    my $use = $event_ref->{'use'};
    my $thread = $event_ref->{'thread'};
        # Faux : l'appel à reference_event peut être fait par autre chose que le thread Graphic ...
        
    my $thread_defined = 1;
    if ( ! defined $thread ) {
        $thread_defined = 0;
        #eval "use $use";
        #if ( $@ ) {
        #    print STDERR "Wrong code for module $use :\n$@";
        #    return 'error';
        #}
        $thread = 0;
    }
    if ( $use ) {
        $package = $use;
        

    }
    my $action = $event_ref->{'action'};
    if ( defined $action ) {
        #print "Action définie à $action pour event_ref = $event_ref\n";
        if ( ! $possible_action{$action} ) {
            print STDERR "Unknown action value $action, instance not created\n";
            return 'error';
        }
    }
    my $sync = $event_ref->{'sync'};
    if ( defined $sync and ! $possible_sync{$sync} ) {
        print STDERR "Unknown sync value $sync, instance not created\n";
        return 'error';
    }

    if ( ! defined $event_ref->{'package'} ) {
        $event_ref->{'package'} = $package;
    }
    else { # A supprimer
        $package = $event_ref->{'package'};
    }
    if ( defined $thread ) {
        my $answer_ref = thread_use( $id, $thread, $use, $event_ref->{'create'}, $event_ref->{'init'}, $package );
        return $answer_ref if ( ! ref $answer_ref );
        if ( $thread_defined ) {
            $event_ref->{'tid'} = $answer_ref->{'tid'}; 
            if ( $action ) {
                if ( $action ne 'exit' and $action ne 'nop' ) {
                    if ( ! defined $sync or $sync eq 'false' ) {
                        print STDERR "Action $action forbidden with asynchronous call to thread $thread\n";
                        delete $event_ref->{'action'};
                    }
                }
            }
        }
    }
    
    my $sub_ref = $event_ref->{'sub'};
    if ( defined $sub_ref ) {
        my $sub = ref $sub_ref;
        if ( $sub ) {
            if ( $sub ne 'ARRAY' ) {
                print STDERR "'sub' option in 'event' declaration should be a string or an array reference\n";
                return 'error';
            }
            $sub = $sub_ref;
        }
        else {
            $sub = [ $sub_ref ];
        }
        $event_ref->{'sub'} = $sub;
        return $event_ref;
    }

    $event_ref->{'sub'} = [ ];
    
    if ( my $string = $event_ref->{'code'} ) {
        my $sub_ref = eval "sub { $string }";
        if ( $@ ) {
            print STDERR "Wrong code for event '$event_ref->{'name'}' : $@\n";
            my $indice = 1;
            for ( split( "\n", $string ) ) {
                print STDERR "\t$indice - $_\n";
                $indice += 1;
            }
            return 'unlink';
        }
        else {
            my $id = $event_ref->{'id'};
            my $tid = $event_ref->{'tid'};
            
            $tid = 0 if ( ! defined $thread ) ;
            
            if ( defined $tid ) {
            # L'évaluation  peut avoir lieu à tort dans le thread 0 (si thread 'File_manager' : plus lent au premier appel...)
                $event_ref->{'id'} = Text::Editor::Easy->ask_thread(
                    'Text::Editor::Easy::Events::thread_eval',
                    $tid,
                    $string,
                    $id
                ); 
            }
            #print "Bonne évaluation, code = $string\n";
        }
        return $event_ref;
    }
    
    if ( ! defined $action ) {
        print STDERR "No action defined and no sub provided, event cancelled\n";
        return 'unlink';
    }
    return $event_ref if ( $action eq 'exit' );
    if ( $action ne 'nop' ) {
        print STDERR "Action $action not correct when no sub is provided, event cancelled\n";
        return 'unlink';
    }
    if ( ! defined $thread ) {
        print STDERR "Action nop should be linked with a thread option, event cancelled\n";
        return 'unlink';
    }
    #print "Pour event $event_ref package = $package\n";
    return $event_ref;
}

sub thread_use {
    my ( $id, $thread, $use, $create, $init, $package ) = @_;

    my $tid = $thread;
    if ( $thread =~ /\D/ ) {
        $tid = Text::Editor::Easy::Comm::get_tid_from_name_and_instance( $id, $thread );
        $tid = 0 if ( $thread eq 'Graphic' );
        if ( ! defined $tid and $thread ne 'File_manager' ) {
            if ( defined $create ) {
                if ( $create eq 'warning' ) {
                    print STDERR "Thread $thread will be created by event management\n";
                }
                elsif ( $create eq 'unlink' ) {
                    print STDERR "Thread $thread won't be created by event management, event not linked\n";
                    return 'unlink';
                }
                else {
                    print STDERR "Thread $thread doesn't exit, object creation aborted\n";
                    return 'error';
                }
            }
            $tid = Text::Editor::Easy->create_new_server( {
                'methods' => [],
                'object' => {},
                'name' => $thread,
            } );
        }
    }
    if ( defined $tid ) {
        Text::Editor::Easy::Async->ask_thread( 'use_module', $tid, 'Text::Editor::Easy::Events' );
        if ( defined $use ) {
            Text::Editor::Easy::Async->ask_thread( 'use_module', $tid, $use );
        }
        if ( defined $init and ref $init eq 'ARRAY' ) {
            my @init = @$init;
            my $sub = shift @init;
            #print "Avant appel $sub : package = $package\n";
            Text::Editor::Easy::Async->ask_thread( $sub, $tid, @init );
        }
    }
    return { 'tid' => $tid }; # $tid maybe undef
}

my %sub_ref;
my $sub_ref_id = 0;

sub thread_eval {
    my ( $self, $ref, $string, $id ) = @_;
    
    print "Dans thread_eval : tid = ", threads->tid, "\n";
    if ( ! defined $id ) {
        $sub_ref_id += 1;
        $id = $sub_ref_id;
    }
    $sub_ref{$id} = eval "sub { $string }";
    if ( $@ ) {
        print STDERR "Wrong 'compilation' during evaluation of :\nsub { $string } :\n$@\n";
        return;
    }

    return $id;
}

sub execute_events {
    my ( $events_ref, $object, $info_ref ) = @_;

    my $events_list_ref;
    
    # possible si l'évènement était incorrect lors du référencement
    return if ( ! ref $events_ref );
    
    if ( ref $events_ref ne 'ARRAY' ) {
        # ==> ref $events_ref eq 'HASH'
        #print "Evènement simple\n";
        $events_list_ref = [ $events_ref ];
    }
    else {
        #print "Multiples évènements\n";
        $events_list_ref = $events_ref;
    }
    
    EVENT: for my $event ( @$events_list_ref ) {
        my $action = $event->{'action'};
        #print "Event $event\n";
        #if ( ! defined $action ) {
        #    print "    ... action non définie pour objet = ", $object->name, "\n";
        #}
        #else {
        #    print "    ... action $action\n";
        #}
        my $new_info_ref = execute_event($event, $object, $info_ref);
        next EVENT if ( ! defined $action or $action eq 'nop' );
        return if ( $action eq 'exit' );

        #print "Dans execute_events action = $action\n";
        #print "   ...ref de new_info_ref : ", ref( $new_info_ref ), "\n";
        if ( ! defined $new_info_ref or ! ref $new_info_ref ) {
            return;
        }
        if ( ref $new_info_ref eq 'ARRAY' ) {
            #print "Dans execute_events, saut détecté\n";
            return if ( $action ne 'jump' );
            my $label = $new_info_ref->[0];
            if ( ! defined $label ) {
                print STDERR "Undefined label in jump event\n";
                $label = q{};
            }
            return ( $new_info_ref->[1], $label );
        }
        if ( ref $new_info_ref ne 'HASH' ) {
            return;
        }            
        my @keys = keys %$info_ref;
        for my $key ( @keys ) {
            return if ( ! defined $new_info_ref->{$key} );
        }
        $info_ref = $new_info_ref;
    }
    return ( $info_ref, q{} );
}

sub execute_event {
    my ( $event_ref, $editor, $info_ref ) = @_;

    my $package = $event_ref->{'package'};
    my ( $sub, @user ) = @{$event_ref->{'sub'}};
    #print "EXECUTE_EVENT : PAckage $package, sub = $sub\n";
    my $action = $event_ref->{'action'};
    if ( ! defined $sub ) {
        if ( defined $action ) {
            return if ( $action eq 'exit' );
            if ( $action eq 'nop' ) {
                #print "Avant exécution d'une action nop pour ", $editor->name, "\n";
                thread_nop( $editor, $event_ref );
                return;
            }
        }
    }    
    my $thread = $event_ref->{'thread'};
    my $code = [ $event_ref->{'code'}, $event_ref->{'id'} ];
    if ( defined $thread ) {
        #print "Appel de thread execute avec thread = $thread\n";
        #if ( ! defined $action ) {
        #    print "1 Avant appel transform and execute pour thread : action = undef\n";
        #}
        #else {
        #    print "1 Avant appel transform and execute pour thread : action = $action\n";
        #}
        return thread_execute( $thread, $event_ref, $editor, $info_ref, $package, $sub, $code, @user );
    }
    else  {
        my $sync = $event_ref->{'sync'};
        if ( defined $sync and $sync eq 'false' ) {
            $event_ref->{'tid'} = 0;
            #print "Avant thread_execute pour tid = 0\n";
            #print "Avant appel thread_execute pour tid = 0 : editor = $editor\n";
            return thread_execute( $thread, $event_ref, $editor, $info_ref, $package, $sub, $code, @user );
        }
        #print "Dans execute event, avant appel transform... editor = $editor\n";
        my $answer = transform_and_execute( $editor, $info_ref, $package, $sub, $code, @user );
        #print "Dans execute_event ref de answer = ", ref( $answer ), "\n";
        return untransform( $answer, $action );
    }
}

sub thread_execute {
    my ( $thread, $event_ref, $object, $info_ref, $package, $sub, $code, @user ) = @_;

    my $tid = $event_ref->{'tid'};
    
    my $type = ref $object;
    my $id = '';
    if ( ref $object and $object->isa('Text::Editor::Easy') ) {
        $id = $object->id;
    }
    if ( ! defined $tid ) {
        if ( $thread ne 'File_manager' ) {
            print STDERR "Can't execute event : unknown tid for thread $thread\n";
            return;
        }
        else {
            $tid = Text::Editor::Easy::Comm::get_tid_from_name_and_instance( $id, 'File_manager' );
            #print "Récupéré le tid $tid pour le thread File_manager\n";
            # Utiliser l'interface dynamique pour modifier l'évènement... ?
        }
    }
    my $object_ref;
    if ( $id eq '' ) {
        $object_ref = [ $type, $object ];
    }
    else {
        $object_ref = [ 'Text::Editor::Easy', $id ];
    }
    
    my $sync = $event_ref->{'sync'};
    my $sub_name = 'Text::Editor::Easy::Events::thread_transform';
    my @param = ( $sub_name, $tid, $object_ref, $package, $sub, $info_ref, $event_ref->{'action'}, $code, @user );
    $sync = 'false' if ( ! defined $sync );
    if ( $sync eq 'true' ) {
        return Text::Editor::Easy->ask_thread( @param );
    }
    elsif ( $sync eq 'pseudo' ) {
        my $call_id = Text::Editor::Easy::Async->ask_thread( @param );
        while ( 'not_ended' ) {
            # Is there any task for me in the queue ?
            if ( Text::Editor::Easy::Comm::anything_for_me() ) {
                Text::Editor::Easy::Comm::have_task_done();
            }
            
            my $status = Text::Editor::Easy->async_status( $call_id );
            # Is the asynchronous call that I have asked for ended ?
            last if ( $status eq 'ended' );
        }
        return Text::Editor::Easy->async_response( $call_id );
    }
    else {
        #print "Appel en asynchrone pour tid = $tid\n";
        Text::Editor::Easy::Async->ask_thread( @param );        
    }        
}

sub thread_nop {
    my ( $editor, $event_ref ) = @_;
        
    my $tid = $event_ref->{'tid'};

    my $type = ref $editor;  
    my $id = '';
    if ( $type eq 'Text::Editor::Easy' ) {
        $id = $editor->id;
    }
    
    if ( ! defined $tid ) {
        if ( $event_ref->{'thread'} ne 'File_manager' ) {
            print STDERR "Can't execute event : unknown tid for thread $event_ref->{'thread'}\n";
            return;
        }
        else {
            $tid = Text::Editor::Easy::Comm::get_tid_from_name_and_instance( $id, 'File_manager' );
            #print "Récupéré le tid $tid pour le thread File_manager\n";
            # Utiliser l'interface dynamique pour modifier l'évènement... ?
        }
    }
    my $sub_name = 'Text::Editor::Easy::Events::nop';
    my @param = ( $sub_name, $tid );
    Text::Editor::Easy::Async->ask_thread( @param );
}

sub nop {
    my ( $self, $reference ) = @_;
    
    #print "Dans nop, thread = ", threads->tid, ", self = $self, reference = $reference\n";
    return;
}

sub thread_transform {
    my ( $self, $ref, $object_ref, $package, $sub, $info_ref, $action, $code, @user ) = @_;
    
    my $object;
    if ( $object_ref->[0] eq 'Text::Editor::Easy::Zone' ) {
        # Cas à gérer 
        # $object = $type -> get_from_id;  ==> $type eq 'Text::Editor::Easy' ou 'Text::Editor::Easy::Zone' ou '...Window' ou ...
        $object = $object_ref->[1];
    }
    else {
        $object = Text::Editor::Easy->get_from_id( $object_ref->[1] );
        #print "Dans thread_transform, récupération pour id ", $object_ref->[1], " de object = $object\n";
    }
    
    #print "Appel transform_and_execute pour tid = ", threads->tid, "\n";
    my $answer = transform_and_execute( $object, $info_ref, $package, $sub, $code, @user);
    return untransform( $answer, $action );
}

sub transform_and_execute {
    my ( $editor, $info_ref, $package, $sub, $code, @user ) = @_;

    KEY: for my $key ( keys %$info_ref ) {
        if ( $key eq 'line' ) {
            my $line = Text::Editor::Easy::Line->new( $editor, $info_ref->{'line'} );
            $info_ref->{'line'} = $line;
            next KEY;
        }
        if ( $key eq 'display' ) {
            my $display = Text::Editor::Easy::Display->new( $editor, $info_ref->{'display'} );
            $info_ref->{'display'} = $display;
            next KEY;
        }
        if ( $key =~ /editor$/ ) {
            my $value = $info_ref->{$key};
            if ( defined $value ) {
                my $editor = Text::Editor::Easy->get_from_id( $info_ref->{$key} );
                #print "Dans transform_and_execute, récupération de editor = $editor\n";
                $info_ref->{$key} = $editor;
            }
            next KEY;
        }
    }
    
    if ( defined $sub ) {
        no strict "refs";
        return &{"${package}::$sub"}( $editor, $info_ref, @user );
    }
    else {
        # A optimiser : récupérer la référene de sub dans le contexte du thread pour ne permettre qu'une seule évaluation
        my ( $string, $id ) = @$code;
        if ( ! defined $id ) {
            print "'Compilation' à la première exécution\n";
            $id = thread_eval(0,0, $string);
            return if ( ! defined $id ); # Erreur de 'compilation'
        }
        #print "Exécution avec id = $id\n";
        my $answer = eval {
            $sub_ref{$id}->( $editor, $info_ref, @user );
        };
        if ( $@ ) {
            print STDERR "Wrong 'execution' during evaluation of :\nsub { $code } :\n$@\n";
            return;
        }
        return $answer;
    }
}

sub untransform {
    my ( $info_ref, $action ) = @_;
    
    if ( ! defined $action or $action eq 'exit' ) {
        #print "Action non définie, retour vide\n";
        return;
    }
    my $hash_ref = $info_ref;
    my $jump = 0;
    if ( ref $info_ref eq 'ARRAY' ) {
        #print "Jump, dans untransform\n";
        $hash_ref = $info_ref->[1];
        $jump = 1;
    }
    if ( my $line = $hash_ref->{'line'} ) {
        $hash_ref->{'line'} = $line->ref;
    }
    if ( my $display = $hash_ref->{'display'} ) {
        $hash_ref->{'display'} = $display->ref;
    }
    if ( $jump ) {
        #print "Jump, retour d'une référence de tableau\n";
        return [ $info_ref->[0], $hash_ref ];
    }
    return $info_ref;
}

sub set_event {
    my ( $self, $name, $event_ref, $options_ref ) = @_;

    return if ( ! defined $name );
    
    my $id = '';
    if ( ref $self and ( ref $self eq 'Text::Editor::Easy'
    or ref $self eq 'Text::Editor::Easy::Async' ) ) {
        $id = $self->id;
    }
    else {
        if ( defined $event_ref and ref $event_ref eq 'HASH' ) {
            $event_ref->{'name'} = $name;
        }
        $event_ref = reference_event( $id, $event_ref )  if ( defined $event_ref );
        my $thread_ref =  Text::Editor::Easy->data_set_event( $self, $name, $event_ref, $options_ref );
        if ( $self eq 'Text::Editor::Easy::Async' or $self->isa('Text::Editor::Easy::Async') ) {
            return;
        }
        my $call_id = $thread_ref->{threads->tid};
        if ( $call_id ) {
            #print "Le thread ", threads->tid, " demande à lui-même de changer un évènement\n";
            while ( 'not_ended' ) {
                if ( Text::Editor::Easy::Comm::anything_for_me() ) {
                    Text::Editor::Easy::Comm::have_task_done();
                }
                my $async_status = Text::Editor::Easy->async_status( $call_id );
                last if ( $async_status eq 'ended' );
            }
        }
        # Tester ici la fin effective des autres threads ...
        
        return;
    }
    
    if ( defined $event_ref ) {
        if ( ref $event_ref eq 'HASH' ) {
            $event_ref->{'name'} = $name;
        }

        $event_ref = reference_event( $id, $event_ref );
    
        return if ( ! ref $event_ref );
    }
    
    #print "Dans set_event : self = $self, name = $name\n";
    
    # Référencement du nouvel évènement dans les thread qui en ont besoin
    Text::Editor::Easy->ask_thread( 'update_events', 0, [ $id ], $event_ref, $name );    
    Text::Editor::Easy->ask_thread( 'update_events', 2, [ $id ], $event_ref, $name );
}

sub set_events {
    my ( $self, $event_ref, $options_ref ) = @_;
 
    #print "Dans set_events : self = $self\n";
 
    my $id = '';
    # Pour l'instant, les méthodes 'set_event(s)' ne marchent pas avec les faux objets zone (méthode id non définie, plus d'autres choses à voir, ...)
    if ( ref $self ) {
        $id = $self->id;
    }
    else {
        $event_ref = reference_events( $id, $event_ref ) if ( defined $event_ref );
        my $thread_ref =  Text::Editor::Easy->data_set_events( $self, $event_ref, $options_ref );
        if ( $self eq 'Text::Editor::Easy::Async' or $self->isa('Text::Editor::Easy::Async') ) {
            return;
        }
        my $call_id = $thread_ref->{threads->tid};
        if ( $call_id ) {
            #print "Le thread ", threads->tid, " demande à lui-même de changer des évènements\n";
            while ( 'not_ended' ) {
                if ( Text::Editor::Easy::Comm::anything_for_me() ) {
                    Text::Editor::Easy::Comm::have_task_done();
                }
                my $async_status = Text::Editor::Easy->async_status( $call_id );
                last if ( $async_status eq 'ended' );
            }
        }
        # Tester ici la fin effective des autres threads ...
        
        return;
    }

    if ( defined $event_ref ) {
        $event_ref = reference_events( $id, $event_ref );
        
        return if ( ! ref $event_ref );
    }
    
    # Référencement du nouvel évènement dans les thread qui en ont besoin
    Text::Editor::Easy->ask_thread( 'update_events', 0, [ $id ], $event_ref );
    Text::Editor::Easy->ask_thread( 'update_events', 2, [ $id ], $event_ref );
}


=head1 COPYRIGHT & LICENSE

Copyright 2008 - 2009 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut


1;















