#lang racket/base

(require (rename-in pict
                    [pin-over pict:pin-over]
                    [pin-under pict:pin-under]
                    [pict-path? tagless-pict-path?])
         ppict/tag
         racket/class
         racket/contract
         racket/draw
         racket/list
         racket/match
         threading
         toolbox/who
         "../color.rkt")

(provide tagless-pict-path?
         (contract-out [pict-finder/c chaperone-contract?]
                       [offset-find (-> pict-finder/c rational? rational? pict-finder/c)]

                       [ppath-cons (-> (or/c pict? symbol?) pict-path? pict-path?)]
                       [ppath-append (-> pict-path? pict-path? pict-path?)]

                       [pict-path? flat-contract?]
                       [find-child (-> pict? pict-path? tagless-pict-path?)]
                       [find-children (-> pict? pict-path? (listof tagless-pict-path?))]

                       [pict-when (->* [any/c pict?] [#:launder? any/c] pict?)]
                       [pict-unless (->* [any/c pict?] [#:launder? any/c] pict?)]

                       [arrowhead (->* [(and/c rational? (not/c negative?))] [rational?] pict?)]
                       [arrow-line (->* [] [#:arrow-size (and/c rational? (not/c negative?))
                                            #:line-length (and/c rational? (not/c negative?))
                                            #:line-width (or/c (and/c rational? (not/c negative?)) #f)]
                                        pict?)]

                       [one-line (-> pict? pict?)]

                       [use-last (-> pict? pict-path? pict?)]
                       [use-last* (-> pict? pict-path? pict?)]

                       [refocus (-> pict? pict-path? pict?)]
                       [refocus* (-> pict? (non-empty-listof pict-path?) pict?)]

                       [recenter (case->
                                  (-> pict? pict-path? pict?)
                                  (-> pict?
                                      (or/c rational? pict-path?)
                                      (or/c rational? pict-finder/c)
                                      pict?))]

                       [set-smoothing (-> pict? (or/c 'unsmoothed 'smoothed 'aligned) pict?)]
                       [set-brush (->* [pict?]
                                       [#:color (or/c color? 'pen #f)
                                        #:style (or/c brush-style/c #f)]
                                       pict?)]
                       [adjust-brush (->* [pict?]
                                          [#:color (or/c color? 'pen #f)
                                           #:style (or/c brush-style/c #f)]
                                          pict?)]
                       [set-pen (->* [pict?]
                                     [#:color (or/c color? #f)
                                      #:width (or/c (real-in 0 255) #f)
                                      #:style (or/c pen-style/c #f)
                                      #:cap (or/c pen-cap-style/c #f)
                                      #:join (or/c pen-join-style/c #f)]
                                     pict?)]
                       [adjust-pen (->* [pict?]
                                        [#:color (or/c color? #f)
                                         #:width (or/c (real-in 0 255) #f)
                                         #:style (or/c pen-style/c #f)
                                         #:cap (or/c pen-cap-style/c #f)
                                         #:join (or/c pen-join-style/c #f)]
                                        pict?)]

                       [pin-over (->* [pict?
                                       (or/c rational? pict-path?)
                                       (or/c rational? pict-finder/c)
                                       pict?]
                                      [#:hole (or/c (vector/c rational? rational?)
                                                    (vector/c pict-path? pict-finder/c)
                                                    pict-finder/c)]
                                      pict?)]
                       [pin-under (->* [pict?
                                        (or/c rational? pict-path?)
                                        (or/c rational? pict-finder/c)
                                        pict?]
                                       [#:hole (or/c (vector/c rational? rational?)
                                                     (vector/c pict-path? pict-finder/c)
                                                     pict-finder/c)]
                                       pict?)]
                       [line-append (-> pict? pict? ... pict?)]))

;; -----------------------------------------------------------------------------
;; miscellany

(define pict-finder/c (-> pict? tagless-pict-path? (values rational? rational?)))

(define ((offset-find find dx dy) p path)
  (define-values [x y] (find p path))
  (values (+ x dx) (+ y dy)))

(define pict-path? (or/c pict? symbol? (listof (or/c pict? symbol?))))

(define (ppath-cons p path)
  (if (list? path)
      (if (empty? path)
          p
          (cons p path))
      (list p path)))

(define (ppath-append path1 path2)
  (cond
    [(empty? path1) path2]
    [(empty? path2) path1]
    [(list? path1)
     (append path1
             (if (list? path2)
                 path2
                 (list path2)))]
    [else
     (if (list? path2)
         (cons path1 path2)
         (list path1 path2))]))

(define (ppath-last path)
  (if (list? path)
      (last path)
      path))

(define (simplify-ppath path)
  (match path
    [(list elem) elem]
    [_           path]))

(define (child-matches-path-elem? child elem)
  (if (pict? elem)
      (equal? child elem)
      (eq? (pict-tag child) elem)))

(define/who (find-child p path #:who [who who])
  (let ([path (if (list? path) path (list path))])
    (let/ec escape
      (let loop ([child p]
                 [parents '()]
                 [path path])
        (match path
          ['() (escape (simplify-ppath (reverse (cons child parents))))]
          [(cons elem path*)
           (if (child-matches-path-elem? child elem)
               (loop child parents path*)
               (for ([child* (in-list (pict-children child))])
                 (loop (child-pict child*) (cons child parents) path)))]))
      (raise-arguments-error who "no sub-pict with the given path"
                             "pict" p
                             "path" path))))

(define (find-children p path)
  (let ([path (if (list? path) path (list path))])
    (let loop ([child p]
               [parents '()]
               [path path])
      (match path
        ['() (list (simplify-ppath (reverse (cons child parents))))]
        [(cons elem path*)
         (if (child-matches-path-elem? child elem)
             (loop child parents path*)
             (append-map
              (λ (child*)
                (loop (child-pict child*) (cons child parents) path))
              (pict-children child)))]))))

;; -----------------------------------------------------------------------------
;; conditionals

(define (pict-when test then #:launder? [launder? #f])
  (if test then (~> (ghost then) (when~> launder? launder))))

(define (pict-unless test then #:launder? [launder? #f])
  (if test (~> (ghost then) (when~> launder? launder)) then))

;; -----------------------------------------------------------------------------
;; constructors

(define (arrowhead size [radians 0])
  (define path (new dc-path%))
  (with-method ([move-to {path move-to}]
                [line-to {path line-to}]
                [close {path close}])
    (move-to  1   0)
    (line-to -1  -1)
    (line-to -1/2 0)
    (line-to -1   1)
    (close))

  ;; Note: By rotating the path but keeping the pict’s bounding box the same,
  ;; some of the path may actually lie outside the bounding box. However, this
  ;; is what `arrowhead` from `pict` does, so we emulate that for now.
  (send path rotate radians)
  (send path translate 1 1)
  (send path scale (/ size 2) (/ size 2))

  (~> (dc (λ (dc x y) (send dc draw-path path x y)) size size)
      (set-pen #:style 'transparent)
      (set-brush #:color 'pen #:style 'solid)))

(define (arrow-line #:arrow-size [arrow-size 10]
                    #:line-length [line-length 50]
                    #:line-width [line-width 2])
  (define head (arrowhead arrow-size))
  (hc-append
   (- (/ (pict-width head) 2))
   (adjust-pen (hline line-length line-width)
               #:width line-width)
   head))

;; -----------------------------------------------------------------------------
;; sizing / bounding box adjusters

(define (one-line p)
  (define ascent (- (pict-height p) (pict-descent p)))
  (pin-over (blank (pict-width p)
                   (pict-height p)
                   ascent
                   (pict-descent p))
            0 0 p))

(define/who (refocus base-p path)
  (define path* (find-child base-p path #:who who))
  (define-values [x1 y1] (lt-find base-p path*))
  (define-values [x2 y2] (rb-find base-p path*))
  (~> (blank (- x2 x1) (- y2 y1))
      (pin-over (- x1) (- y1) base-p)
      (use-last* path*)))

(define/who (refocus* base-p paths)
  (for*/fold ([found-any? #f]
              [x1 +inf.0]
              [y1 +inf.0]
              [x2 -inf.0]
              [y2 -inf.0]
              #:result (if found-any?
                           (~> (blank (- x2 x1) (- y2 y1))
                               (pin-over (- x1) (- y1) base-p))
                           (raise-arguments-error who "no sub-picts with the given paths"
                                                  "pict" base-p
                                                  "paths" paths)))
            ([path (in-list paths)]
             [path* (in-list (find-children base-p path))])
    (define-values [sub-x1 sub-y1] (lt-find base-p path*))
    (define-values [sub-x2 sub-y2] (rb-find base-p path*))
    (values #t
            (min x1 sub-x1)
            (min y1 sub-y1)
            (max x2 sub-x2)
            (max y2 sub-y2))))

(define/who (use-last p path)
  (struct-copy
   pict p
   [children (list (make-child p 0 0 1 1 0 0))]
   [last (find-child p path #:who who)]))

(define/who (use-last* p path)
  (define path* (find-child p path #:who who))
  (define last-path (pict-last (ppath-last path*)))
  (struct-copy
   pict p
   [children (list (make-child p 0 0 1 1 0 0))]
   [last (if last-path
             (ppath-append path* last-path)
             path*)]))


(define/who recenter
  (case-lambda
    [(p x)
     (recenter/path p x cc-find)]
    [(p x y)
     (cond
       [(rational? x)
        (unless (rational? y)
          (raise-argument-error who "rational?" 2 p x y))
        (recenter/coords p x y)]
       [else
        (unless (procedure? y)
          (raise-argument-error who "procedure?" 2 p x y))
        (recenter/path p x y)])]))

(define (recenter/coords p x y)
  (define h-inset (- (* x 2) (pict-width p)))
  (define v-inset (- (* y 2) (pict-height p)))
  (inset p
         (max 0 (- h-inset))
         (max 0 (- v-inset))
         (max 0 h-inset)
         (max 0 v-inset)))

(define/who (recenter/path p path find)
  (define-values [x y] (find p (find-child p path #:who who)))
  (recenter/coords p x y))

;; -----------------------------------------------------------------------------
;; drawing adjusters

(define (dc/wrap p proc)
  (define draw-p (make-pict-drawer p))
  (struct-copy
   pict
   (dc (λ (dc dx dy)
         (proc draw-p dc dx dy))
       (pict-width p)
       (pict-height p)
       (pict-ascent p)
       (pict-descent p))
   [children (list (make-child p 0 0 1 1 0 0))]
   [last (pict-last p)]))

(define (set-smoothing p smoothing)
  (dc/wrap
   p
   (λ (draw-p dc dx dy)
     (define old-smoothing (send dc get-smoothing))
     (send dc set-smoothing smoothing)
     (draw-p dc dx dy)
     (send dc set-smoothing old-smoothing))))

(define (set-brush #:color [color (make-color 0 0 0)]
                   #:style [style 'solid]
                   p)
  (dc/wrap
   p
   (λ (draw-p dc dx dy)
     (define old-brush (send dc get-brush))
     (send dc set-brush (make-brush #:color (match color
                                              [#f   (send old-brush get-color)]
                                              ['pen (send (send dc get-pen) get-color)]
                                              [_    (->color% color)])
                                    #:style (or style (send old-brush get-style))))
     (draw-p dc dx dy)
     (send dc set-brush old-brush))))

(define (adjust-brush #:color [color #f]
                      #:style [style #f]
                      p)
  (dc/wrap
   p
   (λ (draw-p dc dx dy)
     (define old-brush (send dc get-brush))
     (send dc set-brush (make-brush #:color (match color
                                              [#f   (send old-brush get-color)]
                                              ['pen (send (send dc get-pen) get-color)]
                                              [_    (->color% color)])
                                    #:style (or style (send old-brush get-style))
                                    #:stipple (send old-brush get-stipple)
                                    #:gradient (send old-brush get-gradient)
                                    #:transformation (send old-brush get-transformation)))
     (draw-p dc dx dy)
     (send dc set-brush old-brush))))

(define (set-pen #:color [color (make-color 0 0 0)]
                 #:width [width 0]
                 #:style [style 'solid]
                 #:cap [cap 'round]
                 #:join [join 'round]
                 p)
  (dc/wrap
   p
   (λ (draw-p dc dx dy)
     (define old-pen (send dc get-pen))
     (send dc set-pen (make-pen #:color (if color (->color% color) (send old-pen get-color))
                                #:width (or width (send old-pen get-width))
                                #:style (or style (send old-pen get-style))
                                #:cap (or cap (send old-pen get-cap))
                                #:join (or join (send old-pen get-join))))
     (draw-p dc dx dy)
     (send dc set-pen old-pen))))

(define (adjust-pen #:color [color #f]
                    #:width [width #f]
                    #:style [style #f]
                    #:cap [cap #f]
                    #:join [join #f]
                    p)
  (dc/wrap
   p
   (λ (draw-p dc dx dy)
     (define old-pen (send dc get-pen))
     (send dc set-pen (make-pen #:color (if color (->color% color) (send old-pen get-color))
                                #:width (or width (send old-pen get-width))
                                #:style (or style (send old-pen get-style))
                                #:cap (or cap (send old-pen get-cap))
                                #:join (or join (send old-pen get-join))
                                #:stipple (send old-pen get-stipple)))
     (draw-p dc dx dy)
     (send dc set-pen old-pen))))


;; -----------------------------------------------------------------------------
;; combiners

(define (pin base-p arg1 arg2 sub-p
             #:hole [hole #(0 0)]
             #:order [order 'over]
             #:who who)
  (define-values [base-x base-y]
    (if (real? arg1)
        (values arg1 arg2)
        (arg2 base-p (find-child base-p arg1 #:who who))))

  (define-values [sub-x sub-y]
    (match hole
      [(vector (? real? sub-x) sub-y)
       (values sub-x sub-y)]
      [(vector path find)
       (find sub-p (find-child sub-p path #:who who))]
      [find
       (find sub-p sub-p)]))

  ((match order
     ['over  pict:pin-over]
     ['under pict:pin-under])
   base-p (- base-x sub-x) (- base-y sub-y) sub-p))

(define/who (pin-over base-p arg1 arg2 sub-p #:hole [hole #(0 0)])
  (pin base-p arg1 arg2 sub-p #:hole hole #:order 'over #:who who))

(define/who (pin-under base-p arg1 arg2 sub-p #:hole [hole #(0 0)])
  (pin base-p arg1 arg2 sub-p #:hole hole #:order 'under #:who who))

; Combines picts by extending the last line, as determined by pict-last.
(define (line-append p0 . ps)
  (foldl (λ (p2 p1) (line-append/2 p1 p2)) p0 ps))
(define (line-append/2 p1 p2)
  (define draw-p1 (make-pict-drawer p1))
  (define draw-p2 (make-pict-drawer p2))
  ; find the rightmost point on the baseline of (pict-last p1)
  (define-values [last-x last-y] (rbl-find p1 (or (pict-last p1) p1)))

  ; figure out where we’ll place p2 relative to p1, since we want to align the
  ; descent line of (pict-last p1) with the ascent line of p2
  (define p2-y-relative (- last-y (pict-ascent p2)))
  ; if p2-y is negative, that means p2’s ascent peeks out above the top of p1,
  ; so compute how far we need to offset p1/p2 relative to the top of the new pict
  (define p1-y (if (negative? p2-y-relative) (- p2-y-relative) 0))
  (define p2-y (if (negative? p2-y-relative) 0 p2-y-relative))

  ; the x coordinate is simpler, since we don’t have to deal with ascent/descent,
  ; but it’s possible (though unlikely) that last-x is negative, in which case we
  ; want to do a similar adjustment
  (define p1-x (if (negative? last-x) (- last-x) 0))
  (define p2-x (if (negative? last-x) 0 last-x))

  ; compute rightmost point and bottommost point in the new pict’s bounding box
  (define w (max (+ p1-x (pict-width p1))
                 (+ p2-x (pict-width p2))))
  (define h (max (+ p1-y (pict-height p1))
                 (+ p2-y (pict-height p2))))
  ; same for uppermost ascent line and lowermost descent line
  (define a (min (+ p1-y (pict-ascent p1))
                 (+ p2-y (pict-ascent p2))))
  (define d (- h (max (+ p1-y (- (pict-height p1) (pict-descent p1)))
                      (+ p2-y (- (pict-height p2) (pict-descent p2))))))

  ; invent a new, totally unique pict to use as pict-last, in case (pict-last p2)
  ; already exists somewhere in the pict
  (define p2-last (or (ppath-last (pict-last p2)) p2))
  (define-values [p2-last-x p2-last-y] (lt-find p2 (or (pict-last p2) p2)))
  (define last-p (blank (pict-width p2-last)
                        (pict-height p2-last)
                        (pict-ascent p2-last)
                        (pict-descent p2-last)))

  ; compute child offsets, which are weird because pict uses an inverted
  ; coordinate system, so these are relative to the lowermost point
  (define p1-dy (- h (+ p1-y (pict-height p1))))
  (define p2-dy (- h (+ p2-y (pict-height p2))))
  (define p2-last-dy (- h (+ p2-y p2-last-y (pict-height p2-last))))

  (~> (dc (λ (dc dx dy)
            (draw-p1 dc (+ dx p1-x) (+ dy p1-y))
            (draw-p2 dc (+ dx p2-x) (+ dy p2-y)))
          w h a d)
      (struct-copy pict _
                   [children (list (make-child p1 p1-x p1-dy 1 1 0 0)
                                   (make-child p2 p2-x p2-dy 1 1 0 0)
                                   (make-child last-p
                                               (+ p2-x p2-last-x)
                                               p2-last-dy
                                               1 1 0 0))]
                   [last last-p])))
