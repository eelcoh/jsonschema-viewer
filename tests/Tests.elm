module Tests exposing (..)

import Test exposing (..)
import Expect
import Render.Svg exposing (connectorPathD, extractRefName, fontWeightForRequired, iconForSchema, Icon(..))
import Json.Schema as Schema


-- Check out https://package.elm-lang.org/packages/elm-explorations/test/latest to learn more about testing in Elm!


all : Test
all =
    describe "A Test Suite"
        [ test "Addition" <|
            \_ ->
                Expect.equal 10 (3 + 7)
        , test "String.left" <|
            \_ ->
                Expect.equal "a" (String.left 1 "abcdefg")
        , describe "connectorPathD"
            [ test "horizontal line (same Y)" <|
                \_ ->
                    connectorPathD ( 100, 14 ) ( 120, 14 )
                        |> Expect.equal "M 100 14 C 110 14 110 14 120 14"
            , test "diagonal bezier (different Y)" <|
                \_ ->
                    connectorPathD ( 0, 14 ) ( 20, 52 )
                        |> Expect.equal "M 0 14 C 10 14 10 52 20 52"
            ]
        , describe "extractRefName"
            [ test "strips #/definitions/ prefix" <|
                \_ ->
                    extractRefName "#/definitions/Address"
                        |> Expect.equal "Address"
            ]
        , describe "fontWeightForRequired"
            [ test "required is bold" <|
                \_ ->
                    fontWeightForRequired True
                        |> Expect.equal "700"
            , test "optional is normal" <|
                \_ ->
                    fontWeightForRequired False
                        |> Expect.equal "400"
            ]
        , describe "iconForSchema"
            [ test "String with Email format returns IEmail" <|
                \_ ->
                    Schema.String (Schema.string Nothing Nothing Nothing Nothing Nothing (Just Schema.Email) Nothing [] Nothing)
                        |> iconForSchema
                        |> Expect.equal IEmail
            , test "String with DateTime format returns IDateTime" <|
                \_ ->
                    Schema.String (Schema.string Nothing Nothing Nothing Nothing Nothing (Just Schema.DateTime) Nothing [] Nothing)
                        |> iconForSchema
                        |> Expect.equal IDateTime
            , test "String with Hostname format returns IHostname" <|
                \_ ->
                    Schema.String (Schema.string Nothing Nothing Nothing Nothing Nothing (Just Schema.Hostname) Nothing [] Nothing)
                        |> iconForSchema
                        |> Expect.equal IHostname
            , test "String with Ipv4 format returns IIpv4" <|
                \_ ->
                    Schema.String (Schema.string Nothing Nothing Nothing Nothing Nothing (Just Schema.Ipv4) Nothing [] Nothing)
                        |> iconForSchema
                        |> Expect.equal IIpv4
            , test "String with Ipv6 format returns IIpv6" <|
                \_ ->
                    Schema.String (Schema.string Nothing Nothing Nothing Nothing Nothing (Just Schema.Ipv6) Nothing [] Nothing)
                        |> iconForSchema
                        |> Expect.equal IIpv6
            , test "String with Uri format returns IUri" <|
                \_ ->
                    Schema.String (Schema.string Nothing Nothing Nothing Nothing Nothing (Just Schema.Uri) Nothing [] Nothing)
                        |> iconForSchema
                        |> Expect.equal IUri
            , test "String with Custom format returns ICustom" <|
                \_ ->
                    Schema.String (Schema.string Nothing Nothing Nothing Nothing Nothing (Just (Schema.Custom "phone")) Nothing [] Nothing)
                        |> iconForSchema
                        |> Expect.equal (ICustom "phone")
            , test "String with no format returns IStr" <|
                \_ ->
                    Schema.String (Schema.string Nothing Nothing Nothing Nothing Nothing Nothing Nothing [] Nothing)
                        |> iconForSchema
                        |> Expect.equal IStr
            , test "String with enum returns IEnum (enum takes precedence over format)" <|
                \_ ->
                    Schema.String (Schema.string Nothing Nothing Nothing Nothing Nothing (Just Schema.Email) (Just [ "a", "b" ]) [] Nothing)
                        |> iconForSchema
                        |> Expect.equal IEnum
            , test "Integer with enum returns IEnum" <|
                \_ ->
                    Schema.integer Nothing Nothing Nothing Nothing (Just [ 1, 2, 3 ]) [] Nothing
                        |> iconForSchema
                        |> Expect.equal IEnum
            , test "Integer without enum returns IInt" <|
                \_ ->
                    Schema.integer Nothing Nothing Nothing Nothing Nothing [] Nothing
                        |> iconForSchema
                        |> Expect.equal IInt
            , test "Number without enum returns IFloat" <|
                \_ ->
                    Schema.float Nothing Nothing Nothing Nothing Nothing [] Nothing
                        |> iconForSchema
                        |> Expect.equal IFloat
            , test "Boolean without enum returns IBool" <|
                \_ ->
                    Schema.boolean Nothing Nothing Nothing [] Nothing
                        |> iconForSchema
                        |> Expect.equal IBool
            ]
        ]
