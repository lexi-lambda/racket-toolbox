#lang racket/base

(require racket/contract
         racket/format
         racket/match)

(provide ~r*
         (contract-out
          [ordinal (->* [exact-nonnegative-integer?]
                        [#:word? any/c]
                        string?)]))

;; -----------------------------------------------------------------------------

(define (~r* n
             #:sign [sign #f]
             #:base [base 10]
             #:precision [precision 6]
             #:notation [notation 'positional]
             #:format-exponent [format-exponent #f]
             #:min-width [min-width 1]
             #:pad-string [pad-string " "]
             #:groups [groups '(3)]
             #:group-sep [group-sep ","]
             #:decimal-sep [decimal-sep "."])
  (~r n
      #:sign sign
      #:base base
      #:precision precision
      #:notation notation
      #:format-exponent format-exponent
      #:min-width min-width
      #:pad-string pad-string
      #:groups groups
      #:group-sep group-sep
      #:decimal-sep decimal-sep))

(define (ordinal n #:word? [use-word? #f])
  (cond
    [(and use-word? (<= 1 n 10))
     (vector-ref #("first"
                   "second"
                   "third"
                   "fourth"
                   "fifth"
                   "sixth"
                   "seventh"
                   "eighth"
                   "ninth"
                   "tenth")
                 (sub1 n))]
    [else
     (string-append
      (~r* n)
      (match (remainder n 100)
        [(or 11 12 13) "th"]
        [_ (match (remainder n 10)
             [1 "st"]
             [2 "nd"]
             [3 "rd"]
             [_ "th"])]))]))
