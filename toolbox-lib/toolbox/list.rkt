#lang racket/base

(require (for-syntax racket/base)
         racket/contract
         syntax/parse/define)

(provide (contract-out
          [take-at-most (-> list? exact-nonnegative-integer? list?)]
          [split-at-most (-> list? exact-nonnegative-integer? (values list? list?))]
          [maybe->list (-> any/c list?)])
         when/list
         unless/list
         when/list*
         unless/list*)

;; -----------------------------------------------------------------------------

(define (take-at-most lst n)
  (for/list ([v (in-list lst)]
             [i (in-range n)])
    v))

(define (split-at-most lst n)
  (let loop ([head '()]
             [tail lst]
             [i 0])
    (cond
      [(null? tail)
       (values lst '())]
      [(>= i n)
       (values (reverse head) tail)]
      [else
       (loop (cons (car tail) head)
             (cdr tail)
             (add1 i))])))

(define (maybe->list v)
  (if v (list v) '()))

(define-syntax-parse-rule (when/list cond-e:expr body ...+)
  (if cond-e (list (let () body ...)) '()))

(define-syntax-parse-rule (unless/list cond-e:expr body ...+)
  (if cond-e '() (list (let () body ...))))

(define-syntax-parse-rule (when/list* cond-e:expr body ...+)
  #:with {~var body-e (expr/c #'list? #:name "body")}
         (syntax/loc this-syntax
           (let () body ...))
  (if cond-e body-e.c '()))

(define-syntax-parse-rule (unless/list* cond-e:expr body ...+)
  #:with {~var body-e (expr/c #'list? #:name "body")}
         (syntax/loc this-syntax
           (let () body ...))
  (if cond-e '() body-e.c))
