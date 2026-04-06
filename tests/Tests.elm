module Tests exposing (..)

import Test exposing (..)
import Expect
import Render.Svg exposing (connectorPathD, extractRefName, fontWeightForRequired)


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
        ]
