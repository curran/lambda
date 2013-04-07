
$.get 'lambda.peg', (grammar) ->
  parser = PEG.buildParser grammar
  

  # This utility lets us approximate Haskell's 
  # pattern matching syntax in CoffeeScript
  byType = (fnName, fns) ->
    (tree) ->
      fn = fns[tree.type]
      if fn
        fn.apply null, arguments
      else
        throw "missing #{fnName}[#{tree.type}]"

  # The 'show' arg to byType is just for useful 
  # error reporting when a type match is missing.
  show = byType 'show',
    'lambda': (lambda) ->
      arg = lambda.arg.name
      body = show lambda.body
      "(&#{arg}.#{body})"
    'apply': (apply) ->
      (show apply.a) + (show apply.b)
    'name': (name) -> name.name

  # `evaluate` keeps reducing the tree until a 
  # fixed point (irreducible tree) is reached.
  evaluate = (tree) ->
    prev = show tree
    tree = reduce tree
    curr = show tree
    if prev == curr then tree else evaluate tree

  reduce = byType 'reduce',
    'lambda': (lambda) -> _.extend lambda,
      body: reduce lambda.body
    'name': (name) -> name
    'apply': (apply) ->
      if apply.a.type == 'lambda'
        lambda = resolveNameConflicts apply.a, apply.b
        substitute lambda.body, lambda.arg, apply.b
      else _.extend apply,
        a: reduce apply.a
        b: reduce apply.b

  allNames = "tabcdefghijklmnopqrstuvwxyz".split('')

  resolveNameConflicts = (a, b) ->
    usedNames = _.union (allVars a), (allVars b)
    newNames = _.difference allNames, usedNames
    oldNames = _.intersection (boundVars a), (freeVars b)
    for i in [0..oldNames.length]
      do (i) ->
        a = rename a, oldNames[i], newNames[i]
    return a

  extractNames = (onlyLambdaArgs) ->
    byType 'vars',
      'lambda': (lambda) ->
        _.union [lambda.arg.name], allVars lambda.body
      'apply': (apply) ->
        _.union (allVars apply.a), (allVars apply.b)
      'name': (name) ->
        if onlyLambdaArgs then [] else [name.name]

  allVars = extractNames false
  boundVars = extractNames true
  freeVars = (tree) ->
    _.difference (allVars tree), (boundVars tree)

  rename = byType 'rename',
    'lambda': (lambda, oldName, newName) ->
      _.extend lambda,
        arg: rename lambda.arg, oldName, newName
        body: rename lambda.body, oldName, newName
    'apply': (apply, oldName, newName) ->
      _.extend apply,
        a: rename apply.a, oldName, newName
        b: rename apply.b, oldName, newName
    'name': (name, oldName, newName) ->
      if name.name == oldName
        name.name = newName
      return name




#   let
#     -- start with 't' to satisfy given tests
#     availableNames = ['t'..'z'] ++ ['a'..'s']
#     usedNames = union (allVars a) (allVars b)
#     unusedNames = availableNames \\ usedNames
#     namesToChange = intersect (boundVars a) (freeVars b)
#     nameReplacements = zip namesToChange unusedNames
#   in
#     replaceNames a nameReplacements
# 
# allVars :: LambdaTree -> [Char]
# allVars (Lambda arg body) = union [arg] (allVars body)
# allVars (Apply a b) = union (allVars a) (allVars b)
# allVars (Name name) = [name]
# allVars _ = []
# 
# boundVars :: LambdaTree -> [Char]
# boundVars (Lambda arg body) = union [arg] (boundVars body)
# boundVars (Apply a b) = union (boundVars a) (boundVars b)
# boundVars _ = []
# 
# freeVars tree = (allVars tree) \\ (boundVars tree)
# 
# replaceNames tree [] = tree
# replaceNames tree ((old, new):rest) =
#   replaceNames (replaceName tree old new) rest
# 
# -- replaceName ( tree        old     new) -> return value
# replaceName :: LambdaTree -> Char -> Char -> LambdaTree
# replaceName (Lambda arg body) old new = 
#   Lambda (if arg == old then new else arg) (replaceName body old new) 
# replaceName (Name name) old new =
#   Name (if name == old then new else name)
# replaceName (Apply a b) old new = 
#   Apply (replaceName a old new) (replaceName b old new) 
# replaceName whatever old new = whatever

  substitute = byType 'substitute',
    'lambda': (lambda, old, replacement) ->
      # If arg == old the inner arg takes precedence
      # over the outer arg being replaced, so do not 
      # perform the substitution in the lambda body.
      if lambda.arg.name == old.name then lambda
      else _.extend lambda, body:
        substitute lambda.body, old, replacement
    'name': (name, old, replacement) ->
      if name.name == old.name then replacement else name
    'apply': (apply, old, replacement) ->
      _.extend apply,
        a: substitute apply.a, old, replacement
        b: substitute apply.b, old, replacement
  
  # `e` (for "expect") evaluates a lambda calculus 
  # expressions and tests for equality with an expected output.
  e = (input, expectedOutput) ->
    output = show evaluate parser.parse input
    if output != expectedOutput
      console.log """Test failed: for input '#{input}',
        expected #{expectedOutput}
        but got  #{output} """

  # The unit tests
  test = () ->

    # Tests for substitution
    e "x", "x"
    e "xy", "xy"
    e "(&x.xx)y", "yy"
    e "(&x.xx)(&x.x)", "(&x.x)"
    e "(&x.x)(&x.x)", "(&x.x)"

    # Tests for renaming
    e "(&x.(&y.xy))y", "(&t.yt)"
    e "(&x.(&y.(x(&x.xy))))y", "(&t.y(&x.xt))"
    e "(&y.(&x.y((&z.z)x)))", "(&y.(&x.yx))"
    e "(&y.(&x.y((&s.(&z.z))yx)))", "(&y.(&x.yx))"
    e "(&w.(&y.(&x.y(wyx))))(&s.(&z.z))", "(&y.(&x.yx))"

# TODO next: Church Numerals
    
#    # Tests for Curch Numerals
#    e "(&wxy.ywx)abc", "cab"
#    e "I", "(&x.x)"
#    e "S", "(&w.(&y.(&x.y(wyx))))"
#    e "(&s.(&z.z))", "(&s.(&z.z))"
#    e "(&w.(&y.(&x.y(wyx))))(&s.(&z.z))", "(&y.(&x.yx))"
#    e "S(&s.(&z.z))", "(&y.(&x.yx))"
#    e "0", "(&s.(&z.z))"
#    e "1", "(&y.(&x.yx))"
#    e "7", "(&y.(&x.y(y(y(y(y(y(yx))))))))"
#    e "+", "(&x.(&y.x(&w.(&y.(&x.y(wyx))))y))"
#    e "*", "(&x.(&y.(&z.x(yz))))"
#    e "(&w.(&y.(&x.y(wyx))))(&s.(&z.z))", "(&y.(&x.yx))"
#    e "S0", "(&y.(&x.yx))"
#    e "+ 2 3", "(&y.(&x.y(y(y(y(yx))))))"
#    e "+ 2 1", "(&y.(&x.y(y(yx))))"
#    e "* 4 3", "(&z.(&x.z(z(z(z(z(z(z(z(z(z(z(zx)))))))))))))"
#    e "* 2 3", "(&z.(&x.z(z(z(z(z(zx)))))))"
#    e "S (* 2 (+ 1 1))", "(&y.(&x.y(y(y(y(yx))))))"
#    e "S(S(S(0)))", "(&y.(&x.y(y(yx))))"
#
#    # Tests for builtins and Y combinator
#    e "(&x.xx)y", "yy"
#    e "(&wxy.ywx)abc", "cab"
#    e "7", "(&y.(&x.y(y(y(y(y(y(yx))))))))"
#    e "+ 3 5", "(&y.(&x.y(y(y(y(y(y(y(yx)))))))))"
#    e "(&x.(&y.xy))y", "(&t.yt)"
#    e "(&x.(&y.(x(&x.xy))))y", "(&t.y(&x.xt))"
#    e "T", "(&xy.x)"
#    e "F", "(&xy.y)"
#    e "N", "(&x.x(&uv.v)(&ab.a))"
#    e "Z", "(&x.xFNF)"
#    e "P1", "(&f.(&x.x))"
#    e "P5", "(&f.(&x.f(f(f(fx)))))"
#    e "A1", "(&z.(&x.zx))"
#    e "A3", "(&z.(&x.z(z(z(z(z(zx)))))))"
#    e "A4", "(&z.(&x.z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(zx)))))))))))))))))))))))))"
#    e "24", "(&y.(&x.y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(yx)))))))))))))))))))))))))"
#
#    # Tests for subtraction and division
#    e "- 10 3", "(&f.(&x.f(f(f(f(f(f(fx))))))))"
#    e "/ 4 2", "2"
#    e "/ 6 2", "3"
#    e "/ 6 3", "2"
#    e "/ 5 2", "2"
    
  # `exec` is for evaluating expressions in the REPL.
  exec = (expr) -> show evaluate parser.parse expr

  # Export these just for testing in the REPL
  _.extend window, {
    exec, evaluate, reduce, test, show, parser,
    byType, allVars, freeVars, boundVars, rename
  }
