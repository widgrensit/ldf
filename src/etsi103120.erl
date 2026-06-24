-module(etsi103120).

-export([json_to_xml/4]).

-define(SCHEMAIDENTIFIER, <<"http://localhost:8090/schema/1.0/">>).

-include_lib("xmerl/include/xmerl.hrl").

json_to_xml(
    #{
        <<"chat_id">> := ChatId,
        <<"id">> := MessageId,
        <<"payload">> := Payload,
        <<"sender">> := Sender,
        <<"sender_info">> := SenderInfo,
        <<"timestamp">> := Timestamp
    } = Object,
    CountryCode,
    SenderUUID,
    ReceiverUUID
) ->
    logger:debug("converting to 103 120"),
    CspDefinedParameters = csp_defined_parameters(Object),
    logger:debug("payload: ~p", [Payload]),
    Mime =
        case Payload of
            #{<<"mime">> := [MimeType]} -> MimeType;
            _ -> <<"text/plain">>
        end,
    logger:debug("mime: ~p", [Mime]),
    ContentLength =
        case is_binary(Payload) of
            true ->
                integer_to_binary(byte_size(Payload));
            false ->
                case is_map(Payload) of
                    true ->
                        Json = thoas:encode(Payload),
                        integer_to_binary(byte_size(Json));
                    false ->
                        <<"0">>
                end
        end,
    Content = [
        #xmlElement{
            name = 'etsi707:header',
            content = [
                #xmlElement{
                    name = 'etsi707:applicationCorrelation',
                    content = [
                        #xmlElement{
                            name = 'etsi707:applicationLevelID',
                            content = [#xmlText{value = <<"1">>}]
                        },
                        #xmlElement{
                            name = 'etsi707:applicationSequenceNumber',
                            content = [#xmlText{value = <<"3">>}]
                        }
                    ]
                }
            ]
        },
        #xmlElement{
            name = 'etsi707:payload',
            attributes = [
                #xmlAttribute{
                    name = 'xsi:type',
                    value = [<<"etsi707:MessagingPayload">>]
                }
            ],
            content = [
                core_parameters(
                    Sender,
                    SenderInfo,
                    ChatId,
                    calendar:system_time_to_rfc3339(
                        Timestamp,
                        [{unit, microsecond}]
                    ),
                    MessageId,
                    ContentLength,
                    Mime
                ),
                CspDefinedParameters
            ]
        }
    ],
    list_to_binary(
        lists:flatten(
            xmerl:export_simple(
                [hi1(header(Content), CountryCode, SenderUUID, ReceiverUUID)], xmerl_xml
            )
        )
    ).

header(Content) ->
    [
        #xmlElement{
            name = 'etsi707:handoverItem',
            attributes = [],
            content = Content
        }
    ].

core_parameters(Sender, SenderInfo, Receiver, Timestamp, MessageId, ContentLength, Mime) ->
    IsTargetedPartyBool =
        case ldf_db:get_li_user_id(Sender) of
            {ok, User} -> <<"true">>;
            _ -> <<"false">>
        end,
    logger:debug("sender info: ~p", [SenderInfo]),
    #xmlElement{
        name = 'etsi707:coreParameters',
        content = [
            message_sender({Sender, SenderInfo}, IsTargetedPartyBool),
            message_receiver(Receiver),
            timestamp(Timestamp),
            associated_binary_data(MessageId, ContentLength, Mime)
        ]
    }.

message_sender({Sender, SenderInfo}, IsTargetedParty) ->
    #xmlElement{
        name = 'etsi707:messageSender',
        content = [
            identifiers(Sender, SenderInfo),
            #xmlElement{
                name = 'etsi707:isTargetedParty',
                content = [#xmlText{value = [IsTargetedParty]}]
            }
        ]
    }.

identifiers(Identifier, #{
    <<"email">> := Email,
    <<"phone_number">> := PhoneNumber,
    <<"user_agent">> := UserAgent
}) ->
    #xmlElement{
        name = 'etsi707:identifiers',
        content = [
            #xmlElement{
                name = 'etsi707:identifier',
                content = [#xmlText{value = [Identifier]}]
            },
            #xmlElement{
                name = 'etsi707:identifier',
                content = [#xmlText{value = [Email]}]
            },
            #xmlElement{
                name = 'etsi707:identifier',
                content = [#xmlText{value = [PhoneNumber]}]
            },
            #xmlElement{
                name = 'etsi707:identifier',
                content = [#xmlText{value = [UserAgent]}]
            }
        ]
    };
identifiers(Identifier, _) ->
    identifiers(Identifier).

identifiers(Identifier) ->
    #xmlElement{
        name = 'etsi707:identifiers',
        content = [
            #xmlElement{
                name = 'etsi707:identifier',
                content = [#xmlText{value = [Identifier]}]
            }
        ]
    }.
message_receiver(Receiver) ->
    #xmlElement{
        name = 'etsi707:messageReceivers',
        content = [
            #xmlElement{
                name = 'etsi707:recipient',
                content = [identifiers(Receiver)]
            }
        ]
    }.

timestamp(Timestamp) ->
    #xmlElement{
        name = 'etsi707:timestamp',
        content = [#xmlText{value = [Timestamp]}]
    }.

associated_binary_data(MessageId, ContentLength, Mime) ->
    Url = #xmlElement{
        name = 'etsi707:url',
        content = [#xmlText{value = [<<"http://localhost:8095/message/", MessageId/binary>>]}]
    },
    #xmlElement{
        name = 'etsi707:associatedBinaryData',
        content = [
            #xmlElement{
                name = 'etsi707:binaryObject',
                content = [
                    Url,
                    #xmlElement{
                        name = 'etsi707:contentLength',
                        content = [#xmlText{value = [ContentLength]}]
                    },
                    #xmlElement{
                        name = 'etsi707:contentType',
                        content = [#xmlText{value = [Mime]}]
                    },
                    #xmlElement{
                        name = 'etsi707:cspDefinedIdentifier',
                        content = [#xmlText{value = [MessageId]}]
                    }
                ]
            }
        ]
    }.

csp_defined_parameters(Object) ->
    Keys = maps:keys(Object),
    #xmlElement{
        name = 'etsi707:cspDefinedParameters',
        content = [csp_defined_metadata(Keys)]
    }.

csp_defined_metadata(Keys) ->
    #xmlElement{
        name = 'etsi707:cspDefinedMetadata',
        content = [
            schema_details(Keys),
            #xmlElement{
                name = 'etsi707:xmlData',
                content = [chatli_defined_parameters(Keys)]
            }
        ]
    }.

schema_details(_Keys) ->
    #xmlElement{
        name = 'etsi707:schemaDetails',
        content = [
            #xmlElement{
                name = 'etsi707:schemaIdentifier',
                content = [#xmlText{value = [?SCHEMAIDENTIFIER]}]
            }
        ]
    }.

chatli_defined_parameters(Keys) ->
    #xmlElement{
        name = 'chat:chatLiDefinedParameters',
        content = items(Keys, 1)
    }.

items(Keys, N) ->
    Nbin = integer_to_binary(N),
    case Keys of
        [] ->
            [];
        [Key | T] ->
            [
                #xmlElement{
                    name = binary_to_atom(<<"chat:item", Nbin/binary>>, utf8),
                    content = [#xmlText{value = [Key]}]
                }
                | items(T, N + 1)
            ]
    end.

hi1(Etsi707, CountryCode, Sender, Receiver) ->
    TransactionId = get_v4(),
    Timestamp = calendar:system_time_to_rfc3339(os:system_time(microsecond), [{unit, microsecond}]),
    ObjectIdentifier = get_v4(),
    CC =
        case CountryCode of
            <<"undefined">> -> <<"SE">>;
            CountryCode -> CountryCode
        end,
    SenderUnique =
        case Sender of
            <<"undefined">> -> <<"f7b38465-a0c7-4b2a-91cd-acb52152451f">>;
            Sender -> Sender
        end,
    ReceiverUnique =
        case Receiver of
            <<"undefined">> -> <<"1538d92a-0838-4864-8bb7-3b8825d6adbd">>;
            Receiver -> Receiver
        end,
    #xmlElement{
        name = 'HI1Message',
        attributes = [
            #xmlAttribute{
                name = 'xmlns',
                value = <<"http://uri.etsi.org/03120/common/2019/10/Core">>
            },
            #xmlAttribute{
                name = 'xmlns:common',
                value = <<"http://uri.etsi.org/03120/common/2016/02/Common">>
            },
            #xmlAttribute{
                name = 'xmlns:delivery',
                value = <<"http://uri.etsi.org/03120/common/2019/10/Delivery">>
            },
            #xmlAttribute{
                name = 'xmlns:etsi707',
                value = <<"http://uri.etsi.org/03707/2020/02">>
            },
            #xmlAttribute{
                name = 'xmlns:xsi',
                value = <<"http://www.w3.org/2001/XMLSchema-instance">>
            },
            #xmlAttribute{
                name = 'xmlns:chat',
                value = <<"chat">>
            }
        ],
        content = [
            #xmlElement{
                name = 'Header',
                content = [
                    #xmlElement{
                        name = 'SenderIdentifier',
                        content = hi1_identifier(CC, SenderUnique)
                    },
                    #xmlElement{
                        name = 'ReceiverIdentifier',
                        content = hi1_identifier(CC, ReceiverUnique)
                    },
                    #xmlElement{
                        name = 'TransactionIdentifier',
                        content = [#xmlText{value = [TransactionId]}]
                    },
                    #xmlElement{
                        name = 'Timestamp',
                        content = [#xmlText{value = [Timestamp]}]
                    },
                    #xmlElement{
                        name = 'Version',
                        content = [
                            #xmlElement{
                                name = 'ETSIVersion',
                                content = [#xmlText{value = [<<"V1.1.1">>]}]
                            },
                            #xmlElement{
                                name = 'NationalProfileOwner',
                                content = [#xmlText{value = [CC]}]
                            },
                            #xmlElement{
                                name = 'NationalProfileVersion',
                                content = [#xmlText{value = [<<"None">>]}]
                            }
                        ]
                    }
                ]
            },
            #xmlElement{
                name = 'Payload',
                content = [
                    #xmlElement{
                        name = 'RequestPayload',
                        content = [
                            #xmlElement{
                                name = 'ActionRequests',
                                content = [
                                    #xmlElement{
                                        name = 'ActionRequest',
                                        content = [
                                            #xmlElement{
                                                name = 'ActionIdentifier',
                                                content = [#xmlText{value = <<"0">>}]
                                            },
                                            #xmlElement{
                                                name = 'DELIVER',
                                                content = [
                                                    #xmlElement{
                                                        name = 'Identifier',
                                                        content = [
                                                            #xmlText{value = ObjectIdentifier}
                                                        ]
                                                    },
                                                    #xmlElement{
                                                        name = 'HI1Object',
                                                        attributes = [
                                                            #xmlAttribute{
                                                                name = 'xsi:type',
                                                                value =
                                                                    <<"delivery:DeliveryObject">>
                                                            }
                                                        ],
                                                        content = [
                                                            #xmlElement{
                                                                name = 'ObjectIdentifier',
                                                                content = [
                                                                    #xmlText{
                                                                        value = [ObjectIdentifier]
                                                                    }
                                                                ]
                                                            },
                                                            #xmlElement{
                                                                name = 'CountryCode',
                                                                content = [#xmlText{value = [CC]}]
                                                            },
                                                            #xmlElement{
                                                                name = 'OwnerIdentifier',
                                                                content = [
                                                                    #xmlText{value = [SenderUnique]}
                                                                ]
                                                            },
                                                            #xmlElement{
                                                                name = 'delivery:Reference',
                                                                content = [
                                                                    #xmlElement{
                                                                        name = 'delivery:LIID',
                                                                        content = [
                                                                            #xmlText{
                                                                                value = [<<"LIID">>]
                                                                            }
                                                                        ]
                                                                    }
                                                                ]
                                                            },
                                                            #xmlElement{
                                                                name = 'delivery:DeliveryID',
                                                                content = [
                                                                    #xmlText{
                                                                        value = [ObjectIdentifier]
                                                                    }
                                                                ]
                                                            },
                                                            #xmlElement{
                                                                name = 'delivery:SequenceNumber',
                                                                content = [
                                                                    #xmlText{value = <<"1">>}
                                                                ]
                                                            },
                                                            #xmlElement{
                                                                name = 'delivery:LastSequence',
                                                                content = [
                                                                    #xmlText{value = <<"true">>}
                                                                ]
                                                            },
                                                            #xmlElement{
                                                                name = 'delivery:Manifest',
                                                                content = [
                                                                    #xmlElement{
                                                                        name =
                                                                            'delivery:Specification',
                                                                        content = [
                                                                            #xmlElement{
                                                                                name =
                                                                                    'common:Owner',
                                                                                content = [
                                                                                    #xmlText{
                                                                                        value =
                                                                                            <<"ETSI">>
                                                                                    }
                                                                                ]
                                                                            },
                                                                            #xmlElement{
                                                                                name =
                                                                                    'common:Name',
                                                                                content = [
                                                                                    #xmlText{
                                                                                        value =
                                                                                            <<"ManifestSpecification">>
                                                                                    }
                                                                                ]
                                                                            },
                                                                            #xmlElement{
                                                                                name =
                                                                                    'common:Value',
                                                                                content = [
                                                                                    #xmlText{
                                                                                        value =
                                                                                            <<"TS103707">>
                                                                                    }
                                                                                ]
                                                                            }
                                                                        ]
                                                                    }
                                                                ]
                                                            },
                                                            #xmlElement{
                                                                name = 'delivery:Delivery',
                                                                content = [
                                                                    #xmlElement{
                                                                        name = 'delivery:XMLData',
                                                                        content = Etsi707
                                                                    }
                                                                ]
                                                            }
                                                        ]
                                                    }
                                                ]
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    }.

hi1_identifier(CountryCode, Identifier) ->
    [
        #xmlElement{
            name = 'CountryCode',
            content = [#xmlText{value = [CountryCode]}]
        },
        #xmlElement{
            name = 'UniqueIdentifier',
            content = [#xmlText{value = [Identifier]}]
        }
    ].

get_v4() ->
    jhn_uuid:gen(v4, [binary]).
