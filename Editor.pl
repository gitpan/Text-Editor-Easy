#!/usr/bin/perl
use lib 'lib';

use warnings;
use strict;

=head1 NAME

Editor.pl - An editor written using Text::Editor::Easy module.

=head1 VERSION

Version 0.2

=cut

use Text::Editor::Easy;

use IO::File;

if ( ! -d "tmp" ) {
	print STDERR "Need a \"tmp\" directory under your current directory to be executed...\n";
	exit 1;
}

# Start of launching perl process (F5 key management)
open EXEC, "| perl exec.pl" or die "Fork impossible\n";
autoflush EXEC;

# Main tab "zone", area of the main window (syntax re-used : 'place' of Tk)
my $zone4 = Text::Editor::Easy::Zone->new(
    {
        '-x'        => 0,
        '-rely'     => 0,
        '-relwidth' => 1,
        '-height'   => 25,
        'name'      => 'zone4',
        'trace' => {
            'all' => 'tmp/',

            #	'Text::Editor::Easy::Data' => undef,
            # 	'Text::Editor::Easy::Data' => 'tmp/',
            'trace_print' => 'full',
        },
    }
);

# List of main tab files (loading delayed)
my @files_session;
for my $demo ( 1 .. 10 ) {
    my $file_name = "demo${demo}.pl";
    push @files_session,
      {
        'zone'      => 'zone1',
        'file'      => $file_name,
        'name'      => $file_name,
        'highlight' => {
            'use'     => 'Text::Editor::Easy::Syntax::Perl_glue',
            'package' => 'Text::Editor::Easy::Syntax::Perl_glue',
            'sub'     => 'syntax',
        },
      };
}

# Main tab
Text::Editor::Easy->new(
    {
        'zone'        => $zone4,
        'sub'         => 'main', # Program "Editor.pl" will go on with another thread (sub "main" executed)
        'motion_last' => {
            'use'     => 'Text::Editor::Easy::Program::Tab',
            'package' => 'Text::Editor::Easy::Program::Tab',
            'sub'     => 'motion_over_tab',
            'mode'    => 'async',
        },
        'save_info' => {
            'file_list' => \@files_session,
            'color'     => 'yellow',
        },

    }
);

# In thread 0, the graphical MainLoop is over

# End of launching perl process (F5 key management)
print EXEC "quit\n";
close EXEC; # This should be enough to stop process "exec.pl"
# End of Editor.pl

sub main {
    my ( $onglet, @parm ) = @_;

    my $out_tab_zone = Text::Editor::Easy::Zone->new(
        {
            '-relx'     => 0.5,
            '-y'        => 25,
            '-relwidth' => 0.5,
            '-height'   => 25,
            'name'      => 'out_tab_zone',
        }
    );

    my $out_tab = Text::Editor::Easy->new(
        {
            'zone'        => $out_tab_zone,
            'motion_last' => {
                'use'     => 'Text::Editor::Easy::Program::Tab',
                'package' => 'Text::Editor::Easy::Program::Tab',
                'sub'     => 'motion_over_tab',
                'mode'    => 'async',
            },
            'save_info' => { 'color' => 'green', },
        }
    );
    my $zone1 = Text::Editor::Easy::Zone->new(
        {
            '-x'                   => 0,
            '-y'                   => 25,
            '-relwidth'            => 0.5,
            '-relheight'           => 0.7,
            '-height'              => -25,
            'name'                 => 'zone1',
            'on_top_editor_change' => {
                'use'     => 'Text::Editor::Easy::Program::Tab',
                'package' => 'Text::Editor::Easy::Program::Tab',
                'sub'     => [ 'on_main_editor_change', $onglet->get_ref ],
            }
        }
    );
    Text::Editor::Easy->new(
        {
            'zone'      => $zone1,
            'file'      => 'demo1.pl',
            'highlight' => {
                'use'     => 'Text::Editor::Easy::Syntax::Perl_glue',
                'package' => 'Text::Editor::Easy::Syntax::Perl_glue',
                'sub'     => 'syntax',
            },
        }
    );

    Text::Editor::Easy->bind_key(
        { 'package' => 'main', 'sub' => 'launch', 'key' => 'F5' } );

    # Zone des display
    my $zone2 = Text::Editor::Easy::Zone->new(
        {
            '-relx'                => 0.5,
            '-y'                   => 50,
            '-relwidth'            => 0.5,
            '-relheight'           => 0.7,
            '-height'              => -50,
            'name'                 => 'zone2',
            'on_top_editor_change' => {
                'use'     => 'Text::Editor::Easy::Program::Tab',
                'package' => 'Text::Editor::Easy::Program::Tab',
                'sub'     => [ 'on_top_editor_change', $out_tab->get_ref ],
            }
        }
    );

    # Zone des appels de display, traces
    my $zone3 = Text::Editor::Easy::Zone->new(
        {
            '-relx'      => 0.5,
            '-rely'      => 0.7,
            '-relwidth'  => 0.5,
            '-relheight' => 0.3,
            'name'       => 'zone3',
        }
    );
    my $who = Text::Editor::Easy->new(
        {
            'zone'        => $zone3,
            'name'        => 'stack_calls',
            'motion_last' => {
                'use'     => 'Text::Editor::Easy::Motion',
                'package' => 'Text::Editor::Easy::Motion',
                'sub'     => 'cursor_set_on_who_file',
                'mode'    => 'async',

               #'only' => '$origin eq "graphic" or $sub_origin eq "cursor_set"',
                'init' => [ 'init_set', $zone1 ]
            },
        }
    );
    use File::Basename;
    my $name  = fileparse($0);
    my $out_1 = Text::Editor::Easy->new(
        {
            'zone'         => $zone2,
            'file'         => "tmp/${name}_trace.trc",
            'name'         => 'Editor_out',
            'growing_file' => 1,
            'motion_last'  => {
                'use'     => 'Text::Editor::Easy::Motion',
                'package' => 'Text::Editor::Easy::Motion',
                'sub'     => 'move_over_out_editor',
                'mode'    => 'async',
                'init'    => [ 'init_move', $who->get_ref, $zone1 ],
            },
        }
    );
    my $out = Text::Editor::Easy->new(
        {
            'zone' => $zone2,
            'name' => 'Eval_out',
        }
    );

    my $zone5 = Text::Editor::Easy::Zone->new(
        {
            '-x'         => 0,
            '-rely'      => 0.7,
            '-relwidth'  => 0.5,
            '-relheight' => 0.3,
            'name'       => 'zone5',
        }
    );
    my $macro = Text::Editor::Easy->new(
        {
            'zone'        => $zone5,
			'name'        => 'macro',
            'change_last' => {
                'use'     => 'Text::Editor::Easy::Program::Search',
                'package' => 'Text::Editor::Easy::Program::Search',
                'sub'     => 'modify_pattern',
                'mode'    => 'async',
                'only'    => '$origin eq "graphic"',
                'init'    => [ 'init_eval', $out->get_ref ],
            },
            'highlight' => {
                'use'     => 'Text::Editor::Easy::Syntax::Perl_glue',
                'package' => 'Text::Editor::Easy::Syntax::Perl_glue',
                'sub'     => 'syntax',
            },
        }
    );
}

sub launch {

    # Appui sur F5
    my ($self) = @_;

    my $file_name = $self->file_name;
    #print "In sub 'launch' : $self|$file_name\n";
    if (   $file_name eq 'demo7.pl'
        or $file_name eq 'demo8.pl'
        or $file_name eq 'demo9.pl'
        or $file_name eq 'demo10.pl' )
    {
        my $macro_instructions;
        if ( $file_name eq 'demo7.pl' ) {
            $macro_instructions = << 'END_PROGRAM';
my $editor = Text::Editor::Easy->whose_name('stack_calls');
$editor->empty;
$editor->deselect;
my @lines = $editor->insert("Hello world !\nIs there anybody ? body dy dy y ...");
print "\nWritten lines :\n\t", join ("\n\t", @lines), "\n";
$editor->insert ("\n\n\n\n" . $lines[0]->text);
my $next = $lines[0]->next;
print "\nNEXT LINE =\n\n", $next->text;
$next->select;
END_PROGRAM
        }
        elsif ( $file_name eq 'demo8.pl' ) {
            $macro_instructions = << 'END_PROGRAM';
my $editor = Text::Editor::Easy->whose_name('stack_calls');
$editor->add_method('demo8');
print $editor->demo8(4, "bof");
END_PROGRAM
        }
        elsif ( $file_name eq 'demo9.pl' ) {
            $macro_instructions = << 'END_PROGRAM';
my $editor = Text::Editor::Easy->whose_name('Key.pm');
if ( ! $editor ) { $editor = Text::Editor::Easy->new({ 'zone' => 'zone1', 'file' => "lib/Text/Editor/Easy/Key.pm", 'highlight' => { 'use' => 'Text::Editor::Easy::Syntax::Perl_glue', 'package' => 'Text::Editor::Easy::Syntax::Perl_glue', 'sub' => 'syntax', },});};
$editor->focus;

print "Incomplete list of zones (names will be changed) :\n";
for ( sort Text::Editor::Easy::Zone->list ) {
    print "\t$_\n";
}
END_PROGRAM
        }
        else {    # demo10.pl
            $macro_instructions = << 'END_PROGRAM';
my $editor = Text::Editor::Easy->whose_name('demo10.pl');
my $exp = qr/e.+s/;
my ( $line, $start, $end, $regexp ) = $editor->search($exp);
$editor->deselect;
return if ( ! defined $line );
$line->select($start, $end);
$editor->visual_search( $regexp, $line, $end);
END_PROGRAM

            my $editor = Text::Editor::Easy->whose_name('stack_calls');
			$editor->empty;
			my @exp = ( 
			    'qr/e.+s/', 
				'qr/e.+?s/', 
				'\'is\'', 
				'qr/\\bis\\b/', 
				'qr/F.*n/', 
				'qr/F.*n/i', 
				'qr/f[er]+[^e]+/'
		    );
			for ( @exp ) {
					$editor->insert( "$_\n");
			}
			my $first = $editor->number(1);
			$first->select;
			$editor->cursor->set( 0, $first);
            $self->bind_key({ 'package' => 'main', 'sub' => 'up_demo10', 'key' => 'Up' } );
            $self->bind_key({ 'package' => 'main', 'sub' => 'down_demo10', 'key' => 'Down' } );
        }
        my $eval_editor = Text::Editor::Easy->whose_name( 'macro' );
        $eval_editor->empty;
        $eval_editor->insert($macro_instructions);
        return;
    }
    if ( defined $file_name ) {
        #print "fichier $file_name\n";
        print EXEC
"$file_name|start|perl -Ilib -MText::Editor::Easy::Program::Flush $file_name\n";
    }
}

sub demo8 {
    my $editor = Text::Editor::Easy->whose_name('demo8.pl');
    Text::Editor::Easy->substitute_eval_with_file('demo8.pl');

    my $sub_ref = eval $editor->slurp;
    return $sub_ref->(@_);

    #print "End of execution\n";
}

sub up_demo10 {
    my $editor = Text::Editor::Easy->whose_name('stack_calls');
    my ( $line ) = $editor->cursor->get;
	#print "Dans up_demo10 : trouvé $line | ", $line->text, "\n";
	if ( my $previous = $line->previous ) {
		$editor->deselect;
		my $exp = $previous->select;
		$editor->cursor->set(0, $previous);
		new_search ( $exp );
    }
}

sub down_demo10 {
    my $editor = Text::Editor::Easy->whose_name('stack_calls');
    my ( $line ) = $editor->cursor->get;
	#print "Dans down_demo10 : trouvé $line | ", $line->text, "\n";
	if ( my $next = $line->next ) {
		$editor->deselect;
		my $exp = $next->select;
		$editor->cursor->set(0, $next);
		new_search ( $exp );
    }
}

sub new_search {
    my ( $exp ) = @_;

    my $macro_ed = Text::Editor::Easy->whose_name('macro');
	
	# Hoping the automatic inserted lines are still there and in the right order !
	# ==> the line number 2 or the macro editor will be set to "my \$exp = $exp;" and this will cause
	# new execution of the macro instructions
	$macro_ed->number(2)->set("my \$exp = $exp;");
}


=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

