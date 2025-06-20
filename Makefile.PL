use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Data::Tab',
    AUTHOR           => q{Michael Roberts <michael@vivtek.com>},
    VERSION_FROM     => 'lib/Data/Tab.pm',
    ABSTRACT_FROM    => 'lib/Data/Tab.pm',
    LICENSE          => 'perl_5',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Iterator::Records'              => 0,
        'List::MoreUtils'                => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Data-Tab-*' },
);
