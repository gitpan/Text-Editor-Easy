#
# Here is an example of
# Editor object creation with
# a way to make actions on it
# (a new "client thread" have been
# created to execute your sub).
#
# The first argument of the sub is
# the newly created Editor object.
#
# "Editor->manage_event" is called
# internally (by the initial thread).
#
# To execute it, still press F5 and
# wait a few seconds for actions
# to be performed...
#

use lib '.';

use Editor;

Editor->new(
    {
        'sub'      => 'main',    # Sub for action
        'x_offset' => 60,
        'y_offset' => 170,
        'width'    => 500,
        'height'   => 300,
    }
);

print "The user have closed the window\n";

sub main {
    my ($editor) = @_;

    # You can now act on the Editor object with your program and
    # the user can edit things too !
    # Dangerous, isn't it ?

    $editor->focus;    # To see the cursor position, not mandatory
    $editor->insert("\$editor = $editor\n");
    $editor->insert("Second line if user is slower than me\n");
    $editor->insert("\nother line ...\n\nother line");

    my $line = $editor->number(4);
    $line->select( 1, 5 );
    sleep 3;

    $editor->cursor->set( 3, $line );
    $editor->deselect;
    sleep 2;

    $editor->insert( $line->text . " : copied\n" );
    sleep 2;

    $editor->erase(3);
    $editor->save("Uninteresting_data.txt");
}
