module Main exposing (main)

import Browser
import File
import Html exposing (Html, div, text)
import Html.Attributes as Attr
import Html.Events
import Json.Decode exposing (decodeString)
import Json.Schema
import Json.Schema.Decode
import Process
import Render.Svg as Render exposing (HoverState, NodeMeta)
import Set exposing (Set)
import Task


type ExampleSchema
    = ExampleArrays
    | ExamplePerson
    | ExampleNested
    | ExampleTypeBox


type alias Model =
    { inputText : String
    , parsedSchema : Result Json.Decode.Error Json.Schema.Model
    , lastValidSchema : Maybe Json.Schema.Model
    , debounceGeneration : Int
    , displayErrors : Bool
    , panelCollapsed : Bool
    , selectedExample : ExampleSchema
    , dragHover : Bool
    , collapsedNodes : Set String
    , hoveredNode : Maybe HoverState
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
    | ToggleNode String
    | HoverNode HoverState
    | UnhoverNode


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
      , collapsedNodes = Set.empty
      , hoveredNode = Nothing
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TextareaChanged newText ->
            let
                newGen =
                    model.debounceGeneration + 1

                parsed =
                    decodeString Json.Schema.Decode.decoder newText

                newLastValid =
                    case parsed of
                        Ok s ->
                            Just s

                        Err _ ->
                            model.lastValidSchema
            in
            ( { model
                | inputText = newText
                , parsedSchema = parsed
                , lastValidSchema = newLastValid
                , debounceGeneration = newGen
                , displayErrors = False
                , collapsedNodes = Set.empty
                , hoveredNode = Nothing
              }
            , Process.sleep 800
                |> Task.perform (\_ -> DebounceTimeout newGen)
            )

        DebounceTimeout gen ->
            if gen == model.debounceGeneration then
                ( { model | displayErrors = True }, Cmd.none )

            else
                ( model, Cmd.none )

        FileDrop file ->
            ( { model | dragHover = False }
            , Task.perform FileContentLoaded (File.toString file)
            )

        FileContentLoaded content ->
            let
                parsed =
                    decodeString Json.Schema.Decode.decoder content

                newLastValid =
                    case parsed of
                        Ok s ->
                            Just s

                        Err _ ->
                            model.lastValidSchema
            in
            ( { model
                | inputText = content
                , parsedSchema = parsed
                , lastValidSchema = newLastValid
                , displayErrors = True
                , collapsedNodes = Set.empty
                , hoveredNode = Nothing
              }
            , Cmd.none
            )

        ExampleSelected example ->
            let
                content =
                    exampleContent example

                parsed =
                    decodeString Json.Schema.Decode.decoder content
            in
            ( { model
                | inputText = content
                , parsedSchema = parsed
                , lastValidSchema =
                    case parsed of
                        Ok s ->
                            Just s

                        Err _ ->
                            model.lastValidSchema
                , selectedExample = example
                , displayErrors = False
                , collapsedNodes = Set.empty
                , hoveredNode = Nothing
              }
            , Cmd.none
            )

        TogglePanel ->
            ( { model | panelCollapsed = not model.panelCollapsed }, Cmd.none )

        DragEnter ->
            ( { model | dragHover = True }, Cmd.none )

        DragLeave ->
            ( { model | dragHover = False }, Cmd.none )

        ToggleNode pathKey ->
            ( { model | collapsedNodes = Render.toggleInSet pathKey model.collapsedNodes }
            , Cmd.none
            )

        HoverNode hoverState ->
            ( { model | hoveredNode = Just hoverState }, Cmd.none )

        UnhoverNode ->
            ( { model | hoveredNode = Nothing }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


view : Model -> Html Msg
view model =
    div [ Attr.class "app-layout" ]
        [ viewToolbar model
        , div [ Attr.class "app-content" ]
            [ if model.panelCollapsed then
                text ""

              else
                viewInputPanel model
            , viewDiagramPanel model
            ]
        ]


viewToolbar : Model -> Html Msg
viewToolbar model =
    div [ Attr.class "toolbar" ]
        [ div [ Attr.class "toolbar-left" ]
            [ Html.span [ Attr.class "app-title" ] [ text "JSON Schema Viewer" ]
            ]
        , viewExampleButtons model.selectedExample
        , viewCollapseToggle model.panelCollapsed
        ]


viewExampleButtons : ExampleSchema -> Html Msg
viewExampleButtons selected =
    div [ Attr.class "example-buttons" ]
        [ exampleButton ExampleArrays "Arrays" selected
        , exampleButton ExamplePerson "Person" selected
        , exampleButton ExampleNested "Nested" selected
        , exampleButton ExampleTypeBox "TypeBox" selected
        ]


exampleButton : ExampleSchema -> String -> ExampleSchema -> Html Msg
exampleButton example label selected =
    Html.button
        [ Attr.class
            (if example == selected then
                "example-btn active"

             else
                "example-btn"
            )
        , Html.Events.onClick (ExampleSelected example)
        ]
        [ text label ]


viewCollapseToggle : Bool -> Html Msg
viewCollapseToggle collapsed =
    Html.button
        [ Attr.class "collapse-toggle"
        , Html.Events.onClick TogglePanel
        ]
        [ text
            (if collapsed then
                "Show"

             else
                "Hide"
            )
        ]


viewInputPanel : Model -> Html Msg
viewInputPanel model =
    div
        [ Attr.class "input-panel"
        , Attr.classList [ ( "drag-hover", model.dragHover ) ]
        , Html.Events.preventDefaultOn "dragover"
            (Json.Decode.succeed ( DragEnter, True ))
        , Html.Events.preventDefaultOn "dragleave"
            (Json.Decode.succeed ( DragLeave, True ))
        , Html.Events.preventDefaultOn "drop"
            (Json.Decode.map
                (\file -> ( FileDrop file, True ))
                (Json.Decode.at [ "dataTransfer", "files", "0" ] File.decoder)
            )
        ]
        [ Html.textarea
            [ Attr.class "schema-textarea"
            , Attr.value model.inputText
            , Html.Events.onInput TextareaChanged
            , Attr.placeholder "Paste a JSON Schema document here, or drag and drop a .json file."
            , Attr.attribute "spellcheck" "false"
            , Attr.attribute "autocorrect" "off"
            , Attr.attribute "autocapitalize" "off"
            ]
            []
        ]


viewDiagramPanel : Model -> Html Msg
viewDiagramPanel model =
    div
        [ Attr.class "diagram-panel"
        , Attr.style "position" "relative"
        ]
        [ case model.parsedSchema of
            Ok spec ->
                Render.view ToggleNode HoverNode UnhoverNode model.collapsedNodes spec.definitions spec.schema

            Err e ->
                if model.displayErrors then
                    viewError e

                else
                    case model.lastValidSchema of
                        Just spec ->
                            Render.view ToggleNode HoverNode UnhoverNode model.collapsedNodes spec.definitions spec.schema

                        Nothing ->
                            viewError e
        , viewHoverOverlay model.hoveredNode
        ]


viewHoverOverlay : Maybe HoverState -> Html Msg
viewHoverOverlay maybeHover =
    case maybeHover of
        Nothing ->
            text ""

        Just { clientX, clientY, meta } ->
            let
                rows =
                    buildOverlayRows meta
            in
            if List.isEmpty rows then
                text ""

            else
                div
                    [ Attr.style "position" "fixed"
                    , Attr.style "left" (String.fromFloat (clientX + 12) ++ "px")
                    , Attr.style "top" (String.fromFloat (clientY - 8) ++ "px")
                    , Attr.style "background" "#0f1e30"
                    , Attr.style "border" "1px solid #3a5a7a"
                    , Attr.style "border-radius" "4px"
                    , Attr.style "padding" "8px 12px"
                    , Attr.style "font-family" "monospace"
                    , Attr.style "font-size" "11px"
                    , Attr.style "pointer-events" "none"
                    , Attr.style "z-index" "1000"
                    , Attr.style "max-width" "300px"
                    ]
                    (List.map viewOverlayRow rows)


viewOverlayRow : ( String, String ) -> Html Msg
viewOverlayRow ( key, value ) =
    div [ Attr.style "margin" "2px 0" ]
        [ Html.span
            [ Attr.style "color" "#8ab0d0"
            , Attr.style "font-weight" "400"
            ]
            [ text (key ++ "  ") ]
        , Html.span
            [ Attr.style "color" "#e8f0f8"
            , Attr.style "font-weight" "700"
            ]
            [ text value ]
        ]


buildOverlayRows : NodeMeta -> List ( String, String )
buildOverlayRows meta =
    let
        typeRow =
            case meta.baseType of
                Just t ->
                    [ ( "type", t ) ]

                Nothing ->
                    []

        descRow =
            case meta.description of
                Just d ->
                    [ ( "desc", d ) ]

                Nothing ->
                    []

        enumRow =
            case meta.enumValues of
                Just vals ->
                    let
                        shown =
                            List.take 5 vals

                        overflow =
                            List.length vals - 5

                        valStr =
                            String.join ", " (List.map (\v -> "\"" ++ v ++ "\"") shown)
                                ++ (if overflow > 0 then
                                        ", +" ++ String.fromInt overflow ++ " more"

                                    else
                                        ""
                                   )
                    in
                    [ ( "enum", valStr ) ]

                Nothing ->
                    []

        constraintRows =
            List.map (\( k, v ) -> ( k, v )) meta.constraints
    in
    typeRow ++ descRow ++ enumRow ++ constraintRows


viewError : Json.Decode.Error -> Html Msg
viewError error =
    div [ Attr.class "error-container" ]
        [ Html.h2 [ Attr.class "error-heading" ] [ text "Invalid JSON Schema" ]
        , Html.p [ Attr.class "error-body" ]
            [ text "The pasted text is not valid JSON Schema. Check the input and try again." ]
        , Html.pre [ Attr.class "error-detail" ]
            [ text (Json.Decode.errorToString error) ]
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

        ExampleTypeBox ->
            exampleTypeBoxJson


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


exampleTypeBoxJson : String
exampleTypeBoxJson =
    """{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "age": { "type": "integer" },
    "address": { "$ref": "#/$defs/Address" }
  },
  "required": ["name"],
  "oneOf": [
    {
      "properties": {
        "role": { "type": "string", "enum": ["admin"] },
        "permissions": { "type": "array", "items": { "type": "string" } }
      },
      "required": ["role"]
    },
    {
      "properties": {
        "role": { "type": "string", "enum": ["user"] }
      },
      "required": ["role"]
    }
  ],
  "$defs": {
    "Address": {
      "type": "object",
      "properties": {
        "street": { "type": "string" },
        "city": { "type": "string" },
        "zip": { "type": "string" }
      },
      "required": ["street", "city"]
    }
  }
}"""
