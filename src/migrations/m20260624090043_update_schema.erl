-module(m20260624090043_update_schema).
-moduledoc false.
-behaviour(kura_migration).
-include_lib("kura/include/kura.hrl").
-export([up/0, down/0]).

-spec up() -> [kura_migration:operation()].
up() ->
    [{create_table, ~"ldf_message", [
        #kura_column{name = id, type = id, primary_key = true},
        #kura_column{name = message_id, type = uuid, nullable = false},
        #kura_column{name = payload, type = string},
        #kura_column{name = content_length, type = string}
    ]},
     {create_table, ~"li", [
        #kura_column{name = id, type = id, primary_key = true},
        #kura_column{name = type, type = string, nullable = false},
        #kura_column{name = value, type = string, nullable = false},
        #kura_column{name = callback_id, type = uuid, nullable = false},
        #kura_column{name = user_id, type = uuid, nullable = false},
        #kura_column{name = username, type = string},
        #kura_column{name = phone_number, type = string},
        #kura_column{name = email, type = string}
    ]}].

-spec down() -> [kura_migration:operation()].
down() ->
    [{drop_table, ~"ldf_message"},
     {drop_table, ~"li"}].
