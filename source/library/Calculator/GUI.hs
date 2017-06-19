{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE GADTs                     #-}
{-# LANGUAGE LambdaCase                #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE OverloadedStrings         #-}
{-# LANGUAGE RecursiveDo               #-}

module Calculator.GUI where

import Calculator.Evaluation
import Calculator.Parsing
import Calculator.Pretty
import Calculator.Printing
import Calculator.Types
import Calculator.Value
import Control.Applicative ((<$>), (<*>))
import Data.Monoid ((<>))
import Data.Text.Encoding (encodeUtf8)
import Data.Text (Text)
import Prelude hiding (div, head)
import Reflex
import Reflex.Class (fmapMaybe)
import Reflex.Dom
import Reflex.Dom.Extras

import qualified Data.Text as T

main :: IO ()
main = mainWidgetWithHead head body

head :: DomBuilder t m => m ()
head = do styleSheet "https://fonts.googleapis.com/css?family=Noto Sans"
          styleSheet "https://fonts.googleapis.com/css?family=Roboto"
          styleSheet "style.css"

body :: MonadWidget t m => m ()
body = do title
          content

title :: DomBuilder t m => m ()
title = divClass "title" $ text "Haskell Reflex Calculator Example"

introduction :: DomBuilder t m => m ()
introduction = div $ p $ do
        text "A calculator implemented in "
        linkHaskell (text "Haskell"    ) >> text ", "
        linkGhcjs   (text "GHCJS"      ) >> text ", and "
        linkReflex  (text "Reflex"     ) >> text ". ["
        linkSource  (text "source code") >> text "]"
    where
        linkHaskell = a "https://www.haskell.org/"
        linkGhcjs   = a "https://github.com/ghcjs/ghcjs"
        linkReflex  = a "https://github.com/reflex-frp/reflex-platform"
        linkSource  = a "https://github.com/jonathanknowles/haskell-calculator"

usage :: DomBuilder t m => m ()
usage = divClass "usage" $ p $ do
    divClass "heading" $ text "Usage"
    text "This calculator supports:"
    ul $ do li $ text "addition, subtraction, multiplication and division"
            li $ text "natural numbers"
            li $ text "parentheses"

content :: MonadWidget t m => m ()
content = divClass "content" $ do
        introduction
        expressionUpdates <- updated <$> expressionInput
        maybeExpression <- foldDyn update Nothing expressionUpdates
        dyn $ maybe usage evaluateExpression <$> maybeExpression
        pure ()
    where
        update p m = case p of
            ExpressionParseSuccess e               -> Just e  -- update with expression
            ExpressionParseFailure ExpressionEmpty -> Nothing -- update with empty
            ExpressionParseFailure _               -> m       -- no update

expressionInput :: MonadWidget t m => m (Dynamic t ExpressionParseResult)
expressionInput = do
        divClass "heading" $ text "Enter an arithmetic expression"
        rec t <- div $ textInput $ def
                     & textInputConfig_initialValue .~ T.empty
                     & textInputConfig_attributes   .~ attributes
            let attributes = (autofocus <>) . resultClass <$> parseResult
            let parseResult = parseExpression <$> _textInput_value t
            divClass "feedback" $ dyn $ feedback <$> parseResult
        return parseResult
    where
        autofocus = "autofocus" =: T.empty
        resultClass = ("class" =:) . \case
            ExpressionParseSuccess _               -> "valid"
            ExpressionParseFailure ExpressionEmpty -> "empty"
            ExpressionParseFailure _               -> "error"
        feedback = text . \case
            ExpressionParseSuccess _               -> hardSpace
            ExpressionParseFailure ExpressionEmpty -> hardSpace
            ExpressionParseFailure e               -> pretty e

evaluateExpression :: MonadWidget t m => UExp -> m ()
evaluateExpression e =
    divClass "result" $ do
        divClass "heading" $ text "Result"
        divClass "value"   $ text $ pretty $ eval e
        divClass "heading" $ text "Visualization"
        divClass "graphic" $ renderExpression e

renderExpression :: MonadWidget t m => UExp -> m ()
renderExpression = \case
        UVal a -> tableClass "val" $ tr $ text $ pretty a
        UNeg a -> tableClass "neg" $ tr $ do td $ text symbolNeg
                                             td $ renderExpression a
        UAdd a b -> binop "add" symbolAdd a b
        USub a b -> binop "sub" symbolSub a b
        UMul a b -> binop "mul" symbolMul a b
        UDiv a b -> binop "div" symbolDiv a b
    where
        binop c o a b =
            tableClass c $ tr $ do
                td $ renderExpression a
                td $ text o
                td $ renderExpression b

hardSpace = "　"
symbolAdd = "+"
symbolSub = "−"
symbolMul = "×"
symbolDiv = "÷"
symbolBra = "("
symbolKet = ")"
symbolNeg = symbolSub

