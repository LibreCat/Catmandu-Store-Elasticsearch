# NAME

Catmandu::Store::ElasticSearch - A searchable store backed by Elasticsearch

# SYNOPSIS

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

    # Catmandu::Store::ElasticSearch supports CQL...
    my $hits = $store->bag->search(cql_query => 'name any "Patrick"');

# METHODS

## new(index\_name => $name)

## new(index\_name => $name , bags => { data => { cql\_mapping => \\%mapping } })

## new(index\_name => $name , index\_mapping => $mapping)

Create a new Catmandu::Store::ElasticSearch store connected to index $name.

The store supports CQL searches when a cql\_mapping is provided. This hash
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
augment the search query. In this case, in the Biblio::Search package there is a normalize\_title
subroutine which returns a string or an ARRAY of string with augmented title(s). E.g.

    package Biblio::Search;

    sub normalize_title {
       my ($self,$title) = @_;
       my $new_title =~ s{[^A-Z0-9]+}{}g;
       $new_title;
    }

    1;

Optionally, index\_mappings contain Elasticsearch schema mappings. E.g.

    # The 'data' index can ony contain one field 'title' of type 'string'
    index_mappings => {
        data => {
            dynamic => 'strict',
            properties => {
                title => { type => 'string' }
            }
        }
    }

## drop

Deletes the Elasticsearch index backing this store. Calling functions after
this may fail until this class is reinstantiated, creating a new index.

# COMPATIBILITY

This store expects version 1.0 or higher of the Elasticsearch server.

Note that Elasticsearch >= 2.0 doesn't like keys that start with an underscore such as
`_id`. You can use the `key_prefix` option at store level or `id_prefix` at
bag level to handle this.

    # in your catmandu.yml
    store:
      yourstore:
        package: ElasticSearch
        options:
          # use my_id instead of _id
          key_prefix: my_

If you want to use the `delete_by_query` method with Elasticsearch >= 2.0 you
will have to [install the delete by query plugin](https://www.elastic.co/guide/en/elasticsearch/plugins/current/plugins-delete-by-query.html).

# MIGRATING A STORE FROM ELASTICSEARCH 1.0 TO 2.0 OR HIGHER

1\. backup your data as JSON

    catmandu export yourstore --bag yourbag to --file /path/to/yourbag.json -v

2\. drop the store

    catmandu drop yourstore

3\. upgrade the Elasticsearch server

4\. update your catmandu.yml with a `key_prefix` or `id_prefix` (see COMPATIBILITY)

5\. import your data using the new keys specified in your catmandu.yml

    catmandu import --file /path/to/yourbag.json --fix 'move_field(_id, my_id)' \
    to yourstore --bag yourbag -v

# ERROR HANDLING

Error handling can be activated by specifying an error handling callback for index when creating
a store. E.g. to create an error handler for the bag 'data' index use:

    my $store = Catmandu::Store::ElasticSearch->new(
                    index_name => 'catmandu'
                    bags => { data => { on_error => \&error_handler } }
                 });

    sub error_handler {
        my ($action, $response, $i) = @_;
    }

# SEE ALSO

[Catmandu::Store](https://metacpan.org/pod/Catmandu::Store)

# AUTHOR

Nicolas Steenlant, `<nicolas.steenlant at ugent.be>`

# CONTRIBUTORS

- Dave Sherohman, `dave.sherohman at ub.lu.se`
- Robin Sheat, `robin at kallisti.net.nz`
- Patrick Hochstenbach, `patrick.hochstenbach at ugent.be`

# LICENSE AND COPYRIGHT

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
