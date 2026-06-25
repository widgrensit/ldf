-module(ldf_format_tests).

-include_lib("eunit/include/eunit.hrl").

pretty_xml_test() ->
    ?assertEqual(
        ~"<a>\n  <b>x</b>\n</a>",
        ldf_format:pretty_xml(~"<a><b>x</b></a>")
    ).

pretty_xml_with_prolog_test() ->
    ?assertEqual(
        ~"<?xml version=\"1.0\"?>\n<a>\n  <b>1</b>\n</a>",
        ldf_format:pretty_xml(~"<?xml version=\"1.0\"?><a><b>1</b></a>")
    ).

html_escape_test() ->
    ?assertEqual(~"&lt;a&gt;&amp;b", ldf_format:html_escape(~"<a>&b")).

datetime_to_ms_with_seconds_test() ->
    Expected =
        (calendar:datetime_to_gregorian_seconds({{2024, 6, 25}, {15, 0, 30}}) - 62167219200) *
            1000,
    ?assertEqual(Expected, ldf_format:datetime_to_ms(~"2024-06-25T15:00:30")).

datetime_to_ms_without_seconds_test() ->
    Expected =
        (calendar:datetime_to_gregorian_seconds({{2024, 6, 25}, {15, 0, 0}}) - 62167219200) *
            1000,
    ?assertEqual(Expected, ldf_format:datetime_to_ms(~"2024-06-25T15:00")).

datetime_to_ms_empty_test() ->
    ?assertEqual(0, ldf_format:datetime_to_ms(~"")).
