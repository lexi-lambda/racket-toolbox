#lang scribble/manual

@(require "private/common.rkt")

@title[#:tag "syntax"]{Syntax}

@section[#:tag "who"]{Context-sensitive @racket[who]}
@defmodule[toolbox/who]

@defform*[{(define/who id expr)
           (define/who (head args) body ...+)}]{
Like @racket[define], except @racket[who] evaluates to @racket['@#,racket[id]] within the lexical extent of the @racket[expr], @racket[args], or @racket[body] forms.

@(toolbox-examples
  (define/who (vector-first v)
    (when (zero? (vector-length v))
      (raise-arguments-error who "empty vector"))
    (vector-ref v 0))
  (eval:error (vector-first (vector))))}

@defidform[who]{
When used as an expression within @racket[define/who], evaluates to a symbol corresponding to the name of the definition.}
