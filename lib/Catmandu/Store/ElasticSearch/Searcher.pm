package Catmandu::Store::ElasticSearch::Searcher;

use Catmandu::Sane;
use Moo;

with 'Catmandu::Iterable';

has bag   => (is => 'ro', required => 1);
has query => (is => 'ro', required => 1);
has start => (is => 'ro', required => 1);
has limit => (is => 'ro', required => 1);
has total => (is => 'ro');
has sort  => (is => 'ro');

sub generator {
    my ($self) = @_;
    my $limit = $self->limit;
    sub {
        state $total = $self->total;
        if (defined $total) {
            return unless $total;
        }
        state $scroller = do {
            my $args = {
                query => $self->query,
                type  => $self->bag->name,
                from  => $self->start,
            };
            if ($self->sort) {
                $args->{search_type} = 'query_then_fetch';
                $args->{sort} = $self->sort;
            } else {
                $args->{search_type} = 'scan';
            }
            $self->bag->store->elastic_search->scrolled_search($args);
        };
        state @hits;
        unless (@hits) {
            if ($total && $limit > $total) {
                $limit = $total;
            }
            @hits = $scroller->next($limit);
        }
        if ($total) {
            $total--;
        }
        (shift(@hits) || return)->{_source};
    };
}

sub slice { # TODO constrain total?
    my ($self, $start, $total) = @_;
    $start //= 0;
    $self->new(
        bag   => $self->bag,
        query => $self->query,
        start => $self->start + $start,
        limit => $self->limit,
        total => $total,
        sort  => $self->sort,
    );
}

sub count {
    my ($self) = @_;
    $self->bag->store->elastic_search->count(
        query => $self->query,
        type  => $self->bag->name,
    )->{count};
}

1;
