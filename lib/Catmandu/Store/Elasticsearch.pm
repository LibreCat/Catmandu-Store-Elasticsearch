package Catmandu::Store::Elasticsearch;

use Catmandu::Sane;
use Moo;
use Search::Elasticsearch;
use Catmandu::Store::Elasticsearch::Bag;

with 'Catmandu::Store';

=head1 NAME

Catmandu::Store::Elasticsearch - A searchable store backed by Elasticsearch

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use Catmandu::Store::Elasticsearch;

    my $store = Catmandu::Store::Elasticsearch->new(index_name => 'catmandu');

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

    # Catmandu::Store::Elasticsearch supports CQL...
    my $hits = $store->bag->search(cql_query => 'name any "Patrick"');

=cut

has index_name     => (is => 'ro', required => 1);
has index_settings => (is => 'ro', lazy => 1, default => sub { +{} });
has index_mappings => (is => 'ro', lazy => 1, default => sub { +{} });
has _es_args       => (is => 'rw', lazy => 1, default => sub { +{} });
has es             => (is => 'lazy');

sub _build_es {
    my ($self) = @_;
    my $es = Search::Elasticsearch->new($self->_es_args);
    unless ($es->indices->exists(index => $self->index_name)) {
        $es->indices->create(
            index => $self->index_name,
            body  => {
                settings => $self->index_settings,
                mappings => $self->index_mappings,
            },
        );
    }
    $es;
}

sub BUILD {
    my ($self, $args) = @_;
    $self->_es_args($args);
}

sub drop {
    my ($self) = @_;
    $self->es->indices->delete(index => $self->index_name);
}

=head1 METHODS

=head2 new(index_name => $name, cql_mapping => \%mapping)

Create a new Catmandu::Store::Elasticsearch store connected to index $name. The
store supports CQL searches when a cql_mapping is provided. This hash
contains a translation of CQL fields into Elasticsearch searchable fields.

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

For all the operators the 'title' field will be mapping into the Elasticsearch field 'mytitle', except
for the 'exact' operator. In case of 'exact' we will search both the 'mytitle.exact' and 'myalttitle.exact'
fields.

The CQL mapping allows for sorting on the 'title' field. If, for instance, we would like to use a special
Elasticsearch field for sorting we could have written "sort => { field => 'mytitle.sort' }".

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

=head2 drop

Deletes the elasticsearch index backing this store. Calling functions after
this may fail until this class is reinstantiated, creating a new index.

=head1 SEE ALSO

L<Catmandu::Store>

=head1 AUTHOR

Nicolas Steenlant, C<< <nicolas.steenlant at ugent.be> >>

=head1 CONTRIBUTORS

Dave Sherohman, C<< dave.sherohman at ub.lu.se >>
Robin Sheat, C<< robin at kallisti.net.nz >>

=head1 LICENSE AND COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
