module Render.Theme exposing (Theme, colorMap, dark, exportBackground, light)


type alias Theme =
    { nodeBorder : String
    , nodeBorderSubtle : String
    , nodeFill : String
    , nodeText : String
    , iconText : String
    , iconChipBg : String
    , connector : String
    , requiredStrip : String
    }


dark : Theme
dark =
    { nodeBorder = "#5a8fb0"
    , nodeBorderSubtle = "#365d7a"
    , nodeFill = "transparent"
    , nodeText = "#eaf1f8"
    , iconText = "#8fc8ea"
    , iconChipBg = "rgba(143, 200, 234, 0.06)"
    , connector = "#365d7a"
    , requiredStrip = "#e8a020"
    }


light : Theme
light =
    { nodeBorder = "#2d5470"
    , nodeBorderSubtle = "#6a8ba8"
    , nodeFill = "transparent"
    , nodeText = "#0e2233"
    , iconText = "#1d4f70"
    , iconChipBg = "rgba(29, 79, 112, 0.06)"
    , connector = "#6a8ba8"
    , requiredStrip = "#b07512"
    }


exportBackground : String
exportBackground =
    "#ffffff"


{-| Substitutions (dark → light) for post-processing the exported SVG.
The rendered SVG uses `dark` values as literal fill/stroke attributes;
the download handler swaps each into its `light` counterpart.
-}
colorMap : List ( String, String )
colorMap =
    List.map (\f -> ( f dark, f light )) fields


fields : List (Theme -> String)
fields =
    [ .nodeBorder
    , .nodeBorderSubtle
    , .nodeFill
    , .nodeText
    , .iconText
    , .iconChipBg
    , .connector
    , .requiredStrip
    ]
