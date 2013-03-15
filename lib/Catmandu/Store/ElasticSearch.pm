package Catmandu::Store::ElasticSearch;

use Catmandu::Sane;
use Moo;
use ElasticSearch;
use Catmandu::Store::ElasticSearch::Bag;

with 'Catmandu::Store';

=head1 NAME

Catmandu::Store::ElasticSearch - A searchable store backed by ElasticSearch

=head1 VERSION

Version 0.0201

=cut

our $VERSION = '0.0201';

=head1 SYNOPSIS

    use Catmandu::Store::ElasticSearch;

    my $store = Catmandu::Store::ElasticSearch->new(index_name => 'catmandu');

    my $obj1 = $store->bag->add({ name => 'Patrick' });

    printf "obj1 stored as %s\n" , $obj1->{_id};

    # Force an id in the store
    my $obj2 = $store->bag->add({ _id => 'test123' , name => 'Nicolas' });

    # Commit all changes
    $store->bag->commit;

    my $obj3 = $store->bag->get('test123');

    $store->bag->delete('test123');
    
    $store->bag->delete_all;

    # All bags are iterators
    $store->bag->each(sub { ... });
    $store->bag->take(10)->each(sub { ... });

    # Some stores can be searched
    my $hits = $store->bag->search(query => 'name:Patrick');

    # ElasticSearch supports CQL...
    my $hits = $store->bag->search(cql_query => 'name any "Patrick"');

=cut

my $ELASTIC_SEARCH_ARGS = [qw(
    transport
    servers
    trace_calls
    timeout
    max_requests
    no_refresh
)];

has index_name     => (is => 'ro', required => 1);
has index_settings => (is => 'ro', lazy => 1, default => sub { +{} });
has index_mappings => (is => 'ro', lazy => 1, default => sub { +{} });

has elastic_search => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_elastic_search',
);

sub _build_elastic_search {
    my $self = $_[0];
    my $es = ElasticSearch->new(delete $self->{_args});
    unless ($es->index_exists(index => $self->index_name)) {
        $es->create_index(
            index => $self->index_name,
            settings => $self->index_settings,
            mappings => $self->index_mappings,
        );
    }
    $es->use_index($self->index_name);
    $es;
}

sub BUILD {
    my ($self, $args) = @_;
    $self->{_args} = {};
    for my $key (@$ELASTIC_SEARCH_ARGS) {
        $self->{_args}{$key} = $args->{$key} if exists $args->{$key};
    }
}
=head1 SUPPORT

This ElasticSearch interface is based on elasticsearch-0.17.6.

=head1 METHODS

=head2 new(index_name => $name, cql_mapping => \%mapping)

Create a new Catmandu::Store::ElasticSearch store connected to index $name. The
ElasticSearch supports CQL searches when a cql_mapping is provided. This hash
contains a translation of CQL fields into ElasticSearch searchable fields.

 # Example mapping
 $cql_mapping = {
      title => {
        op => {
          'any'   => 1 ,
          'all'   => 1 ,
          '='     => 1 ,
          '<>'    => 1 ,
	  'exact' => {field => [qw(mytitle.exact myalttitle.exact)]}
        } ,
        sort  => 1,
        field => 'mytitle',
        cb    => ['Biblio::Search', 'normalize_title']
      }
 }

 The CQL mapping above will support for the 'title' field the CQL operators: any, all, =, <> and exact.

 For all the operators the 'title' field will be mapping into the ElasticSearch field 'mytitle', except
 for the 'exact' operator. In case of 'exact' we will search both the 'mytitle.exact' and 'myalttitle.exact'
 fields.

 The CQL mapping allows for sorting on the 'title' field. If, for instance, we would like to use a special
 ElasticSearch field for sorting we could have written "sort => { field => 'mytitle.sort' }".

 The CQL has an optional callback field 'cb' which contains a reference to subroutines to rewrite or
 augment the search query. In this case, in the Biblio::Search package there is a normalize_title 
 subroutine which returns a string or an ARRAY of string with augmented title(s). E.g.

    package Biblio::Search;

    sub normalize_title {
       my ($self,$title) = @_;
       my $new_title =~ s{[^A-Z0-9]+}{}g;
       $new_title;
    }

    1;

=head1 SEE ALSO

L<Catmandu::Store>

=head1 AUTHOR

Nicolas Steenlant, C<< <nicolas.steenlant at ugent.be> >>

=head1 LICENSE AND COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
