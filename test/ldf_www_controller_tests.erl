-module(ldf_www_controller_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("nova/include/nova_pubsub.hrl").

-define(MESSAGE_ID, ~"1e87fd7c-de4f-4e97-be27-2bdcdbad23b7").

hiding_a_message_clears_its_block_test() ->
    {datastar, Events} = ldf_www_controller:message_etsi(request(?MESSAGE_ID, ~"hide")),
    [Event] = sse_events(iolist_to_binary(Events)),
    ?assertEqual([~"#xml-1e87fd7c-de4f-4e97-be27-2bdcdbad23b7"], data(~"selector", Event)),
    ?assertEqual([~"inner"], data(~"mode", Event)).

upper_case_message_id_is_accepted_test() ->
    Id = ~"1E87FD7C-DE4F-4E97-BE27-2BDCDBAD23B7",
    {datastar, Events} = ldf_www_controller:message_etsi(request(Id, ~"hide")),
    [Event] = sse_events(iolist_to_binary(Events)),
    ?assertEqual([~"#xml-1E87FD7C-DE4F-4E97-BE27-2BDCDBAD23B7"], data(~"selector", Event)).

message_id_that_is_not_a_uuid_is_not_found_test_() ->
    [
        ?_assertEqual({status, 404}, ldf_www_controller:message_etsi(request(Id, Format)))
     || Id <- [
            ~"1e87fd7c-de4f-4e97-be27-2bdcdbad23b7\n",
            ~"1e87fd7c\nde4f-4e97-be27-2bdcdbad23b7",
            ~"1e87fd7c-de4f-4e97-be27-2bdcdbad23b7\r\nevent: x",
            ~"1e87fd7c-de4f-4e97-be27-2bdcdbad23b7, body",
            ~"1e87fd7c-de4f-4e97-be27-2bdcdbad23bg",
            ~"1e87fd7cde4f4e97be272bdcdbad23b7",
            ~""
        ],
        Format <- [~"hide", ~"103707", ~"103120"]
    ].

line_breaks_in_a_message_text_stay_inside_the_row_event_test() ->
    ok = nova_pubsub:start(),
    ok = nova_pubsub:join(ldf_messages),
    Message = #{~"id" => ?MESSAGE_ID, ~"payload" => ~"one\r\ntwo\rthree\nfour"},
    ldf_www_controller:publish_message(?MESSAGE_ID, iolist_to_binary(json:encode(Message))),
    Stream =
        receive
            #nova_pubsub{channel = ldf_messages, payload = Events} -> iolist_to_binary(Events)
        after 1000 -> error(nothing_published)
        end,
    nova_pubsub:leave(ldf_messages),
    [Placeholder, Row] = sse_events(Stream),
    ?assertEqual([~"data", ~"event"], field_names(Placeholder)),
    ?assertEqual([~"#feed-empty"], data(~"selector", Placeholder)),
    ?assertEqual([~"data", ~"event"], field_names(Row)),
    ?assertEqual([~"#messages"], data(~"selector", Row)),
    ?assertEqual([~"append"], data(~"mode", Row)),
    Html = elements(Row),
    ?assertMatch({0, _}, binary:match(Html, ~"<div class=\"rec new\">")),
    ?assertMatch(
        {_, _},
        binary:match(Html, ~"<div class=\"rec-body\">one\ntwo\nthree\nfour</div>")
    ),
    ?assertEqual(~"class=\"etsi\"></div></div>", binary:part(Html, byte_size(Html), -25)).

request(MessageId, Format) ->
    #{bindings => #{~"messageid" => MessageId, ~"format" => Format}}.

%% Reads a stream the way an EventSource client does: a line ends at CRLF,
%% CR or LF, an empty line ends an event, and a line without a colon is a
%% field with an empty value.
sse_events(Stream) ->
    events(binary:split(Stream, [~"\r\n", ~"\r", ~"\n"], [global]), []).

events([], _Unfinished) ->
    [];
events([~"" | Lines], []) ->
    events(Lines, []);
events([~"" | Lines], Fields) ->
    [lists:reverse(Fields) | events(Lines, [])];
events([Line | Lines], Fields) ->
    events(Lines, [field(Line) | Fields]).

field(Line) ->
    case binary:split(Line, ~":") of
        [Name, <<$\s, Value/binary>>] -> {Name, Value};
        [Name, Value] -> {Name, Value};
        [Name] -> {Name, ~""}
    end.

field_names(Event) ->
    lists:usort([Name || {Name, _Value} <- Event]).

-spec data(binary(), [{binary(), binary()}]) -> [binary()].
data(Kind, Event) ->
    [
        Rest
     || {~"data", Value} <- Event, [Found, Rest] <- [binary:split(Value, ~" ")], Found =:= Kind
    ].

-spec elements([{binary(), binary()}]) -> binary().
elements(Event) ->
    Data = iolist_to_binary([[Line, $\n] || Line <- data(~"elements", Event)]),
    binary:part(Data, 0, byte_size(Data) - 1).
