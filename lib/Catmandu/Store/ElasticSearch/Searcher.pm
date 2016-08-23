package Catmandu::Store::ElasticSearch::Searcher;

use Catmandu::Sane;

our $VERSION = '0.0501';

use Moo;
use namespace::clean;

with 'Catmandu::Iterable';

has bag   => (is => 'ro', required => 1);
has query => (is => 'ro', required => 1);
has start => (is => 'ro', required => 1);
has limit => (is => 'ro', required => 1);
has total => (is => 'ro');
has sort  => (is => 'ro');

sub generator {
    my ($self) = @_;
    my $store = $self->bag->store;
    sub {
        state $total = $self->total;
        if (defined $total) {
            return unless $total;
        }

        state $scroll = do {
            my $body = {query => $self->query};
            $body->{sort} = $self->sort if $self->sort;
            $store->es->scroll_helper(
                index       => $store->index_name,
                type        => $self->bag->name,
                search_type => $self->sort ? 'query_then_fetch' : 'scan',
                from        => $self->start,
                size        => $self->bag->buffer_size, # TODO divide by number of shards
                body        => $body,
            );
        };

        my $data = $scroll->next // return;
        if ($total) {
            $total--;
        }
        $data->{_source};
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
    my $store = $self->bag->store;
    $store->es->count(
        index => $store->index_name,
        type  => $self->bag->name,
        body  => {
            query => $self->query,
        },
    )->{count};
}

1;

__END__

=pod

=head1 NAME

Catmandu::Store::ElasticSearch::Bag - Searcher implementation for Elasticsearch

=head1 DESCRIPTION

This class isn't normally used directly. Instances are constructed using the store's C<searcher> method.

=head1 SEE ALSO

L<Catmandu::Iterable>

=cut
