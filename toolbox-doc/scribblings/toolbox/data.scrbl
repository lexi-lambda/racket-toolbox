#lang scribble/manual

@(require (for-syntax racket/base)
          (only-in racket/base [box r:box])
          "private/common.rkt")

@title[#:tag "data" #:style 'toc]{Data Structures}

@local-table-of-contents[]

@section[#:tag "boolean"]{Booleans}
@defmodule[toolbox/boolean]

@defproc[(->boolean [v any/c]) boolean?]{
Returns @racket[#f] if @racket[v] is @racket[#f], otherwise returns @racket[#t].}

@section[#:tag "box"]{Boxes}
@defmodule[toolbox/box]

@defproc[(box-cas-update! [box (and/c box? (not/c immutable?) (not/c impersonator?))]
                          [proc (-> any/c any/c)])
         any/c]{
Atomically updates the contents of @racket[box] by applying @racket[proc] to the old value to produce a new value. The @racket[proc] procedure will be applied more than once if the box is concurrently modified between reading the old value and writing the new one, so @racket[proc] should generally be inexpensive. The result of the call to @racket[box-cas-update!] is the value written to @racket[box].

@(let-syntax ([box (make-rename-transformer #'r:box)])
   (toolbox-examples
    (define b (box "hello"))
    (eval:check (box-cas-update! b string-upcase) "HELLO")
    (eval:check (unbox b) "HELLO")))}

@defproc[(box-cas-update!* [box (and/c box? (not/c immutable?) (not/c impersonator?))]
                           [proc (-> any/c (values any/c any/c))])
         any/c]{
Like @racket[box-cas-update!], but @racket[proc] should return two values: the first value is returned, and the second value is written to @racket[box].

@(let-syntax ([box (make-rename-transformer #'r:box)])
   (toolbox-examples
    (define b (box "old"))
    (eval:check (box-cas-update!* b (λ (old) (values old "new"))) "old")
    (eval:check (unbox b) "new")))}

@defproc[(box-add1! [box (and/c box? (not/c immutable?) (not/c impersonator?))]) number?]{
Equivalent to @racket[(box-cas-update! box add1)].}

@defproc[(box-sub1! [box (and/c box? (not/c immutable?) (not/c impersonator?))]) number?]{
Equivalent to @racket[(box-cas-update! box sub1)].}

@section[#:tag "list"]{Lists}
@defmodule[toolbox/list]

@defproc[(take-at-most [lst list?] [n exact-nonnegative-integer?]) list?]{
Like @racket[take], except if @racket[lst] has fewer than @racket[n] elements, @racket[take-at-most] returns @racket[lst] instead of raising an exception.

@(toolbox-examples
  (eval:check (take-at-most '(1 2 3 4 5) 3) '(1 2 3))
  (eval:check (take-at-most '(1 2) 3) '(1 2)))}

@defproc[(split-at-most [lst list?] [n exact-nonnegative-integer?])
         (values list? list?)]{
Like @racket[split-at], except if @racket[lst] has fewer than @racket[n] elements, @racket[split-at-most] returns @racket[(values lst '())] instead of raising an exception.

@(toolbox-examples
  (eval:check (split-at-most '(1 2 3 4 5) 3)
              (values '(1 2 3) '(4 5)))
  (eval:check (split-at-most '(1 2) 3)
              (values '(1 2) '())))}

@defproc[(maybe->list [v any/c]) list?]{
If @racket[v] is @racket[#f], returns @racket['()], otherwise returns @racket[(list v)].}

@defform[(when/list test-expr body ...+)]{
Equivalent to @racket[(if test-expr (list (let () body #,m...)) '())].}

@defform[(unless/list test-expr body ...+)]{
Equivalent to @racket[(if test-expr '() (list (let () body #,m...)))].}

@defform[(when/list* test-expr body ...+)]{
Equivalent to @racket[(if test-expr (let () body #,m...) '())], except that the last @racket[body] form must evaluate to a @reftech{list}, or an @racket[exn:fail:contract] exception is raised.}

@defform[(unless/list* test-expr body ...+)]{
Equivalent to @racket[(if test-expr '() (let () body #,m...))], except that the last @racket[body] form must evaluate to a @reftech{list}, or an @racket[exn:fail:contract] exception is raised.}

@section[#:tag "string"]{Strings}
@defmodule[toolbox/string]

@defform[(when/string test-expr body ...+)]{
Equivalent to @racket[(if test-expr (let () body #,m...) "")], except that the last @racket[body] form must evaluate to a @reftech{string}, or an @racket[exn:fail:contract] exception is raised.}

@defform[(unless/string test-expr body ...+)]{
Equivalent to @racket[(if test-expr "" (let () body #,m...))], except that the last @racket[body] form must evaluate to a @reftech{string}, or an @racket[exn:fail:contract] exception is raised.}

@include-section["data/order.scrbl"]
