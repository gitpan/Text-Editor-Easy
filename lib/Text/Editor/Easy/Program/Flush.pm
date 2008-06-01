package Text::Editor::Easy::Program::Flush;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Program::Flush - STDOUT and SDTERR redirection when launching a new application from "Editor.pl" program.

=head1 VERSION

Version 0.3

=cut

our $VERSION = '0.3';

use IO::File;
use File::Basename;
my $name = fileparse($0);
my $info = "tmp/${name}_Flush.info";
open( INFO, ">$info", ) or die "Impossible d'ouvrir $info : $!\n";
autoflush INFO;

use threads;
use threads::shared;
my $seek : shared;

sub TIEHANDLE {
    my ( $classe, $chemin, $type ) = @_;

    my $array_ref;
    open( my $hf, ">>$chemin" ) or die "Impossible de lier $chemin\n";
    $array_ref->[0] = $hf;
    autoflush $hf;
    $array_ref->[1] = $type;
    $seek = 0;
    bless $array_ref, $classe;
}

sub PRINT {
    my $self = shift;
    my $hf   = $self->[0];

    lock($seek)
      ;    # Ecriture sur STDOUT ou STDERR mono_thread (sinon gros bazard !)
    my $depart = tell($hf);
    print INFO $seek, '|', $self->[1], '|';
    my @lines;
    my $indice = 0;
    while ( my ( $pack, $file, $line ) = caller( $indice++ ) ) {
        push @lines, "\t$pack|$file|$line\n";
    }
    my $ok     = print $hf @_;
    my $length = tell($hf) - $depart;
    $seek += $length;

    #print INFO $seek, @_, "\n", @lines;
    print INFO $seek, "\n", @lines;
    return $ok;
}

package main;

my $own_STDOUT = "tmp/${name}_trace.trc";
unlink($own_STDOUT);
tie *STDOUT, "Text::Editor::Easy::Program::Flush", ( $own_STDOUT, 'STDOUT' );
tie *STDERR, "Text::Editor::Easy::Program::Flush", ( $own_STDOUT, 'STDERR' );

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
