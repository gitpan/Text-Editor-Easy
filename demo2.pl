#
# Here is an example of
# "one thread" Text::Editor::Easy object creation
#
# Once "Text::Editor::Easy->manage_event" is
# called, the program is pending
# on this instruction
# until the user quit the window.
#
# To execute it, press F5 :
# a window will open and you
# will be able to ... edit text.
# Quite standard for an editor.

use strict;
use lib 'lib';

use Text::Editor::Easy;

Text::Editor::Easy->new(
    {
        'x_offset' => 240,
        'y_offset' => 150,
        'width'    => 300,
        'height'   => 300,
        'focus'    => 'yes',
    }
);

Text::Editor::Easy->manage_event;

print "The user have closed the window\n";

# Even for this simple example, there is
# in fact more than one thread
# created. Still, the program seems
# to dispose of none.
#
