requires 'perl', 'v5.10.1';

on 'test', sub {
  requires 'Test::Simple', '1.001003';
  requires 'Test::More', '1.001003';
};

requires 'Catmandu', '0.9206';
requires 'CQL::Parser', '1.12';
requires 'Moo', '1.0';
requires 'Search::Elasticsearch', '1.14';

