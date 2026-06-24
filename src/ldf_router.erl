-module(ldf_router).

-export([routes/1]).

routes(_Env) ->
    [
        #{
            prefix => "",
            security => false,
            routes => [
                {"/receiver", fun ldf_receiver_controller:create_message/1, #{methods => [post]}},
                {"/receiver", fun ldf_receiver_controller:get_message/1, #{methods => [get]}},
                {"/message/:messageid", fun ldf_message_controller:message/1, #{methods => [get]}},
                {"/li", fun ldf_li_controller:create_li/1, #{methods => [post]}},
                {"/li", fun ldf_li_controller:manage_li/1, #{methods => [get]}},
                {"/history", fun ldf_li_controller:manage_history/1, #{methods => [post]}},
                {"/li/:liid", fun ldf_li_controller:delete_li/1, #{methods => [delete]}},
                {"/www/receiver", fun ldf_www_controller:receiver_page/1, #{methods => [get]}},
                {"/www/admin", fun ldf_www_controller:admin_page/1, #{methods => [get]}},
                {"/www/history", fun ldf_www_controller:history_page/1, #{methods => [get]}},
                {"/sse/receiver", fun ldf_www_controller:receiver_stream/1, #{methods => [get]}},
                {"/sse/admin", fun ldf_www_controller:admin_stream/1, #{methods => [get]}},
                {"/www/li", fun ldf_www_controller:add_listener/1, #{methods => [post]}},
                {"/www/li/:callbackid", fun ldf_www_controller:remove_listener/1, #{methods => [delete]}},
                {"/www/history", fun ldf_www_controller:submit_history/1, #{methods => [post]}},
                {"/assets/[...]", "assets"}
            ]
        }
    ].
