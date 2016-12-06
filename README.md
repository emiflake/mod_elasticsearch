mod_elasticsearch
=================

Add [tsloughter/erlastic_search](https://github.com/tsloughter/erlastic_search) and its
dependencies at their proper version (for Erlang 18) to your Zotonic deps in `zotonic.config`:

```erlang
{deps, [
    %% ...
    {erlastic_search, ".*", {git, "https://github.com/tsloughter/erlastic_search.git", {tag, "master"}}},
    {hackney, ".*", {git, "https://github.com/benoitc/hackney.git", {tag, "1.6.1"}}},
    {jsx, ".*", {git, "https://github.com/talentdeficit/jsx.git", {tag, "2.8.0"}}}      
]}
```

Search queries
--------------

When mod_elasticsearch is enabled, it will direct all search operations of the 
query type to Elasticsearch:

```erlang
z_search:search({query, Args}, Context).
```

For `Args`, you can pass all regular Zotonic [query arguments](http://docs.zotonic.com/en/latest/developer-guide/search.html#query-arguments),
such as:

```erlang
z_search:search({query, [{hasobject, 507}]}, Context).
````

Notifications
-------------

### elasticsearch_put

Observe this notification to change the resource properties before they are
stored in Elasticsearch. For instance, to store their zodiac sign alongside 
person resources:

```erlang
%% your_site.erl

-export([
    % ...
    observe_elasticsearch_put/3
]).

observe_elasticsearch_put({elasticsearch_put, Id}, Props, Context) ->
    case m_rsc:is_a(Id, person, Context) of
        true ->
            Props ++ [{zodiac, calculate_zodiac(Id, Context)}];
        false ->
            Props
    end.
```

How resources are indexed
-------------------------

Content in all languages is stored in the index, following the 
[one language per field](https://www.elastic.co/guide/en/elasticsearch/guide/current/one-lang-fields.html)
strategy: 

> Each translation is stored in a separate field, which is analyzed according to
> the language it contains. At query time, the user’s language is used to boost
> fields in that particular language.

