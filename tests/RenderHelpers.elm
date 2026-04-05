module RenderHelpers exposing (..)

import Test exposing (..)
import Expect
import Set
import Render.Svg exposing (viewBoxString, extractRefName, isCircularRef, refLabel, fontWeightForRequired, toggleInSet)


all : Test
all =
    describe "Render.Svg helpers"
        [ describe "viewBoxString"
            [ test "adds padding to width and height" <|
                \_ ->
                    Expect.equal "0 0 220 320" (viewBoxString 200 300 20)
            , test "handles zero dimensions with padding" <|
                \_ ->
                    Expect.equal "0 0 20 20" (viewBoxString 0 0 20)
            , test "handles fractional dimensions" <|
                \_ ->
                    Expect.equal "0 0 170.5 228" (viewBoxString 150.5 208 20)
            ]
        , describe "extractRefName"
            [ test "drops #/definitions/ prefix" <|
                \_ ->
                    Expect.equal "Veggie" (extractRefName "#/definitions/Veggie")
            , test "handles longer definition names" <|
                \_ ->
                    Expect.equal "Address.Street" (extractRefName "#/definitions/Address.Street")
            , test "handles empty name after prefix" <|
                \_ ->
                    Expect.equal "" (extractRefName "#/definitions/")
            ]
        , describe "isCircularRef"
            [ test "returns True when ref is in visited set" <|
                \_ ->
                    let
                        visited = Set.fromList [ "#/definitions/Node" ]
                    in
                    Expect.equal True (isCircularRef visited "#/definitions/Node")
            , test "returns False when ref is not in visited set" <|
                \_ ->
                    let
                        visited = Set.fromList [ "#/definitions/Other" ]
                    in
                    Expect.equal False (isCircularRef visited "#/definitions/Node")
            , test "returns False for empty visited set" <|
                \_ ->
                    Expect.equal False (isCircularRef Set.empty "#/definitions/Node")
            ]
        , describe "refLabel"
            [ test "appends cycle indicator when isCycle is True" <|
                \_ ->
                    Expect.equal "Node ↺" (refLabel "Node" True)
            , test "returns plain name when isCycle is False" <|
                \_ ->
                    Expect.equal "Node" (refLabel "Node" False)
            ]
        , describe "fontWeightForRequired"
            [ test "returns 700 for required properties" <|
                \_ ->
                    Expect.equal "700" (fontWeightForRequired True)
            , test "returns 400 for optional properties" <|
                \_ ->
                    Expect.equal "400" (fontWeightForRequired False)
            ]
        , describe "toggleInSet"
            [ test "inserts key when absent" <|
                \_ ->
                    Expect.equal (Set.fromList [ "a" ]) (toggleInSet "a" Set.empty)
            , test "removes key when present" <|
                \_ ->
                    Expect.equal Set.empty (toggleInSet "a" (Set.fromList [ "a" ]))
            , test "does not affect other keys" <|
                \_ ->
                    Expect.equal (Set.fromList [ "b" ]) (toggleInSet "a" (Set.fromList [ "a", "b" ]))
            , test "inserts into non-empty set" <|
                \_ ->
                    Expect.equal (Set.fromList [ "a", "b", "c" ]) (toggleInSet "c" (Set.fromList [ "a", "b" ]))
            ]
        ]
