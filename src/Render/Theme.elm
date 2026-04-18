module Render.Theme exposing
    ( background
    , connector
    , errorDetailBg
    , errorHeading
    , errorText
    , gridDot
    , iconChipBg
    , iconText
    , nodeBorder
    , nodeBorderSubtle
    , nodeFill
    , nodeText
    , overlayBg
    , overlayBorder
    , overlayKeyText
    , refBorder
    , requiredBorder
    , requiredStrip
    )


background : String
background =
    "#0b1420"


gridDot : String
gridDot =
    "#1b2f47"


nodeBorder : String
nodeBorder =
    "#5a8fb0"


nodeBorderSubtle : String
nodeBorderSubtle =
    "#365d7a"


nodeFill : String
nodeFill =
    "transparent"


nodeText : String
nodeText =
    "#eaf1f8"


iconText : String
iconText =
    "#8fc8ea"


iconChipBg : String
iconChipBg =
    "rgba(143, 200, 234, 0.06)"


connector : String
connector =
    "#365d7a"


refBorder : String
refBorder =
    "#5a8fb0"


errorHeading : String
errorHeading =
    "#ff8591"


errorText : String
errorText =
    "#c8d8e8"


errorDetailBg : String
errorDetailBg =
    "#0f1822"


requiredBorder : String
requiredBorder =
    "#e8a020"


requiredStrip : String
requiredStrip =
    "#e8a020"


overlayBg : String
overlayBg =
    "#0f1e30"


overlayBorder : String
overlayBorder =
    "#3a5a7a"


overlayKeyText : String
overlayKeyText =
    "#8ab0d0"
