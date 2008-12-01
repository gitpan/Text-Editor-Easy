package Text::Editor::Easy::Events;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Events - Manage asynchronous events linked to user code : specific code is referenced and called here.

=head1 VERSION

Version 0.43

=cut

our $VERSION = '0.43';

=head1 SYNCHRONOUS AND ASYNCHRONOUS, WARNINGS

There are actually 2 global threads used to execute your special code when events occur : the graphic thread (with tid 0) and another one, which is called the
"Motion" thread. The graphic thread is synchronous, that is the code of your event will block the user interface : you should not use it for heavy
task. The "Motion" thread is asynchronous : the graphic thread still receive the initial event (you can't change that !) but as soon as enough
information has been collected, the "Motion" thread is called asynchronously by the graphic thread (the graphic thread won't wait for the "Motion"
thread response). And here, if you make a heavy task, the user interface won't be blocked.

Still, with the "Motion" thread, you should work in an interruptible way rather than make a huge task at once. Why ? Because the principle of
events is that you can't know when they arrive and how many. Suppose your code responds to the mouse motion event : when the user
moves his mouse from left to right of your editor, you can have more than 10 mouse motion events generated in one second. And a perfect
response to the first event can be useless as soon as the second event has arrived. Moreover, the graphic thread will send all asynchronous events
to the "Motion" thread, even if the "Motion" thread is busy working. Events will stack in a queue if the "Motion" thread can't manage them
quickly. If your code makes, in the end, a graphic action visible by the user, there could be a long delay between the event and the visible action.
And the user would consider your code as very slow. On the contrary, if you work in an interruptible way, that is, if you insert, from time to time,
little code like that :

    return if (anything_for_me); # "me" stands for the "Motion" thread executing your code

the user could have the feeling that your code is very fast. But you should add this line (that is, check your thread queue) when you are in a proper
state : just imagine that there is really something for you and that your code will be stopped and executed another time from the start.

The conclusion is :  "A good way to be fast is to give up useless tasks" and using more than one thread allows you to give up, so don't hesitate
to give up. This is the very power of multi-threaded applications : the ability to make huge tasks while remaining responsive. This does not mean
that programmers can still be worse than they are now (me included !) : they have to know where to interrupt.

=head1 EVENT LIST

=head2 Event "cursor_set_last"
=head2 Event "motion_last"
=head2 Event "shift_motion_last"
=head2 Event "alt_motion_last"
=head2 Event "ctrl_motion_last"
=head2 Event "b1_motion_last"
=head2 Event "on_top_last"
=head2 Event "insert_last"
=head2 Event "change_last"
=head2 Event "clic_last"

=cut

use threads;
use Text::Editor::Easy::Comm;
use Devel::Size qw(size total_size);

my %ref_init;
my %referenced;

use constant {
    SUB_REF => 0,
    PACKAGE => 1, 
    MODULE => 2,
};

sub reference_event {
    my ( $self, $event, $unique_ref, $options_ref ) = @_;

    my $module = $options_ref->{'use'} || 'main';
    eval "use $module";
	if ( $@ ) {
		print STDERR "Wrong evaluation of module $module : $@\n";
    }
	my $package = $options_ref->{'package'} || $module;
	
    my $init_ref = $options_ref->{'init'};

    if ( defined $init_ref ) {
        my ( $sub, @param ) = @$init_ref;

        $ref_init{$event}{$unique_ref}[SUB_REF] = eval "\\&$package::$sub";
		$ref_init{$event}{$unique_ref}[MODULE] = $module;
		$ref_init{$event}{$unique_ref}[PACKAGE] = $package;
		$ref_init{$event}{$unique_ref}[SUB] = $sub;

        Text::Editor::Easy::Async->ask_thread( "$package::$sub",
            threads->tid, $unique_ref, @param );
    }
    $referenced{$event}{$unique_ref} =
      eval "\\&$motion_ref->{package}::$motion_ref->{sub}";
}

sub manage_events {
    my ( $self, $event, $unique_ref, $hash_ref, @param ) = @_;

    my $event_ref = $referenced{$event};
    if ( $event_ref ) {
        #print "Evènement $event référencé size ", total_size($self), "\n";
		my $sub_ref = $event_ref->{$unique_ref};
        if ( !defined $sub_ref ) {
            print STDERR "Event $event has not been referenced for Editor $unique_ref\n";
            return;
        }

        #print "OK ===> $event référencé pour $unique_ref\n";
        my $editor = $self->{$unique_ref};
        if ( !defined $editor ) {
            $editor = bless \do { my $anonymous_scalar }, "Text::Editor::Easy";
            Text::Editor::Easy::Comm::set_ref( $editor, $unique_ref);
            $self->{$unique_ref} = $editor;
        }
        $editor->transform_hash( undef, $hash_ref );
        $sub_ref->( $editor, $hash_ref, @param );
    }
}


=head1 FUNCTIONS

=head2 reference_event

=head2 init

=head2 init_move

=head2 init_set

=head2 manage_events

=head2 move_over_out_editor

=head2 reference_event

=cut

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut


1;



