module DecoderTests exposing (..)

import Dict
import Expect
import Json.Decode
import Json.Schema
import Json.Schema.Decode
import Set
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


openApi3Document : String
openApi3Document =
    """{"openapi":"3.0.1","info":{"title":"X","version":"1"},"paths":{},"components":{"schemas":{"Greeting":{"type":"object","properties":{"message":{"type":"string"}}},"Error":{"type":"object","properties":{"code":{"type":"string"}}}}}}"""


swagger2Document : String
swagger2Document =
    """{"swagger":"2.0","info":{"title":"X","version":"1"},"paths":{},"definitions":{"Pet":{"type":"object","properties":{"name":{"type":"string"}}}}}"""


pathsOpenApiDocument : String
pathsOpenApiDocument =
    """{"openapi":"3.0.1","info":{"title":"X","version":"1"},"paths":{"/foo":{"get":{"summary":"get foo","responses":{"200":{"description":"ok"}}}}}}"""


deprecatedOperationDocument : String
deprecatedOperationDocument =
    """{"openapi":"3.0.1","info":{"title":"X","version":"1"},"paths":{"/foo":{"post":{"deprecated":true,"responses":{}}}}}"""


multiContentTypeDocument : String
multiContentTypeDocument =
    """{"openapi":"3.0.1","info":{"title":"X","version":"1"},"paths":{"/foo":{"get":{"responses":{"200":{"description":"ok","content":{"text/plain":{"schema":{"type":"string","title":"Plain"}},"application/json":{"schema":{"type":"object","title":"Json"}}}}}}}}}"""


nonJsonContentTypeDocument : String
nonJsonContentTypeDocument =
    """{"openapi":"3.0.1","info":{"title":"X","version":"1"},"paths":{"/foo":{"get":{"responses":{"200":{"description":"ok","content":{"text/plain":{"schema":{"type":"string","title":"Plain"}}}}}}}}}"""


parameterDescDocument : String
parameterDescDocument =
    """{"openapi":"3.0.1","info":{"title":"X","version":"1"},"paths":{"/foo":{"get":{"parameters":[{"name":"q","in":"query","description":"Query string","schema":{"type":"string"}}],"responses":{}}}}}"""


swagger2FlatParameterDocument : String
swagger2FlatParameterDocument =
    """{"swagger":"2.0","info":{"title":"X","version":"1"},"paths":{"/foo":{"get":{"parameters":[{"name":"q","in":"query","description":"Query string","type":"integer"}],"responses":{}}}}}"""



-- TRAVERSAL HELPERS


findProperty : String -> List Json.Schema.ObjectProperty -> Maybe Json.Schema.Schema
findProperty name =
    List.filterMap
        (\p ->
            case p of
                Json.Schema.Required n s ->
                    if n == name then
                        Just s

                    else
                        Nothing

                Json.Schema.Optional n s ->
                    if n == name then
                        Just s

                    else
                        Nothing
        )
        >> List.head


findChild : String -> Json.Schema.Schema -> Maybe Json.Schema.Schema
findChild name schema =
    case schema of
        Json.Schema.Object o ->
            findProperty name o.properties

        _ ->
            Nothing


operationAt : String -> String -> Json.Schema.Schema -> Maybe Json.Schema.Schema
operationAt url verb rootSchema =
    findChild "Paths" rootSchema
        |> Maybe.andThen (findChild url)
        |> Maybe.andThen (findChild verb)


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
        , describe "DEC-03: OpenAPI awareness"
            [ test "OpenAPI 3.x components.schemas land in definitions with #/components/schemas/ prefix" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder openApi3Document of
                        Ok model ->
                            Expect.all
                                [ \m -> Dict.member "#/components/schemas/Greeting" m.definitions |> Expect.equal True
                                , \m -> Dict.member "#/components/schemas/Error" m.definitions |> Expect.equal True
                                ]
                                model

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "OpenAPI 3.x synthetic root wraps named schemas under a Schemas section" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder openApi3Document of
                        Ok model ->
                            case findChild "Schemas" model.schema of
                                Just (Json.Schema.Object { properties }) ->
                                    List.length properties |> Expect.equal 2

                                _ ->
                                    Expect.fail "Expected Schemas section to be an Object with 2 properties"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "Swagger 2.0 definitions feed the Schemas section of the synthetic root" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder swagger2Document of
                        Ok model ->
                            case findChild "Schemas" model.schema of
                                Just (Json.Schema.Object { properties }) ->
                                    List.length properties |> Expect.equal 1

                                _ ->
                                    Expect.fail "Expected Schemas section to be an Object with 1 property"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "initialCollapsedPaths collapses every OpenAPI 3.x schema under Schemas" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.initialCollapsedPaths openApi3Document of
                        Ok paths ->
                            Expect.equal
                                (Set.fromList
                                    [ "root.properties.Schemas.properties.Greeting"
                                    , "root.properties.Schemas.properties.Error"
                                    ]
                                )
                                paths

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "initialCollapsedPaths is empty for plain JSON Schema" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.initialCollapsedPaths plainObjectSchema of
                        Ok paths ->
                            Expect.equal Set.empty paths

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "initialCollapsedPaths collapses every Swagger 2.0 schema under Schemas" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.initialCollapsedPaths swagger2Document of
                        Ok paths ->
                            Expect.equal
                                (Set.fromList [ "root.properties.Schemas.properties.Pet" ])
                                paths

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            ]
        , describe "DEC-04: OpenAPI paths and operations"
            [ test "Paths section renders URL with nested verb property" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder pathsOpenApiDocument of
                        Ok model ->
                            case operationAt "/foo" "get" model.schema of
                                Just _ ->
                                    Expect.pass

                                Nothing ->
                                    Expect.fail "Expected Paths → /foo → get to resolve to an operation"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "Operation title uses uppercased verb and summary" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder pathsOpenApiDocument of
                        Ok model ->
                            case operationAt "/foo" "get" model.schema of
                                Just (Json.Schema.Object { title }) ->
                                    Expect.equal (Just "GET — get foo") title

                                _ ->
                                    Expect.fail "Expected operation to be an Object with a title"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "Deprecated operation title gets [DEPRECATED] suffix" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder deprecatedOperationDocument of
                        Ok model ->
                            case operationAt "/foo" "post" model.schema of
                                Just (Json.Schema.Object { title }) ->
                                    case title of
                                        Just t ->
                                            String.endsWith "[DEPRECATED]" t
                                                |> Expect.equal True

                                        Nothing ->
                                            Expect.fail "Expected operation to have a title"

                                _ ->
                                    Expect.fail "Expected operation to be an Object"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "Response prefers application/json over other content types" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder multiContentTypeDocument of
                        Ok model ->
                            case
                                operationAt "/foo" "get" model.schema
                                    |> Maybe.andThen (findChild "responses")
                                    |> Maybe.andThen (findChild "200")
                            of
                                Just (Json.Schema.Object { title }) ->
                                    Expect.equal (Just "Json") title

                                _ ->
                                    Expect.fail "Expected 200 response to resolve to application/json Object schema"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "Response falls back to first content type when no application/json" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder nonJsonContentTypeDocument of
                        Ok model ->
                            case
                                operationAt "/foo" "get" model.schema
                                    |> Maybe.andThen (findChild "responses")
                                    |> Maybe.andThen (findChild "200")
                            of
                                Just (Json.Schema.String { title }) ->
                                    Expect.equal (Just "Plain") title

                                _ ->
                                    Expect.fail "Expected 200 response to fall back to text/plain String schema"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "Parameter description propagates to inner schema" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder parameterDescDocument of
                        Ok model ->
                            case
                                operationAt "/foo" "get" model.schema
                                    |> Maybe.andThen (findChild "parameters")
                                    |> Maybe.andThen (findChild "q")
                            of
                                Just (Json.Schema.String { description }) ->
                                    Expect.equal (Just "Query string") description

                                _ ->
                                    Expect.fail "Expected parameter 'q' to be a String schema with description"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "Swagger 2.0 inline parameter preserves type and description" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.decoder swagger2FlatParameterDocument of
                        Ok model ->
                            case
                                operationAt "/foo" "get" model.schema
                                    |> Maybe.andThen (findChild "parameters")
                                    |> Maybe.andThen (findChild "q")
                            of
                                Just (Json.Schema.Integer { description }) ->
                                    Expect.equal (Just "Query string") description

                                _ ->
                                    Expect.fail "Expected Swagger 2.0 param 'q' to decode as Integer with description"

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            , test "initialCollapsedPaths includes URL entries under Paths" <|
                \_ ->
                    case Json.Decode.decodeString Json.Schema.Decode.initialCollapsedPaths pathsOpenApiDocument of
                        Ok paths ->
                            Set.member "root.properties.Paths.properties./foo" paths
                                |> Expect.equal True

                        Err e ->
                            Expect.fail (Json.Decode.errorToString e)
            ]
        ]
