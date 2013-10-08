Aether implementation
=====================

This implementation is based on the Terra language.

The compiler infrastructure is comprised of the following stages:

1. **Lexing** transforms program text into a list of tokens. It may use a user-provided function returning successive line of input. This is useful when implementing a REPL with line continuations.

2. **Parsing** consumes tokens and builds up a parse tree (PT). This tree closely represents the program text.

3. **Type checking** transforms the parse tree into a typed abstract syntax tree (AST). Type checking is performed on the parse tree in order to provide better error reporting. Once a subtree is fully typed, is can then be transformed into an intermediate form that is more convenient in further stages of the compiler (like optimization and code generation). The final AST is comprised of such transformed subtree.

4. **Optimization passes** are performed on the AST. The high-level information about the language is exploited at this stage to produce an efficient control-flow for the code generation stage.

5. **Code generation** takes the AST and produces Terra quotations that are then handled by the Terra runtime to generate the final machine code.

The whole process is orchestrated by a single compiler object. Customizing each stage is done by setting a particular field on the compiler and then telling it to process a given text input.

A parse tree is a list of statement nodes. Each node has an id, a set of fields and a function to pretty-print itself.

The type checker has a type table where it looks up corresponding typechecking functions for each possible parse node id. That function returns a new node which has type information associated with it. The type checker also needs access to all symbols in the current scope to be able to type check operators and function calls. Those symbols are stored in the environment that is populated from the following sources:

    - builtin environment
    - imported modules
    - functions defined at file scope
    - local functions

The builtin environment is passed to the type checker's initialization function by the compiler.
