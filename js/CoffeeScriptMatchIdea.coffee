# This utility lets us approximate Haskell's 
# pattern matching syntax in CoffeeScript
match = (property, fnName, fns) ->
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

# Using `match` looks like this:
show = match 'type', 'show'
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

# Notice how the function name `show` is passed in
# as an argument to `match` so that the error message
# generated when a match is missing tells you which
# function to look in when debugging.
#
# Also notice how the property to match must be passed
# as a string literal.
#
# The Idea
# ========
#
# 'match' could be integrated into the CoffeeScriipt language.
# Using it could look like this:
show = match type
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

# The CoffeeScript compiler could track which varuable
# the function is assigned to for nice error reporting,
# and could interpret the string directly following 'match'
# as the property name to match.
#
# Not much of a difference, but it would be neat to be able
# to say "CoffeeScript has pattern matching"!
#
# Curran Kelleher 4/14/2013
