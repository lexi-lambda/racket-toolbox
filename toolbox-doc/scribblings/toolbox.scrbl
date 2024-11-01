#lang scribble/manual

@title{Toolbox: Miscellaneous Utilities}
@author{@author+email["Alexis King" "lexi.lambda@gmail.com"]}

This library provides a collection of miscellaneous Racket utilities that I use in my personal projects but I have not felt warrant being published as a separate package. Note that this library is intentionally @emph{not} published on the Racket package server, as @bold{everything in this library should be considered unstable}. In projects that use it, I include this repository as a Git submodule, pinning to a specific version.

@local-table-of-contents[]

@include-section["toolbox/syntax.scrbl"]
@include-section["toolbox/logging.scrbl"]
