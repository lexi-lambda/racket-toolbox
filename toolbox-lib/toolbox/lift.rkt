#lang racket/base

(require (for-syntax racket/base
                     syntax/parse
                     syntax/transformer))

(provide #%lift)

(define-syntax #%lift
  (make-expression-transformer
   (syntax-parser
     [(_ e:expr)
      (syntax-local-lift-expression
       ;; Force expansion to work around racket/racket#4614.
       (local-expand #'e 'expression '()))])))
