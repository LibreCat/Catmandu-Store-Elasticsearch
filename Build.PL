use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name => 'Catmandu::Store::Elasticsearch',
    license => 'perl',
    dist_author => [
        'Nicolas Steenlant <nicolas.steenlant@ugent.be>',
    ],
    build_requires => {
        'Software::License' => 0,
        'Test::Exception' => 0,
        'Test::More' => 0,
    },
    requires => {
        'perl' => '5.10.1',
        'Catmandu' => '0.9206',
        'CQL::Parser' => '1.12',
        'Moo' => '1.00',
        'Search::Elasticsearch' => '1.14',
    },
    add_to_cleanup => [qw(
        Catmandu-Store-Elasticsearch-*
    )],
    create_makefile_pl => 'traditional',
    create_license => 1,
);

$builder->create_build_script;
