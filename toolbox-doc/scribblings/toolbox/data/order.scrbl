#lang scribble/manual

@(require "../private/common.rkt")

@(define order-object @datatech[#:key "order"]{order object})
@(define order-objects @datatech[#:key "order"]{order objects})

@title[#:tag "order"]{Orders}
@defmodule[toolbox/order]

@defproc[(ordering-reverse [ord ordering/c]) ordering/c]{
Returns the reverse of @racket[ord].

@(toolbox-examples
  (eval:check (ordering-reverse '<) '>)
  (eval:check (ordering-reverse '=) '=)
  (eval:check (ordering-reverse '>) '<))}

@defproc[(order-reverse [ord order?]) order?]{
Returns an @order-object like @racket[ord], except its comparator is reversed by @racket[ordering-reverse].

@(toolbox-examples
  (define reversed-real/o (order-reverse real/o))
  (eval:check (reversed-real/o 1.0 1) '=)
  (eval:check (reversed-real/o 5 7) '>)
  (eval:check (reversed-real/o 9.0 3.4) '<))}

@deftogether[(@defproc[(order->? [ord order?]) (-> any/c any/c boolean?)]
              @defproc[(order-<=? [ord order?]) (-> any/c any/c boolean?)]
              @defproc[(order->=? [ord order?]) (-> any/c any/c boolean?)]
              @defproc[(order-<>? [ord order?]) (-> any/c any/c boolean?)])]{
Like @racket[order-=?] and @racket[order-<?], but for other (combinations of) operations.}

@deftogether[(@defthing[real/o order?]
              @defthing[datum/o order?])]{
The same bindings as @racket[real-order] and @racket[datum-order] reprovided under different names for consistency.}

@defproc[(list/o [ord order?] ...) order?]{
Returns an @order-object that orders lists lexicographically. The number of elements in the lists must match the number of arguments supplied to @racket[list/o], and each element of the list is ordered according to the corresponding order. In other words, @racket[list/o] is to @order-objects as @racket[list/c] is to @reftech{contracts}.

@(toolbox-examples
  (define up-then-down (list/o real/o (order-reverse real/o)))
  (eval:check (up-then-down '(1 1) '(2 1)) '<)
  (eval:check (up-then-down '(1 1) '(1 2)) '>)
  (eval:check (up-then-down '(1 1) '(2 2)) '<)
  (eval:check (sort (for*/list ([i (in-range 4)]
                                [j (in-range 4)])
                      (list i j))
                    (order-<? up-then-down))
              '((0 3) (0 2) (0 1) (0 0)
                (1 3) (1 2) (1 1) (1 0)
                (2 3) (2 2) (2 1) (2 0)
                (3 3) (3 2) (3 1) (3 0))))}

@defproc[(property/o [accessor (-> any/c any/c)]
                     [ord order?]
                     [#:name name symbol? (if (symbol? (object-name accessor))
                                              (object-name accessor)
                                              'property)]
                     [#:domain domain-ctc contract? any/c])
         order?]{
Returns an @order-object that orders values by applying @racket[accessor] to both arguments, then ordering the results using @racket[ord]. In other words, @racket[property/o] is to @order-objects as @racket[property/c] is to @reftech{contracts}.

@(toolbox-examples
  (define length/o (property/o length real/o #:domain list?))
  (eval:check (length/o '(1 2) '(3)) '>)
  (eval:check (length/o '(1 2) '(3 4)) '=)
  (eval:check (length/o '(1 2) '(3 4 5)) '<))}

@defproc[(lexico/o [ord order?] ...) order?]{
@margin-note{This is similar to @racket[list/o], but all of the given @order-objects are applied to the same values rather than to successive pairs of list elements.}
Returns an @order-object that orders values lexicographically. The given @racket[ord] objects are applied from left to right to each pair of values to be compared, returning the first non-@racket['=] result, or @racket['=] if all @racket[ord] objects return @racket['=].

@(toolbox-examples
  (define length-then-alphabetical
    (lexico/o (property/o string-length real/o) datum/o))
  (eval:check (sort '("the" "quick" "brown" "fox" "jumps" "over" "the" "lazy" "dog")
                    (order-<? length-then-alphabetical))
              '("dog" "fox" "the" "the" "lazy" "over" "brown" "jumps" "quick")))}
