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
# ligne très très longue----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------milieu de la ligne très longue----------------------------------------------------------fin de la ligne très très longue
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