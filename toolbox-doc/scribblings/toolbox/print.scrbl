#lang scribble/manual

@(require "private/common.rkt")

@(define-id-referencer struct racket/struct)

@title[#:tag "print"]{Printing}
@defmodule[toolbox/print]

The @racketmodname[toolbox/print] module provides utilities for printing Racket values. In particular, it is intended to aid in writing @deftech{custom write procedures} for use with @racket[prop:custom-write].

@local-table-of-contents[]

@section[#:tag "print:helpers"]{General-purpose custom write helpers}

@defthing[custom-write-mode/c flat-contract? #:value (or/c #f #t 0 1)]{
A contract that describes the @racket[_mode] argument to a @tech{custom write procedure}.}

@defproc[(write/mode [v any/c] [out output-port?] [mode custom-write-mode/c]) void?]{
Writes @racket[v] to @racket[out] using either @racket[display], @racket[write], or @racket[print] depending on the given @racket[mode]. This can be useful when printing values inside a @tech{custom write procedure}.

@(toolbox-examples
  (struct tuple1 (value)
    #:property prop:custom-write
    (λ (self out mode)
      (write-string "#<tuple1: " out)
      (write/mode (tuple1-value self) out mode)
      (write-string ">" out)))
  (tuple1 'ok))}

@defproc[(make-write/mode [out output-port?] [mode custom-write-mode/c])
         (->* [any/c] [output-port?] void?)]{
Like @racket[write/mode], but returns a procedure like @racket[display], @racket[write], or @racket[print], except that the returned procedure writes to @racket[out] by default instead of @racket[(current-output-port)].

@(toolbox-examples
  (struct tuple2 (a b)
    #:property prop:custom-write
    (λ (self out mode)
      (define recur (make-write/mode out mode))
      (write-string "#<tuple2: " out)
      (recur (tuple2-a self))
      (write-string " " out)
      (recur (tuple2-b self))
      (write-string ">" out)))
  (tuple2 1 2))}

@deftogether[(@defthing[empty-printing-value empty-printing-value?]
              @defproc[(empty-printing-value? [v any/c]) boolean?])]{
A value that always prints as nothing.

@(toolbox-examples
  empty-printing-value
  (eval:check (~a empty-printing-value) "")
  (eval:check (~s empty-printing-value) "")
  (eval:check (~v empty-printing-value) ""))}

@defproc[(custom-printing-value [proc (-> output-port? custom-write-mode/c any)]
                                [#:quotable quotability (or/c 'self 'never 'always 'maybe) 'self])
         any/c]{
Returns a value that prints like a structure with @racket[proc] as its @tech{custom write procedure} and @racket[quotability] as the value of @racket[prop:custom-print-quotable]. This can be used to create “anonymous” custom printing values of arbitrary quotability.

@(toolbox-examples
  (list (custom-printing-value
         #:quotable 'never
         (λ (out mode)
           (write/mode "never quoted" out mode)))))}

@defproc[(printing-append [v any/c] ...) any/c]{
Returns a value that prints as each @racket[v] printed immediately after the other, with no separation between them.

@(toolbox-examples
  (printing-append '(one two) '(3 4)))}

@defproc[(printing-add-separators [vs list?]
                                  [#:trailing trailing-v any/c empty-printing-value]
                                  [#:leading leading-v any/c empty-printing-value])
         list?]{
Returns a list with the same number of values as @racket[vs]. Each element of the result prints like the corresponding element of @racket[vs], except @racket[trailing-v] is printed after every element except the last and @racket[leading-v] is printed after every element except the first.

@(toolbox-examples
  (printing-add-separators
   '(one two three)
   #:trailing (unquoted-printing-string "<trailing>")
   #:leading (unquoted-printing-string "<leading>")))}

@defproc[(make-constructor-style-printer [get-name (-> any/c (or/c symbol? string?))]
                                         [get-args (-> any/c list?)]
                                         [#:expression? expression? any/c #t])
         (-> any/c output-port? custom-write-mode/c void?)]{
Like @id-from-struct[make-constructor-style-printer], but if @racket[expression?] is @racket[#f], expression-style printing will never be used.}

@defproc[(constructor-style-printing-value [name (or/c symbol? string?)]
                                           [args list?]
                                           [#:expression? expression? any/c #t])
         any/c]{
Returns a value that prints like a structure that uses @racket[make-constructor-style-printer] as its @tech{custom write procedure}. If @racket[expression?] is @racket[#f], the value of the @racket[prop:custom-print-quotable] property will be @racket['never], otherwise it will be @racket['self].}

@section[#:tag "print:pretty"]{Cooperating with @racketmodname[racket/pretty]}

The bindings in this section assist in writing @tech{custom write procedures} that automatically adapt when @deftech{pretty printing} via @racketmodname[racket/pretty]. Specifically, when @racket[(pretty-printing)] is @racket[#t] and @reftech{line location} and @reftech{column location} has been enabled for an output port, they may break their printed output over multiple lines to avoid exceeding the target column width controlled by @racket[pretty-print-columns].

@defproc[(printing-sequence [vs list?]
                            [#:space-after space-after exact-nonnegative-integer? 0]
                            [#:hang hang-indent exact-nonnegative-integer? 0])
         any/c]{
Returns a value that prints like @racket[vs] but without any enclosing parentheses. When not @tech{pretty printing}, this means each element of @racket[vs] is simply printed one after the other, separated by a single space character. However, when @tech{pretty printing}, the elements of @racket[vs] may be printed on separate lines, indented as needed for alignment, if they do not fit within @racket[(- (pretty-print-columns) space-after)].

@(toolbox-examples
  (cons 'prefix (printing-sequence '(three short values)))
  (cons 'prefix (printing-sequence '(some-very-long-values
                                     that-will-be-printed
                                     over-multiple-lines
                                     to-avoid-overflowing
                                     the-desired-width))))

The @racket[space-after] argument is useful when the printed sequence will be followed by a closing delimiter such as @litchar{)} or @litchar{>}, as it ensures the sequence will be broken over multiple lines if the delimiter would not fit.

When printing is broken over multiple lines, the @racket[hang-indent] argument controls how much additional indentation should be printed after each line break.

@(toolbox-examples
  (printing-sequence
   #:hang 2
   '(some-long-values
     that-are-broken-over-several-lines
     and-are-indented-after-the-first-line)))}

@defproc[(delimited-printing-sequence [vs list?]
                                      [#:before before-str string? ""]
                                      [#:after after-str string? ""]
                                      [#:hang hang-indent exact-nonnegative-integer? 0])
         any/c]{
Like @racket[printing-sequence], but @racket[before-str] and @racket[after-str] are printed before or after the elements of @racket[vs], respectively.

@(toolbox-examples
  (delimited-printing-sequence
   #:before "#<"
   #:after ">"
   '(my-cool-struct 3)))}

@defproc[(printing-hang [herald any/c]
                        [body any/c]
                        [#:indent indent-amount exact-nonnegative-integer? 1]
                        [#:space-after space-after exact-nonnegative-integer? 0])
         any/c]{
Returns a value that prints like @racket[herald] followed by @racket[body]. When not @tech{pretty printing}, @racket[herald] and @racket[body] are printed on the same line separated by a single space. When @tech{pretty printing}, @racket[body] is printed on a subsequent line if printing it on the same line would not fit within @racket[(- (pretty-print-columns) space-after)]; the line is indented by @racket[indent-amount] spaces.

@(toolbox-examples
  (printing-hang
   #:indent 2
   (unquoted-printing-string "here is a long list:")
   '(it-gets-wrapped-over-several-lines
     because-it-is-too-long
     and-the-lines-are-indented)))}

@subsection{Printing unquoted expressions}

@defform[#:literals [unquote unquote-splicing ~seq ~@ ~if]
         (quasiexpr quasi-term)
         #:grammar ([term (unquote expr)
                          {~seq head-term ...}
                          {~if expr term term}
                          (head-term ... . term)
                          datum]
                    [head-term (unquote-splicing expr)
                               {~@ . term}
                               {~if expr head-term}
                               {~if expr head-term head-term}
                               term])]{
Constructs a value that prints like an unquoted expression. For example:

@(toolbox-examples
  #:label #f
  (quasiexpr (list (+ 1 2))))

Uses of @racket[unquote] or @racket[unquote-splicing] escape as in @racket[quasiquote], and any value inserted via an escape is printed via @racket[print] with a quote depth of @racket[0]:

@(toolbox-examples
  #:label #f
  (quasiexpr (list a ()))
  (quasiexpr (list ,'a ,'())))

Sequences produced by @racket[quasiexpr] may be broken over multiple lines when @tech{pretty printing}. Subsequences that should not be split, such as keyword argument pairs, can be grouped with @racket[~seq]:

@(toolbox-examples
  #:label #f
  (quasiexpr (foo #:a 'really-long-arguments
                  #:b 'that-cause-wrapping
                  #:c 'over-multiple-lines
                  #:d 'without-any-explicit-grouping))
  (quasiexpr (foo {~seq #:a 'really-long-arguments}
                  {~seq #:b 'that-cause-wrapping}
                  {~seq #:c 'over-multiple-lines}
                  {~seq #:d 'with-explicit-grouping})))

Like @racket[syntax], @racket[{~@ . term}] can be used within a @racket[head-term] to splice a list @racket[term] into the enclosing term. However, as @racket[quasiterm] does not support repetitions via @racket[...], the main use of @racket[~@] is usually only useful as the empty sequence @racket[{~@}] in one arm of a use of @racket[~if].

An @racket[{~if _cond-expr _then-term _else-term}] term is a convenient abbreviation for a conditional subterm. If @racket[_cond-expr] evaluates to @racket[#f], it prints like @racket[_else-term]; otherwise, it prints like @racket[_then-term]. Within a @racket[head-term], @racket[{~if expr term}] is equivalent to @racket[{~if expr term {~@}}].

The @racket[quasiexpr] form can be useful when implementing @tech{custom write procedures} for values that should print as applications of the functions used to create them, such as @reftech{contracts}.}

@defidform[~if]{
Recognized specially by @racket[quasiexpr]. An @racket[~if] form as an expression is a syntax error.}

@subsection{Installing a custom overflow handler}

@defproc[(with-printing-overflow-handler [out output-port?]
           [single-line-proc (-> output-port? any)]
           [multi-line-proc (-> (->* [output-port? exact-positive-integer?] void?) any)]
           [#:width width exact-positive-integer? (pretty-print-columns)]
           [#:space-after space-after exact-nonnegative-integer? 0])
         void?]{
If not currently @tech{pretty printing}, simply calls @racket[(single-line-proc out)]. Otherwise, @racket[single-line-proc] is applied to the result of @racket[make-tentative-pretty-print-output-port]. If @racket[single-line-proc] prints to the port in any way that would exceed the allowed @racket[width], it is immediately aborted, and @racket[multi-line-proc] is applied, instead, which should print to @racket[out] directly.

The procedure supplied to @racket[multi-line-proc] is like @racket[pretty-print-newline], but its arguments default to @racket[out] and @racket[width]. Additionally, after writing a newline, it write spaces until the next column (as returned by @racket[port-next-location]) is the same as it was when @racket[with-printing-overflow-handler] was called. This has the effect of ensuring all subsequent lines of the print are correctly indented to align with the first line.

Internally, higher-level abstractions like @racket[printing-sequence] and @racket[printing-hang] use @racket[with-printing-overflow-handler] to automatically adapt to the available space when pretty-printing via @racketmodname[racket/pretty]. In most cases, it is not necessary to use directly, but it can be useful if maximum control is needed.}
