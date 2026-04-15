module Render.Svg exposing (view, viewBoxString, extractRefName, isCircularRef, refLabel, fontWeightForRequired, toggleInSet, connectorPathD, iconForSchema, borderColorForRequired, Icon(..), HoverState, NodeMeta)

import Dict
import Html exposing (text)
import Json.Decode
import Json.Schema as Schema exposing (Definitions, Schema)
import Set exposing (Set)
import Svg exposing (Svg)
import Svg.Attributes as SvgA exposing (refY)
import Render.Theme as Theme
import Svg.Events
import Svg.Lazy exposing (lazy)



-- import Swagger2 as Swagger exposing (Location(..), Parameter(..), Verb(..), decoder)


type alias Coordinates =
    ( Float, Float )


type alias Dimensions =
    ( Float, Float )


type alias NodeMeta =
    { description : Maybe String
    , constraints : List ( String, String )
    , enumValues : Maybe (List String)
    , baseType : Maybe String
    }


type alias HoverState =
    { path : String
    , x : Float
    , y : Float
    , w : Float
    , meta : NodeMeta
    }


type alias ViewConfig msg =
    { toggleMsg : String -> msg
    , hoverMsg : HoverState -> msg
    , unhoverMsg : msg
    }


ySpace =
    10


pillHeight =
    28


view : (String -> msg) -> (HoverState -> msg) -> msg -> Maybe HoverState -> Set String -> Definitions -> Schema -> Html.Html msg
view toggleMsg hoverMsg unhoverMsg hoveredNode collapsedNodes defs schema =
    let
        config =
            { toggleMsg = toggleMsg
            , hoverMsg = hoverMsg
            , unhoverMsg = unhoverMsg
            }

        ( schemaView, ( w, h ) ) =
            viewSchema Set.empty defs collapsedNodes config "root" ( 0, 0 ) Nothing "700" False schema

        vb =
            viewBoxString w h 20

        overlayView =
            viewHoverOverlay hoveredNode
    in
    Svg.svg
        [ SvgA.width "100%"
        , SvgA.height "100%"
        , SvgA.viewBox vb
        ]
        [ Svg.defs []
            [ Svg.pattern
                [ SvgA.id "dot-grid"
                , SvgA.x "0"
                , SvgA.y "0"
                , SvgA.width "20"
                , SvgA.height "20"
                , SvgA.patternUnits "userSpaceOnUse"
                ]
                [ Svg.circle
                    [ SvgA.cx "10"
                    , SvgA.cy "10"
                    , SvgA.r "0.5"
                    , SvgA.fill Theme.gridDot
                    ]
                    []
                ]
            ]
        , Svg.rect
            [ SvgA.width "100%"
            , SvgA.height "100%"
            , SvgA.fill Theme.background
            ]
            []
        , Svg.rect
            [ SvgA.width "100%"
            , SvgA.height "100%"
            , SvgA.fill "url(#dot-grid)"
            ]
            []
        , schemaView
        , overlayView
        ]


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
    -> ViewConfig msg
    -> String
    -> Float
    -> Float
    -> Coordinates
    -> List Schema.ObjectProperty
    -> ( List (Svg msg), Coordinates )
viewProperties visited defs collapsedNodes config path parentRightX parentY coords props =
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
                            viewProperty visited defs collapsedNodes config path coords_ element

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
    -> ViewConfig msg
    -> String
    -> Float
    -> Float
    -> Coordinates
    -> List Schema
    -> ( List (Svg msg), Coordinates )
viewItems visited defs collapsedNodes config path parentRightX parentY coords items =
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
                            viewArrayItem visited defs collapsedNodes config itemPath coords_ element

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


toSvgCoordsTuple : ( List (Svg msg), Coordinates ) -> ( Svg msg, Coordinates )
toSvgCoordsTuple ( a, b ) =
    ( Svg.g [] a, b )


combinatorIcon : Schema.CombinatorKind -> String
combinatorIcon kind =
    case kind of
        Schema.OneOfKind ->
            "|1|"

        Schema.AnyOfKind ->
            "|o|"

        Schema.AllOfKind ->
            "(&)"


withCombinator : Set String -> Definitions -> Set String -> ViewConfig msg -> String -> Float -> Maybe ( Schema.CombinatorKind, List Schema ) -> ( Svg msg, Dimensions ) -> ( Svg msg, Dimensions )
withCombinator visited defs collapsedNodes config path parentY maybeCombinator ( baseGraph, ( bw, bh ) ) =
    case maybeCombinator of
        Nothing ->
            ( baseGraph, ( bw, bh ) )

        Just ( kind, subSchemas ) ->
            let
                combPath =
                    path ++ ".combinator"

                ( combGraph, ( cw, ch ) ) =
                    viewMulti visited defs collapsedNodes config combPath ( bw + 10, parentY ) (combinatorIcon kind) Nothing subSchemas

                combConnector =
                    connectorPath ( bw, parentY + 14 ) ( bw + 10, parentY + 14 )

                finalGraph =
                    Svg.g [] [ baseGraph, combConnector, combGraph ]
            in
            ( finalGraph, ( cw, Basics.max bh ch ) )


type alias Name =
    String


viewAnonymousSchema : Set String -> Definitions -> Set String -> ViewConfig msg -> String -> Coordinates -> Schema -> ( Svg msg, Dimensions )
viewAnonymousSchema visited defs collapsedNodes config path coords schema =
    viewSchema visited defs collapsedNodes config path coords Nothing "700" False schema


withHoverEvents : ViewConfig msg -> String -> Schema -> Icon -> Coordinates -> ( Svg msg, Dimensions ) -> ( Svg msg, Dimensions )
withHoverEvents config path schema icon ( ox, oy ) ( svg, ( w, h ) ) =
    let
        meta =
            metaForSchema schema icon
    in
    if not (hasMetadata meta) then
        ( svg, ( w, h ) )

    else
        let
            hoverState =
                { path = path
                , x = w + 8
                , y = oy
                , w = w - ox
                , meta = meta
                }

            hoverAttrs =
                [ Svg.Events.on "mouseenter"
                    (Json.Decode.succeed (config.hoverMsg hoverState))
                , Svg.Events.on "mouseleave"
                    (Json.Decode.succeed config.unhoverMsg)
                ]
        in
        ( Svg.g hoverAttrs [ svg ], ( w, h ) )


viewSchema : Set String -> Definitions -> Set String -> ViewConfig msg -> String -> Coordinates -> Maybe Name -> String -> Bool -> Schema -> ( Svg msg, Dimensions )
viewSchema visited defs collapsedNodes config path (( x, y ) as coords) name weight isRequired schema =
    case schema of
        Schema.Object { title, properties, combinator } ->
            let
                icon =
                    iconForSchema schema

                ( objectGraph, ( w, h ) ) =
                    iconRect icon name weight isRequired coords
                        |> withHoverEvents config path schema icon coords
                        |> clickableGroup (config.toggleMsg path)
            in
            if Set.member path collapsedNodes then
                ( objectGraph, ( w, h ) )

            else
                let
                    ( propertiesGraphs, ( pw, ph ) ) =
                        viewProperties visited defs collapsedNodes config path w y ( w + 10, y ) properties

                    ( allGraphs, finalDims ) =
                        case combinator of
                            Nothing ->
                                ( objectGraph :: propertiesGraphs
                                , ( pw, Basics.max h ph )
                                )

                            Just ( kind, subSchemas ) ->
                                let
                                    combStartY =
                                        if List.isEmpty properties then
                                            y

                                        else
                                            ph + ySpace

                                    combPath =
                                        path ++ ".combinator"

                                    ( combGraph, ( cw, ch ) ) =
                                        viewMulti visited defs collapsedNodes config combPath ( w + 10, combStartY ) (combinatorIcon kind) Nothing subSchemas

                                    combConnector =
                                        connectorPath ( w, y + 14 ) ( w + 10, combStartY + 14 )
                                in
                                ( objectGraph :: propertiesGraphs ++ [ combConnector, combGraph ]
                                , ( Basics.max pw cw, Basics.max (Basics.max h ph) ch )
                                )
                in
                ( allGraphs, finalDims )
                    |> toSvgCoordsTuple

        Schema.Array { title, items, combinator } ->
            let
                icon =
                    iconForSchema schema

                ( arrayGraph, ( w, h ) ) =
                    iconRect icon name weight isRequired coords
                        |> withHoverEvents config path schema icon coords
                        |> clickableGroup (config.toggleMsg path)
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
                                viewSchema visited defs collapsedNodes config (path ++ ".items") ( w + 10, y ) Nothing "700" False items_

                    itemConnector =
                        connectorPath ( w, y + 14 ) ( w + 10, y + 14 )

                    ( allGraphs, finalDims ) =
                        case combinator of
                            Nothing ->
                                ( [ arrayGraph, itemConnector, itemsGraph ]
                                , ( iw, Basics.max h ih )
                                )

                            Just ( kind, subSchemas ) ->
                                let
                                    combStartY =
                                        ih + ySpace

                                    combPath =
                                        path ++ ".combinator"

                                    ( combGraph, ( cw, ch ) ) =
                                        viewMulti visited defs collapsedNodes config combPath ( w + 10, combStartY ) (combinatorIcon kind) Nothing subSchemas

                                    combConnector =
                                        connectorPath ( w, y + 14 ) ( w + 10, combStartY + 14 )
                                in
                                ( [ arrayGraph, itemConnector, itemsGraph, combConnector, combGraph ]
                                , ( Basics.max iw cw, Basics.max (Basics.max h ih) ch )
                                )
                in
                ( allGraphs, finalDims )
                    |> toSvgCoordsTuple

        Schema.String stringSchema ->
            let
                icon =
                    iconForSchema schema
            in
            iconRect icon name weight isRequired coords
                |> withHoverEvents config path schema icon coords
                |> withCombinator visited defs collapsedNodes config path y stringSchema.combinator

        Schema.Integer intSchema ->
            let
                icon =
                    iconForSchema schema
            in
            iconRect icon name weight isRequired coords
                |> withHoverEvents config path schema icon coords
                |> withCombinator visited defs collapsedNodes config path y intSchema.combinator

        Schema.Number numSchema ->
            let
                icon =
                    iconForSchema schema
            in
            iconRect icon name weight isRequired coords
                |> withHoverEvents config path schema icon coords
                |> withCombinator visited defs collapsedNodes config path y numSchema.combinator

        Schema.Boolean boolSchema ->
            let
                icon =
                    iconForSchema schema
            in
            iconRect icon name weight isRequired coords
                |> withHoverEvents config path schema icon coords
                |> withCombinator visited defs collapsedNodes config path y boolSchema.combinator

        Schema.Null nullSchema ->
            viewMaybeTitle coords "Null" name
                |> withCombinator visited defs collapsedNodes config path y nullSchema.combinator

        Schema.Ref { title, ref } ->
            let
                defName =
                    extractRefName ref

                isCycle =
                    isCircularRef visited ref
            in
            if isCycle then
                -- Cycle pill: not clickable (D-05)
                iconRect (IRef "*") (Just (refLabel defName True)) weight isRequired ( x, y )

            else if Set.member path collapsedNodes then
                -- Collapsed ref: show label pill with click handler to expand
                iconRect (IRef "*") (Just defName) weight isRequired ( x, y )
                    |> clickableGroup (config.toggleMsg path)

            else
                case Dict.get ref defs of
                    Nothing ->
                        -- Definition not found: show label pill, not clickable
                        iconRect (IRef "*") (Just defName) weight isRequired ( x, y )

                    Just defSchema ->
                        -- Expanded: render definition inline with cycle guard
                        viewSchema (Set.insert ref visited) defs collapsedNodes config path ( x, y ) (Just defName) weight isRequired defSchema
                            |> clickableGroup (config.toggleMsg path)

        Schema.OneOf { title, subSchemas } ->
            viewMulti visited defs collapsedNodes config path ( x, y ) "|1|" name subSchemas

        Schema.AnyOf { title, subSchemas } ->
            viewMulti visited defs collapsedNodes config path ( x, y ) "|o|" name subSchemas

        Schema.AllOf { title, subSchemas } ->
            viewMulti visited defs collapsedNodes config path ( x, y ) "(&)" name subSchemas

        Schema.Fallback _ ->
            ( Svg.g [] [], coords )


viewMulti : Set String -> Definitions -> Set String -> ViewConfig msg -> String -> Coordinates -> String -> Maybe Name -> List Schema -> ( Svg msg, Dimensions )
viewMulti visited defs collapsedNodes config path ( x, y ) icon _ schemas =
    let
        ( choiceGraph, ( w, h ) ) =
            roundRect icon ( x, y )
                |> clickableGroup (config.toggleMsg path)
    in
    if Set.member path collapsedNodes then
        ( choiceGraph, ( w, h ) )

    else
        let
            ( subSchemaGraphs, newCoords ) =
                viewItems visited defs collapsedNodes config path w y ( w + 10, y ) schemas

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


viewProperty : Set String -> Definitions -> Set String -> ViewConfig msg -> String -> Coordinates -> Schema.ObjectProperty -> ( Svg msg, Dimensions )
viewProperty visited defs collapsedNodes config path coords objectProperty =
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
            viewSchema visited defs collapsedNodes config childPath coords (Just name) weight isRequired property
    in
    ( Svg.g [] [ schemaGraph ], newCoords )


viewArrayItem : Set String -> Definitions -> Set String -> ViewConfig msg -> String -> Coordinates -> Schema -> ( Svg msg, Dimensions )
viewArrayItem visited defs collapsedNodes config path coords schema =
    let
        ( schemaGraph, newCoords ) =
            viewSchema visited defs collapsedNodes config path coords Nothing "700" False schema
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
            Theme.nodeFill
                |> SvgA.fill

        fg =
            Theme.nodeText
                |> SvgA.fill

        border =
            Theme.nodeBorder
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
                , SvgA.strokeWidth "1"
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
    | IEmail
    | IDateTime
    | IHostname
    | IIpv4
    | IIpv6
    | IUri
    | ICustom String
    | IEnum


iconForSchema : Schema -> Icon
iconForSchema schema =
    case schema of
        Schema.String { format, enum } ->
            case enum of
                Just _ ->
                    IEnum

                Nothing ->
                    case format of
                        Just Schema.Email ->
                            IEmail

                        Just Schema.DateTime ->
                            IDateTime

                        Just Schema.Hostname ->
                            IHostname

                        Just Schema.Ipv4 ->
                            IIpv4

                        Just Schema.Ipv6 ->
                            IIpv6

                        Just Schema.Uri ->
                            IUri

                        Just (Schema.Custom s) ->
                            ICustom s

                        Nothing ->
                            IStr

        Schema.Integer { enum } ->
            case enum of
                Just _ ->
                    IEnum

                Nothing ->
                    IInt

        Schema.Number { enum } ->
            case enum of
                Just _ ->
                    IEnum

                Nothing ->
                    IFloat

        Schema.Boolean { enum } ->
            case enum of
                Just _ ->
                    IEnum

                Nothing ->
                    IBool

        Schema.Object _ ->
            IObject

        Schema.Array _ ->
            IList

        Schema.Null _ ->
            INull

        Schema.Ref { ref } ->
            IRef "*"

        Schema.OneOf _ ->
            IObject

        Schema.AnyOf _ ->
            IObject

        Schema.AllOf _ ->
            IObject

        Schema.Fallback _ ->
            INull


borderColorForRequired : Bool -> String
borderColorForRequired isRequired =
    if isRequired then
        Theme.requiredBorder

    else
        Theme.nodeBorder


iconRect : Icon -> Maybe String -> String -> Bool -> Coordinates -> ( Svg msg, Dimensions )
iconRect icon txt weight isRequired ( x, y ) =
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
            Theme.nodeFill
                |> SvgA.fill

        border =
            borderColorForRequired isRequired
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
                 , SvgA.strokeWidth "1"
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
            Theme.nodeText
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
            Theme.nodeBorder
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

        IEmail ->
            iconGeneric coords "@"

        IDateTime ->
            iconGeneric coords "dt"

        IHostname ->
            iconGeneric coords "dns"

        IIpv4 ->
            iconGeneric coords "ip4"

        IIpv6 ->
            iconGeneric coords "ip6"

        IUri ->
            iconGeneric coords "url"

        ICustom s ->
            iconGeneric coords (String.left 3 (String.toLower s))

        IEnum ->
            iconGeneric coords "Enum"


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
            Theme.nodeText
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
        , SvgA.stroke Theme.connector
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


-- Metadata extraction


metaForSchema : Schema -> Icon -> NodeMeta
metaForSchema schema icon =
    case schema of
        Schema.String { description, minLength, maxLength, pattern, enum } ->
            let
                constraints =
                    List.filterMap identity
                        [ Maybe.map (\v -> ( "minLen", String.fromInt v )) minLength
                        , Maybe.map (\v -> ( "maxLen", String.fromInt v )) maxLength
                        , Maybe.map (\v -> ( "pattern", truncatePattern v )) pattern
                        ]

                enumStrs =
                    enum

                baseType =
                    case icon of
                        IEnum ->
                            Just "string"

                        _ ->
                            Nothing
            in
            { description = description
            , constraints = constraints
            , enumValues = enumStrs
            , baseType = baseType
            }

        Schema.Integer { description, minimum, maximum, enum } ->
            let
                constraints =
                    List.filterMap identity
                        [ Maybe.map (\v -> ( "min", String.fromInt v )) minimum
                        , Maybe.map (\v -> ( "max", String.fromInt v )) maximum
                        ]

                enumStrs =
                    Maybe.map (List.map String.fromInt) enum
            in
            { description = description
            , constraints = constraints
            , enumValues = enumStrs
            , baseType =
                case icon of
                    IEnum ->
                        Just "integer"

                    _ ->
                        Nothing
            }

        Schema.Number { description, minimum, maximum, enum } ->
            let
                constraints =
                    List.filterMap identity
                        [ Maybe.map (\v -> ( "min", String.fromFloat v )) minimum
                        , Maybe.map (\v -> ( "max", String.fromFloat v )) maximum
                        ]

                enumStrs =
                    Maybe.map (List.map String.fromFloat) enum
            in
            { description = description
            , constraints = constraints
            , enumValues = enumStrs
            , baseType =
                case icon of
                    IEnum ->
                        Just "number"

                    _ ->
                        Nothing
            }

        Schema.Boolean { description, enum } ->
            let
                boolToStr b =
                    if b then
                        "true"

                    else
                        "false"

                enumStrs =
                    Maybe.map (List.map boolToStr) enum
            in
            { description = description
            , constraints = []
            , enumValues = enumStrs
            , baseType =
                case icon of
                    IEnum ->
                        Just "boolean"

                    _ ->
                        Nothing
            }

        Schema.Object { description } ->
            { description = description, constraints = [], enumValues = Nothing, baseType = Nothing }

        Schema.Array { description } ->
            { description = description, constraints = [], enumValues = Nothing, baseType = Nothing }

        Schema.Null { description } ->
            { description = description, constraints = [], enumValues = Nothing, baseType = Nothing }

        Schema.Ref { description } ->
            { description = description, constraints = [], enumValues = Nothing, baseType = Nothing }

        Schema.OneOf { description } ->
            { description = description, constraints = [], enumValues = Nothing, baseType = Nothing }

        Schema.AnyOf { description } ->
            { description = description, constraints = [], enumValues = Nothing, baseType = Nothing }

        Schema.AllOf { description } ->
            { description = description, constraints = [], enumValues = Nothing, baseType = Nothing }

        Schema.Fallback _ ->
            { description = Nothing, constraints = [], enumValues = Nothing, baseType = Nothing }


truncatePattern : String -> String
truncatePattern s =
    if String.length s > 40 then
        String.left 40 s ++ "\u{2026}"

    else
        s


hasMetadata : NodeMeta -> Bool
hasMetadata meta =
    meta.description /= Nothing
        || not (List.isEmpty meta.constraints)
        || meta.enumValues /= Nothing
        || meta.baseType /= Nothing


-- Hover overlay rendering


viewHoverOverlay : Maybe HoverState -> Svg msg
viewHoverOverlay maybeHover =
    case maybeHover of
        Nothing ->
            Svg.g [] []

        Just { x, y, meta } ->
            let
                rows =
                    buildOverlayRows meta

                rowCount =
                    List.length rows

                overlayWidth =
                    240

                hPad =
                    12

                vPad =
                    8

                rowHeight =
                    18

                overlayHeight =
                    toFloat (vPad * 2 + rowCount * rowHeight)
            in
            if rowCount == 0 then
                Svg.g [] []

            else
                Svg.g []
                    [ Svg.rect
                        [ SvgA.x (String.fromFloat x)
                        , SvgA.y (String.fromFloat y)
                        , SvgA.width (String.fromFloat overlayWidth)
                        , SvgA.height (String.fromFloat overlayHeight)
                        , SvgA.fill Theme.overlayBg
                        , SvgA.stroke Theme.overlayBorder
                        , SvgA.strokeWidth "1"
                        , SvgA.rx "4"
                        , SvgA.ry "4"
                        ]
                        []
                    , Svg.g [] (List.indexedMap (renderOverlayRow x y hPad vPad rowHeight) rows)
                    ]


type alias OverlayRow =
    { key : String
    , value : String
    }


buildOverlayRows : NodeMeta -> List OverlayRow
buildOverlayRows meta =
    let
        typeRow =
            case meta.baseType of
                Just t ->
                    [ { key = "type", value = t } ]

                Nothing ->
                    []

        descRow =
            case meta.description of
                Just d ->
                    let
                        lines =
                            wrapText 42 d
                    in
                    List.map (\line -> { key = "desc", value = line }) lines

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
                    [ { key = "enum", value = valStr } ]

                Nothing ->
                    []

        constraintRows =
            List.map (\( k, v ) -> { key = k, value = v }) meta.constraints
    in
    typeRow ++ descRow ++ enumRow ++ constraintRows


wrapText : Int -> String -> List String
wrapText maxChars text_ =
    if String.length text_ <= maxChars then
        [ text_ ]

    else
        let
            chunk =
                String.left maxChars text_

            rest =
                String.dropLeft maxChars text_
        in
        chunk :: wrapText maxChars rest


renderOverlayRow : Float -> Float -> Int -> Int -> Int -> Int -> OverlayRow -> Svg msg
renderOverlayRow panelX panelY hPad vPad rowHeight idx row =
    let
        rowY =
            panelY + toFloat vPad + toFloat idx * toFloat rowHeight + toFloat rowHeight / 2

        keyX =
            panelX + toFloat hPad

        valueX =
            keyX + 60
    in
    Svg.g []
        [ Svg.text_
            [ SvgA.x (String.fromFloat keyX)
            , SvgA.y (String.fromFloat rowY)
            , SvgA.fill Theme.overlayKeyText
            , SvgA.fontFamily "Monospace"
            , SvgA.fontSize "11"
            , SvgA.fontWeight "400"
            , SvgA.dominantBaseline "middle"
            ]
            [ Svg.text row.key ]
        , Svg.text_
            [ SvgA.x (String.fromFloat valueX)
            , SvgA.y (String.fromFloat rowY)
            , SvgA.fill Theme.nodeText
            , SvgA.fontFamily "Monospace"
            , SvgA.fontSize "11"
            , SvgA.fontWeight "700"
            , SvgA.dominantBaseline "middle"
            ]
            [ Svg.text row.value ]
        ]
