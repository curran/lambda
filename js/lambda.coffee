$.get 'lambda.peg', (grammar) ->
  parser = PEG.buildParser grammar
  parse = parser.parse

  # This utility lets us approximate Haskell's 
  # pattern matching syntax in CoffeeScript
  match = (property, fns, fnName = 'obj') ->
    (obj) ->
      fn = fns[obj[property]]
      if fn
        # fn.apply is used
        # ( instead of `fn(tree)`)
        # so functions can take many arguments.
        # (see `rename` and `substitute` as examples)
        fn.apply null, arguments
      else
        throw Error "no match for #{fnName}.#{property} = #{tree.type}"

  byType = (fnName, fns) ->
    match 'type', fns, 'byType'

  # This is the first version of `byType`:
  # Keeping it around because it's interesting to see the progression
  # from this to the generalized version.
  byType_original = (fnName, fns) ->
    (tree) ->
      fn = fns[tree.type]
      if fn
        fn.apply null, arguments
      else
        throw Error "missing #{fnName}[#{tree.type}]"

  # The 'show' arg to byType is just for useful 
  # error reporting when a type match is missing.
  show = byType 'show',
    'lambda': (lambda) ->
      arg = lambda.arg.name
      body = show lambda.body
      "(&#{arg}.#{body})"
    'apply': (apply) ->
      if apply.b.type == 'apply'
        # Include parens for correct associativity
        (show apply.a) + '(' + (show apply.b) + ')'
      else
        # ... only when necessary.
        (show apply.a) + (show apply.b)
    'name': (name) -> name.name
    'number': (number) -> number.value

  # `evaluate` keeps reducing the tree until a 
  # fixed point (irreducible tree) is reached.
  numSteps = 0
  evaluate = (tree) ->
    fixedPoint = false
    while !fixedPoint
      prev = show tree
      tree = reduce tree
      curr = show tree
      fixedPoint = (prev == curr)
      numSteps++
    return tree

  # see http://www.utdallas.edu/~gupta/courses/apl/lambda.pdf
  builtins =
    'I': "(&x.x)"
    'S': "(&wyx.y(wyx))"
    '+': "(&xy.xSy)"
    '-': "(&xy.yPx)"
    '*': "(&xyz.x(yz))"
    '/': "(&ab.Y(&rnc.(G1n)c(r(-nb)(Sc)))a0)"
    'T': "(&xy.x)"
    'F': "(&xy.y)"
    'N': "(&x.x(&uv.v)(&ab.a))"
    'Z': "(&x.xFNF)"
    'G': "(&xy.Z(xPy))"
    'P': "(&n.n(&pz.z(S(pT))(pT))(&z.z00)F)"
    'Y': "(&g.((&x.g(xx))(&x.g(xx))))"
    'A': "Y(&rn.Zn1(*(r(Pn))n))"

  reduce = byType 'reduce',
    'lambda': (lambda) ->
      type: 'lambda'
      arg: lambda.arg
      body: reduce lambda.body
    'name': (name) ->
      builtin = builtins[name.name]
      # Perform one reduce step on builtins
      # so symbols are substituted right away
      if builtin then reduce parse builtin else name
    'apply': (apply) ->
      if apply.a.type == 'lambda'
        lambda = resolveNameConflicts apply.a, apply.b
        substitute lambda.body, lambda.arg, apply.b
      else
        type: 'apply'
        a: reduce apply.a
        b: reduce apply.b
    'number': (number) ->
      value = number.value
      if value == 0 then parse '(&s.(&z.z))'
      else evaluate parse ( _.flatten [
        'S(' for [1..value],
        '0',
        ')' for [1..value]
      ]).join ''

  # Starts with 't' because unit tests expect it.
  allNames = "tabcdefghijklmnopqrsuvwxyz".split('')

  resolveNameConflicts = (a, b) ->
    usedNames = _.union (allVars a), (allVars b)
    newNames = _.difference allNames, usedNames
    oldNames = _.intersection (boundVars a), (freeVars b)
    for i in [0..oldNames.length]
      do -> a = rename a, oldNames[i], newNames[i]
    return a

  extractNames = (onlyLambdaArgs) ->
    byType 'vars',
      'lambda': (lambda) ->
        _.union [lambda.arg.name], allVars lambda.body
      'apply': (apply) ->
        _.union (allVars apply.a), (allVars apply.b)
      'name': (name) ->
        if onlyLambdaArgs then [] else [name.name]
      'number': (number) -> []

  allVars = extractNames false
  boundVars = extractNames true
  freeVars = (tree) ->
    _.difference (allVars tree), (boundVars tree)

  rename = byType 'rename',
    'lambda': (lambda, oldName, newName) ->
      type: 'lambda'
      arg: rename lambda.arg, oldName, newName
      body: rename lambda.body, oldName, newName
    'apply': (apply, oldName, newName) ->
      type: 'apply'
      a: rename apply.a, oldName, newName
      b: rename apply.b, oldName, newName
    'name': (name, oldName, newName) ->
      if name.name == oldName
        type: 'name'
        name: newName
      else
        name
    'number': (number) -> []

  substitute = byType 'substitute',
    'lambda': (lambda, old, replacement) ->
      # If arg == old the inner arg takes precedence
      # over the outer arg being replaced, so do not 
      # perform the substitution in the lambda body.
      if lambda.arg.name == old.name
        lambda
      else
        type: 'lambda'
        arg: lambda.arg
        body: substitute lambda.body, old, replacement
    'name': (name, old, replacement) ->
      if name.name == old.name then replacement else name
    'apply': (apply, old, replacement) ->
      type: 'apply'
      a: substitute apply.a, old, replacement
      b: substitute apply.b, old, replacement
  
  # `e` (for "expect") evaluates a lambda calculus 
  # expressions and tests for equality with an expected output.
  e = (input, output) ->
    console.log "testing '#{input}'"
    numSteps = 0
    inputResult = exec input
    numStepsForInput = numSteps
    outputResult = exec output
    if inputResult != outputResult
      console.error """Test failed: for input '#{input}',
        expected #{outputResult}
        but got  #{inputResult}"""
    else
      console.log "  ok, took #{numStepsForInput} steps"

  exec = (expr) -> show evaluate parse expr

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

    # Tests for multi-argument lambdas
    e "(&sz.z)", "(&s.(&z.z))"
    e "(&wxy.ywx)abc", "cab"
    e "(&wxyz.zyxw)abcd", "dcba"
    
    # Tests for Curch Numerals
    e "I", "(&x.x)"
    e "S", "(&w.(&y.(&x.y(wyx))))"
    e "(&s.(&z.z))", "(&s.(&z.z))"
    e "(&w.(&y.(&x.y(wyx))))(&s.(&z.z))", "(&y.(&x.yx))"
    e "S(&s.(&z.z))", "(&y.(&x.yx))"
    e "0", "(&s.(&z.z))"
    e "1", "(&y.(&x.yx))"
    e "7", "(&y.(&x.y(y(y(y(y(y(yx))))))))"
    e "+", "(&x.(&y.x(&w.(&y.(&x.y(wyx))))y))"
    e "*", "(&x.(&y.(&z.x(yz))))"
    e "(&w.(&y.(&x.y(wyx))))(&s.(&z.z))", "(&y.(&x.yx))"
    e "S0", "(&y.(&x.yx))"
    e "+ 2 3", "(&y.(&x.y(y(y(y(yx))))))"
    e "+ 2 1", "(&y.(&x.y(y(yx))))"
    e "* 4 3", "(&z.(&x.z(z(z(z(z(z(z(z(z(z(z(zx)))))))))))))"
    e "* 2 3", "(&z.(&x.z(z(z(z(z(zx)))))))"
    e "S (* 2 (+ 1 1))", "(&y.(&x.y(y(y(y(yx))))))"
    e "S(S(S(0)))", "(&y.(&x.y(y(yx))))"

    # Tests for builtins
    e "(&x.xx)y", "yy"
    e "(&wxy.ywx)abc", "cab"
    e "7", "(&y.(&x.y(y(y(y(y(y(yx))))))))"
    e "+ 3 5", "(&y.(&x.y(y(y(y(y(y(y(yx)))))))))"
    e "(&x.(&y.xy))y", "(&t.yt)"
    e "(&x.(&y.(x(&x.xy))))y", "(&t.y(&x.xt))"
    e "T", "(&xy.x)"
    e "F", "(&xy.y)"
    e "N", "(&x.x(&uv.v)(&ab.a))"
    e "Z", "(&x.xFNF)"
    e "P1", "(&s.(&z.z))"
    e "P5", "(&y.(&x.y(y(y(yx)))))"

# TODO make the rest of these pass
    # Tests for Y-Combinator
    e "A1", "(&z.(&x.zx))"
    e "A3", "(&z.(&x.z(z(z(z(z(zx)))))))"
#    e "A4", "(&z.(&x.z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(z(zx)))))))))))))))))))))))))"
#    e "24", "(&y.(&x.y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(y(yx)))))))))))))))))))))))))"
#
#    # Tests for subtraction and division
#    e "- 10 3", "(&f.(&x.f(f(f(f(f(f(fx))))))))"
    e "/ 4 2", "2"
    e "/ 3 2", "1"
#    e "/ 6 2", "3"
#    e "/ 6 3", "2"
#    e "/ 5 2", "2"

  # The functions below are for testing in the REPL.

  # `step` executes n reductions on `tree`
  # and prints each step to the console.
  step = (n, expr) ->
    tree = parse expr
    for [0..n]
      do ->
        console.log show tree
        tree = reduce tree

  # Prints the tree structure using indentation.
  printTree = (tree) ->
    helper = byType 'printTree',
      'lambda': (lambda, indent) ->
        console.log indent + 'lambda'
        indent += '  '
        console.log indent + 'arg'
        helper lambda.arg, indent
        console.log indent + 'body'
        helper lambda.body, indent
      'name': (name, indent) ->
        console.log indent+'name '+name.name
      'number': (number, indent) ->
        console.log indent+'number '+number.value
      'apply': (apply, indent) ->
        console.log indent + 'apply'
        indent += '  '
        console.log indent + 'a'
        helper apply.a, indent
        console.log indent + 'b'
        helper apply.b, indent
    helper tree, ''

  # Export functions to the global object for testing in the REPL
  _.extend window, {
    exec, evaluate, reduce, test, show, parser,
    byType, allVars, freeVars, boundVars, rename,
    printTree, step
  }
