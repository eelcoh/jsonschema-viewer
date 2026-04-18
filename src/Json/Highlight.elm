module Json.Highlight exposing (Token(..), tokenize, tokensToHtml)

{-| Lightweight JSON tokenizer for syntax highlighting.

It is intentionally lenient: malformed input produces best-effort tokens
so the editor remains usable while the user is mid-edit. Strings that are
immediately followed (after whitespace) by `:` are promoted to `TKey` so
object keys can receive a distinct color.

-}

import Char
import Html exposing (Html, span, text)
import Html.Attributes exposing (class)


type Token
    = TPunct String
    | TKey String
    | TString String
    | TNumber String
    | TBool String
    | TNull String
    | TWhitespace String
    | TInvalid String


tokenize : String -> List Token
tokenize src =
    src
        |> String.toList
        |> tokenizeChars []
        |> List.reverse
        |> assignKeys


tokenizeChars : List Token -> List Char -> List Token
tokenizeChars acc chars =
    case chars of
        [] ->
            acc

        '{' :: rest ->
            tokenizeChars (TPunct "{" :: acc) rest

        '}' :: rest ->
            tokenizeChars (TPunct "}" :: acc) rest

        '[' :: rest ->
            tokenizeChars (TPunct "[" :: acc) rest

        ']' :: rest ->
            tokenizeChars (TPunct "]" :: acc) rest

        ',' :: rest ->
            tokenizeChars (TPunct "," :: acc) rest

        ':' :: rest ->
            tokenizeChars (TPunct ":" :: acc) rest

        '"' :: rest ->
            let
                ( body, remaining ) =
                    readString [ '"' ] rest
            in
            tokenizeChars (TString body :: acc) remaining

        c :: rest ->
            if isWhitespaceChar c then
                let
                    ( ws, remaining ) =
                        consumeWhile isWhitespaceChar chars
                in
                tokenizeChars (TWhitespace ws :: acc) remaining

            else if Char.isDigit c || c == '-' then
                let
                    ( num, remaining ) =
                        consumeWhile isNumberChar chars
                in
                tokenizeChars (TNumber num :: acc) remaining

            else if Char.isAlpha c then
                let
                    ( ident, remaining ) =
                        consumeWhile isIdentChar chars
                in
                case ident of
                    "true" ->
                        tokenizeChars (TBool "true" :: acc) remaining

                    "false" ->
                        tokenizeChars (TBool "false" :: acc) remaining

                    "null" ->
                        tokenizeChars (TNull "null" :: acc) remaining

                    other ->
                        tokenizeChars (TInvalid other :: acc) remaining

            else
                tokenizeChars (TInvalid (String.fromChar c) :: acc) rest


readString : List Char -> List Char -> ( String, List Char )
readString collected chars =
    case chars of
        [] ->
            ( String.fromList (List.reverse collected), [] )

        '"' :: rest ->
            ( String.fromList (List.reverse ('"' :: collected)), rest )

        '\\' :: c :: rest ->
            readString (c :: '\\' :: collected) rest

        c :: rest ->
            readString (c :: collected) rest


consumeWhile : (Char -> Bool) -> List Char -> ( String, List Char )
consumeWhile pred chars =
    consumeHelp pred [] chars


consumeHelp : (Char -> Bool) -> List Char -> List Char -> ( String, List Char )
consumeHelp pred acc chars =
    case chars of
        c :: rest ->
            if pred c then
                consumeHelp pred (c :: acc) rest

            else
                ( String.fromList (List.reverse acc), chars )

        [] ->
            ( String.fromList (List.reverse acc), [] )


isWhitespaceChar : Char -> Bool
isWhitespaceChar c =
    c == ' ' || c == '\t' || c == '\n' || c == '\u{000D}'


isNumberChar : Char -> Bool
isNumberChar c =
    Char.isDigit c || c == '.' || c == '-' || c == '+' || c == 'e' || c == 'E'


isIdentChar : Char -> Bool
isIdentChar c =
    Char.isAlpha c || Char.isDigit c || c == '_'


{-| Reclassify strings that are followed by `:` as keys. -}
assignKeys : List Token -> List Token
assignKeys tokens =
    case tokens of
        [] ->
            []

        (TString s) :: rest ->
            case peekNonWhitespace rest of
                Just (TPunct ":") ->
                    TKey s :: assignKeys rest

                _ ->
                    TString s :: assignKeys rest

        t :: rest ->
            t :: assignKeys rest


peekNonWhitespace : List Token -> Maybe Token
peekNonWhitespace tokens =
    case tokens of
        [] ->
            Nothing

        (TWhitespace _) :: rest ->
            peekNonWhitespace rest

        t :: _ ->
            Just t


tokensToHtml : List Token -> List (Html msg)
tokensToHtml =
    List.map viewToken


viewToken : Token -> Html msg
viewToken tok =
    case tok of
        TPunct s ->
            span [ class "tk-punct" ] [ text s ]

        TKey s ->
            span [ class "tk-key" ] [ text s ]

        TString s ->
            span [ class "tk-string" ] [ text s ]

        TNumber s ->
            span [ class "tk-number" ] [ text s ]

        TBool s ->
            span [ class "tk-bool" ] [ text s ]

        TNull s ->
            span [ class "tk-null" ] [ text s ]

        TWhitespace s ->
            text s

        TInvalid s ->
            span [ class "tk-invalid" ] [ text s ]
