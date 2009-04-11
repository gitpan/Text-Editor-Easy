BEGIN {
  use Config;
  if (! $Config{'useithreads'}) {
      print("1..0 # Skipped: Perl not compiled with 'useithreads'\n");
      exit(0);
  }
}

use strict;

use lib '../lib';
use Text::Editor::Easy;
use Text::Editor::Easy::Comm;

my $editor = Text::Editor::Easy->new({
    #'trace' => {
    #    'all' => 'tmp/',
    #    'trace_print' => 'full',
    #},

    #'sub' => 'main',
    
	'bloc' => "use Text::Editor::Easy::Comm;\nmy \$editor = Text::Editor::Easy->new\n",
	'focus' => 'yes',
    'events' => {
        'any_hard_clic' => {              # hard_clic for any meta key combination
                'sub' => 'my_hard_clic_sub',
				'action' => 'change',
				'thread' => 'Graphic',
				'create' => 'warning',
				'init' => [ 'main::init_any_hard', "Bonjour" ],
        },    
        'hard_clic' => [
		    { 
                'sub' => 'first_clic',
				'action' => 'jump',
				'thread' => 'Fil_managerf',
				'sync' => 'true',
				'create' => 'warning',
            },
		    { 
                'sub' => 'second_clic',
				'thread' => 'Fil_manager',
				#'sync' => 'false',
				'create' => 'warning',
            },
        ],
		'drag' => {
				'sub' => 'drag',
		},
        'cursor_set' => {
            'sub' => 'cursor_set',
        }
    }
});

#sub main {

#   my ( $editor ) = @_;

use Test::More qw( no_plan );

is ( ref($editor), "Text::Editor::Easy", "Object type");

print "EDITOR height = ", $editor->height, "\n";

$editor->clic( {
    'x' => 1,
    'y' => 1, 
    'meta_hash' => {}, 
    'meta' => 'ctrl_',
});

# 'Graphic' thread is the current client thread and not a server one (manage_event not called ) :
# have to make server actions 'manually'
while ( anything_for_me ) {
    have_task_done;
}


#}  # For interactive test ('sub' => 'main')

use Data::Dump qw(dump);

sub first_clic {
    my ( $editor, $options_ref ) = @_;

    print "Dans first_clic : editor = $editor\n";
	print "  options_ref =>\n", dump($options_ref), "\n";
	$options_ref->{'x'} -= 50;
	my $y = $options_ref->{'y'};
	if ( $y > 20 ) {
        # jump
        return [ 'hard_clic', $options_ref ];
    }
	else {
        # Change
	    return $options_ref;
    }
}

sub second_clic {
    my ( $editor, $options_ref ) = @_;

    print "Dans second_clic : editor = $editor\n";
	print "  options_ref =>\n", dump($options_ref), "\n";
	#$editor->first->set('Hello !');
}

sub my_hard_clic_sub {
     my ( $editor, $info_ref ) = @_;

     print "Dans my_hard_clic_sub...\n";
     if ( $info_ref->{'x'} < ( $editor->width / 2 ) ) {
         print "   ...pas de changement\n";
         return $info_ref;                               # no jump, values unchanged
     }
	 print "   ... saut à clic, height = ", $editor->height, "\n";
	 print "   ==> nouvelle valeur",  int( 20 * $info_ref->{'y'} / $editor->height ), "\n";
     my %new_info = ( 
         'line' => $editor->first,
         'pos'  => int( 20 * $info_ref->{'y'} / $editor->height ),
		 'meta' => $info_ref->{'meta'},
		 'meta_hash' => $info_ref->{'meta_hash'},
     );
     return [ 'clic', \%new_info ];                      # jump to 'clic' label, providing the hash required
}

sub init_any_hard {
		my ( undef, $reference, $text ) = @_;
		
		print "Dans init_any_hard : $reference, $text\n";
}

sub cursor_set {
    print "Bonjour de la part de cursor_set\n";
}