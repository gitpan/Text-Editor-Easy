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