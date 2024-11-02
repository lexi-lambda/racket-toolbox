#lang scribble/manual

@(require (for-syntax racket/base)
          (only-in racket/base [box r:box])
          "private/common.rkt")

@title[#:tag "data"]{Data Structures}

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
