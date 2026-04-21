module Render.Svg exposing (view, viewBoxString, extractRefName, isCircularRef, refLabel, fontWeightForRequired, toggleInSet, connectorPathD, iconForSchema, Icon(..), HoverState, NodeMeta)

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
    , clientX : Float
    , clientY : Float
    , meta : NodeMeta
    }


type alias ViewConfig msg =
    { toggleMsg : String -> msg
    , hoverMsg : HoverState -> msg
    , unhoverMsg : msg
    }


ySpace : Float
ySpace =
    8


pillHeight : Float
pillHeight =
    22


halfPill : Float
halfPill =
    11


iconSize : Float
iconSize =
    14


hSpace : Float
hSpace =
    8


{-| Font stack for all SVG text. Consolas is the primary choice because
it ships with Microsoft Office on both Windows and macOS, so the exported
SVG renders faithfully when embedded in PowerPoint. DM Mono is retained
as a fallback so in-browser rendering still picks it up when available.
-}
svgFontFamily : String
svgFontFamily =
    "Consolas, 'Menlo', 'DM Mono', 'Courier New', ui-monospace, monospace"


fontSize : Float
fontSize =
    11


textCharPx : Float
textCharPx =
    6.6


view : (String -> msg) -> (HoverState -> msg) -> msg -> Set String -> Definitions -> Schema -> Html.Html msg
view toggleMsg hoverMsg unhoverMsg collapsedNodes defs schema =
    let
        config =
            { toggleMsg = toggleMsg
            , hoverMsg = hoverMsg
            , unhoverMsg = unhoverMsg
            }

        ( schemaView, ( w, h ) ) =
            viewSchema Set.empty defs collapsedNodes config "root" ( 0, 0 ) Nothing "700" False schema

        padding =
            20

        svgW =
            w + padding

        svgH =
            h + padding

        vb =
            viewBoxString w h padding
    in
    Svg.svg
        [ SvgA.width (String.fromFloat svgW)
        , SvgA.height (String.fromFloat svgH)
        , SvgA.viewBox vb
        , SvgA.style "display: block;"
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
                                ( parentRightX, parentY + halfPill )
                                ( x, y + halfPill )

                        ( gs, ( w2, h2 ), w3 ) =
                            viewProps ( x, h1 + ySpace ) elements

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
                                ( parentRightX, parentY + halfPill )
                                ( x, y + halfPill )

                        ( gs, ( w2, h2 ), w3 ) =
                            viewItems_ (idx + 1) ( x, h1 + ySpace ) elements

                        maxW =
                            List.foldl Basics.max w1 [ w1, w2, w3 ]
                    in
                    ( connector :: g_ :: gs, ( x, h2 ), maxW )
    in
    ( g, ( w, h ) )


toSvgCoordsTuple : ( List (Svg msg), Coordinates ) -> ( Svg msg, Coordinates )
toSvgCoordsTuple ( a, b ) =
    ( Svg.g [] a, b )


combinatorIcon : Schema.CombinatorKind -> Icon
combinatorIcon kind =
    case kind of
        Schema.OneOfKind ->
            IOneOf

        Schema.AnyOfKind ->
            IAnyOf

        Schema.AllOfKind ->
            IAllOf


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
                    viewMulti visited defs collapsedNodes config combPath ( bw + hSpace, parentY ) (combinatorIcon kind) Nothing subSchemas

                combConnector =
                    connectorPath ( bw, parentY + halfPill ) ( bw + hSpace, parentY + halfPill )

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
            hoverDecoder =
                Json.Decode.map2
                    (\cx cy ->
                        config.hoverMsg
                            { path = path
                            , clientX = cx
                            , clientY = cy
                            , meta = meta
                            }
                    )
                    (Json.Decode.field "clientX" Json.Decode.float)
                    (Json.Decode.field "clientY" Json.Decode.float)

            hoverAttrs =
                [ Svg.Events.on "mouseenter" hoverDecoder
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
                        viewProperties visited defs collapsedNodes config path w y ( w + hSpace, y ) properties

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
                                        viewMulti visited defs collapsedNodes config combPath ( w + hSpace, combStartY ) (combinatorIcon kind) Nothing subSchemas

                                    combConnector =
                                        connectorPath ( w, y + halfPill ) ( w + hSpace, combStartY + halfPill )
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
                                roundRect "*" ( w + hSpace, y )

                            Just items_ ->
                                viewSchema visited defs collapsedNodes config (path ++ ".items") ( w + hSpace, y ) Nothing "700" False items_

                    itemConnector =
                        connectorPath ( w, y + halfPill ) ( w + hSpace, y + halfPill )

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
                                        viewMulti visited defs collapsedNodes config combPath ( w + hSpace, combStartY ) (combinatorIcon kind) Nothing subSchemas

                                    combConnector =
                                        connectorPath ( w, y + halfPill ) ( w + hSpace, combStartY + halfPill )
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
                iconRect (IRef "↺") (Just defName) weight isRequired ( x, y )

            else if Set.member path collapsedNodes then
                -- Collapsed ref: show label pill with click handler to expand
                iconRect (IRef "↗") (Just defName) weight isRequired ( x, y )
                    |> clickableGroup (config.toggleMsg path)

            else
                case Dict.get ref defs of
                    Nothing ->
                        -- Definition not found: show label pill, not clickable
                        iconRect (IRef "↗") (Just defName) weight isRequired ( x, y )

                    Just defSchema ->
                        -- Expanded: render definition inline with cycle guard
                        viewSchema (Set.insert ref visited) defs collapsedNodes config path ( x, y ) (Just defName) weight isRequired defSchema
                            |> clickableGroup (config.toggleMsg path)

        Schema.OneOf { title, subSchemas } ->
            viewMulti visited defs collapsedNodes config path ( x, y ) IOneOf name subSchemas

        Schema.AnyOf { title, subSchemas } ->
            viewMulti visited defs collapsedNodes config path ( x, y ) IAnyOf name subSchemas

        Schema.AllOf { title, subSchemas } ->
            viewMulti visited defs collapsedNodes config path ( x, y ) IAllOf name subSchemas

        Schema.Fallback _ ->
            ( Svg.g [] [], coords )


viewMulti : Set String -> Definitions -> Set String -> ViewConfig msg -> String -> Coordinates -> Icon -> Maybe Name -> List Schema -> ( Svg msg, Dimensions )
viewMulti visited defs collapsedNodes config path ( x, y ) icon name schemas =
    let
        ( choiceGraph, ( w, h ) ) =
            iconRect icon name "500" False ( x, y )
                |> clickableGroup (config.toggleMsg path)
    in
    if Set.member path collapsedNodes then
        ( choiceGraph, ( w, h ) )

    else
        let
            ( subSchemaGraphs, newCoords ) =
                viewItems visited defs collapsedNodes config path w y ( w + hSpace, y ) schemas

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
        textWidth =
            computeTextWidth txt

        mt =
            computeHorizontalText x txt
                |> String.fromFloat

        rectWidth =
            textWidth + (hSpace * 2) + 8

        wRect =
            String.fromFloat rectWidth

        tt =
            computeVerticalText y
                |> String.fromFloat

        fg =
            Theme.dark.iconText
                |> SvgA.fill

        caption c =
            let
                attrs =
                    [ SvgA.x mt
                    , SvgA.y tt
                    , fg
                    , SvgA.fontFamily svgFontFamily
                    , SvgA.fontSize (String.fromFloat fontSize)
                    , SvgA.fontWeight "500"
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
                , SvgA.height (String.fromFloat pillHeight)
                , SvgA.fill Theme.dark.iconChipBg
                , SvgA.stroke Theme.dark.nodeBorder
                , SvgA.strokeWidth "1"
                , SvgA.rx "3"
                , SvgA.ry "3"
                ]
                []

        el =
            Svg.g [ SvgA.textAnchor "middle" ]
                [ rct, caption txt ]
    in
    ( el, ( rectWidth + x, pillHeight + y ) )


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
    | IOneOf
    | IAnyOf
    | IAllOf


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
            IOneOf

        Schema.AnyOf _ ->
            IAnyOf

        Schema.AllOf _ ->
            IAllOf

        Schema.Fallback _ ->
            INull


iconRect : Icon -> Maybe String -> String -> Bool -> Coordinates -> ( Svg msg, Dimensions )
iconRect icon txt weight isRequired ( x, y ) =
    let
        ( iconG, ( iconW, _ ) ) =
            iconGraph icon ( x + hSpace, y )

        ( separatorG, ( separatorW, _ ) ) =
            separatorGraph ( iconW + hSpace, y )

        mNameG =
            Maybe.map (viewNameGraph weight ( separatorW + hSpace, y )) txt

        ( graphs, rectWidth, iconChamberWidth ) =
            case mNameG of
                Nothing ->
                    let
                        w =
                            iconW - x + hSpace
                    in
                    ( [ iconG ], w, w )

                Just ( nameG, ( nameW, _ ) ) ->
                    ( [ iconG, separatorG, nameG ]
                    , nameW - x + hSpace
                    , iconW + hSpace - x
                    )

        wRect =
            String.fromFloat rectWidth

        dashAttrs =
            case icon of
                IRef _ ->
                    [ SvgA.strokeDasharray "4 2" ]

                _ ->
                    []

        outerRect =
            Svg.rect
                ([ SvgA.x (String.fromFloat x)
                 , SvgA.y (String.fromFloat y)
                 , SvgA.width wRect
                 , SvgA.height (String.fromFloat pillHeight)
                 , SvgA.fill Theme.dark.nodeFill
                 , SvgA.stroke Theme.dark.nodeBorder
                 , SvgA.strokeWidth "1"
                 , SvgA.rx "3"
                 , SvgA.ry "3"
                 ]
                    ++ dashAttrs
                )
                []

        iconChamberRect =
            Svg.rect
                [ SvgA.x (String.fromFloat x)
                , SvgA.y (String.fromFloat y)
                , SvgA.width (String.fromFloat iconChamberWidth)
                , SvgA.height (String.fromFloat pillHeight)
                , SvgA.fill Theme.dark.iconChipBg
                , SvgA.rx "3"
                , SvgA.ry "3"
                ]
                []

        requiredStripEls =
            if isRequired then
                [ Svg.rect
                    [ SvgA.x (String.fromFloat (x + 1))
                    , SvgA.y (String.fromFloat (y + 1))
                    , SvgA.width "2"
                    , SvgA.height (String.fromFloat (pillHeight - 2))
                    , SvgA.fill Theme.dark.requiredStrip
                    , SvgA.rx "1"
                    , SvgA.ry "1"
                    ]
                    []
                ]

            else
                []

        el =
            Svg.g [ SvgA.textAnchor "middle" ]
                (outerRect :: iconChamberRect :: requiredStripEls ++ graphs)
    in
    ( el, ( rectWidth + x, pillHeight + y ) )


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
            Theme.dark.nodeText
                |> SvgA.fill

        caption c =
            let
                attrs =
                    [ SvgA.x (String.fromFloat mt)
                    , SvgA.y (String.fromFloat tt)
                    , fg
                    , SvgA.fontFamily svgFontFamily
                    , SvgA.fontSize (String.fromFloat fontSize)
                    , SvgA.fontWeight weight
                    , SvgA.cursor "pointer"
                    ]
            in
            Svg.text_
                attrs
                [ Svg.text c ]

        graph =
            caption name

        dims =
            ( x + fullWidth, y + pillHeight )
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
            (y + 4)
                |> String.fromFloat

        y2 =
            (y + pillHeight - 4)
                |> String.fromFloat

        strokeColor =
            Theme.dark.nodeBorderSubtle
                |> SvgA.stroke

        strokeWidth =
            1

        attrs =
            [ SvgA.strokeWidth (String.fromFloat strokeWidth)
            , strokeColor
            , SvgA.strokeLinecap "round"
            , SvgA.x1 x1
            , SvgA.y1 y1
            , SvgA.x2 x2
            , SvgA.y2 y2
            ]

        separator =
            Svg.line attrs []

        dims =
            ( x + strokeWidth, y + pillHeight )
    in
    ( separator, dims )


iconGraph : Icon -> Coordinates -> ( Svg msg, Dimensions )
iconGraph icon ( x, y ) =
    let
        offsetY =
            y + ((pillHeight - iconSize) / 2)

        translate =
            "translate("
                ++ String.fromFloat x
                ++ " "
                ++ String.fromFloat offsetY
                ++ ")"

        color =
            Theme.dark.iconText

        graph =
            Svg.g
                [ SvgA.transform translate
                , SvgA.cursor "pointer"
                ]
                (iconShapes icon color)

        dims =
            ( x + iconSize, y + pillHeight )
    in
    ( graph, dims )


iconStrokeAttrs : String -> List (Svg.Attribute msg)
iconStrokeAttrs color =
    [ SvgA.stroke color
    , SvgA.fill "none"
    , SvgA.strokeWidth "1.1"
    , SvgA.strokeLinecap "round"
    , SvgA.strokeLinejoin "round"
    ]


iconShapes : Icon -> String -> List (Svg msg)
iconShapes icon color =
    case icon of
        IObject ->
            [ Svg.path (SvgA.d "M5 2 Q3 2 3 4.5 Q3 6.5 1.5 7 Q3 7.5 3 9.5 Q3 12 5 12" :: iconStrokeAttrs color) []
            , Svg.path (SvgA.d "M9 2 Q11 2 11 4.5 Q11 6.5 12.5 7 Q11 7.5 11 9.5 Q11 12 9 12" :: iconStrokeAttrs color) []
            ]

        IList ->
            [ Svg.path (SvgA.d "M5 2 L2.5 2 L2.5 12 L5 12" :: iconStrokeAttrs color) []
            , Svg.path (SvgA.d "M9 2 L11.5 2 L11.5 12 L9 12" :: iconStrokeAttrs color) []
            ]

        IInt ->
            [ Svg.path (SvgA.d "M5 2 L3.5 12 M10 2 L8.5 12 M2 5.5 L12 5.5 M1.5 9 L11.5 9" :: iconStrokeAttrs color) []
            ]

        IStr ->
            [ Svg.path (SvgA.d "M3.5 3.5 L3.5 6 M5.5 3.5 L5.5 6" :: iconStrokeAttrs color) []
            , Svg.path (SvgA.d "M8.5 3.5 L8.5 6 M10.5 3.5 L10.5 6" :: iconStrokeAttrs color) []
            , Svg.path (SvgA.d "M3 10.5 L11 10.5" :: iconStrokeAttrs color) []
            ]

        IFile ->
            [ Svg.path (SvgA.d "M3 2 L9 2 L11 4 L11 12 L3 12 Z" :: iconStrokeAttrs color) []
            , Svg.path (SvgA.d "M9 2 L9 4 L11 4" :: iconStrokeAttrs color) []
            ]

        INull ->
            [ Svg.circle
                ([ SvgA.cx "7", SvgA.cy "7", SvgA.r "4.5" ] ++ iconStrokeAttrs color)
                []
            , Svg.path (SvgA.d "M3.8 10.2 L10.2 3.8" :: iconStrokeAttrs color) []
            ]

        IBool ->
            [ Svg.rect
                ([ SvgA.x "1.5"
                 , SvgA.y "4.5"
                 , SvgA.width "11"
                 , SvgA.height "5"
                 , SvgA.rx "2.5"
                 , SvgA.ry "2.5"
                 ]
                    ++ iconStrokeAttrs color
                )
                []
            , Svg.circle [ SvgA.cx "9.5", SvgA.cy "7", SvgA.r "1.4", SvgA.fill color ] []
            ]

        IFloat ->
            [ Svg.path (SvgA.d "M5 2 L3.5 10 M9.5 2 L8 10 M2 5 L11 5 M1.5 8 L10.5 8" :: iconStrokeAttrs color) []
            , Svg.circle [ SvgA.cx "11.2", SvgA.cy "11.2", SvgA.r "0.9", SvgA.fill color ] []
            ]

        IRef s ->
            if s == "↺" then
                -- cycle
                [ Svg.path (SvgA.d "M11.5 4 A4.5 4.5 0 1 0 12 9.5" :: iconStrokeAttrs color) []
                , Svg.path (SvgA.d "M8.5 3.5 L11.5 4 L11 7" :: iconStrokeAttrs color) []
                ]

            else
                -- collapsed ref / default arrow
                arrowNEShapes color

        IEmail ->
            [ Svg.circle
                ([ SvgA.cx "7", SvgA.cy "7", SvgA.r "5" ] ++ iconStrokeAttrs color)
                []
            , Svg.circle
                ([ SvgA.cx "7", SvgA.cy "7", SvgA.r "1.8" ] ++ iconStrokeAttrs color)
                []
            , Svg.path (SvgA.d "M8.8 8.8 Q10 10.2 11.3 9 Q12.5 7.5 11.8 5" :: iconStrokeAttrs color) []
            ]

        IDateTime ->
            [ Svg.circle
                ([ SvgA.cx "7", SvgA.cy "7", SvgA.r "5" ] ++ iconStrokeAttrs color)
                []
            , Svg.path (SvgA.d "M7 3.5 L7 7 L9.5 8.5" :: iconStrokeAttrs color) []
            ]

        IHostname ->
            [ Svg.circle
                ([ SvgA.cx "7", SvgA.cy "7", SvgA.r "5" ] ++ iconStrokeAttrs color)
                []
            , Svg.path (SvgA.d "M2 7 L12 7" :: iconStrokeAttrs color) []
            , Svg.path (SvgA.d "M7 2 Q3.5 7 7 12 M7 2 Q10.5 7 7 12" :: iconStrokeAttrs color) []
            ]

        IIpv4 ->
            digitIcon color "4"

        IIpv6 ->
            digitIcon color "6"

        IUri ->
            arrowNEShapes color

        ICustom s ->
            customTextIcon color (String.left 3 (String.toLower s))

        IEnum ->
            [ Svg.circle [ SvgA.cx "2.5", SvgA.cy "4", SvgA.r "0.9", SvgA.fill color ] []
            , Svg.circle [ SvgA.cx "2.5", SvgA.cy "7", SvgA.r "0.9", SvgA.fill color ] []
            , Svg.circle [ SvgA.cx "2.5", SvgA.cy "10", SvgA.r "0.9", SvgA.fill color ] []
            , Svg.path (SvgA.d "M5 4 L12 4 M5 7 L12 7 M5 10 L10 10" :: iconStrokeAttrs color) []
            ]

        IOneOf ->
            -- ⊕ (exclusive or): circle with plus inside
            [ Svg.circle
                ([ SvgA.cx "7", SvgA.cy "7", SvgA.r "5" ] ++ iconStrokeAttrs color)
                []
            , Svg.path (SvgA.d "M7 3.5 L7 10.5 M3.5 7 L10.5 7" :: iconStrokeAttrs color) []
            ]

        IAnyOf ->
            -- ∪ (union / cup): at-least-one
            [ Svg.path (SvgA.d "M3 3 L3 9 A4 4 0 0 0 11 9 L11 3" :: iconStrokeAttrs color) []
            ]

        IAllOf ->
            -- ∩ (intersection / cap): all-of
            [ Svg.path (SvgA.d "M3 11 L3 5 A4 4 0 0 1 11 5 L11 11" :: iconStrokeAttrs color) []
            ]


arrowNEShapes : String -> List (Svg msg)
arrowNEShapes color =
    [ Svg.path (SvgA.d "M3.5 10.5 L10.5 3.5" :: iconStrokeAttrs color) []
    , Svg.path (SvgA.d "M6 3.5 L10.5 3.5 L10.5 8" :: iconStrokeAttrs color) []
    ]


digitIcon : String -> String -> List (Svg msg)
digitIcon color digit =
    [ Svg.rect
        ([ SvgA.x "1.5"
         , SvgA.y "2.5"
         , SvgA.width "11"
         , SvgA.height "9"
         , SvgA.rx "1.5"
         , SvgA.ry "1.5"
         ]
            ++ iconStrokeAttrs color
        )
        []
    , Svg.text_
        [ SvgA.x "7"
        , SvgA.y "9.7"
        , SvgA.textAnchor "middle"
        , SvgA.fill color
        , SvgA.fontFamily svgFontFamily
        , SvgA.fontSize "7.5"
        , SvgA.fontWeight "600"
        ]
        [ Svg.text digit ]
    ]


customTextIcon : String -> String -> List (Svg msg)
customTextIcon color txt =
    [ Svg.text_
        [ SvgA.x "7"
        , SvgA.y "9.85"
        , SvgA.textAnchor "middle"
        , SvgA.fill color
        , SvgA.fontFamily svgFontFamily
        , SvgA.fontSize "6.5"
        , SvgA.fontWeight "500"
        , SvgA.textLength "12"
        ]
        [ Svg.text txt ]
    ]


computeTextWidth : String -> Float
computeTextWidth txt =
    String.length txt
        |> Basics.toFloat
        |> (*) textCharPx


computeTextHeight : String -> Float
computeTextHeight _ =
    pillHeight


computeHorizontalText : Float -> String -> Float
computeHorizontalText x txt =
    let
        textWidth =
            computeTextWidth txt
    in
    x + (textWidth / 2)


{-| Vertical position for SVG `<text>` nodes whose y is treated as the
alphabetic baseline — the default in every renderer, including PowerPoint.
We used to rely on `dominantBaseline="middle"`, but PowerPoint ignores that
attribute and falls back to alphabetic, which rendered the text above the
pill's vertical centre. Computing the baseline ourselves keeps web + PPT
in sync. The `0.36 * fontSize` offset approximates half the cap-height so
the glyph body lands on the pill centre.
-}
computeVerticalText : Float -> Float
computeVerticalText y =
    y + halfPill + (fontSize * 0.36)


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
        , SvgA.stroke Theme.dark.connector
        , SvgA.strokeWidth "1"
        , SvgA.strokeOpacity "0.65"
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


