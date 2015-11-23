%%% @doc Base GET|PUT|DELETE /[entity]s/:id implementation
-module(sr_single_entity_handler).

-include_lib("mixer/include/mixer.hrl").
-mixin([{ sr_entities_handler
        , [ init/3
          , allowed_methods/2
          , content_types_provided/2
          , announce_req/2
          , handle_exception/3
          ]
        }]).

-export([ rest_init/2
        , resource_exists/2
        , content_types_accepted/2
        , handle_get/2
        , handle_put/2
        , delete_resource/2
        ]).

-type options() :: #{ path => string()
                    , model => module()
                    , verbose => boolean()
                    }.
-type state() :: #{ opts => options()
                  , id => binary()
                  , entity => sumo:user_doc()
                  }.
-export_type([state/0, options/0]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Cowboy Callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec rest_init(cowboy_req:req(), options()) ->
  {ok, cowboy_req:req(), state()}.
rest_init(Req, Opts) ->
  Req1 = announce_req(Req, Opts),
  {Id, Req2} = cowboy_req:binding(id, Req1),
  {ok, Req2, #{opts => Opts, id => Id}}.

-spec resource_exists(cowboy_req:req(), state()) ->
  {boolean(), cowboy_req:req(), state()}.
resource_exists(Req, State) ->
  #{opts := #{model := Model}, id := Id} = State,
  case sumo:find(Model, Id) of
    notfound -> {false, Req, State};
    Entity -> {true, Req, State#{entity => Entity}}
  end.

%% @todo Use swagger's 'consumes' to auto-generate this if possible
%% @see https://github.com/inaka/sumo_rest/issues/7
-spec content_types_accepted(cowboy_req:req(), state()) ->
  {[{{binary(), binary(), '*'}, atom()}], cowboy_req:req(), state()}.
content_types_accepted(Req, State) ->
  {[{{<<"application">>, <<"json">>, '*'}, handle_put}], Req, State}.

-spec handle_get(cowboy_req:req(), state()) ->
  {iodata(), cowboy_req:req(), state()}.
handle_get(Req, State) ->
  #{opts := #{model := Model}, entity := Entity} = State,
  ResBody = sr_json:encode(Model:to_json(Entity)),
  {ResBody, Req, State}.

-spec handle_put(cowboy_req:req(), state()) ->
  {{true, binary()} | false | halt, cowboy_req:req(), state()}.
handle_put(Req, #{entity := Entity} = State) ->
  #{opts := #{model := Model}} = State,
  try
    {ok, Body, Req1} = cowboy_req:body(Req),
    Json             = sr_json:decode(Body),
    handle_put(Model:update(Entity, Json), Req1, State)
  catch
    _:badjson ->
      Req3 = cowboy_req:set_resp_body(<<"Malformed JSON request">>, Req),
      {false, Req3, State};
    _:Exception -> handle_exception(Exception, Req, State)
  end;
handle_put(Req, #{id := Id} = State) ->
  #{opts := #{model := Model}} = State,
  try
    {ok, Body, Req1} = cowboy_req:body(Req),
    Json             = sr_json:decode(Body),
    handle_put(from_json(Model, Id, Json), Req1, State)
  catch
    _:badjson ->
      Req3 = cowboy_req:set_resp_body(<<"Malformed JSON request">>, Req),
      {false, Req3, State};
    _:Exception -> handle_exception(Exception, Req, State)
  end.

-spec delete_resource(cowboy_req:req(), state()) ->
  {boolean() | halt, cowboy_req:req(), state()}.
delete_resource(Req, State) ->
  #{opts := #{model := Model}, id := Id} = State,
  try
    Result = sumo:delete(Model, Id),
    {Result, Req, State}
  catch
    _:Exception -> handle_exception(Exception, Req, State)
  end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Auxiliary Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
from_json(Model, Id, Json) ->
  case erlang:function_exported(Model, from_json, 2) of
    true -> Model:from_json(Id, Json);
    false -> Model:from_json(Json)
  end.

handle_put({error, Reason}, Req, State) ->
  Req1 = cowboy_req:set_resp_body(Reason, Req),
  {false, Req1, State};
handle_put({ok, Entity}, Req1, State) ->
  #{opts := #{model := Model}} = State,
  PersistedEntity = sumo:persist(Model, Entity),
  ResBody = sr_json:encode(Model:to_json(PersistedEntity)),
  Req2 = cowboy_req:set_resp_body(ResBody, Req1),
  {true, Req2, State}.
