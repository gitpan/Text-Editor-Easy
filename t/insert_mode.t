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
my $editor = Text::Editor::Easy->new;
		
use Test::More qw( no_plan );
is ( ref($editor), "Text::Editor::Easy", "Object type");

$editor->set_insert;
my $mode = $editor->insert_mode;
is ( $mode, 1, "Set insert mode");

$editor->insert('efghij');
$editor->cursor->set(0);
$editor->insert('abcd');
my $text = $editor->first->text;
is ( $text, 'abcdefghij', "Insertion");

$editor->set_replace;
$mode = $editor->insert_mode;
is ( $mode, 0, "Set replace mode");

$editor->insert('kl');
$text = $editor->first->text;
is ( $text, 'abcdklghij', "Replacement");

my $editor2 = Text::Editor::Easy->new;

$editor2->set_insert;
$mode = $editor2->insert_mode;
is ( $mode, 1, "Set insert mode");

$editor2->insert('efghij');
$editor2->cursor->set(0);
$editor2->insert('abcd');
$text = $editor2->first->text;
is ( $text, 'abcdefghij', "Insertion");

$editor2->set_replace;
$mode = $editor2->insert_mode;
is ( $mode, 0, "Set replace mode");

$editor2->insert('kl');
$text = $editor2->first->text;
is ( $text, 'abcdklghij', "Replacement");
