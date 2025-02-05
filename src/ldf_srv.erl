-module(ldf_srv).

-behaviour(gen_server).

%% API
-export([
    start_link/0,
    add_li/2,
    remove_li/1,
    get_all_li/0,
    get_history/1
]).

%% gen_server callbacks
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3,
    format_status/1
]).

-define(SERVER, ?MODULE).

-record(state, {}).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%% @end
%%--------------------------------------------------------------------
-spec start_link() ->
    {ok, Pid :: pid()}
    | {error, Error :: {already_started, pid()}}
    | {error, Error :: term()}
    | ignore.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

add_li(Type, Value) ->
    gen_server:call(?MODULE, {add, Type, Value}).

get_history(Json) ->
    gen_server:call(?MODULE, {history, Json}).

remove_li(Id) ->
    gen_server:call(?MODULE, {remove, Id}).

get_all_li() ->
    gen_server:call(?MODULE, get_all).
%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%% @end
%%--------------------------------------------------------------------
-spec init(Args :: term()) ->
    {ok, State :: term()}
    | {ok, State :: term(), Timeout :: timeout()}
    | {ok, State :: term(), hibernate}
    | {stop, Reason :: term()}
    | ignore.
init([]) ->
    process_flag(trap_exit, true),
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request :: term(), From :: {pid(), term()}, State :: term()) ->
    {reply, Reply :: term(), NewState :: term()}
    | {reply, Reply :: term(), NewState :: term(), Timeout :: timeout()}
    | {reply, Reply :: term(), NewState :: term(), hibernate}
    | {noreply, NewState :: term()}
    | {noreply, NewState :: term(), Timeout :: timeout()}
    | {noreply, NewState :: term(), hibernate}
    | {stop, Reason :: term(), Reply :: term(), NewState :: term()}
    | {stop, Reason :: term(), NewState :: term()}.
handle_call({add, Type, Value}, _, State) ->
    Url =
        case application:get_env(ldf, ldf_callback) of
            {ok, Config} ->
                Config;
            undefined ->
                {ok, IfConfig} = inet:getifaddrs(),
                Eth0 = proplists:get_value("eth0", IfConfig),
                [IP] = [{A, B, C, D} || {addr, {A, B, C, D}} <- Eth0],
                IP2 = list_to_binary(inet:ntoa(IP)),
                <<"http://", IP2/binary, ":8095/receiver">>
        end,
    Object = #{
        <<"type">> => Type,
        <<"value">> => Value,
        <<"url">> => Url
    },
    {ok, ChatliPath} = application:get_env(ldf, chatli_path),
    case
        jhn_shttpc:post(
            [ChatliPath, <<"/callback">>],
            thoas:encode(Object),
            #{headers => #{'Content-Type' => <<"application/json">>}, close => true}
        )
    of
        #{status := {404, _}} ->
            {reply, undefined, State};
        #{status := {200, _}, body := RespBody} ->
            {ok, #{
                <<"id">> := CallbackId,
                <<"user_id">> := UserId,
                <<"username">> := Username,
                <<"phone_number">> := PhoneNumber,
                <<"email">> := Email
            }} = thoas:decode(RespBody),
            ok = ldf_db:add_li(Type, Value, CallbackId, UserId, Username, PhoneNumber, Email),
            {reply, #{callback_id => CallbackId}, State}
    end;
handle_call({remove, CallbackId}, _, State) ->
    {ok, ChatliPath} = application:get_env(ldf, chatli_path),
    #{status := {200, _}} = jhn_shttpc:delete(
        [ChatliPath, <<"/callback">>, <<"/">>, CallbackId],
        #{
            headers => #{'Content-Type' => <<"application/json">>},
            close => true
        }
    ),
    ok = ldf_db:remove_li(CallbackId),
    {reply, #{status => ok}, State};
handle_call(get_all, _, State) ->
    {ok, List} = ldf_db:get_all_li(),
    {reply, List, State};
handle_call({history, Json}, _, State) ->
    {ok, ChatliPath} = application:get_env(ldf, chatli_path),
    #{status := {200, _}} = jhn_shttpc:post(
        [ChatliPath, <<"/history">>],
        Json,
        #{
            headers => #{'Content-Type' => <<"application/json">>},
            close => true
        }
    ),
    {reply, ok, State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_cast(Request :: term(), State :: term()) ->
    {noreply, NewState :: term()}
    | {noreply, NewState :: term(), Timeout :: timeout()}
    | {noreply, NewState :: term(), hibernate}
    | {stop, Reason :: term(), NewState :: term()}.
handle_cast(_Request, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%% @end
%%--------------------------------------------------------------------
-spec handle_info(Info :: timeout() | term(), State :: term()) ->
    {noreply, NewState :: term()}
    | {noreply, NewState :: term(), Timeout :: timeout()}
    | {noreply, NewState :: term(), hibernate}
    | {stop, Reason :: normal | term(), NewState :: term()}.
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%% @end
%%--------------------------------------------------------------------
-spec terminate(
    Reason :: normal | shutdown | {shutdown, term()} | term(),
    State :: term()
) -> any().
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%% @end
%%--------------------------------------------------------------------
-spec code_change(
    OldVsn :: term() | {down, term()},
    State :: term(),
    Extra :: term()
) ->
    {ok, NewState :: term()}
    | {error, Reason :: term()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called for changing the form and appearance
%% of gen_server status when it is returned from sys:get_status/1,2
%% or when it appears in termination error logs.
%% @end
%%--------------------------------------------------------------------
format_status(Status) ->
    Status.

%%%===================================================================
%%% Internal functions
%%%===================================================================
