-module(li).
-behaviour(kura_schema).

-include_lib("kura/include/kura.hrl").

-export([table/0, fields/0]).

table() -> ~"li".

fields() -> [
    #kura_field{name = id, type = id, primary_key = true},
    #kura_field{name = type, type = string, nullable = false},
    #kura_field{name = value, type = string, nullable = false},
    #kura_field{name = callback_id, type = uuid, nullable = false},
    #kura_field{name = user_id, type = uuid, nullable = false},
    #kura_field{name = username, type = string},
    #kura_field{name = phone_number, type = string},
    #kura_field{name = email, type = string}
].
