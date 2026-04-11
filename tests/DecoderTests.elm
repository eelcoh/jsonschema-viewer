module DecoderTests exposing (..)

import Dict
import Expect
import Json.Decode
import Json.Schema
import Json.Schema.Decode
import Test exposing (..)


defsSchema : String
defsSchema =
    """{"type":"object","properties":{"addr":{"$ref":"#/$defs/Address"}},"$defs":{"Address":{"type":"object","properties":{"street":{"type":"string"}}}}}"""


bothDefsSchema : String
bothDefsSchema =
    """{"type":"object","definitions":{"Shared":{"type":"string"}},"$defs":{"Extra":{"type":"integer"}}}"""


combinedObjectSchema : String
combinedObjectSchema =
    """{"type":"object","properties":{"name":{"type":"string"}},"oneOf":[{"properties":{"a":{"type":"string"}}},{"properties":{"b":{"type":"integer"}}}]}"""


pureCombinatorSchema : String
pureCombinatorSchema =
    """{"oneOf":[{"type":"string"},{"type":"integer"}]}"""


arrayWithAnyOfSchema : String
arrayWithAnyOfSchema =
    """{"type":"array","items":{"type":"string"},"anyOf":[{"minItems":1},{"minItems":0}]}"""


plainObjectSchema : String
plainObjectSchema =
    """{"type":"object","properties":{"name":{"type":"string"}}}"""


decoderTests : Test
decoderTests =
    describe "Json.Schema.Decode"
        [ describe "DEC-01: $defs support"
            [ test "$defs keys normalized to #/definitions/ prefix" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder defsSchema of
                        Ok model ->
                            Dict.member "#/definitions/Address" model.definitions
                                |> Expect.equal True

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "$ref value #/$defs/Address rewritten to #/definitions/Address" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder defsSchema of
                        Ok model ->
                            case model.schema of
                                Json.Schema.Object { properties } ->
                                    case properties of
                                        (Json.Schema.Optional "addr" (Json.Schema.Ref { ref })) :: _ ->
                                            Expect.equal "#/definitions/Address" ref

                                        _ ->
                                            Expect.fail "Expected Optional addr property with Ref"

                                _ ->
                                    Expect.fail "Expected Object schema"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "both definitions and $defs merged into single Dict" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder bothDefsSchema of
                        Ok model ->
                            Expect.all
                                [ \m -> Dict.member "#/definitions/Shared" m.definitions |> Expect.equal True
                                , \m -> Dict.member "#/definitions/Extra" m.definitions |> Expect.equal True
                                , \m -> Dict.size m.definitions |> Expect.equal 2
                                ]
                                model

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            ]
        , describe "DEC-02: combined type+combinator"
            [ test "object with oneOf decodes as Object with combinator = Just (OneOfKind, ...)" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder combinedObjectSchema of
                        Ok model ->
                            case model.schema of
                                Json.Schema.Object { combinator } ->
                                    case combinator of
                                        Just ( Json.Schema.OneOfKind, subSchemas ) ->
                                            List.length subSchemas |> Expect.equal 2

                                        _ ->
                                            Expect.fail "Expected combinator = Just (OneOfKind, [2 items])"

                                _ ->
                                    Expect.fail "Expected Object schema variant"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "pure oneOf (no type) still decodes as OneOf variant" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder pureCombinatorSchema of
                        Ok model ->
                            case model.schema of
                                Json.Schema.OneOf { subSchemas } ->
                                    List.length subSchemas |> Expect.equal 2

                                _ ->
                                    Expect.fail "Expected OneOf schema variant"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "array with anyOf decodes as Array with combinator = Just (AnyOfKind, ...)" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder arrayWithAnyOfSchema of
                        Ok model ->
                            case model.schema of
                                Json.Schema.Array { combinator } ->
                                    case combinator of
                                        Just ( Json.Schema.AnyOfKind, subSchemas ) ->
                                            List.length subSchemas |> Expect.equal 2

                                        _ ->
                                            Expect.fail "Expected combinator = Just (AnyOfKind, [2 items])"

                                _ ->
                                    Expect.fail "Expected Array schema variant"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "object without combinator has combinator = Nothing" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder plainObjectSchema of
                        Ok model ->
                            case model.schema of
                                Json.Schema.Object { combinator } ->
                                    Expect.equal Nothing combinator

                                _ ->
                                    Expect.fail "Expected Object schema variant"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            ]
        ]
