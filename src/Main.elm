module Main exposing (main)

import Browser
import Dict
import File
import Html exposing (Html, div, text)
import Html.Attributes as Attr
import Html.Events
import Json.Decode exposing (decodeString)
import Json.Schema exposing (Definitions, Schema)
import Json.Schema.Decode exposing (decoder)
import Process
import Render.Svg as Render
import Task


type ExampleSchema
    = ExampleArrays
    | ExamplePerson
    | ExampleNested


type alias Model =
    { inputText : String
    , parsedSchema : Result Json.Decode.Error Json.Schema.Model
    , lastValidSchema : Maybe Json.Schema.Model
    , debounceGeneration : Int
    , displayErrors : Bool
    , panelCollapsed : Bool
    , selectedExample : ExampleSchema
    , dragHover : Bool
    }


type Msg
    = TextareaChanged String
    | DebounceTimeout Int
    | FileDrop File.File
    | FileContentLoaded String
    | ExampleSelected ExampleSchema
    | TogglePanel
    | DragEnter
    | DragLeave
    | NoOp


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        }


init : () -> ( Model, Cmd Msg )
init _ =
    let
        initialText =
            exampleContent ExampleArrays

        parsed =
            decodeString Json.Schema.Decode.decoder initialText
    in
    ( { inputText = initialText
      , parsedSchema = parsed
      , lastValidSchema =
            case parsed of
                Ok s ->
                    Just s

                Err _ ->
                    Nothing
      , debounceGeneration = 0
      , displayErrors = False
      , panelCollapsed = False
      , selectedExample = ExampleArrays
      , dragHover = False
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TextareaChanged _ ->
            ( model, Cmd.none )

        DebounceTimeout _ ->
            ( model, Cmd.none )

        FileDrop _ ->
            ( model, Cmd.none )

        FileContentLoaded _ ->
            ( model, Cmd.none )

        ExampleSelected _ ->
            ( model, Cmd.none )

        TogglePanel ->
            ( model, Cmd.none )

        DragEnter ->
            ( model, Cmd.none )

        DragLeave ->
            ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    case model.parsedSchema of
        Err e ->
            div [] [ text (Json.Decode.errorToString e) ]

        Ok spec ->
            div []
                [ Render.view spec.definitions spec.schema
                ]


exampleContent : ExampleSchema -> String
exampleContent example =
    case example of
        ExampleArrays ->
            exampleArraysJson

        ExamplePerson ->
            examplePersonJson

        ExampleNested ->
            exampleNestedJson


exampleArraysJson : String
exampleArraysJson =
    """
{
  "$id": "https://example.com/arrays.schema.json",
  "$schema": "http://json-schema.org/draft-07/schema#",
  "description": "A representation of a person, company, organization, or place",
  "type": "object",
  "properties": {
    "fruits": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "vegetables": {
      "type": "array",
      "items": { "$ref": "#/definitions/veggie" }
    }
  },
  "definitions": {
    "veggie": {
      "type": "object",
      "required": [ "veggieName", "veggieLike" ],
      "properties": {
        "veggieName": {
          "type": "string",
          "description": "The name of the vegetable."
        },
        "veggieLike": {
          "type": "boolean",
          "description": "Do I like this vegetable?"
        }
      }
    }
  }
}
"""


examplePersonJson : String
examplePersonJson =
    """
{
  "$id": "https://example.com/person.schema.json",
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Person",
  "type": "object",
  "properties": {
    "firstName": {
      "type": "string",
      "description": "The person's first name."
    },
    "lastName": {
      "type": "string",
      "description": "The person's last name."
    },
    "age": {
      "description": "Age in years which must be equal to or greater than zero.",
      "type": "integer",
      "minimum": 0
    }
  }
}
    """


exampleNestedJson : String
exampleNestedJson =
    """
{
  "type": "object",
  "title": "person",
  "properties": {
    "firstName": {
      "type": "string",
      "description": "The person's first name."
    },
    "lastName": {
      "type": "string",
      "description": "The person's last name."
    },
    "age": {
      "description": "Age in years which must be equal to or greater than zero.",
      "type": "integer",
      "minimum": 0
    },
    "children": {
      "description": "Children.",
      "type": "array",
      "minItems": 0,
      "items": {
        "type": "object",
        "properties": {
          "firstName": {
            "type": "string",
            "description": "The person's first name."
          },
          "lastName": {
            "type": "string",
            "description": "The person's last name."
          },
          "age": {
            "description": "Age in years which must be equal to or greater than zero.",
            "type": "integer",
            "minimum": 0
          }
        }
      }
    }
  }
}
    """
