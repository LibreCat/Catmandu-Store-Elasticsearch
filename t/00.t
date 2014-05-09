#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

my @pkgs = qw(
    Catmandu::Store::Elasticsearch
    Catmandu::Store::Elasticsearch::Bag
    Catmandu::Store::Elasticsearch::Searcher
    Catmandu::Store::Elasticsearch::CQL
);

require_ok $_ for @pkgs;

done_testing 4;
