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
