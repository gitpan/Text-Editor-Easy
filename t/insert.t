use Test::More;
use Config;
BEGIN {
    if ( ! $Config{'useithreads'} ) {
        plan skip_all => "Perl not compiled with 'useithreads'";
    }
    elsif ( ! -f 'tk_is_ok' ) {
        plan skip_all => "Tk is not working properly on this machine";
    }
    else {
        plan no_plan;
    }
}

use strict;

use lib '../lib';
use Text::Editor::Easy;

my $editor = Text::Editor::Easy->new({
    'highlight' => {
	          'use' => 'Text::Editor::Easy::Syntax::Perl_glue',
		      'package' => 'Text::Editor::Easy::Syntax::Perl_glue',
		      'sub' => 'syntax',
		     },	
});

print "DANS THREAD : ", threads->tid, "\n";
is ( ref($editor), "Text::Editor::Easy", "Object type");

my $program = << 'END_PROGRAM'; 
my $file = $ARGV[0] || "Basic.pm";
# Bof
open ( PRO, $file) or die "Impossible d'ouvrir $file\n";
# Re bof
my %sub;

while (<PRO>) {
    if (/^\s*package /) {
        print "\n$_";
        next1;
    }
    if (/^\s*sub (.*) {\s*$/) {
        $sub{$1} = 0;
        next2;
    }
}
print "\n\n";
close PRO;
# ligne tr�s tr�s longue----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------milieu de la ligne tr�s longue----------------------------------------------------------fin de la ligne tr�s tr�s longue
open ( PRO, $file) or die "2 : Impossible d'ouvrir $file\n";
while (<PRO>) {
    for my $sub ( keys %sub ) {
        if (/$sub\s*\(/) {
            $sub{$sub} += 1;
        }
    }
}
my $indice = 1;
for ( sort keys %sub ) {
    printf "%0.3u %40s : %d\n", $indice++, $_, $sub{$_};
}
END_PROGRAM

chomp $program; # Due to split that ignore trailing...
my @program = split (/\n/, $program);

my ( @ref ) = $editor->insert( $program );
#my ( @ref ) = $editor->insert( $program[0] );
is ( scalar(@ref), scalar(@program), "Number of modified/inserted lines");

# We have here every reference of the lines in @ref, and, as we started from
# an empty file, the line number "x" will just be accessed by its $ref[x]
my $text;

my $max_length = 0;
my $indice_of_max;
for my $line ( 1..scalar(@program) ) {
$text = $ref[$line-1]->text;
is ( $text, $program[$line-1], "Text of the line $line");
if ( length($text) > $max_length ) {
		$max_length = length($text);
		$indice_of_max = $line - 1;
		print "Indice $indice_of_max => longueur $max_length\n";
}
}

my $file = 'test_filename_9753124680.pl';
unlink $file;
$editor->save($file);

my $return = open ( FIL, $file );
is ( $return, 1, "Open of file generated by the editor");

if ( $return ) {
	my $indice = 0;
	while ( my $line = <FIL> ) {
		chomp $line;
		$text = $ref[$indice]->text;
		$indice += 1;
		is ( $text, $line, "Text on the line $indice of the generated file" ) 
	}
}
# Working and deleting the longuest line of the file
if ( $max_length > 10 ) {
$ref[$indice_of_max]->display;
#print "Texte de la ligne la plus longue : ", $ref[$indice_of_max]->text, "\n";
$editor->cursor->set( 0, $ref[$indice_of_max]);
$editor->erase(4);

$text = $ref[$indice_of_max]->text;
is ( $text, substr ( $program[$indice_of_max], 4), "Text of the longuest line after first truncature");		

# Test of replacement option of insert
$editor->insert( "HERE ", { 'replace' => 1 } );		sleep 0;
$text = $ref[$indice_of_max]->text;
is ( $text, "HERE " . substr ( $program[$indice_of_max], 9), "Text of the longuest line after replacement");

$editor->insert( "INSERTED", { 'replace' => 0 } );		sleep 0;
$text = $ref[$indice_of_max]->text;
is ( $text, "HERE INSERTED" . substr ( $program[$indice_of_max], 9), "Text of the longuest line after insertion");

$editor->erase( $max_length - 9 );		sleep 0;
$text = $ref[$indice_of_max]->text;
is ( $text, "HERE INSERTED", "Text of the longuest line after second troncature");

# Line suppression (voir option auto_indent pour changement de comportement)
if ( $#program > $indice_of_max ) {
	$editor->erase( 1 );		sleep 0;
	$text = $ref[$indice_of_max]->text;
	is ( $text, "HERE INSERTED" . $program[$indice_of_max + 1], "Line concatenation");
}
}
$editor->close;
close FIL;
if ( ! unlink $file ) {
print STDERR "Can't remove file $file : $!\n";
}
