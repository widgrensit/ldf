-module(ldf_receiver_controller).
-export([
    create_message/1,
    get_message/1
]).

create_message(#{json := #{<<"id">> := MessageId} = Json}) ->
    Message =
        case Json of
            #{<<"payload">> := #{<<"url">> := Url} = Payload} ->
                {ok, ChatliPath} = application:get_env(ldf, chatli_public_path),
                Payload2 = maps:update(<<"url">>, <<ChatliPath/binary, "/", Url/binary>>, Payload),
                maps:update(<<"payload">>, Payload2, Json);
            _ ->
                Json
        end,
    logger:debug("message: ~p~n", [Message]),
    EncodedMessage = encode(Message),
    logger:debug("Encoded message: ~p~n", [EncodedMessage]),
    case ldf_db:add_message(EncodedMessage, MessageId) of
        ok ->
            ldf_www_controller:publish_message(MessageId, EncodedMessage);
        {error, Reason} ->
            logger:error("failed to store message ~s: ~p", [MessageId, Reason])
    end,
    {status, 200}.

get_message(#{parsed_qs := ParsedQS}) ->
    logger:debug("parse qs"),
    {ok, List} = ldf_db:get_messages(),
    Xml =
        case maps:get(<<"type">>, ParsedQS, undefined) of
            <<"103120">> ->
                #{
                    <<"countryCode">> := CountryCode,
                    <<"sender">> := Sender,
                    <<"receiver">> := Receiver
                } = ParsedQS,
                [
                    etsi103120:json_to_xml(decode(Json), CountryCode, Sender, Receiver)
                 || #{payload := Json} <- List
                ];
            _ ->
                [etsi103707:json_to_xml(decode(Json)) || #{payload := Json} <- List]
        end,
    {json, 200, #{<<"Content-type">> => <<"application/json">>}, Xml};
get_message(_) ->
    {ok, List} = ldf_db:get_messages(),
    Xml = [etsi103707:json_to_xml(decode(Json)) || #{payload := Json} <- List],
    {json, 200, #{<<"Content-type">> => <<"application/json; charset=utf-8">>}, Xml}.

encode(Item) ->
    thoas:encode(Item).

decode(Item) ->
    {ok, Map} = thoas:decode(Item),
    Map.
