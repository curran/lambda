-- This Lambda Calculus evaluator was written in April 2013
-- by Curran Kelleher as part of a class "Design of Programming Languages"
-- taught at UMass Lowell by Professor Fred Martin and TA Nat Tuck
module Main where

import Parser
import Data.List

-- `eval` calls reduce until a fixed point is reached
-- (stops when the tree stops changing)
eval tree = 
  let tree' = reduce tree
  in if tree == tree' then tree else eval tree'

-- `reduce` is the main evaluator that applies
-- the Lambda Calculus rules for renaming and substitution.
reduce :: LambdaTree -> LambdaTree
reduce (Lambda arg body) = Lambda arg (reduce body)
reduce tree@(Name name) = tree
reduce (Apply a@(Lambda _ _) b) = 
  let (Lambda arg body) = resolveNameConflicts a b
  in substitute body arg b
reduce (Apply a b) = Apply (reduce a) (reduce b)
reduce (Number num) = makeNumber num 
reduce (Symbol sym)
  | sym == 'I' = parseLambda "(&x.x)"
  | sym == 'S' = parseLambda "(&wyx.y(wyx))"
  | sym == '+' = parseLambda "(&xy.xSy)"
  | sym == '-' = parseLambda "(&xy.yPx)"
  | sym == '*' = parseLambda "(&xyz.x(yz))"
  -- This '/' takes about 25 seconds for (/ 25 5)
  --  | sym == '/' = parseLambda "(&ab.Y(&rn.Z(-a(*nb))n(r(Sn)))0)"
  -- This '/' takes about 10 seconds for (/ 25 5)
  --  | sym == '/' = parseLambda "(&ab.Y(&rnc.Znc(r(-nb)(Sc)))a0)"
  -- This '/' accounts for non-perfect integer division (e.g. (/ 26 5))
  | sym == '/' = parseLambda "(&ab.Y(&rnc.(G1n)c(r(-nb)(Sc)))a0)"
  | sym == 'T' = parseLambda "(&xy.x)"
  | sym == 'F' = parseLambda "(&xy.y)"
  | sym == '∧' = parseLambda "(&xy.xy(&uv.v))"
  | sym == '∨' = parseLambda "(&xy.x(&uv.u)y)"
  | sym == 'N' = parseLambda "(&x.x(&uv.v)(&ab.a))"
  | sym == 'Z' = parseLambda "(&x.xFNF)"
  | sym == 'G' = parseLambda "(&xy.Z(xPy))"
  | sym == 'P' = parseLambda "(&n.&f.&x.n(&g.&h.h(gf))(&u.x)(&u.u))"
  | sym == 'Y' = parseLambda "(&g.((&x.g(xx))(&x.g(xx))))"
  | sym == 'A' = parseLambda "Y(&rn.Zn1(*(r(Pn))n))"
  | otherwise  = Error ("Unrecognized Symbol '"++[sym]++"'")
-- Just bubble up errors
reduce tree@(Error _) = tree

makeNumber num = eval $ parseLambda $ makeNumberExpr num

makeNumberExpr 0 = "(&s.(&z.z))"
makeNumberExpr n = "S("++(makeNumberExpr (n-1))++")"

resolveNameConflicts a b =
  let
    -- start with 't' to satisfy given tests using
    -- exact string matching
    availableNames = ['t'..'z'] ++ ['a'..'s']
    usedNames = union (allVars a) (allVars b)
    unusedNames = availableNames \\ usedNames
    namesToChange = intersect (boundVars a) (freeVars b)
    nameReplacements = zip namesToChange unusedNames
  in
    replaceNames a nameReplacements

allVars :: LambdaTree -> [Char]
allVars (Lambda arg body) = union [arg] (allVars body)
allVars (Apply a b) = union (allVars a) (allVars b)
allVars (Name name) = [name]
allVars _ = []

boundVars :: LambdaTree -> [Char]
boundVars (Lambda arg body) = union [arg] (boundVars body)
boundVars (Apply a b) = union (boundVars a) (boundVars b)
boundVars _ = []

freeVars tree = (allVars tree) \\ (boundVars tree)

replaceNames tree [] = tree
replaceNames tree ((old, new):rest) =
  replaceNames (replaceName tree old new) rest

-- replaceName ( tree        old     new) -> return value
replaceName :: LambdaTree -> Char -> Char -> LambdaTree
replaceName (Lambda arg body) old new = 
  Lambda (if arg == old then new else arg) (replaceName body old new) 
replaceName (Name name) old new =
  Name (if name == old then new else name)
replaceName (Apply a b) old new = 
  Apply (replaceName a old new) (replaceName b old new) 
replaceName whatever old new = whatever

-- substitute ( body        old       new    ) -> return value
substitute :: LambdaTree -> Char -> LambdaTree -> LambdaTree
substitute lambda@(Lambda arg body) old new = 
  -- In this case the inner arg takes precedence
  -- over the outer arg being replaced, so do not 
  -- perform the substitution in the lambda body.
  if arg == old then lambda
  else Lambda arg (substitute body old new) 
substitute (Apply a b) old new = 
  Apply (substitute a old new) (substitute b old new) 
substitute tree@(Name name) old new = 
  if name == old then new else tree
substitute whatever old new = whatever

-- call the `t` function from a REPL
-- to run these unit tests.
t = [ e "(&x.xx)y" "yy",
      e "(&x.xx)(&x.x)" "(&x.x)",
      e "(&x.x)(&x.x)" "(&x.x)",
      e "(&x.(&y.xy))y" "(&t.yt)",
      -- Begin test from the perl script
      e "x" "x",
      e "(&x.x)y" "y",
      e "(&x.xx)y" "yy",
      e "(&x.xx)(&x.xx)z" "(&x.xx)(&x.xx)z",
      e "(&x.(&y.xy))y" "(&t.yt)",
      e "(&x.(&y.(x(&x.xy))))y" "(&t.y(&x.xt))",
      e "(&y.(&x.y((&z.z)x)))" "(&y.(&x.yx))",
      e "(&y.(&x.y((&s.(&z.z))yx)))" "(&y.(&x.yx))",
      e "(&w.(&y.(&x.y(wyx))))(&s.(&z.z))" "(&y.(&x.yx))",
      -- Begin tests for Curch Numerals
      e "(&wxy.ywx)abc" "cab",
      e "I" "(&x.x)",
      e "S" "(&w.(&y.(&x.y(wyx))))",
      e "(&s.(&z.z))" "(&s.(&z.z))",
      e "(&w.(&y.(&x.y(wyx))))(&s.(&z.z))" "(&y.(&x.yx))",
--step 0 (&w.(&y.(&x.y(wyx))))(&s.(&z.z))
--step 1 (&y.(&x.y((&s.(&z.z))yx)))
--step 2 (&y.(&x.y((&z.z)x)))
--step 3 (&y.(&x.yx))
--step 4 (&y.(&x.yx))
-- this is equavalent to "(&s.(&z.sz))"
      e "S(&s.(&z.z))" "(&y.(&x.yx))",
      e "0" "(&s.(&z.z))",
      e "1" "(&y.(&x.yx))",
      e "7" "(&y.(&x.y(y(y(y(y(y(yx))))))))",
      e "+" "(&x.(&y.x(&w.(&y.(&x.y(wyx))))y))",
      e "*" "(&x.(&y.(&z.x(yz))))",
      e "(&w.(&y.(&x.y(wyx))))(&s.(&z.z))" "(&y.(&x.yx))",
      e "S0" "(&y.(&x.yx))",
      e "+ 2 3" "(&y.(&x.y(y(y(y(yx))))))",
      e "+ 2 1" "(&y.(&x.y(y(yx))))",
      e "* 4 3" "(&z.(&x.z(z(z(z(z(z(z(z(z(z(z(zx)))))))))))))",
      e "* 2 3" "(&z.(&x.z(z(z(z(z(zx)))))))",
      e "S (* 2 (+ 1 1))" "(&y.(&x.y(y(y(y(yx))))))",
      e "S(S(S(0)))" "(&y.(&x.y(y(yx))))",
-- Begin tests for Y Combinator
      e "(&x.xx)y" "yy",
      e "(&wxy.ywx)abc" "cab",
      e "7" "(&y.(&x.y(y(y(y(y(y(yx))))))))",
      e "+ 3 5" "(&y.(&x.y(y(y(y(y(y(y(yx)))))))))",
      e "(&x.(&y.xy))y" "(&t.yt)",
      e "(&x.(&y.(x(&x.xy))))y" "(&t.y(&x.xt))",
      e "T" "(&xy.x)",
      e "F" "(&xy.y)",
      e "N" "(&x.x(&uv.v)(&ab.a))",
      e "Z" "(&x.xFNF)",
      e "P1" "(&f.(&x.x))",
      e "P5" "(&f.(&x.f(f(f(fx)))))",
      e "A1" "(&z.(&x.zx))",
--       e "A3" "6"]
-- expected (&y.(&x.y(y(y(y(y(yx)))))))
-- got      (&z.(&x.z(z(z(z(z(zx)))))))
      e "A3" "(&z.(&x.z(z(z(z(z(zx)))))))",
      e "A4" "(&z.(&x.z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(zx)))))))))))))))))))))))))",
      e "24" "(&y.(&x.y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(yx)))))))))))))))))))))))))",
--        e "A5" "120"]
      e "- 10 3" "(&f.(&x.f(f(f(f(f(f(fx))))))))",
      e "/ 4 2" "2",
      e "/ 6 2" "3",
      e "/ 6 3" "2",
      e "/ 5 2" "2"]
 
-- `e` evaluates both sides then tests for equality.
-- Returns 'ok' or a helpful message.
e input expectedOutput = 
  let
    output = showLx $ eval $ parseLambda input
    expected = showLx $ eval $ parseLambda expectedOutput
  in if output == expected then "ok"
     else "expected " ++ expected ++ 
       ", got " ++ output ++ " on input " ++ input

-- `exec` parses and evaluates a Lambda Calculus expression string.
exec exp = showLx $ eval $ parseLambda exp

main = do 
  line <- getLine
  putStr $ exec line
