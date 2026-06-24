-module(ldf_db).

-export([
    get_all_li/0,
    get_li_user_id/1,
    add_li/7,
    find_li/2,
    remove_li/1,
    add_message/2,
    get_messages/0,
    get_message/1
]).

-include_lib("kura/include/kura.hrl").

get_all_li() ->
    ldf_repo:all(kura_query:from(li)).

get_li_user_id(UserId) ->
    find_by(li, user_id, UserId).

find_li(phone_number, PhoneNumber) ->
    find_by(li, phone_number, PhoneNumber);
find_li(email, Email) ->
    find_by(li, email, Email).

add_li(Type, Value, CallbackId, UserId, Username, PhoneNumber, Email) ->
    case {find_li(phone_number, PhoneNumber), find_li(email, Email)} of
        {undefined, undefined} ->
            CS = kura_changeset:cast(
                li,
                #{},
                #{
                    <<"type">> => Type,
                    <<"value">> => Value,
                    <<"callback_id">> => CallbackId,
                    <<"user_id">> => UserId,
                    <<"username">> => Username,
                    <<"phone_number">> => PhoneNumber,
                    <<"email">> => Email
                },
                [type, value, callback_id, user_id, username, phone_number, email]
            ),
            case ldf_repo:insert(CS) of
                {ok, _} -> ok;
                {error, _} = Error -> Error
            end;
        _ ->
            ok
    end.

remove_li(CallbackId) ->
    Q = kura_query:where(kura_query:from(li), {callback_id, CallbackId}),
    case ldf_repo:delete_all(Q) of
        {ok, _} -> ok;
        {error, _} = Error -> Error
    end.

add_message(Payload, MessageId) ->
    CS = kura_changeset:cast(
        ldf_message,
        #{},
        #{<<"payload">> => Payload, <<"message_id">> => MessageId},
        [payload, message_id]
    ),
    case ldf_repo:insert(CS) of
        {ok, _} -> ok;
        {error, _} = Error -> Error
    end.

get_messages() ->
    Q = kura_query:select(kura_query:from(ldf_message), [payload]),
    ldf_repo:all(Q).

get_message(MessageId) ->
    Q0 = kura_query:select(kura_query:from(ldf_message), [payload]),
    Q = kura_query:where(Q0, {message_id, MessageId}),
    ldf_repo:all(Q).

find_by(Schema, Field, Value) ->
    case ldf_repo:get_by(Schema, [{Field, Value}]) of
        {ok, Row} -> {ok, Row};
        {error, not_found} -> undefined
    end.
