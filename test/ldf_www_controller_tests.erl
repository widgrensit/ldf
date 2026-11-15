-module(ldf_www_controller_tests).

-include_lib("eunit/include/eunit.hrl").

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

-spec data(binary(), [{binary(), binary()}]) -> [binary()].
data(Kind, Event) ->
    [
        Rest
     || {~"data", Value} <- Event, [Found, Rest] <- [binary:split(Value, ~" ")], Found =:= Kind
    ].
