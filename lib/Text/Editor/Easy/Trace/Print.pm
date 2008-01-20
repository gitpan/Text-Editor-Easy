# Ce thread génère le fichier d'info et le hachage permettant d'y accéder rapidement
# Ce fichier d'info contient :
#   La liste des print (thread, liste d'appels ayant générée ce print, heure)
#   La liste des calls de méthodes inter-thread (call_id, méthode, liste d'appels ayant générée cet appel de méthode, heure, paramètres d'appels ?)
#   La liste des débuts de réponse (call_id)
#   La liste des fins de réponse (call_id, paramètres de retour ?)

package Easy::Trace::Print;
use strict;

#use Easy::Comm;
use Comm;
use Fcntl;
use SDBM_File;

use Devel::Size qw(size total_size);
use IO::File;
use File::Basename;
my $name        = fileparse($0);
my $trace_print = "tmp/${name}_Trace_Print.trc";
open( DBG, ">$trace_print" ) or die "Impossible d'ouvrir $trace_print : $!\n";
autoflush DBG;

use constant {

    #------------------------------------
    # LEVEL 1 : $self->[???]
    #------------------------------------
    HASH      => 0,
    OUT_NAME  => 1,
    INFO_DESC => 2,
    DBG_DESC  => 3,
};

sub init_trace_print {
    my ( $self, $file_name ) = @_;

# Faire de même avec le fichier info. Référencer également
# le nom initial du fichier STDOUT (pour analyse : ouverture et réouverture régulières dans full_trace)
#$self = 'Bidon';
    print DBG "Dans init_trace_print ", total_size($self), " : $file_name\n";
    my %h;

    # Ménage de l'ancien
    my $suppressed = unlink( $file_name . '.pag', $file_name . '.dir' );
    tie( %h, 'SDBM_File', $file_name, O_RDWR | O_CREAT, 0666 )
      or die "Couldn't tie SDBM file $file_name: $!; aborting";
    $self->[HASH]     = \%h;
    $self->[OUT_NAME] = $file_name;
    use IO::File;
    open( $self->[INFO_DESC], ">${file_name}.info" )
      or print DBG "Ouverture Info impossible\n";
    autoflush { $self->[INFO_DESC] };
}

sub trace_full {
    my ( $self, $seek_start, $seek_end, $tid, $call_id, $calls_dump, $data ) =
      @_;

    # Valeur de la clé (ou des clés de hachage)
    my $value = tell $self->[INFO_DESC];
    print { $self->[INFO_DESC] } "$seek_start|$seek_end\n";
    $call_id = '' if ( !defined $call_id );
    print { $self->[INFO_DESC] } "\t$tid|$call_id\n";
    my @calls = eval $calls_dump;
    for my $indice ( 1 .. scalar(@calls) / 3 ) {
        my ( $pack, $file, $line ) = splice @calls, 0, 3;
        print { $self->[INFO_DESC] } "\t$file|$line|$pack\n";
    }

# La donnée a été écrite sur le fichier, on peut l'ouvrir et analyser les départs de nouvelles lignes
    if ( !open( FIC, $self->[OUT_NAME] ) ) {
        print DBG "Ouverture trace en erreur : $!\n";
        return;
    }

    my $start_of_line = $seek_start;
    my $new_position;

    #print DBG "\tRecherche vrai début seek_start : $seek_start\n";
    if ($start_of_line)
    { # si $start_of_line est nul ==> on est bien au début de la ligne puisqu'on est au début du fichier
        do {
            $start_of_line -= 5;
            $start_of_line = 0 if ( $start_of_line < 0 );
            if ( !seek FIC, $start_of_line, 0 ) {

                #print DBG "Positionnement trace en erreur : $!\n";
                close FIC;
                return;
            }
            <FIC>;
            $new_position = tell FIC;

            #print DBG "\tBOUCLE start|$start_of_line|new|$new_position|\n";
        } while ( $new_position > $seek_start );
    }

    #print DBG "\tFIN Boucle start|$start_of_line|new|$new_position|\n";
    if ( $start_of_line != $seek_start ) {

  #print DBG "\tCondition start|$start_of_line|new|$new_position|$seek_start\n";
      READ: while ( $new_position <= $seek_start ) {
            $start_of_line = $new_position;
            my $enreg = <FIC>;
            last READ if ( !defined $enreg );
            $new_position = tell FIC;

       #print DBG "\tTEST start|$start_of_line|new|$new_position|$seek_start\n";
        }
    }

    #print DBG "\tFIN start|$start_of_line|\n";
    while ( $start_of_line < $seek_end ) {
        if ( !defined $self->[HASH]{$start_of_line} ) {
            $self->[HASH]{$start_of_line} = $value;
        }

        #print DBG "Clé $start_of_line, valeur : |$value|$data\n";
        <FIC>;
        $start_of_line = tell FIC;
    }
    close FIC;
}

sub get_info_for_display {
    my ( $self, $start_of_line ) = @_;

    print DBG "Dans get_info_for_display : |$start_of_line|\n";
    my $value = $self->[HASH]{$start_of_line};
    if ( defined $value ) {
        print DBG "Clé $start_of_line trouvée !! valeur : |$value|\n";
        return ( $value, tell $self->[INFO_DESC] );
    }
    return;
}

# Internal
sub trace_display_calls {
    my @calls = @_;
    for my $indice ( 1 .. scalar(@calls) / 3 ) {
        my ( $pack, $file, $line ) = splice @calls, 0, 3;

        #print ENC "\tF|$file|L|$line|P|$pack\n";
    }
}

1;
