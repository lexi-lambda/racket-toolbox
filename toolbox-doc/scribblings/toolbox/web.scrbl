#lang scribble/manual

@(require "private/common.rkt")

@title[#:tag "web"]{Web}

@section[#:tag "web:dispatch"]{Dispatch}
@defmodule[toolbox/web/dispatch]

@defform[(define-enum-bidi-match-expander id syms-expr)
         #:contracts ([syms-expr (listof symbol?)])]{
Binds @racket[id] as a @tech[#:doc '(lib "web-server/scribblings/web-server.scrbl")]{bi-directional match expander} like @racket[symbol-arg], but additionally constrained to be one of the symbols in the list produced by @racket[syms-expr].

@(toolbox-examples
  (define-enum-bidi-match-expander language-arg '(racket rhombus))
  (eval:check (match "racket" [(language-arg l) l]) 'racket)
  (eval:check (match "rhombus" [(language-arg l) l]) 'rhombus)
  (eval:error (match "cheesecake" [(language-arg l) l])))}
