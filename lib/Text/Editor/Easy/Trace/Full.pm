package Text::Editor::Easy::Trace::Full;

use warnings;
use strict;

=head1 NAME

Text::Editor::Easy::Trace::Full - Full trace management. The following events are saved on files : print (on STDOUT or STDERR), inter-thread call and
user event (key press, mouse move, ...). For each trace, the client thread and the stack call are saved.

=head1 VERSION

Version 0.40

=cut

our $VERSION = '0.40';

# Ce thread génère le fichier d'info et le hachage permettant d'y accéder rapidement
# Ce fichier d'info contient :
#   La liste des print (thread, liste d'appels ayant générée ce print, heure)
#   La liste des calls de méthodes inter-thread (call_id, méthode, liste d'appels ayant générée cet appel de méthode, heure, paramètres d'appels ?)
#   La liste des débuts de réponse (call_id)
#   La liste des fins de réponse (call_id, paramètres de retour ?)

use Fcntl;
use SDBM_File;

use Devel::Size qw(size total_size);
use IO::File;

Text::Editor::Easy::Comm::manage_debug_file( __PACKAGE__, *DBG );

use constant {

    #------------------------------------
    # LEVEL 1 : $self->[???]
    #------------------------------------
    HASH      => 0,
    OUT_NAME  => 1,
    INFO_DESC => 2,
    DBG_DESC  => 3,
    CALL_DESC => 4,
    HIDE => 5,
    INTER_CALL => 6,
    EVAL_DESC => 7,
};

# Hash content : depends on the key shape
#
# key = "\d+" (seek position, digits only : 5678) :
#     => the key corresponds to the position of text displayed in the redirected file (redirection of STDOUT and STDERR)
#     => the value corresponds to the position of the stack call ( at the time of the print ) in the print trace file

# key = "\d+_\d+" (call_id form : 0_345)
#     => the key corresponds to call_id, call identification
#     => the value corresponds to the position of the stack call ( at the time of the call ) in the call trace file

# key = "U_\d+" (user event : U_345 ) => "extended call"
#     => the key corresponds to the pseudo-call_id : the user made the "initial call"
#     => the value corresponds to the position of the user event description in the call trace file

# key = "E_\d+_\d+" (eval : E_0_345 = 'E' . $call_id)
#     => the second part of the key corresponds to the call_id that made the eval
#     => the value corresponds to the position(s) (if several, positions are separated by ';') of the code that has been 'evaled' in the eval file

=head1 FUNCTIONS

=head2 init_trace_print

This function is called just after the Trace::Full thread has been created. It initializes the files that will make possible to link a print and the
code that generated it.

=cut

my $length_s_n;

sub init_trace_full {
    my ( $self, $reference, $file_name ) = @_;

# Faire de même avec le fichier info. Référencer également
# le nom initial du fichier STDOUT (pour analyse : ouverture et réouverture régulières dans full_trace)
#$self = 'Bidon';
    print DBG "Dans init_trace_print ", total_size($self), " : $file_name|\n";
    my %h;

    # Hash (tied to a file to enable huge size)
    my $suppressed = unlink( $file_name . '.pag', $file_name . '.dir' );
    tie( %h, 'SDBM_File', $file_name, O_RDWR | O_CREAT, 0666 )
      or die "Couldn't tie SDBM file $file_name: $!; aborting";
    $self->[HASH]     = \%h;
    $self->[OUT_NAME] = $file_name;
    use IO::File;
    
    # print trace file
    open( $self->[INFO_DESC], "+>${file_name}.print_info" )
      or print DBG "Ouverture Info impossible\n";
    autoflush { $self->[INFO_DESC] };
    
    # call trace file
    open( $self->[CALL_DESC], "+>${file_name}.call_info" )
      or print DBG "Ouverture Call impossible\n";
    autoflush { $self->[CALL_DESC] };
    
    # eval trace file
    open( $self->[EVAL_DESC], "+>${file_name}.eval_info" )
      or print DBG "Ouverture Eval impossible\n";
    autoflush { $self->[EVAL_DESC] };

    my %package = (
        'Text::Editor::Easy' => 1,
        'Text::Editor::Easy::Comm' => 1,
    );

    my $indice = 0;
    FILE: while ( my ( $pack, $file, $line ) = caller( $indice++ ) ) {
        if ( $pack eq 'Text::Editor::Easy::Comm' ) {
            $package{$pack} = $file;
            $file =~ s/Easy\/Comm\.pm/Easy\.pm/;
            $package{'Text::Editor::Easy'} = $file;
        }
        last FILE;
    }

    print "Fichiers trouvés :\n\t", join( "\n\t", values %package), "\n";

    while ( my ( $package, $file ) = each %package ) {
        open ( FIC, $file ) or die "Can't open file $file : $!\n";
        while ( <FIC> ) {
            if ( /# Following call not to be shown in trace/ ) {
                $self->[HIDE]{$package}{$. + 1} = 1;
                print "Package $package, ligne à ignorer : ", $. + 1, " :\n";
                print scalar <FIC>;
            }
            if ( /# Inter-thread call, not to be shown in trace/ ) {
                $self->[INTER_CALL]{$. + 1} = 1;
            }
        }
        close FIC;
    }
    $length_s_n = Text::Editor::Easy->tell_length_slash_n;
}

=head2 trace_full_print

This function saves the link between a print and the code that generated it.

=cut

sub trace_full_print {
    my ( $self, $seek_start, $seek_end, $tid, $call_id, $on, $calls_dump, $data ) = @_;

    print DBG "Appel à trace_full_print : $data\n";

    return if ( !$self->[INFO_DESC] );

    # Valeur de la clé (ou des clés de hachage)
    my $value = tell $self->[INFO_DESC];
    $self->[HASH]{$seek_start} = $value;
    print { $self->[INFO_DESC] } "$seek_start|$seek_end\n";
    $call_id = '' if ( !defined $call_id );
    print { $self->[INFO_DESC] } "\t$tid|$call_id|$on\n";
    my @calls = eval $calls_dump;
    for my $tab_ref ( @calls ) {
        my ( $pack, $file, $line ) = @$tab_ref;
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

=head2 get_info_for_display 

This function recovers the link between a print and the code that generated it.

=cut

my %editor;

sub get_info_for_eval_display {
    my ( $self, $ref_editor, $ref_line, $pos_in_line ) = @_;
    
    print DBG "Dans get_info_for_eval_display : ref_editor : $ref_editor| ref_line $ref_line| pos_in_line $pos_in_line\n";
    my $editor = $editor{$ref_editor};
    if ( ! $editor ) {
        $editor = bless \do { my $anonymous_scalar }, "Text::Editor::Easy";
        Text::Editor::Easy::Comm::set_ref ($editor, $ref_editor);
        $editor{$ref_editor} = $editor;
    }
    my $seek_start = $editor->line_seek_start( $ref_line );
    my $text = $editor->get_text_from_ref ( $ref_line );
    print DBG "Seek start de la ligne : $seek_start| texte : $text\n";
    
    # Décomposition de la ligne
    my @seek_start = split ( /;/, $seek_start );
    my $to_calc = scalar(@seek_start);
    #my $current_length = length ( $text );
    my $current_length = 0;
    print DBG "\tCURRENT LENGTH $current_length\n";
    my $indice = 0;
    my ( $top_start, $real_start ) = split ( /,/, $seek_start[0] );
    while ( $to_calc ) {
        my ( $start, $end, $length ) = split ( /,/, $seek_start[$indice] );
        print DBG "\tSEEK_START $start de la position ", $current_length, " à la position ", $current_length + $length, "\n";
        if ( $pos_in_line <= $current_length + $length ) {
            print DBG "C'est ce seek_start $start qu'il faut renvoyer\n";
            my $seek = $self->[HASH]{$start};
            if ( $indice == 0 ) {
                return (
                    get_first_line_for_print ( $self, $editor, $ref_line, $seek, $start, $end, $length ),
                    $ref_line,
                    $current_length + $length, 
                    get_call_list_for_print ( $self, $seek ),
                );
            }
            if ( $indice == $#seek_start ) {
                return (
                    $ref_line,
                    $current_length,
                    get_last_line_for_print ( $self, $editor, $ref_line, $seek, $start, $end, $length ),
                    get_call_list_for_print ( $self, $seek ),
                );
            }

            return (
                $ref_line,
                $current_length,
                $ref_line,
                $current_length + $length, 
                get_call_list_for_print ( $self, $seek ),
            );
        }
        $current_length += $length;
        print DBG "\tCURRENT LENGTH $current_length\n";
        $to_calc -= 1;
        $indice += 1;
    }
    my ( $start, $end, $length ) = split ( /,/, $seek_start[$indice - 1] );
    #print DBG "\tCURRENT LENGTH $current_length\n";
    #print DBG "\tPour finir, SEEK_START $start de la position ", $end - $real_start , " à la position ", $end + $current_length - $real_start, "\n";
    
    my $last_info_seek = $self->[HASH]{$start};
    print DBG "\tlast_info_seek = $last_info_seek\n";
    seek $self->[INFO_DESC], $last_info_seek, 0;
    my $info = readline ( $self->[INFO_DESC] );
    chomp $info;
    print DBG "\tinfo lu pour start = $start : $info\n";
    my ( $seek_1, $seek_2 ) = split ( /\|/, $info );
    print DBG "\tla longueur de SEEK_START $start est de ", $seek_2 - $seek_1, "\n";
    print DBG "\tIl reste donc ", $seek_2 - ( $end + $length ), " caractères sur le dernier seek_start\n";

    print DBG "\tIl reste également 1 ", $real_start - $top_start, " caractères à lire pour start $top_start\n";
    my $first_info_seek = $self->[HASH]{$top_start};
    print DBG "\tfirst_info_seek = $first_info_seek\n";
    seek $self->[INFO_DESC], $first_info_seek, 0;
    $info = readline ( $self->[INFO_DESC] );
    print DBG "\tinfo lu pour start = $top_start : $info\n";
    ( $seek_1, $seek_2 ) = split ( /\|/, $info );
    print DBG "\tIl reste également 2 ", $real_start - $seek_1, " caractères à lire pour start $top_start\n";

    seek $self->[INFO_DESC], 0, 2;
    return;
}

sub get_first_line_for_print {
    my ( $self, $editor, $ref_line, $seek, $start, $end, $length ) = @_;
    
    my $remain = $end - $start;
    print DBG "Dans get_first_line_for_print : Il faut remonter de $remain caractères\n";
    my $text;
    while ( $remain > 0 ) {
        $remain -= $length_s_n;
        ( $ref_line, $text ) = $editor->previous_line( $ref_line );
        my $length = length($text);
        if ( $length >= $remain ) {
            return ( $ref_line, $length - $remain );
        }
        else {
            $remain -= $length;
        }
    }
    return ( $ref_line, 0 );
}

sub get_last_line_for_print {
    my ( $self, $editor, $ref_line, $seek, $start, $end, $length ) = @_;

    seek $self->[INFO_DESC], $seek, 0;
    my $info = readline ( $self->[INFO_DESC] );
    chomp $info;
    print DBG "Dans get_last : info lu pour start = $seek : $info\n";
    my ( $seek_1, $seek_2 ) = split ( /\|/, $info );
    seek $self->[INFO_DESC], 0, 2;
    
    my $remain = $seek_2 - $seek_1 - $length;
    print DBG "Dans get_last_line_for_print : Il faut descendre de $remain caractères\n";
    #$remain = 0;
    my $text;
    while ( $remain > 0 ) {
        $remain -= $length_s_n;
        ( $ref_line, $text ) = $editor->next_line( $ref_line );
        my $length = length($text);
        if ( $length >= $remain ) {
            return ( $ref_line, $remain );
        }
        else {
            $remain -= $length;
        }
    }
    return ( $ref_line, 0 );
}


sub get_info_for_display {
    my ( $self, $start_of_line, $shift ) = @_;

    print DBG "Dans get_info_for_display : |$start_of_line| décalage : $shift\n";
    my $value = $self->[HASH]{$start_of_line};
    return if ( ! defined $value );
    print DBG "Clé $start_of_line trouvée !! valeur : |$value|\n";
    seek $self->[INFO_DESC], $value, 0;
    my $enreg = readline $self->[INFO_DESC];
    my ( $start, $end ) = $enreg =~ /^(\d+)\|(\d+)$/;
    while ( $end < $start + $shift ) {
        ($start, $end ) = next_display( $self );
    }
    return ($start, $end, get_call_list_for_print( $self, $value ) );
}
    
sub get_call_list_for_print {
    my ( $self, $seek ) = @_;
    
    seek $self->[INFO_DESC], $seek, 0;
    readline $self->[INFO_DESC];
    my $enreg = readline $self->[INFO_DESC];
    $enreg =~ s/\t//;
    chomp $enreg;
    my @enreg = $enreg;
    my ( $tid, $call_id ) = split( /\|/, $enreg );
    $enreg = readline $self->[INFO_DESC];
    PRINT: while ( $enreg =~ /^\t/ ) {
        chomp $enreg;
        my ( $file, $line, $package ) = split( /\|/, $enreg );
        if ( $package eq 'Text::Editor::Easy::Comm' ) {
            if ( $self->[INTER_CALL]{$line} ) {
                push @enreg, "", get_info_for_call ( $self, $call_id );
                last PRINT;
            }
        }
        if ( my $hash_ref = $self->[HIDE]{$package} ) {
            if ( $hash_ref->{$line} ) {
                $enreg = readline $self->[INFO_DESC];
                next PRINT;
            }
        }
        if ( $file =~ /^\t\(eval / ) {
            $enreg = try_to_identify_eval ( $self, $enreg, $call_id, $self->[INFO_DESC] );
        }
        push @enreg, $enreg;
        $enreg = readline $self->[INFO_DESC];
    }
    seek $self->[INFO_DESC], 0, 2;
    
    return @enreg;
}

sub next_display {
    my ( $self ) = @_;
    
    my $enreg = readline $self->[INFO_DESC];
    while ( $enreg =~ /^\t.+/ ) {
        $enreg = readline $self->[INFO_DESC];
    }
    return $enreg =~ /^(\d+)\|(\d+)$/;
}

sub try_to_identify_eval {
    my ( $self, $enreg, $call_id, $file_desc ) = @_;
    
    my $value = $self->[HASH]{'E_' . $call_id};
    return $enreg if ( ! defined $value );
    print "Dans identify : trouvé $value pour clé E_$call_id\n";
    
    my $seek = tell $file_desc;
    my $eval_call = readline $file_desc;
    seek $file_desc, $seek, 0;
        
    return $enreg if ( $eval_call !~ /\t(.+)\|(.+)\|(.+)$/ );
    my ( $file, $line, $package ) = ( $1, $2, $3 );
    print "file line et package : $file | $line | $package\n";

    # Vérification de l'égalité de fichier et de ligne entre l'eval et la ligne suivante du fichier $file_desc
    my @position = split ( /;/, $value);
    my $indice = 0;
    my $found = 0;
    EVAL: for ( @position ) {
        seek $self->[EVAL_DESC], $_, 0;
        my $eval_info = readline $self->[EVAL_DESC];
        print "INFO Eval lu =\n\t$eval_info";
        
        chomp $eval_info;
        my ( $tid, $c_file, $c_package, $c_line, $c_call_id ) = split (/\|/, $eval_info );
        if ( $c_file eq $file and $line == $c_line ) {
            print "EVAL identifié : E_${call_id}__$indice\n";
            $found = 1;
            last EVAL;
        }
        $indice += 1;
    };
    if ( $found ) {
        my ( $file, $line, $package ) = $enreg =~ /\t(.+)\|(.+)\|(.+)$/;
        $enreg = "\teval E_${call_id}__$indice|$line|$package\n";
        print "Trouvé, on renvoie $enreg\n";
    }
    
    
    # Repositionement à la fin
    seek $self->[EVAL_DESC], 0, 2;

    return $enreg;
}

sub trace_full_call {
    my ( $self, $call_id, $client_call_id, @calls ) = @_;
    
    #print DBG "Dans trace_full_call (self = $self): $call_id\n";
    my $seek = tell $self->[CALL_DESC];
    no warnings;
    print { $self->[CALL_DESC] } "$call_id|$client_call_id\n";
    use warnings;
    for my $tab_ref ( @calls ) {
        if ( ref $tab_ref ) {
            my ( $pack, $file, $line ) = @$tab_ref;
            print { $self->[CALL_DESC] } "\t$file|$line|$pack\n";            
        }
        else {
            print { $self->[CALL_DESC] } "\t$tab_ref\n";
        }

    }
    $self->[HASH]{$call_id} = $seek;
    #print DBG "Fin de trace_full_call pour call_id $call_id => position $seek\n";
    #print DBG "Relecture du hachage : ", $self->[HASH]{$call_id}, "\n";
    #print DBG "Hash = ", $self->[HASH], "\n";
}

sub get_info_for_call {
    my ( $self, $call_id ) = @_;

    #print DBG "Dans get_info_for_call (self = $self): position de $call_id :\n";
    #print DBG "HASH = ", $self->[HASH], "\n";
    #print DBG "KEY  = ", $self->[HASH]{$call_id}, "\n";
    my $seek = $self->[HASH]{$call_id};
    return if ( ! defined $seek );
    #print DBG "\tSEEK de $call_id => $seek\n";
    seek $self->[CALL_DESC], $seek, 0;
    my $enreg = readline $self->[CALL_DESC];
    chomp $enreg;
    my ( undef, $new_call_id ) = split ( /\|/, $enreg );
    my @return = $enreg;
    print DBG $enreg;
    $enreg = readline $self->[CALL_DESC];
    CALL: while ( $enreg =~ /^\t/ ) {
        chomp $enreg;
        my ( $file, $line, $package ) = split( /\|/, $enreg );
        if ( $package eq 'Text::Editor::Easy::Comm' ) {
            if ( $self->[INTER_CALL]{$line} ) {
                if ( defined $new_call_id ) {
                    push @return, "", get_info_for_call ( $self, $new_call_id );
                }
                last CALL;
            }
        }
        if ( my $hash_ref = $self->[HIDE]{$package} ) {
            if ( $hash_ref->{$line} ) {
                $enreg = readline $self->[CALL_DESC];
                next CALL;
            }
        }
        push @return, $enreg;
        $enreg = readline $self->[CALL_DESC];
    }
    # Repostionnement à la fin
    seek $self->[CALL_DESC], 0, 2;
    return @return;
}
=head2 trace_display_calls

This function is not used.

=cut

# Internal
sub trace_display_calls {
    my @calls = @_;
    for my $indice ( 1 .. scalar(@calls) / 3 ) {
        my ( $pack, $file, $line ) = splice @calls, 0, 3;

        #print ENC "\tF|$file|L|$line|P|$pack\n";
    }
}

sub trace_full_eval {
    my ( $self, $eval, $tid, $file, $package, $line, $call_id ) = @_;
    
    my $key = 'E_' . $call_id;
    my $value;
    if ( $value = $self->[HASH]{$key} ) {
        $value .= ';';
    }
    $value .= tell $self->[EVAL_DESC];
    $self->[HASH]{$key} = $value;
    print { $self->[EVAL_DESC] } "$tid|$file|$package|$line|$call_id\n";
    my @eval = split ( /\n/, $eval );
    for ( @eval ) {
        print { $self->[EVAL_DESC] } "\t$_\n";
    }
}

sub get_code_for_eval {
    my ( $self, $eval_id ) = @_;
    
    print "Dans get_code_for_eval : eval_id = $eval_id\n";
    return if ( $eval_id !~ /(E_.+)__(.+)$/ );
    my ( $key, $indice ) = ( $1, $2 );
    print "Dans get_code_for_eval : clé $key, indice $indice\n";
    my $value = $self->[HASH]{$key};
    my @position = split ( /;/, $value );
    seek $self->[EVAL_DESC], $position[$indice], 0;
    readline $self->[EVAL_DESC];
    my $enreg = readline $self->[EVAL_DESC];
    my @enreg;
    while ( $enreg =~ /^\t(.*)/ ) {
        push @enreg, $1;
        $enreg = readline $self->[EVAL_DESC];
    }
    seek $self->[EVAL_DESC], 0, 2;
    return @enreg;
}

sub trace_full_eval_err {
    my ( $self, $seek_start, $seek_end, $dump_hash, $message ) = @_;
    
    
    print DBG "Dans trace_full_eval_err, reçu : $seek_start | $seek_end\n";
    # 1 - retrouver l'eval à partir de la pile d'appel : inutile...
    
    my @line = split ( /\n/, $message );
    if ( scalar(@line) > 1 ) {
        print "Cas pas encore géré : retrouver la taille du \\n\n";
        return;
    }
    
    my ( $num_eval, $num_line );
    
    my $info = $line[0];
    my $value = tell $self->[INFO_DESC];
    
    # très dangereux !
    $self->[HASH]{$seek_start} = $value;
    
    
    my %option = eval $dump_hash;
    if ( $info =~ / at \(eval (\d+)\) line (\d+)/ ) {
        ( $num_eval, $num_line ) = ( $1, $2 );
        print { $self->[INFO_DESC] } "$seek_start|$seek_end\n";
        print { $self->[INFO_DESC] } "\t$option{'who'}|$option{'call_id'}|STDERR\n";
        print { $self->[INFO_DESC] } "\t(eval $num_eval)|$num_line|$option{'package'}\n";
        print { $self->[INFO_DESC] } "\t$option{'file'}|$option{'line'}|$option{'package'}\n";
        
        #(eval 265)|1|Text::Editor::Easy::Program::Eval::Exec
        my @calls = eval $option{'calls'};
        for my $tab_ref ( @calls ) {
            my ( $pack, $file, $line ) = @$tab_ref;
            print { $self->[INFO_DESC] } "\t$file|$line|$pack\n";
        }
    }
    # 2 - décomposer le message d'erreur en ligne : trouver la longueur d'un \n
    # => pour chaque ligne analyser la provenance dans le texte de la ligne
    # => modifier la pile d'appel pour ajouter l'eval ainsi que le numéro de ligne dans l'eval trouvé
    # => envoyer un premier trace_full_print en mettant à jour seek_end en fonction de la longueur \n trouvée
    # Les autres lignes sont toutes entières : le travail complexe de trace_full_print est inutile
    
}

=head1 COPYRIGHT & LICENSE

Copyright 2008 Sebastien Grommier, all rights reserved.

This program is free software; you can redistribute it and/or modify it

=cut

1;
