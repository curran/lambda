
$.get 'lambda.peg', (grammar) ->
  parser = PEG.buildParser grammar
  
  exec = (expr) ->
    show reduce parser.parse expr

  byType = (fnName, fns) ->
    (tree) ->
      fn = fns[tree.type]
      if fn
        fn.apply null, arguments
      else
        throw "missing #{fnName}[#{tree.type}]"

  show = byType 'show',
    'lambda': (lambda) ->
      arg = lambda.arg.name
      body = show lambda.body
      "(&#{arg}.#{body})"
    'apply': (apply) ->
      (show apply.a) + (show apply.b)
    'name': (name) -> name.name

  reduce = byType 'reduce',
    'lambda': (lambda) -> _.extend lambda,
      body: reduce lambda.body
    'name': (name) -> name
    'apply': (apply) ->
      if apply.a.type == 'lambda'
        lambda = apply.a
        substitute lambda.body, lambda.arg, apply.b
      else _.extend apply,
        a: reduce apply.a
        b: reduce apply.b

  substitute = byType 'substitute',
    'apply': (apply, old, replacement) ->
      _.extend apply,
        a: substitute apply.a, old, replacement
        b: substitute apply.b, old, replacement
    'name': (name, old, replacement) ->
      if name.name == old.name then replacement else name
  
  # `e` (for "expect") evaluates a lambda calculus 
  # expressions and tests for equality with an expected output.
  e = (input, expectedOutput) ->
    output = show reduce parser.parse input
    if output != expectedOutput
      console.log """Test failed: for input '#{input}',
        expected #{expectedOutput}
        but got  #{output} """

  # The unit tests
  test = () ->
    e "(&x.xx)y", "yy"
# TODO next: make this test pass
    e "(&x.xx)(&x.x)", "(&x.x)"

#      e "(&x.x)(&x.x)" "(&x.x)",
#      e "(&x.(&y.xy))y" "(&t.yt)",
    

  # Export these just for testing in the REPL
  _.extend window, {
    exec, reduce, test, show, parser,
    byType
  }
