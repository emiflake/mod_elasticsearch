-module(mod_elasticsearch).
-author("Driebit <tech@driebit.nl>").

-mod_title("Elasticsearch module").
-mod_description("Elasticsearch integration for Zotonic").
-mod_prio(500).

-behaviour(gen_server).

-export([
    pid_observe_rsc_pivot_done/3,
    pid_observe_rsc_delete/3,
    pid_observe_search_query/3,
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3,
    start_link/1
]).

-include("zotonic.hrl").

-record(state, {context}).

start_link(Args) when is_list(Args) ->
    gen_server:start_link(?MODULE, Args, []).

pid_observe_rsc_pivot_done(Pid, Msg, _Context) ->
    gen_server:cast(Pid, Msg).

pid_observe_rsc_delete(Pid, Msg, _Context) ->
    gen_server:cast(Pid, Msg).

pid_observe_search_query(Pid, #search_query{} = Search, Context) ->
    gen_server:call(Pid, {Search, Context}).

%% gen_server callbacks
init(Args) ->
    application:ensure_all_started(erlastic_search),
    {context, Context} = proplists:lookup(context, Args),

    elasticsearch:ensure_index(elasticsearch:index(Context)),

    %% Create default mapping
    DefaultMapping = elasticsearch_mapping:default_mapping(resource, Context),
    {ok, _} = elasticsearch:put_mapping("resource", DefaultMapping, Context),

    {ok, #state{context = z_context:new(Context)}}.

handle_call({#search_query{} = Search, Context}, _From, State) ->
    {reply, search(Search, Context), State};
handle_call(Message, _From, State) ->
    {stop, {unknown_call, Message}, State}.

handle_cast(#rsc_pivot_done{id = Id}, State = #state{context = Context}) ->
    elasticsearch:put_doc(Id, Context),
    {noreply, State};
handle_cast(#rsc_delete{id = Id}, State = #state{context = Context}) ->
    elasticsearch:delete_doc(Id, Context),
    {noreply, State};
handle_cast(Msg, State) ->
    {stop, {unknown_cast, Msg}, State}.

handle_info(_Info, State) ->
    {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

%% @doc Only handle 'elastic' and 'query' search types
search(#search_query{search = {elastic, _Query}} = Search, Context) ->
    elasticsearch_search:search(Search, Context);
search(#search_query{search = {query, _Query}} = Search, Context) ->
    elasticsearch_search:search(Search, Context);
search(_Search, _Context) ->
    undefined.
