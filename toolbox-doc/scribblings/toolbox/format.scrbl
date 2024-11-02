#lang scribble/manual

@(require "private/common.rkt")

@title[#:tag "format"]{Formatting}
@defmodule[toolbox/format]

@defproc[(~r* [x rational?]
              [#:sign sign
               (or/c #f '+ '++ 'parens
                     (let ([ind (or/c string? (list/c string? string?))])
                       (list/c ind ind ind)))
               #f]
              [#:base base (or/c (integer-in 2 36) (list/c 'up (integer-in 2 36))) 10]
              [#:precision precision
               (or/c exact-nonnegative-integer?
                     (list/c '= exact-nonnegative-integer?))
               6]
              [#:notation notation
               (or/c 'positional 'exponential
                     (-> rational? (or/c 'positional 'exponential)))
               'positional]
              [#:format-exponent format-exponent (or/c #f string? (-> exact-integer? string?)) #f]
              [#:min-width min-width exact-positive-integer? 1]
              [#:pad-string pad-string non-empty-string? " "]
              [#:groups groups (non-empty-listof exact-positive-integer?) '(3)]
              [#:group-sep group-sep string? ","]
              [#:decimal-sep decimal-sep string? "."])
         string?]{
Like @racket[~r] from @racketmodname[racket/format], except that the default value of @racket[group-sep] is @racket[","] instead of @racket[""], so numbers include thousands separators by default.}

@defproc[(ordinal [n exact-nonnegative-integer?]
                  [#:word? use-word? any/c #f])
         string?]{
Returns an @hyperlink["https://en.wikipedia.org/wiki/Ordinal_numeral"]{ordinal numeral} for @racket[n].

@(toolbox-examples
  (eval:check (ordinal 1) "1st")
  (eval:check (ordinal 2) "2nd")
  (eval:check (ordinal 23) "23rd"))

If @racket[use-word?] is not @racket[#f], then a word will be returned instead of a numeral with a suffix if @racket[n] is between @racket[1] and @racket[10], inclusive.

@(toolbox-examples
  (eval:check (ordinal 1 #:word? #t) "first")
  (eval:check (ordinal 2 #:word? #t) "second")
  (eval:check (ordinal 10 #:word? #t) "tenth")
  (eval:check (ordinal 11 #:word? #t) "11th"))}
