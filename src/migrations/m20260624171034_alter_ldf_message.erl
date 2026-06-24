-module(m20260624171034_alter_ldf_message).
-moduledoc false.
-behaviour(kura_migration).
-include_lib("kura/include/kura.hrl").
-export([up/0, down/0]).

-spec up() -> [kura_migration:operation()].
up() ->
    [{alter_table, ~"ldf_message", [
        {modify_column, payload, text}
    ]}].

-spec down() -> [kura_migration:operation()].
down() ->
    [{alter_table, ~"ldf_message", [
        {modify_column, payload, string}
    ]}].
