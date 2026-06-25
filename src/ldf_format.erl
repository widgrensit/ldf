-module(ldf_format).

-export([pretty_xml/1, html_escape/1, datetime_to_ms/1]).

pretty_xml(Xml) ->
    Spaced = binary:replace(Xml, ~"><", ~">\n<", [global]),
    Lines = binary:split(Spaced, ~"\n", [global]),
    iolist_to_binary(lists:join(~"\n", reindent(Lines, 0))).

reindent([], _Depth) ->
    [];
reindent([Line | Rest], Depth) ->
    {Out, Next} = format_line(Line, Depth),
    [Out | reindent(Rest, Next)].

format_line(<<"</", _/binary>> = Line, Depth) ->
    Indent = max(Depth - 1, 0),
    {[pad(Indent), Line], Indent};
format_line(<<"<?", _/binary>> = Line, Depth) ->
    {[pad(Depth), Line], Depth};
format_line(<<"<", _/binary>> = Line, Depth) ->
    case self_contained(Line) of
        true -> {[pad(Depth), Line], Depth};
        false -> {[pad(Depth), Line], Depth + 1}
    end;
format_line(Line, Depth) ->
    {[pad(Depth), Line], Depth}.

self_contained(Line) ->
    Closes = binary:match(Line, ~"</") =/= nomatch,
    Empty = byte_size(Line) >= 2 andalso binary:part(Line, byte_size(Line) - 2, 2) =:= ~"/>",
    Closes orelse Empty.

pad(N) ->
    binary:copy(~"  ", N).

html_escape(Bin) ->
    Amp = binary:replace(Bin, ~"&", ~"&amp;", [global]),
    Lt = binary:replace(Amp, ~"<", ~"&lt;", [global]),
    binary:replace(Lt, ~">", ~"&gt;", [global]).

datetime_to_ms(
    <<Y:4/binary, "-", Mo:2/binary, "-", D:2/binary, "T", H:2/binary, ":", Mi:2/binary, Rest/binary>>
) ->
    Seconds =
        case Rest of
            <<":", S:2/binary>> -> binary_to_integer(S);
            _ -> 0
        end,
    DateTime = {
        {binary_to_integer(Y), binary_to_integer(Mo), binary_to_integer(D)},
        {binary_to_integer(H), binary_to_integer(Mi), Seconds}
    },
    Epoch = 62167219200,
    (calendar:datetime_to_gregorian_seconds(DateTime) - Epoch) * 1000;
datetime_to_ms(_) ->
    0.
