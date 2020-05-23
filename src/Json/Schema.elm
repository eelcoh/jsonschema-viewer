module Json.Schema exposing
    ( ArraySchema
    , BaseCombinatorSchema
    , BaseNumberSchema
    , BaseSchema
    , BooleanSchema
    , Definitions
    , IntegerSchema
    , Model
    , NullSchema
    , NumberSchema
    , ObjectProperty(..)
    , ObjectSchema
    , RefSchema
    , Schema(..)
    , StringFormat(..)
    , StringSchema
    , WithEnumSchema
    , array
    , baseCombinatorSchema
    , boolean
    , float
    , integer
    , null
    , object
    , reference
    , string
    )

import Dict exposing (Dict)
import Json.Decode
import Json.Encode as Encode


type alias Model =
    { definitions : Definitions
    , schema : Schema
    }


type Schema
    = Object ObjectSchema
    | Array ArraySchema
    | String StringSchema
    | Integer IntegerSchema
    | Number NumberSchema
    | Boolean BooleanSchema
    | Null NullSchema
    | Ref RefSchema
    | OneOf BaseCombinatorSchema
    | AnyOf BaseCombinatorSchema
    | AllOf BaseCombinatorSchema
      -- | Lazy (() -> Schema)
    | Fallback Json.Decode.Value


type alias Definitions =
    Dict String Schema


type alias BaseSchema extras =
    { extras
        | title : Maybe String
        , description : Maybe String
        , examples : List Encode.Value
    }


type alias WithEnumSchema primitive extras =
    { extras
        | enum : Maybe (List primitive)
    }


type alias ObjectSchema =
    BaseSchema
        { properties : List ObjectProperty
        , minProperties : Maybe Int
        , maxProperties : Maybe Int
        }


object : Maybe String -> Maybe String -> Dict String Schema -> List String -> Maybe Int -> Maybe Int -> List Encode.Value -> Schema
object title description properties required minProperties maxProperties examples =
    let
        isRequired p =
            List.member p required

        property ( p, v ) =
            if isRequired p then
                Required p v

            else
                Optional p v
    in
    Object
        { title = title
        , description = description
        , properties = List.map property <| Dict.toList properties
        , minProperties = minProperties
        , maxProperties = maxProperties
        , examples = examples
        }


type alias ArraySchema =
    BaseSchema
        { items : Maybe Schema
        , minItems : Maybe Int
        , maxItems : Maybe Int
        }


array : Maybe String -> Maybe String -> Maybe Schema -> Maybe Int -> Maybe Int -> List Encode.Value -> Schema
array title description items minItems maxItems examples =
    Array
        { title = title
        , description = description
        , items = items
        , minItems = minItems
        , maxItems = maxItems
        , examples = examples
        }


type alias BaseNumberSchema num =
    WithEnumSchema num
        (BaseSchema
            { minimum : Maybe num
            , maximum : Maybe num
            }
        )


type alias IntegerSchema =
    BaseNumberSchema Int


integer : Maybe String -> Maybe String -> Maybe Int -> Maybe Int -> Maybe (List Int) -> List Encode.Value -> Schema
integer title description minumum maximum enum examples =
    Integer
        { title = title
        , description = description
        , minimum = minumum
        , maximum = maximum
        , enum = enum
        , examples = examples
        }


type alias NumberSchema =
    BaseNumberSchema Float


float : Maybe String -> Maybe String -> Maybe Float -> Maybe Float -> Maybe (List Float) -> List Encode.Value -> Schema
float title description minumum maximum enum examples =
    Number
        { title = title
        , description = description
        , minimum = minumum
        , maximum = maximum
        , enum = enum
        , examples = examples
        }


type ObjectProperty
    = Required String Schema
    | Optional String Schema


type alias StringSchema =
    WithEnumSchema String
        (BaseSchema
            { minLength : Maybe Int
            , maxLength : Maybe Int
            , pattern : Maybe String
            , format : Maybe StringFormat
            }
        )


string : Maybe String -> Maybe String -> Maybe Int -> Maybe Int -> Maybe String -> Maybe StringFormat -> Maybe (List String) -> List Encode.Value -> StringSchema
string title description minLength maxLength pattern format enum examples =
    { title = title
    , description = description
    , examples = examples
    , minLength = minLength
    , maxLength = maxLength
    , pattern = pattern
    , format = format
    , enum = enum
    }


type alias BooleanSchema =
    WithEnumSchema Bool (BaseSchema {})


boolean : Maybe String -> Maybe String -> Maybe (List Bool) -> List Encode.Value -> Schema
boolean title description enum examples =
    Boolean
        { title = title
        , description = description
        , enum = enum
        , examples = examples
        }


type alias NullSchema =
    BaseSchema {}


null : Maybe String -> Maybe String -> List Encode.Value -> Schema
null title description examples =
    Null
        { title = title
        , description = description
        , examples = examples
        }


type alias RefSchema =
    BaseSchema
        { ref : String
        }


reference : Maybe String -> Maybe String -> String -> List Encode.Value -> Schema
reference title description ref examples =
    Ref
        { title = title
        , description = description
        , ref = ref
        , examples = examples
        }


type alias BaseCombinatorSchema =
    BaseSchema
        { subSchemas : List Schema
        }


baseCombinatorSchema : Maybe String -> Maybe String -> List Schema -> List Encode.Value -> BaseCombinatorSchema
baseCombinatorSchema title description subSchemas examples =
    { title = title
    , description = description
    , subSchemas = subSchemas
    , examples = examples
    }



-- baseCombinatorSchema : Combinator -> Maybe String -> Maybe String -> List Encode.Value -> List Schema -> BaseCombinatorSchema
-- baseCombinatorSchema combinator title description examples subSchemas =
--     let
--         s =
--             { title = title
--             , description = description
--             , examples = examples
--             , subSchemas = subSchemas
--             }
--     in
--     case combinator of
--         All ->
--             AllOf s
--         Any ->
--             AnyOf s
--         One ->
--             OneOf s


{-| One of the built-in string formats defined by the json schema specification,
or a custom format your schema validator understands.
-}
type StringFormat
    = DateTime
    | Email
    | Hostname
    | Ipv4
    | Ipv6
    | Uri
    | Custom String


getName : Schema -> Maybe String
getName schema =
    case schema of
        Object { title } ->
            title

        Array { title } ->
            title

        String { title } ->
            title

        Integer { title } ->
            title

        Number { title } ->
            title

        Boolean { title } ->
            title

        Null { title } ->
            title

        Ref { title } ->
            title

        OneOf { title } ->
            title

        AnyOf { title } ->
            title

        AllOf { title } ->
            title

        -- | Lazy (()  {name} -> name
        Fallback _ ->
            Nothing
