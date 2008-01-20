use strict;

use IO::File;

autoflush STDIN;
autoflush STDOUT;

my %file_desc;
my %pid;

while ( my $command = <STDIN> ) {
    print "COMMAND reçue $command\n";
    chomp $command;

    #exit if ( $command eq 'quit' );
    exit if ( $command eq "quit" );

    my ( $file_name, $action, $data ) = split( /\|/, $command );
    print "Avant Fork\n";
    if ( $action eq 'start' ) {
        if ( my $pid = $pid{$file_name} ) {
            if ( kill 0, $pid ) {
                kill 9, $pid;
            }
        }
        $pid{$file_name} = open $file_desc{$file_name}, "| $data";
    }
    elsif ( $action eq 'stop' ) {
        if ( my $pid = $pid{$file_name} ) {
            if ( kill 0, $pid ) {
                kill 9, $pid;
            }
        }
    }

    # Send action here (to send data from Editor to STDIN of launched process)
}

