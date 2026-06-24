-module(ldf_www_controller).

%% Dispatches to erlydtl-generated view modules (`*_dtl:render/1`) by name.
-elvis([{elvis_style, no_invalid_dynamic_calls, disable}]).

-export([
    receiver_page/1,
    admin_page/1,
    history_page/1,
    receiver_stream/1,
    admin_stream/1,
    add_listener/1,
    remove_listener/1,
    submit_history/1,
    publish_message/2
]).

-define(MESSAGES, ldf_messages).
-define(LISTENERS, ldf_listeners).

%% --- pages ----------------------------------------------------------------

receiver_page(_Req) ->
    page(receiver_dtl, [{active, ~"receiver"}, {live, true}]).

admin_page(_Req) ->
    page(admin_dtl, [{active, ~"admin"}, {live, false}]).

history_page(_Req) ->
    page(history_dtl, [{active, ~"history"}, {live, false}]).

page(Mod, Vars) ->
    Headers = #{
        ~"content-type" => ~"text/html; charset=utf-8",
        ~"cache-control" => ~"no-store"
    },
    {status, 200, Headers, render(Mod, Vars)}.

%% --- live streams ---------------------------------------------------------

receiver_stream(_Req) ->
    {ok, Msgs} = ldf_db:get_messages(),
    {datastar_stream, ?MESSAGES, message_init(Msgs)}.

admin_stream(_Req) ->
    {ok, Listeners} = ldf_db:get_all_li(),
    {datastar_stream, ?LISTENERS, listener_frame(Listeners)}.

%% --- actions --------------------------------------------------------------

add_listener(Req0) ->
    case datastar_nova:read_signals(Req0) of
        {{ok, #{~"type" := Type, ~"value" := Value}}, _Req} when Value =/= ~"" ->
            ldf_srv:add_li(Type, Value),
            broadcast_listeners(),
            {datastar, [datastar:patch_signals(#{~"value" => ~""})]};
        _ ->
            {datastar, []}
    end.

remove_listener(#{bindings := #{~"callbackid" := CallbackId}}) ->
    ldf_srv:remove_li(CallbackId),
    broadcast_listeners(),
    {datastar, []}.

submit_history(Req0) ->
    case datastar_nova:read_signals(Req0) of
        {{ok, #{~"type" := Type, ~"value" := Value} = Signals}, _Req} when Value =/= ~"" ->
            Timestamp = maps:get(~"timestamp", Signals, ~""),
            ldf_srv:get_history(
                thoas:encode(#{type => Type, value => Value, timestamp => Timestamp})
            ),
            status_patch(~"Request submitted.");
        _ ->
            status_patch(~"Target type and value are required.")
    end.

%% --- published by the message API on each intercepted message -------------

publish_message(MessageId, Payload) ->
    Row = render(message_row_dtl, row_vars(ref(MessageId), Payload, true)),
    datastar_nova:publish(?MESSAGES, [
        datastar:patch_elements(~"", #{selector => ~"#feed-empty", mode => remove}),
        datastar:patch_elements(Row, #{selector => ~"#messages", mode => append})
    ]).

%% --- helpers --------------------------------------------------------------

%% Replace (not append) the whole list on connect, so reconnects re-sync
%% instead of duplicating the batch. Live messages still append.
message_init([]) ->
    [datastar:patch_elements(feed_empty(), #{selector => ~"#messages", mode => inner})];
message_init(Msgs) ->
    Rows = [
        render(
            message_row_dtl,
            row_vars(ref(maps:get(message_id, M, ~"")), maps:get(payload, M, ~""), false)
        )
     || M <- Msgs
    ],
    [datastar:patch_elements(Rows, #{selector => ~"#messages", mode => inner})].

feed_empty() ->
    ~"<tr id=\"feed-empty\"><td colspan=\"2\" class=\"empty\">Awaiting interception</td></tr>".

%% The stored payload is the full encoded message; show its inner payload -
%% an attachment URL becomes a clickable link, plain text stays text.
row_vars(Ref, StoredPayload, New) ->
    case display(StoredPayload) of
        {link, Url} -> [{ref, Ref}, {new, New}, {link, Url}, {text, ~""}];
        {text, Text} -> [{ref, Ref}, {new, New}, {link, false}, {text, Text}]
    end.

display(StoredPayload) ->
    try json:decode(StoredPayload) of
        #{~"payload" := #{~"url" := Url}} when is_binary(Url) -> {link, public_url(Url)};
        #{~"payload" := Text} when is_binary(Text) -> {text, Text};
        _ -> {text, StoredPayload}
    catch
        _:_ -> {text, StoredPayload}
    end.

%% Rewrite an attachment URL onto the browser-reachable chatli host,
%% regardless of which host got baked in when it was stored.
public_url(Url) ->
    case binary:split(Url, ~"/chat/") of
        [_Host, Rest] ->
            {ok, Public} = application:get_env(ldf, chatli_public_path),
            <<Public/binary, "/chat/", Rest/binary>>;
        _ ->
            Url
    end.

broadcast_listeners() ->
    {ok, Listeners} = ldf_db:get_all_li(),
    datastar_nova:publish(?LISTENERS, listener_frame(Listeners)).

listener_frame([]) ->
    datastar:patch_elements(
        ~"<tr id=\"li-empty\"><td colspan=\"5\" class=\"empty\">No active listeners</td></tr>",
        #{selector => ~"#listeners", mode => inner}
    );
listener_frame(Listeners) ->
    Rows = [render(listener_row_dtl, [{item, L}, {new, false}]) || L <- Listeners],
    datastar:patch_elements(Rows, #{selector => ~"#listeners", mode => inner}).

status_patch(Text) ->
    Html = [
        ~"<div id=\"hist-status\" style=\"margin-top:16px;color:var(--live);font-size:12.5px\">&#9656; ",
        Text,
        ~"</div>"
    ],
    {datastar, [datastar:patch_elements(Html, #{selector => ~"#hist-status", mode => outer})]}.

render(Mod, Vars) ->
    {ok, Html} = Mod:render(Vars),
    string:trim(iolist_to_binary(Html), trailing).

ref(<<Short:8/binary, _/binary>>) -> Short;
ref(MessageId) when is_binary(MessageId) -> MessageId;
ref(_) -> ~"".
