#lang racket/base

(require (for-syntax racket/base
                     syntax/kerncase)
         syntax/parse/define)

(provide printing-block)

(define-syntax-parser printing-block
  [(_ form ...+)
   (cond
     [(eq? (syntax-local-context) 'expression)
      (syntax/loc this-syntax
        (let ()
          (do-printing-block form) ...))]
     [else
      #`(#%expression #,this-syntax)])])

(define-syntax-parser do-printing-block
  [(_ form)
   (syntax-parse (local-expand #'form
                               (syntax-local-context)
                               (kernel-form-identifier-list))
     #:literal-sets [kernel-literals]
     [(begin form ...)
      #'(begin (do-printing-block form) ...)]
     [({~or* define-values define-syntaxes} . _)
      this-syntax]
     [expr
      (syntax/loc this-syntax
        (call-with-values (λ () expr) print-values))])])

(define (print-values . vs)
  (for-each (current-print) vs)
  (apply values vs))
