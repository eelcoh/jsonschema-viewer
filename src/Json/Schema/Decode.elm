module Json.Schema.Decode exposing (decoder, initialCollapsedPaths)

{-| Decoder for a JSON Schema or OpenAPI document.

@docs decoder, initialCollapsedPaths

-}

import Dict exposing (Dict)
import Json.Decode exposing (Decoder, andThen, at, bool, dict, fail, field, float, int, keyValuePairs, lazy, list, map, map2, map3, maybe, nullable, oneOf, string, succeed, value)
import Json.Decode.Pipeline exposing (custom, optional, required)
import Json.Schema as Schema exposing (Schema)
import Set exposing (Set)



-- PUBLIC API


{-| Decoder for a JSON Schema or OpenAPI document.

For plain JSON Schema, the root schema is decoded directly.

For OpenAPI 2.0/3.x documents (detected by a top-level `openapi` or `swagger`
string field), a synthetic root object is built with one child per top-level
section: Info, Servers, Tags, Paths, Webhooks, Schemas, Parameters, Request
Bodies, Responses, Headers, Security Schemes, Examples, Links, Callbacks.
Empty sections are omitted.

-}
decoder : Decoder Schema.Model
decoder =
    oneOf
        [ openApiDecoder
        , map2 Schema.Model definitionsDecoder schemaDecoder
        ]


{-| Paths (matching Render.Svg's path scheme) that should start collapsed for
this input. For OpenAPI documents, every URL under Paths/Webhooks and every
named entry under the component sections starts collapsed — otherwise a spec
with hundreds of schemas or endpoints triggers a combinatorial ref-expansion
that hangs the browser.
-}
initialCollapsedPaths : Decoder (Set String)
initialCollapsedPaths =
    oneOf
        [ isOpenApi |> andThen (\_ -> oasCollapsedPathsDecoder)
        , succeed Set.empty
        ]



-- OPENAPI DETECTION


isOpenApi : Decoder ()
isOpenApi =
    oneOf
        [ field "openapi" string |> map (always ())
        , field "swagger" string |> map (always ())
        ]



-- TOP-LEVEL OPENAPI DECODER


openApiDecoder : Decoder Schema.Model
openApiDecoder =
    isOpenApi
        |> andThen
            (\_ ->
                map3
                    (\jsonSchemaDefs oasDefs sections ->
                        Schema.Model
                            (Dict.union jsonSchemaDefs oasDefs)
                            (syntheticRoot sections)
                    )
                    definitionsDecoder
                    oasAllDefinitionsDecoder
                    oasRootSectionsDecoder
            )


syntheticRoot : List ( String, Schema ) -> Schema
syntheticRoot pairs =
    syntheticObject
        (Just "OpenAPI Document")
        (Just "Top-level sections of this OpenAPI document.")
        []
        pairs



-- $REF RESOLUTION DICT


definitionsDecoder : Decoder Schema.Definitions
definitionsDecoder =
    let
        readDefs key =
            field key
                (keyValuePairs schemaDecoder
                    |> map (List.map (Tuple.mapFirst (\k -> "#/definitions/" ++ k)) >> Dict.fromList)
                )
                |> maybe
                |> map (Maybe.withDefault Dict.empty)
    in
    map2 Dict.union (readDefs "definitions") (readDefs "$defs")


{-| Build the lookup dict for all OpenAPI-named components so that `$ref`s from
any location in the document (paths, operations, parameter lists, responses,
etc.) can be resolved by the renderer.
-}
oasAllDefinitionsDecoder : Decoder Schema.Definitions
oasAllDefinitionsDecoder =
    map Dict.fromList <|
        combineLists
            [ prefixed "#/components/schemas/" (namedPairsAt [ "components", "schemas" ] schemaDecoder)
            , prefixed "#/components/parameters/" (namedPairsAt [ "components", "parameters" ] parameterComponentDecoder)
            , prefixed "#/components/requestBodies/" (namedPairsAt [ "components", "requestBodies" ] requestBodyDecoder)
            , prefixed "#/components/responses/" (namedPairsAt [ "components", "responses" ] responseDecoder)
            , prefixed "#/components/headers/" (namedPairsAt [ "components", "headers" ] headerDecoder)
            , prefixed "#/components/securitySchemes/" (namedPairsAt [ "components", "securitySchemes" ] securitySchemeDecoder)
            , prefixed "#/components/examples/" (namedPairsAt [ "components", "examples" ] exampleDecoder)
            , prefixed "#/components/links/" (namedPairsAt [ "components", "links" ] linkDecoder)
            , prefixed "#/components/callbacks/" (namedPairsAt [ "components", "callbacks" ] callbackDecoder)
            , prefixed "#/parameters/" (namedPairsAt [ "parameters" ] parameterComponentDecoder)
            , prefixed "#/responses/" (namedPairsAt [ "responses" ] responseDecoder)
            , prefixed "#/securityDefinitions/" (namedPairsAt [ "securityDefinitions" ] securitySchemeDecoder)
            ]


prefixed : String -> Decoder (List ( String, Schema )) -> Decoder (List ( String, Schema ))
prefixed prefix =
    map (List.map (Tuple.mapFirst ((++) prefix)))



-- ROOT SECTIONS


oasRootSectionsDecoder : Decoder (List ( String, Schema ))
oasRootSectionsDecoder =
    combineLists
        [ infoSectionDecoder
        , serversSectionDecoder
        , tagsSectionDecoder
        , pathsSectionDecoder
        , webhooksSectionDecoder
        , schemasSectionDecoder
        , componentsSectionDecoder "parameters" [ [ "parameters" ] ] "Parameters" "Reusable parameter definitions." parameterComponentDecoder
        , componentsSectionDecoder "requestBodies" [] "Request Bodies" "Reusable request body definitions." requestBodyDecoder
        , componentsSectionDecoder "responses" [ [ "responses" ] ] "Responses" "Reusable response definitions." responseDecoder
        , componentsSectionDecoder "headers" [] "Headers" "Reusable header definitions." headerDecoder
        , componentsSectionDecoder "securitySchemes" [ [ "securityDefinitions" ] ] "Security Schemes" "Security schemes declared by this document." securitySchemeDecoder
        , componentsSectionDecoder "examples" [] "Examples" "Reusable example definitions." exampleDecoder
        , componentsSectionDecoder "links" [] "Links" "Reusable link definitions." linkDecoder
        , componentsSectionDecoder "callbacks" [] "Callbacks" "Reusable callback definitions." callbackDecoder
        ]


infoSectionDecoder : Decoder (List ( String, Schema ))
infoSectionDecoder =
    maybe (field "info" infoBlockDecoder)
        |> map (maybeToSection "Info")


serversSectionDecoder : Decoder (List ( String, Schema ))
serversSectionDecoder =
    maybe (field "servers" serversBlockDecoder)
        |> map (maybeToSection "Servers")


tagsSectionDecoder : Decoder (List ( String, Schema ))
tagsSectionDecoder =
    maybe (field "tags" tagsBlockDecoder)
        |> map (maybeToSection "Tags")


pathsSectionDecoder : Decoder (List ( String, Schema ))
pathsSectionDecoder =
    namedPairsAt [ "paths" ] pathItemDecoder
        |> map (pairsToSection "Paths" "API endpoints defined by this document.")


webhooksSectionDecoder : Decoder (List ( String, Schema ))
webhooksSectionDecoder =
    namedPairsAt [ "webhooks" ] pathItemDecoder
        |> map (pairsToSection "Webhooks" "Outgoing webhook endpoints.")


schemasSectionDecoder : Decoder (List ( String, Schema ))
schemasSectionDecoder =
    map2 (++)
        (namedPairsAt [ "components", "schemas" ] schemaDecoder)
        (namedPairsAt [ "definitions" ] schemaDecoder)
        |> map (pairsToSection "Schemas" "Named schemas declared by this OpenAPI document.")


componentsSectionDecoder : String -> List (List String) -> String -> String -> Decoder Schema -> Decoder (List ( String, Schema ))
componentsSectionDecoder subKey swaggerPaths sectionTitle sectionDesc entryDecoder =
    let
        primary =
            namedPairsAt [ "components", subKey ] entryDecoder

        fallbacks =
            List.map (\p -> namedPairsAt p entryDecoder) swaggerPaths
    in
    combineLists (primary :: fallbacks)
        |> map (pairsToSection sectionTitle sectionDesc)


pairsToSection : String -> String -> List ( String, Schema ) -> List ( String, Schema )
pairsToSection title description pairs =
    if List.isEmpty pairs then
        []

    else
        [ ( title, syntheticObject (Just title) (Just description) [] pairs ) ]


maybeToSection : String -> Maybe Schema -> List ( String, Schema )
maybeToSection title m =
    case m of
        Just s ->
            [ ( title, s ) ]

        Nothing ->
            []



-- SMALL METADATA BLOCKS (INFO / SERVERS / TAGS)


infoBlockDecoder : Decoder Schema
infoBlockDecoder =
    let
        build title version description tos contactName contactEmail contactUrl licenseName licenseUrl =
            let
                lines =
                    List.filterMap identity
                        [ Maybe.map (\v -> "title: " ++ v) title
                        , Maybe.map (\v -> "version: " ++ v) version
                        , Maybe.map (\v -> "description: " ++ v) description
                        , Maybe.map (\v -> "terms of service: " ++ v) tos
                        , Maybe.map (\v -> "contact name: " ++ v) contactName
                        , Maybe.map (\v -> "contact email: " ++ v) contactEmail
                        , Maybe.map (\v -> "contact url: " ++ v) contactUrl
                        , Maybe.map (\v -> "license: " ++ v) licenseName
                        , Maybe.map (\v -> "license url: " ++ v) licenseUrl
                        ]
            in
            stringPill title (linesToDescription lines)
    in
    succeed build
        |> maybeOptional "title" string
        |> maybeOptional "version" string
        |> maybeOptional "description" string
        |> maybeOptional "termsOfService" string
        |> custom (maybe (at [ "contact", "name" ] string))
        |> custom (maybe (at [ "contact", "email" ] string))
        |> custom (maybe (at [ "contact", "url" ] string))
        |> custom (maybe (at [ "license", "name" ] string))
        |> custom (maybe (at [ "license", "url" ] string))


serversBlockDecoder : Decoder Schema
serversBlockDecoder =
    list
        (map2 Tuple.pair
            (field "url" string)
            (maybe (field "description" string))
        )
        |> map
            (\entries ->
                let
                    lines =
                        List.map
                            (\( url, mDesc ) ->
                                case mDesc of
                                    Just d ->
                                        url ++ " — " ++ d

                                    Nothing ->
                                        url
                            )
                            entries
                in
                stringPill (Just "Servers") (linesToDescription lines)
            )


tagsBlockDecoder : Decoder Schema
tagsBlockDecoder =
    list
        (map2 Tuple.pair
            (field "name" string)
            (maybe (field "description" string))
        )
        |> map
            (\entries ->
                let
                    lines =
                        List.map
                            (\( name, mDesc ) ->
                                case mDesc of
                                    Just d ->
                                        name ++ " — " ++ d

                                    Nothing ->
                                        name
                            )
                            entries
                in
                stringPill (Just "Tags") (linesToDescription lines)
            )


linesToDescription : List String -> Maybe String
linesToDescription lines =
    if List.isEmpty lines then
        Nothing

    else
        Just (String.join "\n" lines)



-- PATH ITEMS / OPERATIONS


pathItemDecoder : Decoder Schema
pathItemDecoder =
    lazy
        (\_ ->
            oneOf
                [ refSchemaDecoder
                , inlinePathItemDecoder
                ]
        )


inlinePathItemDecoder : Decoder Schema
inlinePathItemDecoder =
    map3
        (\summary description verbPairs ->
            syntheticObject summary description [] verbPairs
        )
        (maybe (field "summary" string))
        (maybe (field "description" string))
        pathItemVerbsDecoder


pathItemVerbsDecoder : Decoder (List ( String, Schema ))
pathItemVerbsDecoder =
    let
        verbs =
            [ "get", "put", "post", "delete", "options", "head", "patch", "trace" ]

        decodeVerb verb =
            maybe (field verb (operationDecoder verb))
                |> map (Maybe.map (\op -> ( verb, op )))
    in
    List.map decodeVerb verbs
        |> decodersToList
        |> map (List.filterMap identity)


operationDecoder : String -> Decoder Schema
operationDecoder verb =
    lazy
        (\_ ->
            succeed (buildOperation verb)
                |> maybeOptional "summary" string
                |> maybeOptional "description" string
                |> maybeOptional "operationId" string
                |> optional "deprecated" bool False
                |> optional "tags" (list string) []
                |> custom (maybe (field "parameters" parametersListDecoder))
                |> custom (maybe (field "requestBody" requestBodyDecoder))
                |> custom (maybe (field "responses" responsesMapDecoder))
        )


buildOperation :
    String
    -> Maybe String
    -> Maybe String
    -> Maybe String
    -> Bool
    -> List String
    -> Maybe Schema
    -> Maybe Schema
    -> Maybe Schema
    -> Schema
buildOperation verb summary description operationId deprecated tags parameters requestBody responses =
    let
        verbUpper =
            String.toUpper verb

        baseTitle =
            case summary of
                Just s ->
                    verbUpper ++ " — " ++ s

                Nothing ->
                    verbUpper

        titleText =
            if deprecated then
                baseTitle ++ " [DEPRECATED]"

            else
                baseTitle

        descLines =
            List.filterMap identity
                [ description
                , Maybe.map (\o -> "operationId: " ++ o) operationId
                , if List.isEmpty tags then
                    Nothing

                  else
                    Just ("tags: " ++ String.join ", " tags)
                ]

        descText =
            if List.isEmpty descLines then
                Nothing

            else
                Just (String.join "\n\n" descLines)

        props =
            List.filterMap identity
                [ Maybe.map (\p -> ( "parameters", p )) parameters
                , Maybe.map (\b -> ( "requestBody", b )) requestBody
                , Maybe.map (\r -> ( "responses", r )) responses
                ]
    in
    syntheticObject (Just titleText) descText [] props



-- PARAMETERS


parametersListDecoder : Decoder Schema
parametersListDecoder =
    list parameterEntryDecoder
        |> map
            (\entries ->
                let
                    requiredNames =
                        List.filterMap
                            (\( n, r, _ ) ->
                                if r then
                                    Just n

                                else
                                    Nothing
                            )
                            entries

                    pairs =
                        List.map (\( n, _, s ) -> ( n, s )) entries
                in
                syntheticObject Nothing Nothing requiredNames pairs
            )


parameterEntryDecoder : Decoder ( String, Bool, Schema )
parameterEntryDecoder =
    lazy
        (\_ ->
            oneOf
                [ field "$ref" string
                    |> map
                        (\ref ->
                            let
                                normalized =
                                    normalizeRef ref
                            in
                            ( refName normalized, False, Schema.reference Nothing Nothing normalized [] Nothing )
                        )
                , inlineParameterEntry
                ]
        )


inlineParameterEntry : Decoder ( String, Bool, Schema )
inlineParameterEntry =
    succeed (\name requiredFlag schema -> ( name, requiredFlag, schema ))
        |> required "name" string
        |> optional "required" bool False
        |> custom inlineParameterSchema


{-| Schema for an inline parameter entry. OAS 3.x nests the schema under
`schema` and carries the parameter-level `description` separately (merged in
here). Swagger 2.0 puts `type`/`format`/`description` directly on the
parameter object — `schemaDecoder` reads the description itself, so no
second merge is needed.
-}
inlineParameterSchema : Decoder Schema
inlineParameterSchema =
    oneOf
        [ map2 attachDescription
            (maybe (field "description" string))
            (field "schema" schemaDecoder)
        , schemaDecoder
        , succeed anySchema
        ]



-- REQUEST BODIES / RESPONSES / CONTENT


requestBodyDecoder : Decoder Schema
requestBodyDecoder =
    lazy (\_ -> refOrDescribed contentSchemaDecoder)


responsesMapDecoder : Decoder Schema
responsesMapDecoder =
    keyValuePairs responseDecoder
        |> map (\pairs -> syntheticObject Nothing Nothing [] pairs)


responseDecoder : Decoder Schema
responseDecoder =
    lazy (\_ -> refOrDescribed contentSchemaDecoder)


{-| `$ref` or an inline object whose top-level `description` is merged onto the
inner content schema.
-}
refOrDescribed : Decoder Schema -> Decoder Schema
refOrDescribed content =
    oneOf
        [ refSchemaDecoder
        , map2 attachDescription
            (maybe (field "description" string))
            content
        ]


{-| Pick the schema out of an OpenAPI Media Type Object map. Prefers
`application/json`; falls back to the first media type; `anySchema` if none.
-}
contentSchemaDecoder : Decoder Schema
contentSchemaDecoder =
    maybe (field "content" (keyValuePairs (maybe (field "schema" schemaDecoder))))
        |> map
            (\maybePairs ->
                case maybePairs of
                    Just pairs ->
                        pickContentSchema pairs

                    Nothing ->
                        anySchema
            )


pickContentSchema : List ( String, Maybe Schema ) -> Schema
pickContentSchema pairs =
    let
        preferred =
            List.filterMap
                (\( ct, ms ) ->
                    if ct == "application/json" then
                        ms

                    else
                        Nothing
                )
                pairs
    in
    case preferred of
        s :: _ ->
            s

        [] ->
            case List.filterMap Tuple.second pairs of
                s :: _ ->
                    s

                [] ->
                    anySchema



-- COMPONENT ENTRY DECODERS (display-level)


{-| Parameter and header objects share the same shape: `$ref`, OAS 3.x
(nested `schema` with an outer `description` to merge), or Swagger 2.0
(type/format/enum directly on the object — the object *is* the schema).
-}
parameterOrHeaderDecoder : Decoder Schema
parameterOrHeaderDecoder =
    lazy
        (\_ ->
            oneOf
                [ refSchemaDecoder
                , map2 attachDescription
                    (maybe (field "description" string))
                    (field "schema" schemaDecoder)
                , schemaDecoder
                , succeed anySchema
                ]
        )


parameterComponentDecoder : Decoder Schema
parameterComponentDecoder =
    parameterOrHeaderDecoder


headerDecoder : Decoder Schema
headerDecoder =
    parameterOrHeaderDecoder


securitySchemeDecoder : Decoder Schema
securitySchemeDecoder =
    lazy
        (\_ ->
            oneOf
                [ refSchemaDecoder
                , map2
                    (\type_ desc ->
                        stringPill (Just (Maybe.withDefault "(security scheme)" type_)) desc
                    )
                    (maybe (field "type" string))
                    (maybe (field "description" string))
                ]
        )


exampleDecoder : Decoder Schema
exampleDecoder =
    lazy
        (\_ ->
            oneOf
                [ refSchemaDecoder
                , map2
                    (\summary desc ->
                        stringPill summary desc
                    )
                    (maybe (field "summary" string))
                    (maybe (field "description" string))
                ]
        )


linkDecoder : Decoder Schema
linkDecoder =
    lazy
        (\_ ->
            oneOf
                [ refSchemaDecoder
                , map3
                    (\opId opRef desc ->
                        let
                            title =
                                case opId of
                                    Just v ->
                                        Just v

                                    Nothing ->
                                        opRef
                        in
                        stringPill title desc
                    )
                    (maybe (field "operationId" string))
                    (maybe (field "operationRef" string))
                    (maybe (field "description" string))
                ]
        )


callbackDecoder : Decoder Schema
callbackDecoder =
    lazy
        (\_ ->
            oneOf
                [ refSchemaDecoder
                , keyValuePairs pathItemDecoder
                    |> map (\pairs -> syntheticObject Nothing Nothing [] pairs)
                ]
        )



-- INITIAL COLLAPSE PATHS


oasCollapsedPathsDecoder : Decoder (Set String)
oasCollapsedPathsDecoder =
    map2 Set.union
        (combineLists
            [ collapseForSection "Schemas" schemasNamesDecoder
            , collapseForSection "Parameters" (unionNames [ [ "components", "parameters" ], [ "parameters" ] ])
            , collapseForSection "Request Bodies" (namesAt [ "components", "requestBodies" ])
            , collapseForSection "Responses" (unionNames [ [ "components", "responses" ], [ "responses" ] ])
            , collapseForSection "Headers" (namesAt [ "components", "headers" ])
            , collapseForSection "Security Schemes" (unionNames [ [ "components", "securitySchemes" ], [ "securityDefinitions" ] ])
            , collapseForSection "Examples" (namesAt [ "components", "examples" ])
            , collapseForSection "Links" (namesAt [ "components", "links" ])
            , collapseForSection "Callbacks" (namesAt [ "components", "callbacks" ])
            ]
            |> map Set.fromList
        )
        endpointsDeepCollapseDecoder


collapseForSection : String -> Decoder (List String) -> Decoder (List String)
collapseForSection sectionName namesDecoder =
    namesDecoder
        |> map (List.map (\n -> "root.properties." ++ sectionName ++ ".properties." ++ n))


{-| Deep-collapse every descendant inside the `Paths` and `Webhooks`
sections so that expanding an endpoint reveals exactly one more level —
the URL pill opens to show verbs (collapsed), the verb opens to show
`parameters` / `requestBody` / `responses` (collapsed), and so on all
the way down. Without this, opening a single verb explodes its whole
parameter/response tree (including inlined `$ref` targets) in one click.
-}
endpointsDeepCollapseDecoder : Decoder (Set String)
endpointsDeepCollapseDecoder =
    openApiDecoder
        |> map (\{ schema } -> deepCollapseInEndpointSections schema)


deepCollapseInEndpointSections : Schema -> Set String
deepCollapseInEndpointSections rootSchema =
    case rootSchema of
        Schema.Object { properties } ->
            List.concatMap
                (\prop ->
                    let
                        ( name, child ) =
                            propNameSchema prop
                    in
                    if name == "Paths" || name == "Webhooks" then
                        allExpandablePathsUnder ("root.properties." ++ name) child

                    else
                        []
                )
                properties
                |> Set.fromList

        _ ->
            Set.empty


propNameSchema : Schema.ObjectProperty -> ( String, Schema )
propNameSchema prop =
    case prop of
        Schema.Required n s ->
            ( n, s )

        Schema.Optional n s ->
            ( n, s )


{-| Walk a schema and return every collapsible descendant path. Assumes
the Object/Array/combinator path scheme used by Render.Svg. Does not
recurse through `$ref` targets — the ref pill itself is added and
clicking it still expands the target inline.
-}
allExpandablePathsUnder : String -> Schema -> List String
allExpandablePathsUnder basePath schema =
    case schema of
        Schema.Object { properties, combinator } ->
            List.concatMap
                (\prop ->
                    let
                        ( name, child ) =
                            propNameSchema prop

                        childPath =
                            basePath ++ ".properties." ++ name
                    in
                    childPath :: allExpandablePathsUnder childPath child
                )
                properties
                ++ combinatorPaths basePath combinator

        Schema.Array { items, combinator } ->
            (case items of
                Just s ->
                    let
                        itemPath =
                            basePath ++ ".items"
                    in
                    itemPath :: allExpandablePathsUnder itemPath s

                Nothing ->
                    []
            )
                ++ combinatorPaths basePath combinator

        Schema.OneOf { subSchemas } ->
            multiPaths basePath subSchemas

        Schema.AnyOf { subSchemas } ->
            multiPaths basePath subSchemas

        Schema.AllOf { subSchemas } ->
            multiPaths basePath subSchemas

        _ ->
            []


multiPaths : String -> List Schema -> List String
multiPaths basePath subs =
    List.indexedMap
        (\i s ->
            let
                itemPath =
                    basePath ++ "." ++ String.fromInt i
            in
            itemPath :: allExpandablePathsUnder itemPath s
        )
        subs
        |> List.concat


combinatorPaths : String -> Maybe ( Schema.CombinatorKind, List Schema ) -> List String
combinatorPaths basePath m =
    case m of
        Nothing ->
            []

        Just ( _, subs ) ->
            let
                combPath =
                    basePath ++ ".combinator"
            in
            combPath :: multiPaths combPath subs


schemasNamesDecoder : Decoder (List String)
schemasNamesDecoder =
    unionNames [ [ "components", "schemas" ], [ "definitions" ] ]


unionNames : List (List String) -> Decoder (List String)
unionNames paths =
    List.map namesAt paths
        |> combineLists


namesAt : List String -> Decoder (List String)
namesAt path =
    at path (keyValuePairs value)
        |> maybe
        |> map (Maybe.withDefault [] >> List.map Tuple.first)



-- HELPERS


namedPairsAt : List String -> Decoder a -> Decoder (List ( String, a ))
namedPairsAt path inner =
    at path (keyValuePairs inner)
        |> maybe
        |> map (Maybe.withDefault [])


combineLists : List (Decoder (List a)) -> Decoder (List a)
combineLists =
    List.foldr (map2 (++)) (succeed [])


decodersToList : List (Decoder a) -> Decoder (List a)
decodersToList =
    List.foldr (map2 (::)) (succeed [])


syntheticObject : Maybe String -> Maybe String -> List String -> List ( String, Schema ) -> Schema
syntheticObject title description requiredList props =
    Schema.object title description (Dict.fromList props) requiredList Nothing Nothing [] Nothing


stringPill : Maybe String -> Maybe String -> Schema
stringPill title description =
    Schema.String
        { title = title
        , description = description
        , examples = []
        , minLength = Nothing
        , maxLength = Nothing
        , pattern = Nothing
        , format = Nothing
        , enum = Nothing
        , combinator = Nothing
        }


anySchema : Schema
anySchema =
    stringPill Nothing Nothing


refSchemaDecoder : Decoder Schema
refSchemaDecoder =
    field "$ref" string
        |> map (\ref -> Schema.reference Nothing Nothing (normalizeRef ref) [] Nothing)


refName : String -> String
refName ref =
    String.split "/" ref
        |> List.reverse
        |> List.head
        |> Maybe.withDefault ref


{-| Combine an OpenAPI-level description (on parameters, responses, request
bodies, headers) with the underlying schema's own description, preserving both.
-}
attachDescription : Maybe String -> Schema -> Schema
attachDescription outer schema =
    case outer of
        Nothing ->
            schema

        Just _ ->
            case schema of
                Schema.String r ->
                    Schema.String { r | description = mergeDescriptions outer r.description }

                Schema.Integer r ->
                    Schema.Integer { r | description = mergeDescriptions outer r.description }

                Schema.Number r ->
                    Schema.Number { r | description = mergeDescriptions outer r.description }

                Schema.Boolean r ->
                    Schema.Boolean { r | description = mergeDescriptions outer r.description }

                Schema.Object r ->
                    Schema.Object { r | description = mergeDescriptions outer r.description }

                Schema.Array r ->
                    Schema.Array { r | description = mergeDescriptions outer r.description }

                Schema.Null r ->
                    Schema.Null { r | description = mergeDescriptions outer r.description }

                Schema.Ref r ->
                    Schema.Ref { r | description = mergeDescriptions outer r.description }

                Schema.OneOf r ->
                    Schema.OneOf { r | description = mergeDescriptions outer r.description }

                Schema.AnyOf r ->
                    Schema.AnyOf { r | description = mergeDescriptions outer r.description }

                Schema.AllOf r ->
                    Schema.AllOf { r | description = mergeDescriptions outer r.description }

                Schema.Fallback _ ->
                    schema


mergeDescriptions : Maybe String -> Maybe String -> Maybe String
mergeDescriptions outer inner =
    case ( outer, inner ) of
        ( Nothing, Nothing ) ->
            Nothing

        ( Just o, Nothing ) ->
            Just o

        ( Nothing, Just i ) ->
            Just i

        ( Just o, Just i ) ->
            Just (o ++ "\n\n" ++ i)


normalizeRef : String -> String
normalizeRef ref =
    if String.startsWith "#/$defs/" ref then
        "#/definitions/" ++ String.dropLeft 8 ref

    else
        ref


combinatorDecoder : Decoder (Maybe ( Schema.CombinatorKind, List Schema ))
combinatorDecoder =
    oneOf
        [ field "oneOf" (list schemaDecoder) |> map (\s -> Just ( Schema.OneOfKind, s ))
        , field "anyOf" (list schemaDecoder) |> map (\s -> Just ( Schema.AnyOfKind, s ))
        , field "allOf" (list schemaDecoder) |> map (\s -> Just ( Schema.AllOfKind, s ))
        , succeed Nothing
        ]


schemaDecoder : Decoder Schema
schemaDecoder =
    lazy
        (\_ ->
            oneOf
                [ succeed Schema.object
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> optional "properties" (dict schemaDecoder) Dict.empty
                    |> optional "required" (list string) []
                    |> maybeOptional "minProperties" int
                    |> maybeOptional "maxProperties" int
                    |> optional "examples" (list value) []
                    |> custom combinatorDecoder
                    |> withType "object"
                , succeed Schema.array
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> maybeOptional "items" schemaDecoder
                    |> maybeOptional "minItems" int
                    |> maybeOptional "maxItems" int
                    |> optional "examples" (list value) []
                    |> custom combinatorDecoder
                    |> withType "array"
                , succeed Schema.string
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> maybeOptional "minLength" int
                    |> maybeOptional "maxLength" int
                    |> maybeOptional "pattern" string
                    |> maybeOptional "format" (string |> map stringFormat)
                    |> maybeOptional "enum" (list string)
                    |> optional "examples" (list value) []
                    |> custom combinatorDecoder
                    |> withType "string"
                    |> map Schema.String
                , succeed Schema.integer
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> maybeOptional "minimum" int
                    |> maybeOptional "maximum" int
                    |> maybeOptional "enum" (list int)
                    |> optional "examples" (list value) []
                    |> custom combinatorDecoder
                    |> withType "integer"
                , succeed Schema.float
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> maybeOptional "minimum" float
                    |> maybeOptional "maximum" float
                    |> maybeOptional "enum" (list float)
                    |> optional "examples" (list value) []
                    |> custom combinatorDecoder
                    |> withType "number"
                , succeed Schema.boolean
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> maybeOptional "enum" (list bool)
                    |> optional "examples" (list value) []
                    |> custom combinatorDecoder
                    |> withType "boolean"
                , succeed Schema.null
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> optional "examples" (list value) []
                    |> custom combinatorDecoder
                    |> withType "null"
                , succeed Schema.object
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> optional "properties" (dict schemaDecoder) Dict.empty
                    |> optional "required" (list string) []
                    |> maybeOptional "minProperties" int
                    |> maybeOptional "maxProperties" int
                    |> optional "examples" (list value) []
                    |> custom combinatorDecoder
                    |> withField "properties"
                , succeed Schema.reference
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> required "$ref" (string |> map normalizeRef)
                    |> optional "examples" (list value) []
                    |> custom combinatorDecoder
                , succeed Schema.baseCombinatorSchema
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> required "oneOf" (list schemaDecoder)
                    |> optional "examples" (list value) []
                    |> map Schema.OneOf
                , succeed Schema.baseCombinatorSchema
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> required "anyOf" (list schemaDecoder)
                    |> optional "examples" (list value) []
                    |> map Schema.AnyOf
                , succeed Schema.baseCombinatorSchema
                    |> maybeOptional "title" string
                    |> maybeOptional "description" string
                    |> required "allOf" (list schemaDecoder)
                    |> optional "examples" (list value) []
                    |> map Schema.AllOf
                , map Schema.Fallback value
                ]
        )


{-| Ensure a decoder has a specific "type" value.
-}
withType : String -> Decoder a -> Decoder a
withType typeString decoder_ =
    field "type" (constant typeString string)
        |> andThen (always decoder_)


{-| Ensure a JSON object has a specific field present (any value).
Used for implicit type inference — e.g. a schema with "properties" is an object.
-}
withField : String -> Decoder a -> Decoder a
withField fieldName decoder_ =
    field fieldName value
        |> andThen (always decoder_)


{-| Decode into a specific expected value or fail.
-}
constant : a -> Decoder a -> Decoder a
constant expectedValue decoder_ =
    decoder_
        |> andThen
            (\actualValue ->
                if actualValue == expectedValue then
                    succeed actualValue

                else
                    fail "Constant value mismatch"
            )


maybeOptional : String -> Decoder a -> Decoder (Maybe a -> b) -> Decoder b
maybeOptional key decoder_ =
    optional key (nullable decoder_) Nothing


stringFormat : String -> Schema.StringFormat
stringFormat format =
    case format of
        "date-time" ->
            Schema.DateTime

        "email" ->
            Schema.Email

        "hostname" ->
            Schema.Hostname

        "ipv4" ->
            Schema.Ipv4

        "ipv6" ->
            Schema.Ipv6

        "uri" ->
            Schema.Uri

        _ ->
            Schema.Custom format
