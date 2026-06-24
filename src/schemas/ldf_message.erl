-module(ldf_message).
-behaviour(kura_schema).

-include_lib("kura/include/kura.hrl").

-export([table/0, fields/0]).

table() -> ~"ldf_message".

fields() -> [
    #kura_field{name = id, type = id, primary_key = true},
    #kura_field{name = message_id, type = uuid, nullable = false},
    #kura_field{name = payload, type = string},
    #kura_field{name = content_length, type = string}
].
