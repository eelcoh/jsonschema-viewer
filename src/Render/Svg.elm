module Render.Svg exposing (view, viewBoxString, extractRefName, isCircularRef, refLabel, fontWeightForRequired, toggleInSet, connectorPathD)

import Color exposing (gray)
import Color.Convert
import Dict
import Html exposing (text)
import Json.Decode
import Json.Schema as Schema exposing (Definitions, Schema)
import Set exposing (Set)
import Svg exposing (Svg)
import Svg.Attributes as SvgA exposing (refY)
import Svg.Events
import Svg.Lazy exposing (lazy)



-- import Swagger2 as Swagger exposing (Location(..), Parameter(..), Verb(..), decoder)


type alias Coordinates =
    ( Float, Float )


type alias Dimensions =
    ( Float, Float )


ySpace =
    10


pillHeight =
    28


view : (String -> msg) -> Set String -> Definitions -> Schema -> Html.Html msg
view toggleMsg collapsedNodes defs schema =
    let
        ( schemaView, ( w, h ) ) =
            viewSchema Set.empty defs collapsedNodes toggleMsg "root" ( 0, 0 ) Nothing "700" schema

        vb =
            viewBoxString w h 20
    in
    Svg.svg
        [ SvgA.width "100%"
        , SvgA.height "100%"
        , SvgA.viewBox vb
        ]
        [ schemaView ]


clickableGroup : msg -> ( Svg.Svg msg, Dimensions ) -> ( Svg.Svg msg, Dimensions )
clickableGroup msg ( svg, dims ) =
    ( Svg.g
        [ Svg.Events.stopPropagationOn "click"
            (Json.Decode.succeed ( msg, True ))
        , SvgA.cursor "pointer"
        ]
        [ svg ]
    , dims
    )


viewProperties :
    Set String
    -> Definitions
    -> Set String
    -> (String -> msg)
    -> String
    -> Float
    -> Float
    -> Coordinates
    -> List Schema.ObjectProperty
    -> ( List (Svg msg), Coordinates )
viewProperties visited defs collapsedNodes toggleMsg path parentRightX parentY coords props =
    let
        ( g, ( _, h ), w ) =
            viewProps coords props

        viewProps (( x, y ) as coords_) elms =
            case elms of
                [] ->
                    ( [], coords_, x )

                element :: elements ->
                    let
                        ( g_, ( w1, h1 ) ) =
                            viewProperty visited defs collapsedNodes toggleMsg path coords_ element

                        connector =
                            connectorPath
                                ( parentRightX, parentY + 14 )
                                ( x, y + 14 )

                        ( gs, ( w2, h2 ), w3 ) =
                            viewProps ( x, h1 + 10 ) elements

                        maxW =
                            List.foldl Basics.max w1 [ w1, w2, w3 ]
                    in
                    ( connector :: g_ :: gs, ( x, h2 ), maxW )
    in
    ( g, ( w, h ) )


viewItems :
    Set String
    -> Definitions
    -> Set String
    -> (String -> msg)
    -> String
    -> Float
    -> Float
    -> Coordinates
    -> List Schema
    -> ( List (Svg msg), Coordinates )
viewItems visited defs collapsedNodes toggleMsg path parentRightX parentY coords items =
    let
        ( g, ( _, h ), w ) =
            viewItems_ 0 coords items

        viewItems_ idx (( x, y ) as coords_) elms =
            case elms of
                [] ->
                    ( [], coords_, x )

                element :: elements ->
                    let
                        itemPath =
                            path ++ "." ++ String.fromInt idx

                        ( g_, ( w1, h1 ) ) =
                            viewArrayItem visited defs collapsedNodes toggleMsg itemPath coords_ element

                        connector =
                            connectorPath
                                ( parentRightX, parentY + 14 )
                                ( x, y + 14 )

                        ( gs, ( w2, h2 ), w3 ) =
                            viewItems_ (idx + 1) ( x, h1 + 10 ) elements

                        maxW =
                            List.foldl Basics.max w1 [ w1, w2, w3 ]
                    in
                    ( connector :: g_ :: gs, ( x, h2 ), maxW )
    in
    ( g, ( w, h ) )



-- viewElms :
--     (Definitions -> Coordinates -> a -> ( Svg msg, Dimensions ))
--     -> Definitions
--     -> Coordinates
--     -> List a
--     -> ( List (Svg msg), Coordinates )
-- viewElms fn defs coords elms =
--     let
--         ( g, ( _, h ), w ) =
--             viewElms_ fn defs coords elms
--     in
--     ( g, ( w, h ) )
-- viewElms_ :
--     (Definitions -> Coordinates -> a -> ( Svg msg, Dimensions ))
--     -> Definitions
--     -> Coordinates
--     -> List a
--     -> ( List (Svg msg), Coordinates, Float )
-- viewElms_ fn defs (( x, y ) as coords) elms =
--     case elms of
--         [] ->
--             ( [], coords, x )
--         element :: elements ->
--             let
--                 ( g, ( w1, h1 ) ) =
--                     fn defs coords element
--                 ( gs, ( w2, h2 ), w3 ) =
--                     viewElms_ fn defs ( x, h1 + 10 ) elements
--                 maxW =
--                     List.foldl Basics.max w1 [ w1, w2, w3 ]
--             in
--             ( g :: gs, ( x, h2 ), maxW )


toSvgCoordsTuple : ( List (Svg msg), Coordinates ) -> ( Svg msg, Coordinates )
toSvgCoordsTuple ( a, b ) =
    ( Svg.g [] a, b )


type alias Name =
    String


viewAnonymousSchema : Set String -> Definitions -> Set String -> (String -> msg) -> String -> Coordinates -> Schema -> ( Svg msg, Dimensions )
viewAnonymousSchema visited defs collapsedNodes toggleMsg path coords schema =
    viewSchema visited defs collapsedNodes toggleMsg path coords Nothing "700" schema


viewSchema : Set String -> Definitions -> Set String -> (String -> msg) -> String -> Coordinates -> Maybe Name -> String -> Schema -> ( Svg msg, Dimensions )
viewSchema visited defs collapsedNodes toggleMsg path (( x, y ) as coords) name weight schema =
    case schema of
        Schema.Object { title, properties } ->
            let
                ( objectGraph, ( w, h ) ) =
                    iconRect IObject name weight coords
                        |> clickableGroup (toggleMsg path)
            in
            if Set.member path collapsedNodes then
                ( objectGraph, ( w, h ) )

            else
                let
                    ( propertiesGraphs, ( pw, ph ) ) =
                        viewProperties visited defs collapsedNodes toggleMsg path w y ( w + 10, y ) properties

                    graphs =
                        objectGraph :: propertiesGraphs
                in
                ( graphs, ( pw, Basics.max h ph ) )
                    |> toSvgCoordsTuple

        Schema.Array { title, items } ->
            let
                ( arrayGraph, ( w, h ) ) =
                    iconRect IList name weight coords
                        |> clickableGroup (toggleMsg path)
            in
            if Set.member path collapsedNodes then
                ( arrayGraph, ( w, h ) )

            else
                let
                    ( itemsGraph, ( iw, ih ) ) =
                        case items of
                            Nothing ->
                                roundRect "*" ( w + 10, y )

                            Just items_ ->
                                viewSchema visited defs collapsedNodes toggleMsg (path ++ ".items") ( w + 10, y ) Nothing "700" items_

                    itemConnector =
                        connectorPath ( w, y + 14 ) ( w + 10, y + 14 )

                    graphs =
                        [ arrayGraph, itemConnector, itemsGraph ]
                in
                ( graphs, ( iw, Basics.max h ih ) )
                    |> toSvgCoordsTuple

        Schema.String { title } ->
            viewString weight coords name

        Schema.Integer { title } ->
            viewInteger weight coords name

        Schema.Number { title } ->
            viewFloat weight coords name

        Schema.Boolean { title } ->
            viewBool weight coords name

        Schema.Null { title } ->
            viewMaybeTitle coords "Null" name

        Schema.Ref { title, ref } ->
            let
                defName =
                    extractRefName ref

                isCycle =
                    isCircularRef visited ref
            in
            if isCycle then
                -- Cycle pill: not clickable (D-05)
                iconRect (IRef "*") (Just (refLabel defName True)) weight ( x, y )

            else if Set.member path collapsedNodes then
                -- Collapsed ref: show label pill with click handler to expand
                iconRect (IRef "*") (Just defName) weight ( x, y )
                    |> clickableGroup (toggleMsg path)

            else
                case Dict.get ref defs of
                    Nothing ->
                        -- Definition not found: show label pill, not clickable
                        iconRect (IRef "*") (Just defName) weight ( x, y )

                    Just defSchema ->
                        -- Expanded: render definition inline with cycle guard
                        viewSchema (Set.insert ref visited) defs collapsedNodes toggleMsg path ( x, y ) (Just defName) weight defSchema
                            |> clickableGroup (toggleMsg path)

        Schema.OneOf { title, subSchemas } ->
            viewMulti visited defs collapsedNodes toggleMsg path ( x, y ) "|1|" name subSchemas

        Schema.AnyOf { title, subSchemas } ->
            viewMulti visited defs collapsedNodes toggleMsg path ( x, y ) "|o|" name subSchemas

        Schema.AllOf { title, subSchemas } ->
            viewMulti visited defs collapsedNodes toggleMsg path ( x, y ) "(&)" name subSchemas

        Schema.Fallback _ ->
            ( Svg.g [] [], coords )


viewMulti : Set String -> Definitions -> Set String -> (String -> msg) -> String -> Coordinates -> String -> Maybe Name -> List Schema -> ( Svg msg, Dimensions )
viewMulti visited defs collapsedNodes toggleMsg path ( x, y ) icon _ schemas =
    let
        ( choiceGraph, ( w, h ) ) =
            roundRect icon ( x, y )
                |> clickableGroup (toggleMsg path)
    in
    if Set.member path collapsedNodes then
        ( choiceGraph, ( w, h ) )

    else
        let
            ( subSchemaGraphs, newCoords ) =
                viewItems visited defs collapsedNodes toggleMsg path w y ( w + 10, y ) schemas

            allOfGraph =
                choiceGraph :: subSchemaGraphs
        in
        ( allOfGraph, newCoords )
            |> toSvgCoordsTuple


viewMaybeTitle : Coordinates -> String -> Maybe String -> ( Svg msg, Dimensions )
viewMaybeTitle coords s mTitle =
    let
        mkTitle t =
            t ++ " : " ++ s

        title =
            Maybe.map mkTitle mTitle
                |> Maybe.withDefault s
    in
    roundRect title coords



-- viewBodyParams defs coords { name, schema } =
--     viewPathParams defs coords "body" schema name
-- viewPathParams defs ( x, y ) location schema name =
--     let
--         ( locGraph, ( w, h ) ) =
--             roundRect (location ++ " ::") ( x, y )
--         ( schemaGraphs, newCoords ) =
--             viewSchema defs ( w + 10, y ) (Just name) schema
--         fullGraph =
--             [ locGraph, schemaGraphs ]
--     in
--     ( fullGraph, newCoords )
--         |> toSvgCoordsTuple
-- viewFile : Coordinates -> Maybe String -> ( Svg msg, Dimensions )
-- viewFile coords name =
--     iconRect IFile name coords


viewBool : String -> Coordinates -> Maybe String -> ( Svg msg, Dimensions )
viewBool weight coords name =
    iconRect IBool name weight coords


viewFloat : String -> Coordinates -> Maybe String -> ( Svg msg, Dimensions )
viewFloat weight coords name =
    iconRect IFloat name weight coords


viewInteger : String -> Coordinates -> Maybe String -> ( Svg msg, Dimensions )
viewInteger weight coords name =
    iconRect IInt name weight coords


viewString : String -> Coordinates -> Maybe String -> ( Svg msg, Dimensions )
viewString weight coords name =
    iconRect IStr name weight coords



-- viewResponses defs coords responses =
--     viewElms viewResponse defs coords responses
-- viewResponse defs ( x, y ) ( code, { description, schema } ) =
--     let
--         ( codeGraph, ( w, h ) ) =
--             roundRect code ( x, y )
--         schemaView =
--             Maybe.map (viewAnonymousSchema defs ( w + 10, y )) schema
--     in
--     case schemaView of
--         Nothing ->
--             ( codeGraph, ( w, h ) )
--         Just ( schemaGraph, newCoords ) ->
--             let
--                 graph =
--                     Svg.g [] [ codeGraph, schemaGraph ]
--             in
--             ( graph, newCoords )


viewProperty : Set String -> Definitions -> Set String -> (String -> msg) -> String -> Coordinates -> Schema.ObjectProperty -> ( Svg msg, Dimensions )
viewProperty visited defs collapsedNodes toggleMsg path coords objectProperty =
    let
        ( name, property, isRequired ) =
            case objectProperty of
                Schema.Required name_ property_ ->
                    ( name_, property_, True )

                Schema.Optional name_ property_ ->
                    ( name_, property_, False )

        weight =
            fontWeightForRequired isRequired

        childPath =
            path ++ ".properties." ++ name

        ( schemaGraph, newCoords ) =
            viewSchema visited defs collapsedNodes toggleMsg childPath coords (Just name) weight property
    in
    ( Svg.g [] [ schemaGraph ], newCoords )


viewArrayItem : Set String -> Definitions -> Set String -> (String -> msg) -> String -> Coordinates -> Schema -> ( Svg msg, Dimensions )
viewArrayItem visited defs collapsedNodes toggleMsg path coords schema =
    let
        ( schemaGraph, newCoords ) =
            viewSchema visited defs collapsedNodes toggleMsg path coords Nothing "700" schema
    in
    ( Svg.g [] [ schemaGraph ], newCoords )


roundRect : String -> Coordinates -> ( Svg msg, Dimensions )
roundRect txt ( x, y ) =
    let
        l =
            String.length txt
                |> Basics.toFloat

        charWidth =
            7.2

        textWidth =
            computeTextWidth txt

        mt =
            computeHorizontalText x txt
                |> String.fromFloat

        rectWidth =
            textWidth + 30

        wRect =
            String.fromFloat rectWidth

        wText =
            String.fromFloat textWidth

        tt =
            computeVerticalText y
                |> String.fromFloat

        bg =
            darkClr
                |> SvgA.fill

        fg =
            lightClr
                |> SvgA.fill

        border =
            lightClr
                |> SvgA.stroke

        caption c =
            let
                attrs =
                    [ SvgA.x mt
                    , SvgA.y tt
                    , fg
                    , SvgA.fontFamily "Monospace"
                    , SvgA.fontSize "12"
                    , SvgA.dominantBaseline "middle"
                    , SvgA.cursor "pointer"
                    ]
            in
            Svg.text_
                attrs
                [ Svg.text c ]

        rct =
            Svg.rect
                [ SvgA.x (String.fromFloat x)
                , SvgA.y (String.fromFloat y)
                , SvgA.width wRect
                , SvgA.height "28"
                , bg
                , border
                , SvgA.strokeWidth "0.2"
                , SvgA.rx "2"
                , SvgA.ry "2"
                ]
                []

        el =
            Svg.g [ SvgA.textAnchor "middle" ]
                [ rct, caption txt ]
    in
    ( el, ( rectWidth + x, 28 + y ) )


type Icon
    = IList
    | IObject
    | IInt
    | IStr
    | IFloat
    | IFile
    | IBool
    | INull
    | IRef String


iconRect : Icon -> Maybe String -> String -> Coordinates -> ( Svg msg, Dimensions )
iconRect icon txt weight ( x, y ) =
    let
        space =
            10

        ( iconG, ( iconW, _ ) ) =
            iconGraph icon ( x + space, y )

        ( separatorG, ( separatorW, _ ) ) =
            separatorGraph ( iconW + space, y )

        mNameG =
            Maybe.map (viewNameGraph weight ( separatorW + space, y )) txt

        ( graphs, rectWidth ) =
            case mNameG of
                Nothing ->
                    ( [ iconG ], iconW - x + space )

                Just ( nameG, ( nameW, _ ) ) ->
                    ( [ iconG, separatorG, nameG ], nameW - x + space )

        wRect =
            String.fromFloat rectWidth

        bg =
            darkClr
                |> SvgA.fill

        border =
            lightClr
                |> SvgA.stroke

        dashAttrs =
            case icon of
                IRef _ ->
                    [ SvgA.strokeDasharray "5 3" ]

                _ ->
                    []

        rct =
            Svg.rect
                ([ SvgA.x (String.fromFloat x)
                 , SvgA.y (String.fromFloat y)
                 , SvgA.width wRect
                 , SvgA.height "28"
                 , bg
                 , border
                 , SvgA.strokeWidth "0.2"
                 , SvgA.rx "2"
                 , SvgA.ry "2"
                 ]
                    ++ dashAttrs
                )
                []

        el =
            Svg.g [ SvgA.textAnchor "middle" ]
                (rct :: graphs)
    in
    ( el, ( rectWidth + x, 28 + y ) )


viewNameGraph : String -> Coordinates -> String -> ( Svg msg, Dimensions )
viewNameGraph weight ( x, y ) name =
    let
        tt =
            computeVerticalText y

        mt =
            computeHorizontalText x name

        fullWidth =
            computeTextWidth name

        fg =
            lightClr
                |> SvgA.fill

        caption c =
            let
                attrs =
                    [ SvgA.x (String.fromFloat mt)
                    , SvgA.y (String.fromFloat tt)
                    , fg
                    , SvgA.fontFamily "Monospace"
                    , SvgA.fontSize "12"
                    , SvgA.fontWeight weight
                    , SvgA.dominantBaseline "middle"
                    , SvgA.cursor "pointer"
                    ]
            in
            Svg.text_
                attrs
                [ Svg.text c ]

        graph =
            caption name

        dims =
            ( x + fullWidth, y + 28 )
    in
    ( graph, dims )


separatorGraph : Coordinates -> ( Svg msg, Dimensions )
separatorGraph ( x, y ) =
    let
        x1 =
            String.fromFloat x

        x2 =
            x1

        y1 =
            (y + 5)
                |> String.fromFloat

        y2 =
            (y + 28 - 5)
                |> String.fromFloat

        strokeColor =
            lightClr
                |> SvgA.stroke

        strokeWidth =
            1.2

        attrs =
            [ SvgA.strokeWidth (String.fromFloat strokeWidth)
            , strokeColor
            , SvgA.strokeLinecap "Round"
            , SvgA.x1 x1
            , SvgA.y1 y1
            , SvgA.x2 x2
            , SvgA.y2 y2
            ]

        separator =
            Svg.line attrs []

        dims =
            ( x + strokeWidth, y + 28 )
    in
    ( separator, dims )


iconGraph : Icon -> Coordinates -> ( Svg msg, Dimensions )
iconGraph icon coords =
    case icon of
        IList ->
            iconGeneric coords "[..]"

        IObject ->
            iconGeneric coords "{..}"

        IInt ->
            viewNameGraph "700" coords "I"

        IStr ->
            iconGeneric coords "S"

        IFile ->
            iconGeneric coords "File"

        INull ->
            iconGeneric coords "Null"

        IBool ->
            iconGeneric coords "B"

        IFloat ->
            iconGeneric coords "F"

        IRef s ->
            iconGeneric coords s


iconGeneric : Coordinates -> String -> ( Svg msg, Dimensions )
iconGeneric ( x, y ) iconStr =
    let
        strWidth =
            computeTextWidth iconStr

        strHeight =
            computeTextHeight iconStr

        mt =
            computeHorizontalText x iconStr

        tt =
            computeVerticalText y

        fg =
            lightClr
                |> SvgA.fill

        attrs =
            [ SvgA.x (String.fromFloat mt)
            , SvgA.y (String.fromFloat tt)
            , fg
            , SvgA.fontFamily "Monospace"
            , SvgA.fontSize "12"
            , SvgA.dominantBaseline "middle"
            , SvgA.cursor "pointer"
            ]

        graph =
            Svg.text_
                attrs
                [ Svg.text iconStr ]

        dims =
            ( x + strWidth, y + strHeight )
    in
    ( graph, dims )


computeTextWidth txt =
    String.length txt
        |> Basics.toFloat
        |> (*) 7.2


computeTextHeight txt =
    28


computeHorizontalText x txt =
    let
        textWidth =
            computeTextWidth txt
    in
    x + (textWidth / 2)


computeVerticalText y =
    y + 15


color r g b =
    Color.rgb r g b
        |> Color.Convert.colorToHex


lightClr =
    "#e6e6e6"


darkClr =
    color 57 114 206


connectorPathD : Coordinates -> Coordinates -> String
connectorPathD ( startX, startY ) ( endX, endY ) =
    let
        hOffset =
            (endX - startX) * 0.5
    in
    "M "
        ++ String.fromFloat startX
        ++ " "
        ++ String.fromFloat startY
        ++ " C "
        ++ String.fromFloat (startX + hOffset)
        ++ " "
        ++ String.fromFloat startY
        ++ " "
        ++ String.fromFloat (endX - hOffset)
        ++ " "
        ++ String.fromFloat endY
        ++ " "
        ++ String.fromFloat endX
        ++ " "
        ++ String.fromFloat endY


connectorPath : Coordinates -> Coordinates -> Svg msg
connectorPath start end =
    Svg.path
        [ SvgA.d (connectorPathD start end)
        , SvgA.stroke "#8baed6"
        , SvgA.strokeWidth "1.5"
        , SvgA.strokeLinecap "round"
        , SvgA.fill "none"
        ]
        []


viewBoxString : Float -> Float -> Float -> String
viewBoxString w h padding =
    "0 0 "
        ++ String.fromFloat (w + padding)
        ++ " "
        ++ String.fromFloat (h + padding)


extractRefName : String -> String
extractRefName ref =
    String.dropLeft 14 ref


isCircularRef : Set String -> String -> Bool
isCircularRef visited ref =
    Set.member ref visited


refLabel : String -> Bool -> String
refLabel name isCycle =
    if isCycle then
        name ++ " ↺"

    else
        name


fontWeightForRequired : Bool -> String
fontWeightForRequired isRequired =
    if isRequired then
        "700"

    else
        "400"


toggleInSet : comparable -> Set comparable -> Set comparable
toggleInSet key set =
    if Set.member key set then
        Set.remove key set

    else
        Set.insert key set


--
