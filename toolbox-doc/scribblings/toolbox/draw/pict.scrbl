#lang scribble/manual

@(begin
   (require scribble/core
            scribble/html-properties
            "../private/common.rkt")

   (define-id-referencer pict pict)
   (define svg-render-style (style #f (list (render-convertible-as '(svg-bytes png-bytes gif-bytes))))))

@title[#:tag "pict" #:style svg-render-style]{Pict}
@defmodule[#:multi [toolbox/pict toolbox/pict/base]]

The @racketmodname[toolbox/pict/base] module exports all of the bindings documented in this section. The @racketmodname[toolbox/pict] module re-exports everything from @racketmodname[pict], @racketmodname[pict/conditional], @racketmodname[ppict/tag], and @racketmodname[toolbox/pict/base], except exports from later modules shadow exports from earlier ones with the same name.

@section[#:tag "pict:constructors"]{Constructors}

@defproc[(arrowhead [size (and/c rational? (not/c negative?))]
                    [radians rational? 0])
         pict?]{
Like @id-from-pict[arrowhead], but only draws a fill, not a stroke (and @racket[radians] is optional).

@(toolbox-examples
  (arrowhead 30))}

@defproc[(arrow-line [#:arrow-size arrow-size (and/c rational? (not/c negative?)) 10]
                     [#:line-length line-length (and/c rational? (not/c negative?)) 50]
                     [#:line-width line-width (or/c (and/c rational? (not/c negative?)) #f) 2])
         pict?]{
Draws a right-facing arrow built from an arrowhead of size @racket[arrow-size] and a tail line of length @racket[line-length] and stroke width @racket[line-width]. If @racket[line-width] is @racket[#f], the current pen width is used.

@(toolbox-examples
  (arrow-line))}

@section[#:tag "pict:combine"]{Combiners}

@defproc*[([(pin-over [base pict?]
                      [dx rational?]
                      [dy rational?]
                      [pict pict?]
                      [#:hole hole
                       (or/c (vector/c rational? rational?)
                             (vector/c pict-path? pict-finder/c)
                             pict-finder/c)
                       #(0 0)])
            pict?]
           [(pin-over [base pict?]
                      [path pict-path?]
                      [find pict-finder/c]
                      [pict pict?]
                      [#:hole hole
                       (or/c (vector/c rational? rational?)
                             (vector/c pict-path? pict-finder/c)
                             pict-finder/c)
                       #(0 0)])
            pict?])]{
Like @id-from-pict[pin-over], but extended to accept the more general @tech{pict paths} instead of @tech{tagless pict paths}. Additionally, the @racket[hole] argument specifies a “pinhole” within @racket[pict] that controls how @racket[pict] is aligned to the pin location:

@itemlist[
 @item{If @racket[hole] is a vector of two @reftech{rational numbers}, the numbers are used as x- and y-coordinates for the pinhole’s location, relative to the top-left corner of @racket[pict].}

 @item{If @racket[hole] is a vector of a @tech{pict path} and a finder procedure, the finder procedure is used to locate a child of @racket[pict], and the resulting coordinates are used as the pinhole.}

 @item{If @racket[hole] is a finder procedure, it is equivalent to supplying the finder procedure with an empty @tech{pict path}.}]

@(toolbox-examples
  (define (bg-rect color)
    (filled-rectangle 30 30
                      #:draw-border? #f
                      #:color color))
  (define bg
    (vc-append (hc-append (bg-rect "light green")
                          (bg-rect "light blue"))
               (hc-append (bg-rect "light blue")
                          (bg-rect "light green"))))
  (define fg
    (disk 15 #:color "crimson"
          #:draw-border? #f))
  (pin-over bg '() cc-find fg)
  (pin-over bg '() cc-find fg #:hole rb-find)
  (pin-over bg '() ct-find fg #:hole ct-find))}

@defproc*[([(pin-under [base pict?]
                       [dx rational?]
                       [dy rational?]
                       [pict pict?]
                       [#:hole hole
                        (or/c (vector/c rational? rational?)
                              (vector/c pict-path? pict-finder/c)
                              pict-finder/c)
                        #(0 0)])
            pict?]
           [(pin-under [base pict?]
                       [path pict-path?]
                       [find pict-finder/c]
                       [pict pict?]
                       [#:hole hole
                        (or/c (vector/c rational? rational?)
                              (vector/c pict-path? pict-finder/c)
                              pict-finder/c)
                        #(0 0)])
            pict?])]{
Like @id-from-pict[pin-under], but extended in the same ways as @racket[pin-over].}

@defproc[(line-append [pict pict?] ...+) pict?]{
Creates a new pict by aligning the descent and ascent lines of each adjacent pair of picts. That is, each @racket[pict] is vertically positioned such that its ascent line (as reported by @racket[pict-ascent]) is aligned with the previous @racket[pict]’s descent line (as reported by @racket[pict-descent]). Each @racket[pict] is horizontally positioned so that it immediately follows the previous @racket[pict]’s last element (as reported by @racket[pict-last]).

The alignment rules used by @racket[line-append] make it useful for aligning multiline blocks, especially code that uses expression-based indentation.

@(toolbox-examples
  (define (tt str)
    (text str 'modern 16))
  (line-append
   (vl-append
    (tt "(define some-example-with-a-long-first-line")
    (tt "  (values "))
   (vl-append
    (tt "(some-expression)")
    (tt "(another-expression)")
    (tt "note-the-close-paren!"))
   (tt ")")))}

@section[#:tag "pict:adjust-draw"]{Drawing Adjusters}

@defproc[(set-smoothing [pict pict?]
                        [smoothing (or/c 'unsmoothed 'smoothed 'aligned)])
         pict?]{
Sets the anti-aliased smoothing mode used when drawing @racket[pict] to @racket[smoothing]. For an explanation of the different modes, see @xmethod[dc<%> set-smoothing].}

@defproc[(set-brush [pict pict?]
                    [#:color color (or/c color? 'pen #f) (make-color 0 0 0)]
                    [#:style style (or/c brush-style/c #f) 'solid])
         pict?]{
Sets the @drawtech{brush} used while drawing @racket[pict]. If any argument is @racket[#f], its value is inherited from whatever brush was installed by the enclosing context.

As a special case, if @racket[color] is @racket['pen], the brush’s color is set to the current @emph{pen} color. This is intended to be used to follow the convention used by pict constructors like @racket[filled-rectangle], which (for some reason) default to using the current pen color rather than the current brush color if no color is provided.

@(toolbox-examples
  (define rect
    (dc (λ (dc x y)
          (send dc draw-rectangle x y 50 30))
        50 30))
  (set-brush rect #:color "red")
  (set-brush rect #:style 'fdiagonal-hatch))}

@defproc[(adjust-brush [pict pict?]
                       [#:color color (or/c color? 'pen #f) #f]
                       [#:style style (or/c brush-style/c #f) #f])
         pict?]{
Like @racket[set-brush], but argument values default to @racket[#f], so any unprovided arguments will be inherited from the current brush.}

@defproc[(set-pen [pict pict?]
                  [#:color color (or/c color? #f) (make-color 0 0 0)]
                  [#:width width (or/c (real-in 0 255) #f) 0]
                  [#:style style (or/c pen-style/c #f) 'solid]
                  [#:cap cap (or/c pen-cap-style/c #f) 'round]
                  [#:join join (or/c pen-join-style/c #f) 'round])
         pict?]{
Sets the pen used while drawing @racket[pict]. If any argument is @racket[#f], its value is inherited from whatever pen was installed by the enclosing context.

Note that many pict constructors, like @racket[filled-rectangle], conventionally default (for some reason) to using the current pen color for the fill rather than the current @drawtech{brush} color if no color is provided. For that reason, using @racket[set-pen] to change the pen color can also affect the fill color of picts created that way.

@(toolbox-examples
  (define rect
    (dc (λ (dc x y)
          (send dc draw-rectangle x y 50 30))
        50 30))
  (set-pen rect #:color "red" #:width 3)
  (set-pen rect #:style 'short-dash #:width 3))}

@defproc[(adjust-pen [pict pict?]
                     [#:color color (or/c color? #f) #f]
                     [#:width width (or/c (real-in 0 255) #f) #f]
                     [#:style style (or/c pen-style/c #f) #f]
                     [#:cap cap (or/c pen-cap-style/c #f) #f]
                     [#:join join (or/c pen-join-style/c #f) #f])
         pict?]{
Like @racket[set-pen], but argument values default to @racket[#f], so any unprovided arguments will be inherited from the current brush.}

@section[#:tag "pict:adjust-bounds"]{Bounding Box Adjusters}

@defproc[(one-line [pict pict?]) pict?]{
Drops the ascent line (as reported by @racket[pict-ascent]) to the descent line, making the entire pict behave as a single line of text.}

@defproc[(refocus [pict pict?] [path pict-path?]) pict?]{
Like @id-from-pict[refocus], but accepts an arbitrary @tech{pict path} to locate the sub-pict to focus on.

@(toolbox-examples
  (define p1 (filled-rectangle 15 30 #:color "sienna"))
  (define p2 (hc-append
              p1
              (filled-rectangle 15 30 #:color "darkkhaki")))
  (define p3 (filled-rectangle 50 50 #:color "khaki"))
  (define combined (cc-superimpose p3 p2))
  combined
  (refocus combined p2)
  (refocus combined (list p2 p1)))}

@defproc[(refocus* [pict pict?] [paths (non-empty-listof pict-path?)]) pict?]{
Like @racket[refocus], but shifts the bounding box to encompass @emph{all} of the picts at the given @racket[paths]. Unlike @racket[refocus], @racket[refocus*] does not set @racket[pict-last].

@(toolbox-examples
  (define p1 (disk 15 #:color "dark sea green"))
  (define p2 (filled-rectangle 15 15 #:color "cadet blue"))
  (define p3 (rotate (filled-rectangle 15 15 #:color "plum") (/ pi 4)))
  (define p4 (vc-append 7 (hc-append 12 p1 p2) p3))
  p4
  (refocus* p4 (list p1 p2))
  (refocus* p4 (list p1 p3))
  (refocus* p4 (list p2 p3)))}

@defproc*[([(recenter [pict pict?] [x rational?] [y rational?]) pict?]
           [(recenter [pict pict?]
                      [path pict-path?]
                      [find pict-finder/c cc-find])
            pict?])]{
Insets @racket[pict] so that the chosen point is its new center. In the first form, the @racket[x] and @racket[y] arguments specify a new center point as a coordinate offset from @racket[pict]’s top-left corner. In the second form, the @racket[find] procedure is used to locate a sub-pict at @racket[path] in the same way as @racket[pin-over], and the result is used as the new center point.

@(toolbox-examples
  (define p1 (filled-rectangle 15 15 #:color "slate blue"))
  (define p2 (disk 15 #:color "firebrick"))
  (define p3 (disk 15 #:color "forest green"))
  (define p2+p3 (hc-append 5 p2 p3))
  (frame (vc-append 5 p1 p2+p3))
  (frame (vc-append 5 p1 (recenter p2+p3 p3))))}

@defproc[(use-last [pict pict?] [path pict-path?]) pict?]{
Like @id-from-pict[use-last], but accepts an arbitrary @tech{pict path} instead of a @tech{tagless pict path}.}

@defproc[(use-last* [pict pict?] [path pict-path?]) pict?]{
Like @id-from-pict[use-last*], but accepts an arbitrary @tech{pict path} instead of a sub-pict.}

@section[#:tag "pict:path-find"]{Paths and Finders}

@defproc[(pict-path? [v any/c]) boolean?]{
Returns @racket[#t] if @racket[v] is a @deftech{pict path}, which is either a @pictech{pict}, a @reftech{symbol}, or a @reftech{list} of picts and symbols. Otherwise, returns @racket[#f].

This definition is broader than the one used by @id-from-pict[pict-path?] (which is provided by this library as @racket[tagless-pict-path?]), as it allows pict path elements to be symbols in addition to picts. When a symbol is an element of a pict path, it refers to all children tagged with that symbol via @racket[tag-pict]. Additionally, an empty list may be used as a pict path, which always refers to the root pict.}

@defproc[(tagless-pict-path? [v any/c]) boolean?]{
Returns @racket[#t] if @racket[v] is a @deftech{tagless pict path}, which is either a @pictech{pict} or a non-empty @reftech{list} of picts. As the name of this function suggests, a tagless pict path is a @tech{pict path} that contains no symbolic tags (though it additionally requires that a list path be non-empty).

The @racket[tagless-pict-path?] function is actually the same binding as @id-from-pict[pict-path?], re-exported under a different name.}

@defproc[(ppath-cons [p (or/c pict? symbol?)] [path pict-path?]) pict-path?]{
Prefixes @racket[path] with @racket[p] to form a larger @tech{pict path}.

@(toolbox-examples
  (eval:check (ppath-cons 'a '()) 'a)
  (eval:check (ppath-cons 'a 'b) '(a b))
  (eval:check (ppath-cons 'a '(b c)) '(a b c)))}

@defproc[(find-child [p pict?] [path pict-path?]) tagless-pict-path?]{
Finds a child @pictech{pict} with the given @tech{pict path} and returns a (possibly more specific) @tech{tagless pict path} to it. If there are multiple child picts with the given path, one is selected arbitrarily. If there are no child picts with the given path, an @racket[exn:fail:contract] exception is raised.}

@defproc[(find-children [p pict?] [path pict-path?]) (listof tagless-pict-path?)]{
Finds all child @pictech{picts} with the given @tech{pict path} and returns a list of (possibly more specific) @tech{tagless pict paths} to them.}

@defproc[(offset-find [find pict-finder/c] [dx rational?] [dy rational?]) pict-finder/c]{
Returns a @tech{pict finder} like @racket[find], except the returned x- and y-coordinates are offset by @racket[dx] and @racket[dy], respectively.}

@defthing[pict-finder/c chaperone-contract?
          #:value (-> pict? tagless-pict-path? (values rational? rational?))]{
A contract that accepts @deftech{pict finder} procedures like @racket[lt-find]. See also @secref["Pict_Finders" #:doc '(lib "pict/scribblings/pict.scrbl")] in the @racketmodname[pict] documentation.}

@section[#:tag "pict:cond"]{Conditional Picts}

@defproc[(pict-when [show? any/c]
                    [p pict?]
                    [#:launder? launder? any/c #f])
         pict?]{
Like @racket[(show p show?)], except if @racket[show?] is @racket[#f] and @racket[launder?] is not @racket[#f], @racket[launder] is additionally applied to the result.}

@defproc[(pict-unless [hide? any/c]
                      [p pict?]
                      [#:launder? launder? any/c #f])
         pict?]{
Like @racket[(hide p hide?)], except that if @racket[hide?] and @racket[launder?] are both not @racket[#f], @racket[launder] is additionally applied to the result.}
