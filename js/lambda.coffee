
$.get 'lambda.peg', (grammar) ->
  parser = PEG.buildParser grammar
  
  exec = (expr) ->
    show eval parser.parse expr

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

  # TODO implement this
  resolveNameConflicts = (a, b) -> a

# resolveNameConflicts a b =
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
      console.dir old.name
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
    e "(&x.xx)y", "yy"
    e "(&x.xx)(&x.x)", "(&x.x)"
    e "(&x.x)(&x.x)", "(&x.x)"
# TODO next: make this test pass
    e "(&x.(&y.xy))y", "(&t.yt)"
    

  # Export these just for testing in the REPL
  _.extend window, {
    exec, reduce, test, show, parser,
    byType
  }
