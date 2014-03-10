use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name => 'Catmandu::Store::ElasticSearch',
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
        'Catmandu' => '0.8',
        'CQL::Parser' => '1.12',
        'Moo' => '1.00',
        'Search::Elasticsearch::Compat' => '0.10',
    },
    add_to_cleanup => [qw(
        Catmandu-Store-ElasticSearch-*
    )],
    create_makefile_pl => 'traditional',
    create_license => 1,
);

$builder->create_build_script;
