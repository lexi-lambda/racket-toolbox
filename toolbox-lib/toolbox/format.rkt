#lang racket/base

(require racket/format)

(provide ~r*)

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
