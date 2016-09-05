module SplitPane
    exposing
        ( view
        , ViewConfig
        , createViewConfig
        , createCustomSplitter
        , CustomSplitter
        , HtmlDetails
        , Model
        , Msg
        , Orientation(..)
        , Percentage
        , draggable
        , subscriptions
        , update
        , UpdateConfig
        , createUpdateConfig
        , init
        )

{-|

This is a split pane view library. Can be used to split views into multiple parts with a splitter between them.

Check out the [examples][] to see how it works.

[examples]: https://github.com/doodledood/elm-split-pane/tree/master/examples

@docs view, ViewConfig, createViewConfig, createCustomSplitter, CustomSplitter, HtmlDetails, Model, Msg, Orientation, Percentage, draggable, subscriptions, update, UpdateConfig, createUpdateConfig, init
-}

import Html exposing (Html, span, div, Attribute)
import Html.Attributes exposing (style, class)
import Html.Events exposing (onWithOptions)
import Mouse
import Json.Decode as Json exposing (Decoder, (:=), at)
import Maybe
import Styles exposing (paneContainerStyle, childViewStyle, defaultHorizontalSplitterStyle, defaultVerticalSplitterStyle)


-- MODEL


{-| A percentage value between 0.0 and 1.0
-}
type alias Percentage =
    Float


{-| Orientation of pane.
-}
type Orientation
    = Horizontal
    | Vertical


{-| Tracks state of pane.
-}
type Model
    = Model
        { dragPosition : Maybe Position
        , draggable : Bool
        , orientation : Orientation
        , splitterPosition : Percentage
        , resizeLimits : ( Percentage, Percentage )
        , paneWidth : Maybe Int
        , paneHeight : Maybe Int
        }


{-| Used to track SplitterMoves.
-}
type Msg
    = SplitterClick DOMInfo
    | SplitterMove Position
    | SplitterLeftAlone Position


type alias Position =
    { x : Int
    , y : Int
    }


{-| Sets whether the pane is draggable or not
-}
draggable : Bool -> Model -> Model
draggable isDraggable (Model model) =
    Model { model | draggable = isDraggable }


{-| Changes orientation of the pane.
-}
orientation : Orientation -> Model -> Model
orientation o (Model model) =
    Model { model | orientation = o }


{-| Changes the splitter position
-}
withSplitterAt : Percentage -> Model -> Model
withSplitterAt newPosition (Model model) =
    Model
        { model | splitterPosition = min 1.0 <| max newPosition 0.0 }


{-| Changes resizes limits
-}
withResizeLimits : Percentage -> Percentage -> Model -> Model
withResizeLimits minLimit maxLimit (Model model) =
    Model
        { model | resizeLimits = ( minLimit, maxLimit ) }



-- INIT


{-| Initialize a new model.

        init
            { paneWidth = 600
            , paneHeight = 600
            }
-}
init : Orientation -> Model
init orientation =
    Model
        { dragPosition = Nothing
        , draggable = True
        , orientation = orientation
        , splitterPosition = 0.5
        , resizeLimits = ( 0.0, 1.0 )
        , paneWidth = Nothing
        , paneHeight = Nothing
        }



-- UPDATE


domInfoToPosition : DOMInfo -> Position
domInfoToPosition { x, y, touchX, touchY, parentWidth, parentHeight } =
    case ( x, y, touchX, touchY ) of
        ( _, _, Just posX, Just posY ) ->
            { x = posX, y = posY }

        ( Just posX, Just posY, _, _ ) ->
            { x = posX, y = posY }

        _ ->
            { x = 0, y = 0 }


{-| Configuration for updates.
-}
type UpdateConfig msg
    = UpdateConfig
        { onResize : Percentage -> Maybe msg
        , onResizeStarted : Maybe msg
        , onResizeEnded : Maybe msg
        }


{-| Creates the update configuration.
    Gives you the option to respond to various things that happen.

    For example:
    - Draw a different view when the pane is resized:

        updateConfig
            { onResize (\p -> Just (SwitchViews p))
            , onResizeStarted Nothing
            , onResizeEnded Nothing
            }
-}
createUpdateConfig :
    { onResize : Percentage -> Maybe msg
    , onResizeStarted : Maybe msg
    , onResizeEnded : Maybe msg
    }
    -> UpdateConfig msg
createUpdateConfig config =
    UpdateConfig config


{-| Updates internal model.
-}
update : UpdateConfig msg -> Msg -> Model -> ( Model, Maybe msg )
update (UpdateConfig updateConfig) msg (Model model) =
    if not model.draggable then
        ( Model model, Nothing )
    else
        case msg of
            SplitterClick pos ->
                ( Model
                    { model
                        | dragPosition = Just <| domInfoToPosition pos
                        , paneWidth = Just pos.parentWidth
                        , paneHeight = Just pos.parentHeight
                    }
                , updateConfig.onResizeStarted
                )

            SplitterLeftAlone _ ->
                ( Model { model | dragPosition = Nothing }
                , updateConfig.onResizeEnded
                )

            SplitterMove curr ->
                case model.dragPosition of
                    Nothing ->
                        ( Model model, Nothing )

                    Just dragPos ->
                        let
                            ( minLimit, maxLimit ) =
                                model.resizeLimits

                            newSplitterPosition =
                                resize model.orientation model.splitterPosition curr dragPos model.paneWidth model.paneHeight minLimit maxLimit
                        in
                            ( Model
                                { model
                                    | dragPosition = Just curr
                                    , splitterPosition = newSplitterPosition
                                }
                            , updateConfig.onResize newSplitterPosition
                            )


resize : Orientation -> Percentage -> Position -> Position -> Maybe Int -> Maybe Int -> Percentage -> Percentage -> Percentage
resize orientation splitterPosition newPosition prevPosition paneWidth paneHeight minLimit maxLimit =
    case ( paneWidth, paneHeight ) of
        ( Just width, Just height ) ->
            case orientation of
                Horizontal ->
                    max minLimit <| min maxLimit <| splitterPosition + toFloat (newPosition.x - prevPosition.x) / toFloat width

                Vertical ->
                    max minLimit <| min maxLimit <| splitterPosition + toFloat (newPosition.y - prevPosition.y) / toFloat height

        ( _, _ ) ->
            splitterPosition



-- VIEW


{-| Lets you specify attributes such as style and children for the splitter element
-}
type alias HtmlDetails msg =
    { attributes : List (Attribute msg)
    , children : List (Html msg)
    }


{-| Decribes a custom splitter
-}
type CustomSplitter msg
    = CustomSplitter (Html msg)


createDefaultSplitterDetails : Orientation -> Bool -> HtmlDetails msg
createDefaultSplitterDetails orientation draggable =
    case orientation of
        Horizontal ->
            { attributes =
                [ defaultHorizontalSplitterStyle draggable
                ]
            , children = []
            }

        Vertical ->
            { attributes =
                [ defaultVerticalSplitterStyle draggable
                ]
            , children = []
            }


{-| Creates a custom splitter.

        myCustomSplitter : CustomSplitter Msg
        myCustomSplitter =
            customSplitter PaneMsg
                { attributes =
                    [ style
                        [ ( "width", "20px" )
                        , ( "height", "20px" )
                        ]
                    ]
                , children =
                    []
                }
-}
createCustomSplitter :
    (Msg -> msg)
    -> HtmlDetails msg
    -> CustomSplitter msg
createCustomSplitter toMsg details =
    CustomSplitter <|
        span
            (onMouseDown toMsg :: onTouchStart toMsg :: onTouchEnd toMsg :: onTouchMove toMsg :: onTouchCancel toMsg :: details.attributes)
            details.children


{-| Configuration for the view.
-}
type ViewConfig msg
    = ViewConfig
        { toMsg : Msg -> msg
        , splitter : Maybe (CustomSplitter msg)
        }


{-| Creates a configuration for the view.

-}
createViewConfig :
    { toMsg : Msg -> msg
    , customSplitter : Maybe (CustomSplitter msg)
    }
    -> ViewConfig msg
createViewConfig { toMsg, customSplitter } =
    ViewConfig
        { toMsg = toMsg
        , splitter = customSplitter
        }


{-| A pane with custom splitter.

        view : Model -> Html Msg
        view =
            SplitPane.viewWithCustomSplitter myCustomSplitter firstView secondView


        myCustomSplitter : CustomSplitter Msg
        myCustomSplitter =
            customSplitter PaneMsg
                { attributes =
                    [ style
                        [ ( "width", "20px" )
                        , ( "height", "20px" )
                        ]
                    ]
                , children =
                    []
                }

        firstView : Html a
        firstView =
            img [ src "http://4.bp.blogspot.com/-s3sIvuCfg4o/VP-82RkCOGI/AAAAAAAALSY/509obByLvNw/s1600/baby-cat-wallpaper.jpg" ] []


        secondView : Html a
        secondView =
            img [ src "http://2.bp.blogspot.com/-pATX0YgNSFs/VP-82AQKcuI/AAAAAAAALSU/Vet9e7Qsjjw/s1600/Cat-hd-wallpapers.jpg" ] []
-}
view : ViewConfig msg -> Html msg -> Html msg -> Model -> Html msg
view (ViewConfig viewConfig) firstView secondView ((Model model) as m) =
    div
        [ class "pane-container"
        , paneContainerStyle <| model.orientation == Horizontal
        ]
        [ div
            [ class "pane-first-view"
            , childViewStyle model.splitterPosition
            ]
            [ firstView ]
        , getConcreteSplitter viewConfig model.orientation model.draggable
        , div
            [ class "pane-second-view"
            , childViewStyle <| 1 - model.splitterPosition
            ]
            [ secondView ]
        ]


getConcreteSplitter :
    { toMsg : Msg -> msg
    , splitter : Maybe (CustomSplitter msg)
    }
    -> Orientation
    -> Bool
    -> Html msg
getConcreteSplitter viewConfig orientation draggable =
    case viewConfig.splitter of
        Just (CustomSplitter splitter) ->
            splitter

        Nothing ->
            case createCustomSplitter viewConfig.toMsg <| createDefaultSplitterDetails orientation draggable of
                CustomSplitter defaultSplitter ->
                    defaultSplitter


onMouseDown : (Msg -> msg) -> Attribute msg
onMouseDown toMsg =
    onWithOptions "mousedown" { preventDefault = True, stopPropagation = False } <| Json.map (toMsg << SplitterClick) domInfo


onTouchStart : (Msg -> msg) -> Attribute msg
onTouchStart toMsg =
    onWithOptions "touchstart" { preventDefault = True, stopPropagation = True } <| Json.map (toMsg << SplitterClick) domInfo


onTouchEnd : (Msg -> msg) -> Attribute msg
onTouchEnd toMsg =
    onWithOptions "touchend" { preventDefault = True, stopPropagation = True } <| Json.map (toMsg << SplitterLeftAlone << domInfoToPosition) domInfo


onTouchCancel : (Msg -> msg) -> Attribute msg
onTouchCancel toMsg =
    onWithOptions "touchcancel" { preventDefault = True, stopPropagation = True } <| Json.map (toMsg << SplitterLeftAlone << domInfoToPosition) domInfo


onTouchMove : (Msg -> msg) -> Attribute msg
onTouchMove toMsg =
    onWithOptions "touchmove" { preventDefault = True, stopPropagation = True } <| Json.map (toMsg << SplitterMove << domInfoToPosition) domInfo


{-| The position of the touch relative to the whole document. So if you are
scrolled down a bunch, you are still getting a coordinate relative to the
very top left corner of the *whole* document.
-}
type alias DOMInfo =
    { x : Maybe Int
    , y : Maybe Int
    , touchX : Maybe Int
    , touchY : Maybe Int
    , parentWidth : Int
    , parentHeight : Int
    }


{-| The decoder used to extract a `Position` from a JavaScript touch event.
-}
domInfo : Json.Decoder DOMInfo
domInfo =
    Json.object6 DOMInfo
        (Json.maybe ("clientX" := Json.int))
        (Json.maybe ("clientY" := Json.int))
        (Json.maybe (at [ "touches", "0", "clientX" ] Json.int))
        (Json.maybe (at [ "touches", "0", "clientY" ] Json.int))
        (at [ "target", "parentElement", "clientWidth" ] Json.int)
        (at [ "target", "parentElement", "clientHeight" ] Json.int)



-- SUBSCRIPTIONS


{-| Subscribes to relevant events for resizing
-}
subscriptions : Model -> Sub Msg
subscriptions (Model model) =
    if not model.draggable then
        Sub.none
    else
        case model.dragPosition of
            Just _ ->
                Sub.batch
                    [ Mouse.moves SplitterMove
                    , Mouse.ups SplitterLeftAlone
                    ]

            Nothing ->
                Sub.none
