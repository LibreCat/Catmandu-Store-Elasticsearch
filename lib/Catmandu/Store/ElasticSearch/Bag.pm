package Catmandu::Store::ElasticSearch::Bag;

use Catmandu::Sane;

our $VERSION = '0.0503';

use Moo;
use Catmandu::Hits;
use Catmandu::Store::ElasticSearch::Searcher;
use Catmandu::Store::ElasticSearch::CQL;

with 'Catmandu::Bag';
with 'Catmandu::Droppable';
with 'Catmandu::Searchable';

has buffer_size => (is => 'ro', lazy => 1, builder => 'default_buffer_size');
has _bulk       => (is => 'ro', lazy => 1, builder => '_build_bulk');
has cql_mapping => (is => 'ro');
has on_error    => (is => 'ro', default => sub { sub {} });

sub default_buffer_size { 100 }

sub _build_bulk {
    my ($self) = @_;
    my %args = (
        index     => $self->store->index_name,
        type      => $self->name,
        max_count => $self->buffer_size,
        on_error  => \&{$self->on_error},
    );
    if ($self->log->is_debug) {
        $args{on_success} = sub {
            my ($action, $res, $i) = @_; # TODO return doc instead of index
            $self->log->debug($res);
        };
    }
    $self->store->es->bulk_helper(%args);
}

sub generator {
    my ($self) = @_;
    sub {
        state $scroll = $self->store->es->scroll_helper(
            index       => $self->store->index_name,
            type        => $self->name,
            search_type => 'scan',
            size        => $self->buffer_size, # TODO divide by number of shards
            body        => {
                query => {match_all => {}},
            },
        );
        my $data = $scroll->next // return;
        $data->{_source};
    };
}

sub count {
    my ($self) = @_;
    $self->store->es->count(
        index => $self->store->index_name,
        type  => $self->name,
    )->{count};
}

sub get {
    my ($self, $id) = @_;
    try {
        $self->store->es->get_source(
            index => $self->store->index_name,
            type  => $self->name,
            id    => $id,
        );
   } catch_case [
       'Search::Elasticsearch::Error::Missing' => sub { undef }
   ];
}

sub add {
    my ($self, $data) = @_;
    $data = {%$data};
    my $id = $data->{$self->id_key};
    $self->_bulk->index({
        id     => $id,
        source => $data,
    });
}

sub delete {
    my ($self, $id) = @_;
    $self->_bulk->delete({id => $id});
}

sub delete_all {
    my ($self) = @_;
    my $es = $self->store->es;
    if ($es->can('delete_by_query')) {
        $es->delete_by_query(
            index => $self->store->index_name,
            type => $self->name,
            body => {
                query => {match_all => {}},
            },
        );
    } else { # TODO document plugin needed for es >= 2.0
        $es->transport->perform_request(
            method => 'DELETE',
            path => '/'.$self->store->index_name.'/'.$self->name.'/_query',
            body => {
                query => {match_all => {}},
            }
        );
    }
}

sub delete_by_query {
    my ($self, %args) = @_;
    my $es = $self->store->es;
    if ($es->can('delete_by_query')) {
        $es->delete_by_query(
            index => $self->store->index_name,
            type => $self->name,
            body => {
                query => $args{query},
            },
        );
    } else { # TODO document plugin needed for es >= 2.0
        $es->transport->perform_request(
            method => 'DELETE',
            path => '/'.$self->store->index_name.'/'.$self->name.'/_query',
            body => {
                query => $args{query},
            }
        );
    }
}

sub commit {
    my ($self) = @_;
    $self->_bulk->flush;
    $self->store->es->transport->perform_request(
        method => 'POST',
        path => '/'.$self->store->index_name.'/_refresh',
    );
}

sub search {
    my ($self, %args) = @_;

    my $id_key = $self->id_key;

    my $start = delete $args{start};
    my $limit = delete $args{limit};
    my $bag   = delete $args{reify};

    if ($bag) {
        $args{fields} = [];
    }

    my $res = $self->store->es->search(
        index => $self->store->index_name,
        type  => $self->name,
        body  => {
            %args,
            from => $start,
            size => $limit,
        },
    );

    my $docs = $res->{hits}{hits};

    my $hits = {
        start => $start,
        limit => $limit,
        total => $res->{hits}{total},
    };

    if ($bag) {
        $hits->{hits} = [ map { $bag->get($_->{$id_key}) } @$docs ];
    } elsif ($args{fields}) {
        $hits->{hits} = [ map { $_->{fields} || +{} } @$docs ];
    } else {
        $hits->{hits} = [ map { $_->{_source} } @$docs ];
    }

    $hits = Catmandu::Hits->new($hits);

    for my $key (qw(facets suggest aggregations)) {
        $hits->{$key} = $res->{$key} if exists $args{$key};
    }

    if ($args{highlight}) {
        for my $hit (@$docs) {
            if (my $hl = $hit->{highlight}) {
                $hits->{highlight}{$hit->{$id_key}} = $hl;
            }
        }
    }

    $hits;
}

sub searcher {
    my ($self, %args) = @_;
    Catmandu::Store::ElasticSearch::Searcher->new(%args, bag => $self);
}

sub translate_sru_sortkeys {
    my ($self, $sortkeys) = @_;
    [ grep { defined $_ } map { $self->_translate_sru_sortkey($_) } split /\s+/, $sortkeys ];
}

sub _translate_sru_sortkey {
    my ($self, $sortkey) = @_;
    my ($field, $schema, $asc) = split /,/, $sortkey;
    $field || return;
    if (my $map = $self->cql_mapping) {
        $field = lc $field;
        $field =~ s/(?<=[^_])_(?=[^_])//g if $map->{strip_separating_underscores};
        $map = $map->{indexes} || return;
        $map = $map->{$field}  || return;
        $map->{sort} || return;
        if (ref $map->{sort} && $map->{sort}{field}) {
            $field = $map->{sort}{field};
        } elsif (ref $map->{field}) {
            $field = $map->{field}->[0];
        } elsif ($map->{field}) {
            $field = $map->{field};
        }
    }
    $asc //= 1;
    +{ $field => $asc ? 'asc' : 'desc' };
}

sub translate_cql_query {
    my ($self, $query) = @_;
    Catmandu::Store::ElasticSearch::CQL->new(mapping => $self->cql_mapping,
        id_key => $self->id_key)->parse($query);
}

sub normalize_query {
    my ($self, $query) = @_;
    if (ref $query) {
        $query;
    } elsif ($query) {
        {query_string => {query => $query}};
    } else {
        {match_all => {}};
    }
}

sub drop {
    my ($self) = @_;
    $self->delete_all;
    $self->commit;
}

1;

__END__

=pod

=head1 NAME

Catmandu::Store::ElasticSearch::Bag - Catmandu::Bag implementation for Elasticsearch

=head1 DESCRIPTION

This class isn't normally used directly. Instances are constructed using the store's C<bag> method.

=head1 SEE ALSO

L<Catmandu::Bag>, L<Catmandu::Searchable>

=cut
