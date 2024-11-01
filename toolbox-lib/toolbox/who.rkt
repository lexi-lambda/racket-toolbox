#lang racket/base

(require (for-syntax racket/base
                     syntax/parse/lib/function-header
                     syntax/transformer)
         racket/splicing
         racket/stxparam
         syntax/parse/define)

(provide who define/who)

(define-syntax-parameter who
  (λ (stx)
    (raise-syntax-error #f "used out of context" stx)))

(define-syntax-parser define/who
  [(_ name:id rhs:expr)
   (syntax/loc this-syntax
     (define name
       (syntax-parameterize ([who (make-variable-like-transformer (quote-syntax 'name))])
         (#%expression rhs))))]
  [(_ header:function-header body ...)
   #`(splicing-syntax-parameterize ([who (make-variable-like-transformer (quote-syntax 'header.name))])
       #,(syntax/loc this-syntax
           (define header body ...)))])
