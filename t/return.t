BEGIN {
  use Config;
  if (! $Config{'useithreads'}) {
      print("1..0 # Skip: Perl not compiled with 'useithreads'\n");
      exit(0);
  }
  if (! -f 'tk_is_ok' ) {
      print("1..0 # Skip: Tk can't work : graphical environment is out ?\n");
      exit(0);
  }
}

use strict;

use lib '../lib';
use Text::Editor::Easy;

Text::Editor::Easy->new({
    'sub' => 'main',
});

sub main {
		my ( $editor ) = @_;
		

        use Test::More qw( no_plan );
		is ( ref($editor), 'Text::Editor::Easy', 'Object type');

		my $text = "Returns in end of test file\n\n\n";
		$editor->insert($text);
		$editor->save('return_saved.txt');	
		if ( ! open ( FIL,  'return_saved.txt' ) ) {
		    is ( 1, 0, 'Save or re-open unsuccessful, skip other tests...' );
            Text::Editor::Easy->exit(0);
	    }
		is ( 1, 1, 'Text::Editor::Easy->save' );

		my $saved;
		my $number = read FIL, $saved, 100;
		if ( ! defined $number ) {
		    is ( 1, 0, 'Read unsuccessful, skip other tests...' );
            Text::Editor::Easy->exit(0);
	    }
        is ( 1, 1, 'Perl read' );

        is ( $saved, $text, 'Saving file with returns at end' );
		
		use File::Copy;
		copy ( 'return_saved.txt', 'return_to_open.txt' );
		my $editor2 = Text::Editor::Easy->new({
            'file' => 'return_to_open.txt',
        });

		is ( $editor2->slurp, $text, 'Opening file with returns at end');
		$editor2->close;
        unlink ( 'return_to_open.txt' );
        Text::Editor::Easy->exit(0);
}
