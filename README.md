lambda
======

A Lambda Calculus interpreter. Uses PEG.js, CoffeeScript, and Underscore.

See also [A Tutorial Introduction to the Lambda Calculus by Raul Rojas](http://www.utdallas.edu/~gupta/courses/apl/lambda.pdf)

The story:

 * Built a Lambda Calculus interpreter in Haskell for a class (Design of Programming Languages with Professor Fred Martin and TA Nat Tuck at UMass Lowell Spring 2013)
 * Thought to myself "Is the JavaScript platform up to the task?"
 * Thought of a way to emulate the pattern matching syntax of Haskell in CoffeeScript (see `byType` in `lambda.coffee`)
 * Learned how to use PEG.js to build a parser.
 * Thought to generate an abstract syntax tree using simple object literals with a string `type` property (one of `'lambda'`, `'apply'`, `'name'`)
 * Had to write helper functions for the parser to achieve proper associativity for sequential apply statements and multi-argument lambdas.
 * Ported Haskell interpreter to CoffeeScript (using Underscore when needed)
 * Emulated pure functional style by always creating new AST nodes for reduction steps
 * Ideas for future work:
   * use a procedural style that mutates AST nodes during reduction steps.
   * Instrument the code to count how many new AST objects are created.
   * Visualize a table with the following columns:
     * input - a lambda calculus expression (from unit tests)
     * # new AST objects created in functional style
     * # new AST objects created in procedural style
