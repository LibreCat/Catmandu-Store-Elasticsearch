package Catmandu::Store::ElasticSearch::Bag;

use Catmandu::Sane;
use Moo;
use Catmandu::Hits;
use Catmandu::Store::ElasticSearch::Searcher;
use Catmandu::Store::ElasticSearch::CQL;

with 'Catmandu::Bag';
with 'Catmandu::Searchable';
with 'Catmandu::Buffer';

has cql_mapping => (is => 'ro'); # TODO move to Searchable
has on_error    => (is => 'ro', default => sub { 'IGNORE'} ); 

sub generator {
    my ($self) = @_;
    my $limit = $self->buffer_size;
    sub {
        state $scroller = $self->store->elastic_search->scrolled_search({
            search_type => 'scan',
            query => {match_all => {}},
            type  => $self->name,
        });
        state @hits;
        @hits = $scroller->next($limit) unless @hits;
        (shift(@hits) || return)->{_source};
    };
}

sub count {
    my ($self) = @_;
    $self->store->elastic_search->count(type => $self->name)->{count};
}

sub get {
    my ($self, $id) = @_;
    my $res = $self->store->elastic_search->get(
        type => $self->name,
        ignore_missing => 1,
        id => $id,
    );
    return $res->{_source} if $res;
    return;
}

sub add {
    my ($self, $data) = @_;

    $self->buffer_add({index => {
        type => $self->name,
        id => $data->{_id},
        data => $data,
    }});

    if ($self->buffer_is_full) {
        $self->commit;
    }
}

sub delete {
    my ($self, $id) = @_;

    $self->buffer_add({delete => {
        type => $self->name,
        id => $id,
    }});

    if ($self->buffer_is_full) {
        $self->commit;
    }
}

sub delete_all {
    my ($self) = @_;
    my $es = $self->store->elastic_search;
    $es->delete_by_query(
        query => {match_all => {}},
        type  => $self->name,
    );
    $es->refresh_index;
}

sub delete_by_query {
    my ($self, %args) = @_;
    my $es = $self->store->elastic_search;
    $es->delete_by_query(
        query => $args{query},
        type  => $self->name,
    );
    $es->refresh_index;
}

sub commit { # TODO optimize
    my ($self) = @_;
    return 1 unless $self->buffer_used;
    $self->store->elastic_search->bulk(actions => $self->buffer, refresh => 1, on_error => $self->on_error);
    $self->clear_buffer;
    return 1;
}

sub search {
    my ($self, %args) = @_;

    my $start = delete $args{start};
    my $limit = delete $args{limit};
    my $bag   = delete $args{reify};

    if ($bag) {
        $args{fields} = [];
    }

    my $res = $self->store->elastic_search->search({
        %args,
        type  => $self->name,
        from  => $start,
        size  => $limit,
    });

    my $docs = $res->{hits}{hits};

    my $hits = {
        start => $start,
        limit => $limit,
        total => $res->{hits}{total},
    };

    if ($bag) {
        $hits->{hits} = [ map { $bag->get($_->{_id}) } @$docs ];
    } elsif ($args{fields}) {
        $hits->{hits} = [ map { $_->{fields} || {} } @$docs ];
    } else {
        $hits->{hits} = [ map { $_->{_source} } @$docs ];
    }

    $hits = Catmandu::Hits->new($hits);

    if ($args{facets}) {
        $hits->{facets} = $res->{facets};
    }

    if ($args{highlight}) {
        for my $hit (@$docs) {
            if (my $hl = $hit->{highlight}) {
                $hits->{highlight}{$hit->{_id}} = $hl;
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
    Catmandu::Store::ElasticSearch::CQL->new(mapping => $self->cql_mapping)->parse($query);
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

=head1 SEE ALSO

L<Catmandu::Bag>, L<Catmandu::Searchable>

=cut

1;
