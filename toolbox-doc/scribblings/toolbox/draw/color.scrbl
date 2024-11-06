#lang scribble/manual

@(require "../private/common.rkt")

@(define (HSV-coordinates)
   @hyperlink["https://en.wikipedia.org/wiki/HSL_and_HSV"]{HSV coordinates})

@title[#:tag "color"]{Color}
@defmodule[toolbox/color]

This module provides structures and functions useful when working with colors.

Note that, technically, none of the structures provided by this module (or the ones provided by @racketmodname[racket/draw]) represent @emph{colors}, only @emph{color coordinates}. The specific color referred to by a given set of color coordinates depends on the @hyperlink["https://en.wikipedia.org/wiki/Color_space"]{color space} they are interpreted in.

@defproc[(rgb [red (real-in 0 1)]
              [green (real-in 0 1)]
              [blue (real-in 0 1)]
              [alpha (real-in 0 1) 1.0])
         rgb?]{
Constructs an @deftech{RGB color} from the given components.

@(toolbox-examples
  (rgb 1 0 1 0.5))}

@defproc[(hsv [hue rational?]
              [saturation (real-in 0 1)]
              [value (real-in 0 1)]
              [alpha (real-in 0 1) 1.0])
         rgb?]{
Constructs an @tech{RGB color} from the given @HSV-coordinates[]. The @racket[hue] component represents an angle, where @racket[0.0] is interpreted as 0° and @racket[1.0] is interpreted as 360°. The value of @racket[hue] may be any @reftech{rational number}, and it will be interpreted modulo 1.

@(toolbox-examples
  (eval:check (hsv 0 1 1) (rgb 1 0 0))
  (hsv 1/3 1 1)
  (hsv 2/3 1 1)
  (hsv 1/6 1 0.5))}

@defproc[(rgb? [v any/c]) boolean?]{
Returns @racket[#t] if @racket[v] is an @tech{RGB color} constructed with @racket[rgb] or @racket[hsv], otherwise returns @racket[#f].}

@defproc[(rgb-red [c rgb?]) (real-in 0 1)]{
Returns the red component of an @tech{RGB color}.}

@defproc[(rgb-green [c rgb?]) (real-in 0 1)]{
Returns the green component of an @tech{RGB color}.}

@defproc[(rgb-blue [c rgb?]) (real-in 0 1)]{
Returns the blue component of an @tech{RGB color}.}

@defproc[(rgb-alpha [c rgb?]) (real-in 0 1)]{
Returns the alpha component of an @tech{RGB color}.}

@defproc[(rgb-hue [c rgb?]) (and/c (>=/c 0) (</c 1))]{
Returns the hue component of the @HSV-coordinates[] for the given @tech{RGB color}.}

@defproc[(rgb-saturation [c rgb?]) (real-in 0 1)]{
Returns the saturation component of the @HSV-coordinates[] for the given @tech{RGB color}.}

@defproc[(rgb-value [c rgb?]) (real-in 0 1)]{
Returns the value component of the @HSV-coordinates[] for the given @tech{RGB color}.}

@defproc[(rgb->hsv [c rgb?])
         (values (and/c (>=/c 0) (</c 1))
                 (real-in 0 1)
                 (real-in 0 1))]{
Equivalent to @racket[(values (rgb-hue v) (rgb-saturation v) (rgb-value v))], except that @racket[rgb->hsv] can be more efficient.}

@defproc[(color? [v any/c]) boolean?]{
Returns @racket[#t] if @racket[#f] is an @tech{RGB color}, a @racket[color%] object, or a @reftech{string} corresponding to a color name in @racket[the-color-database].}

@defproc[(->rgb [c color?]) rgb?]{
Returns an @tech{RGB color} that represents the same color as @racket[c].}

@defproc[(->color% [c color?]) (is-a?/c color%)]{
Returns an immutable @racket[color%] object that represents the same color as @racket[c].}
