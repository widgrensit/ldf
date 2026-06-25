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
    message_etsi/1,
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
            Timestamp = ldf_format:datetime_to_ms(maps:get(~"timestamp", Signals, ~"")),
            ldf_srv:get_history(
                thoas:encode(#{type => Type, value => Value, timestamp => Timestamp})
            ),
            status_patch(~"Request submitted.");
        _ ->
            status_patch(~"Target type and value are required.")
    end.

%% Convert a stored message to the requested ETSI XML and inject it, pretty
%% printed, under its row. Any other format (e.g. "hide") clears the block.
message_etsi(#{bindings := #{~"messageid" := MessageId, ~"format" := Format}}) when
    Format =:= ~"103707"; Format =:= ~"103120"
->
    Block =
        case ldf_db:get_message(MessageId) of
            {ok, [#{payload := Payload} | _]} ->
                render_etsi(Format, MessageId, safe_decode(Payload));
            _ ->
                etsi_error(~"Message not found.")
        end,
    {datastar, [patch_xml(MessageId, Block)]};
message_etsi(#{bindings := #{~"messageid" := MessageId}}) ->
    {datastar, [patch_xml(MessageId, ~"")]}.

%% --- published by the message API on each intercepted message -------------

publish_message(_MessageId, Payload) ->
    Row = render(message_row_dtl, row_vars(Payload, true)),
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
    Rows = [render(message_row_dtl, row_vars(maps:get(payload, M, ~""), false)) || M <- Msgs],
    [datastar:patch_elements(Rows, #{selector => ~"#messages", mode => inner})].

feed_empty() ->
    ~"<div id=\"feed-empty\" class=\"empty\">Awaiting interception</div>".

%% The stored payload is the full encoded message; expand every field for a
%% structured record. The inner payload renders as text, or a clickable link
%% for attachments.
row_vars(StoredPayload, New) ->
    case safe_decode(StoredPayload) of
        Msg when is_map(Msg) ->
            [{new, New} | fields(Msg)];
        _ ->
            [{new, New}, {text, StoredPayload}, {link, false} | blank_fields()]
    end.

fields(Msg) ->
    SenderInfo = maps:get(~"sender_info", Msg, #{}),
    Payload =
        case maps:get(~"payload", Msg, ~"") of
            #{~"url" := Url} when is_binary(Url) -> [{link, public_url(Url)}, {text, ~""}];
            Text when is_binary(Text) -> [{link, false}, {text, Text}];
            _ -> [{link, false}, {text, ~""}]
        end,
    [
        {email, maps:get(~"email", SenderInfo, ~"")},
        {phone, maps:get(~"phone_number", SenderInfo, ~"")},
        {agent, maps:get(~"user_agent", SenderInfo, ~"")},
        {time, fmt_time(maps:get(~"timestamp", Msg, undefined))},
        {type, maps:get(~"type", Msg, ~"")},
        {action, maps:get(~"action", Msg, ~"")},
        {sender, short(maps:get(~"sender", Msg, ~""))},
        {recipient, short(maps:get(~"to", Msg, ~""))},
        {chat, short(maps:get(~"chat_id", Msg, ~""))},
        {id, short(maps:get(~"id", Msg, ~""))},
        {full_id, maps:get(~"id", Msg, ~"")}
        | Payload
    ].

blank_fields() ->
    [
        {email, ~""},
        {phone, ~""},
        {agent, ~""},
        {time, ~""},
        {type, ~""},
        {action, ~""},
        {sender, ~""},
        {recipient, ~""},
        {chat, ~""},
        {id, ~""},
        {full_id, ~""}
    ].

safe_decode(Bin) ->
    try json:decode(Bin) of
        Decoded -> Decoded
    catch
        _:_ -> error
    end.

fmt_time(Ms) when is_integer(Ms) ->
    list_to_binary(calendar:system_time_to_rfc3339(Ms div 1000, [{offset, "Z"}]));
fmt_time(_) ->
    ~"".

patch_xml(MessageId, Block) ->
    datastar:patch_elements(Block, #{selector => <<"#xml-", MessageId/binary>>, mode => inner}).

render_etsi(Format, MessageId, Msg) when is_map(Msg) ->
    try to_etsi(Format, Msg) of
        Xml ->
            etsi_block(Format, MessageId, ldf_format:html_escape(ldf_format:pretty_xml(Xml)))
    catch
        _:_ -> etsi_error(~"Could not convert this message.")
    end;
render_etsi(_Format, _MessageId, _Msg) ->
    etsi_error(~"Malformed message payload.").

to_etsi(~"103120", Msg) ->
    etsi103120:json_to_xml(Msg, ~"undefined", ~"undefined", ~"undefined");
to_etsi(_, Msg) ->
    etsi103707:json_to_xml(Msg).

etsi_block(Format, MessageId, EscapedXml) ->
    iolist_to_binary([
        ~"<div class=\"etsi-bar\"><span class=\"etsi-label\">ETSI ",
        Format,
        ~"</span><button class=\"etsi-btn etsi-copy\" data-on:click=\"navigator.clipboard.writeText(el.closest('.etsi').querySelector('code').textContent);el.textContent='copied';setTimeout(()=>el.textContent='copy',1200)\">copy</button>",
        ~"<button class=\"btn-ghost etsi-hide\" data-on:click=\"@get('/www/message/",
        MessageId,
        ~"/hide')\">hide</button></div><pre class=\"etsi-pre\"><code>",
        EscapedXml,
        ~"</code></pre>"
    ]).

etsi_error(Text) ->
    iolist_to_binary([
        ~"<div class=\"etsi-bar\"><span class=\"etsi-label etsi-err\">", Text, ~"</span></div>"
    ]).

short(<<Eight:8/binary, _/binary>>) -> Eight;
short(Bin) when is_binary(Bin) -> Bin;
short(_) -> ~"".

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
