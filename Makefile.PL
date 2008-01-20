use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Text::Editor::Easy',
    AUTHOR              => 'Sébastien Grommier <sgrommier@free.fr>',
    VERSION_FROM        => 'lib/Text/Editor/Easy.pm',
    ABSTRACT_FROM       => 'lib/Text/Editor/Easy.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Text-Editor-Easy-*' },
);
