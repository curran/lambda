-- This Lambda Calculus parser was written by Nat Tuck
-- for the class "Design of Programming Languages"
-- taught at UMass Lowell by Professor Fred Martin in Spring 2013.
module Parser where

import Text.ParserCombinators.Parsec
import Text.ParserCombinators.Parsec.Char
import Data.Char

data LambdaTree = Lambda Char LambdaTree
                | Name Char
                | Apply LambdaTree LambdaTree
                | Number Int
                | Symbol Char
                | Error String
  deriving (Show, Eq)

showLx (Lambda vv tt) = "(&" ++ [vv] ++ "." ++ showLx tt ++ ")"
showLx (Name vv)      = [vv]
showLx (Apply aa bb@(Apply _ _)) =
  showLx aa ++ "(" ++ showLx bb ++ ")"
showLx (Apply aa bb)  = showLx aa ++ showLx bb
showLx (Number nn)    = show nn
showLx (Symbol cc)    = [cc]
showLx (Error ee)    = ee

nameExpr = 
  do nn <- lower
     spaces
     return (Name nn)

numbExpr :: GenParser Char st LambdaTree
numbExpr =
  do nn <- many1 digit
     spaces
     return (Number (read nn :: Int))

symbExpr :: GenParser Char st LambdaTree
symbExpr =
  do symb <- (upper <|> oneOf "+-*/<>=")
     spaces
     return (Symbol symb)

makeLambda :: [Char] -> LambdaTree -> LambdaTree
makeLambda [nn]    bb = Lambda nn bb
makeLambda (nn:ns) bb = Lambda nn (makeLambda ns bb)

lambdaExpr :: GenParser Char st LambdaTree
lambdaExpr =
  do char '&'
     spaces
     ns <- many1 lower
     spaces
     char '.'
     spaces
     ee <- expr
     spaces
     return (makeLambda ns ee)

parenExpr =
  do char '('
     spaces
     ee <- expr
     spaces
     char ')'
     spaces
     return ee

simpleExpr = nameExpr <|> lambdaExpr <|> parenExpr <|> numbExpr <|> symbExpr

expr =
  do es <- many1 simpleExpr
     spaces
     return $ foldl1 Apply es

fullExpr :: GenParser Char st LambdaTree
fullExpr =
  do spaces
     ee <- expr
     spaces
     eof
     return ee

parseLambda ss =
  case parse fullExpr "error" ss of
    Left  ee -> error (show ee)
    Right tt -> tt 
