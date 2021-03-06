%% A wrapper around the Erlasticsearch library that integrates it with Zotonic
-module(elasticsearch).
-author("Driebit <tech@driebit.nl>").

-export([
    connection/0,
    index/1,
    put_doc/2,
    put_doc/3,
    put_doc/5,
    put_mapping/3,
    put_mapping/4,
    delete_doc/2,
    delete_doc/3,
    delete_doc/4,
    get_doc/3,
    handle_response/1
]).

-include("zotonic.hrl").
-include("deps/erlastic_search/include/erlastic_search.hrl").
-include("../include/elasticsearch.hrl").

%% Get Elasticsearch connection params from config
connection() ->
    EsHost = application:get_env(erlastic_search, host, z_config:get(elasticsearch_host, <<"127.0.0.1">>)),
    EsPort = application:get_env(erlastic_search, port, z_config:get(elasticsearch_port, 9200)),
    #erls_params{host=EsHost, port=EsPort, http_client_options=[{pool, mod_elasticsearch:pool()}]}.

%% Get Elasticsearch index name from config; defaults to site name
-spec index(z:context()) -> binary().
index(Context) ->
    SiteName = z_context:site(Context),
    IndexName = case m_config:get_value(mod_elasticsearch, index, Context) of
        undefined -> SiteName;
        <<>> -> SiteName;
        Value -> Value
    end,
    z_convert:to_binary(IndexName).

%% Create Elasticsearch mapping
put_mapping(Type, Doc, Context) ->
    put_mapping(index(Context), Type, Doc, Context).

put_mapping(Index, Type, Doc, _Context) ->
    Response = erlastic_search:put_mapping(connection(), Index, Type, Doc),
    handle_response(Response).

%% Save a resource to Elasticsearch
put_doc(Id, Context) ->
    put_doc(index(Context), Id, Context).

put_doc(Index, Id, Context) ->
    % All resource properties
    Props = elasticsearch_mapping:map_rsc(Id, Context),
    put_doc(Index, <<"resource">>, z_convert:to_binary(Id), Props, Context).

put_doc(Index, Type, Id, Data, Context) ->
    NotifiedData = z_notifier:foldl(#elasticsearch_put{index = Index, type = Type, id = Id}, Data, Context),
    Response = erlastic_search:index_doc_with_id(connection(), Index, Type, Id, NotifiedData),
    handle_response(Response).

delete_doc(Id, Context) ->
    delete_doc(Id, index(Context), Context).

delete_doc(Id, Index, _Context) ->
    Response = erlastic_search:delete_doc(
                 connection(),
                 Index, "resource", z_convert:to_binary(Id)
    ),
    handle_response(Response).

delete_doc(Id, Type, Index, _Context) ->
    Response = erlastic_search:delete_doc(
                 connection(), Index, Type, Id
    ),
    handle_response(Response).

%% Handle Elasticsearch response
handle_response(Response) ->
    case Response of
        {error, {StatusCode, Error}} ->
            lager:error(
                "Elasticsearch error: ~p: ~p with connection ~p",
                [StatusCode, Error, connection()]
            ),
            Response;
        {error, Reason} ->
            lager:error(
                "Elasticsearch error: ~p with connection ~p",
                [Reason, connection()]
            ),
            Response;
        {ok, _} ->
            Response
    end.

%% Fetch a single document by type and Id
get_doc(Index, Type, Id) ->
    erlastic_search:get_doc(connection(), Index, Type, Id).
