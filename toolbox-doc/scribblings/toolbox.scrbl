#lang scribble/manual

@(require "toolbox/private/common.rkt")

@title{Toolbox: Miscellaneous Utilities}
@author{@author+email["Alexis King" "lexi.lambda@gmail.com"]}

This library provides a collection of miscellaneous Racket utilities that I use in my personal projects but I have not felt warrant being published as a separate package. Note that this library is intentionally @emph{not} published on the Racket package server, as @bold{everything in this library should be considered unstable}. In projects that use it, I include this repository as a Git submodule, pinning to a specific version.

@local-table-of-contents[]

@include-section["toolbox/syntax.scrbl"]
@include-section["toolbox/data.scrbl"]
@include-section["toolbox/logging.scrbl"]

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
