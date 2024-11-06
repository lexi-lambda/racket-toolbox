#lang racket/base

(require racket/class
         racket/contract
         racket/draw
         racket/flonum
         racket/match
         toolbox/who)

(provide (contract-out
          [rgb? predicate/c]
          (rename make-rgb rgb (->* [(real-in 0 1)
                                     (real-in 0 1)
                                     (real-in 0 1)]
                                    [(real-in 0 1)]
                                    rgb?))
          [rgb-red (-> rgb? (real-in 0 1))]
          [rgb-green (-> rgb? (real-in 0 1))]
          [rgb-blue (-> rgb? (real-in 0 1))]
          [rgb-alpha (-> rgb? (real-in 0 1))]

          [hsv (->* [rational?
                     (real-in 0 1)
                     (real-in 0 1)]
                    [(real-in 0 1)]
                    rgb?)]
          [rgb-hue (-> rgb? (and/c (>=/c 0) (</c 1)))]
          [rgb-saturation (-> rgb? (real-in 0 1))]
          [rgb-value (-> rgb? (real-in 0 1))]
          [rgb->hsv (-> rgb? (values (and/c (>=/c 0) (</c 1))
                                     (real-in 0 1)
                                     (real-in 0 1)))]

          [color? predicate/c]
          [->color% (-> color? (is-a?/c color%))]
          [->rgb (-> color? rgb?)]))

;; -----------------------------------------------------------------------------

(define (flmod x n)
  (fl- x (fl* (fltruncate (fl/ x n)) n)))

;; Invariant: All fields are flonums between 0.0 and 1.0.
(struct rgb (red green blue alpha) #:transparent)

(define (make-rgb r g b [alpha 1.0])
  (rgb (real->double-flonum r)
       (real->double-flonum g)
       (real->double-flonum b)
       (real->double-flonum alpha)))

(define (hsv hue sat val [alpha 1.0])
  (define h (real->double-flonum hue))
  (define s (real->double-flonum sat))
  (define v (real->double-flonum val))
  (define a (real->double-flonum alpha))

  (define 6h (fl* h 6.0))
  (define (f n)
    (define k (flmod (fl+ n 6h) 6.0))
    (fl- v (fl* v s (flmax 0.0 (flmin k (fl- 4.0 k) 1.0)))))
  (rgb (f 5.0) (f 3.0) (f 1.0) a))

(define (rgb-hue rgb)
  (define r (rgb-red rgb))
  (define g (rgb-green rgb))
  (define b (rgb-blue rgb))
  (define v (calculate-rgb-value r g b))
  (define c (calculate-rgb-chroma r g b v))
  (calculate-rgb-hue r g b v c))

(define (rgb-saturation rgb)
  (define r (rgb-red rgb))
  (define g (rgb-green rgb))
  (define b (rgb-blue rgb))
  (define v (calculate-rgb-value r g b))
  (define c (calculate-rgb-chroma r g b v))
  (calculuate-rgb-saturation v c))

(define (rgb-value rgb)
  (define r (rgb-red rgb))
  (define g (rgb-green rgb))
  (define b (rgb-blue rgb))
  (calculate-rgb-value r g b))

(define (rgb->hsv rgb)
  (define r (rgb-red rgb))
  (define g (rgb-green rgb))
  (define b (rgb-blue rgb))
  (define v (calculate-rgb-value r g b))
  (define c (calculate-rgb-chroma r g b v))
  (define h (calculate-rgb-hue r g b v c))
  (define s (calculuate-rgb-saturation v c))
  (values h s v))

(define (calculate-rgb-value r g b)
  (flmax r g b))

(define (calculate-rgb-chroma r g b v)
  (fl- v (flmin r g b)))

(define (calculate-rgb-hue r g b v c)
  (cond
    [(fl= c 0.0)
     0.0]
    [(fl= v r)
     (define h (fl/ (fl/ (fl- g b) c) 6.0))
     (if (fl< h 0.0) (fl+ 1.0 h) h)]
    [(fl= v g)
     (fl/ (fl+ 2.0 (fl/ (fl- b r) c)) 6.0)]
    [else
     (fl/ (fl+ 4.0 (fl/ (fl- r g) c)) 6.0)]))

(define (calculuate-rgb-saturation v c)
  (if (fl= c 0.0) 0.0 (fl/ c v)))

;; -----------------------------------------------------------------------------

(define (color%? v)
  (is-a? v color%))

(define (color? v)
  (or (rgb? v)
      (color%? v)
      (and (string? v)
           (send the-color-database find-color v)
           #t)))

(define (find-color% who name)
  (or (send the-color-database find-color name)
      (raise-arguments-error who "no known color with name" "name" name)))

(define/who (->color% v)
  (match v
    [(? color%?) v]
    [(rgb r g b a)
     (define (f n)
       (fl->exact-integer (flround (fl* n 255.0))))
     (make-color (f r) (f g) (f b) a)]
    [(? string?)
     (find-color% who v)]))

(define/who (->rgb v)
  (match v
    [(? rgb?) v]
    [(? color%?)
     (rgb (fl/ (->fl (send v red)) 255.0)
          (fl/ (->fl (send v green)) 255.0)
          (fl/ (->fl (send v blue)) 255.0)
          (real->double-flonum (send v alpha)))]
    [(? string?)
     (->rgb (find-color% who v))]))
