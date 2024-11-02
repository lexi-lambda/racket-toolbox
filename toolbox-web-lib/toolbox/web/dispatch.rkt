#lang racket/base

(require (for-syntax racket/base
                     racket/stxparam-exptime
                     racket/syntax)
         racket/contract
         racket/match
         syntax/parse/define
         web-server/dispatch/extend)

(provide define-enum-bidi-match-expander)

(define ((in-pred strs) v)
  (and (string? v) (member v strs string=?) #t))
(define ((out-pred syms) v)
  (and (symbol? v) (memq v syms) #t))

(begin-for-syntax
  (define (enum-arg-match-expander-transformer syms-id strs-id)
    (syntax-parser
      [(_ x:id)
       (if (syntax-parameter-value #'bidi-match-going-in?)
           #`(? (in-pred #,strs-id) (app string->symbol x))
           #`(? (out-pred #,syms-id) (app symbol->string x)))])))

(define-syntax-parser define-enum-bidi-match-expander
  [(_ x:id syms)
   #:declare syms (expr/c #'(listof symbol?))
   #:with syms-id (generate-temporary #'x)
   #:with strs-id (generate-temporary #'x)
   #'(begin
       (define syms-id syms.c)
       (define strs-id (map symbol->string syms-id))
       (define-match-expander x
         (enum-arg-match-expander-transformer #'syms-id #'strs-id)))])
