#lang scribble/manual

@(require "toolbox/private/common.rkt")

@title{Toolbox: Miscellaneous Utilities}
@author{@author+email["Alexis King" "lexi.lambda@gmail.com"]}

This library provides a collection of miscellaneous Racket utilities that I use in my personal projects but I have not felt warrant being published as a separate package. Note that this library is intentionally @emph{not} published on the Racket package server, as @bold{everything in this library should be considered unstable}. In projects that use it, I include this repository as a Git submodule, pinning to a specific version.

@local-table-of-contents[]

@include-section["toolbox/syntax.scrbl"]
@include-section["toolbox/data.scrbl"]
@include-section["toolbox/logging.scrbl"]

@section[#:tag "format"]{Formatting}
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

@section[#:tag "gregor"]{Gregor}
@defmodule[toolbox/gregor]

@defthing[UTC tz/c #:auto-value]{
The @hyperlink["https://www.iana.org/time-zones"]{IANA timezone identifier} for @hyperlink["https://en.wikipedia.org/wiki/Coordinated_Universal_Time"]{Coordinated Universal Time}.

This binding is actually provided by @racketmodname[gregor] itself, but it is not documented. The @racketmodname[toolbox/gregor] module simply reprovides it.}

@defproc[(posix->moment/utc [v rational?]) moment?]{
Equivalent to @racket[(posix->moment v UTC)].}

@defproc[(jd->moment [v rational?] [tz tz/c (current-timezone)]) moment?]{
Equivalent to @racket[(adjust-timezone (jd->moment/utc v) tz)].}

@defproc[(jd->moment/utc [v rational?]) moment?]{
Equivalent to @racket[(with-timezone (jd->datetime v) UTC)].}
