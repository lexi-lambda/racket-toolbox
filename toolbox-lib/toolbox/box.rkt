#lang racket/base

(require racket/contract)

(provide (contract-out
          [box-cas-update! (-> cas-box/c (-> any/c any/c) any/c)]
          [box-cas-update!* (-> cas-box/c (-> any/c (values any/c any/c)) any/c)]
          [box-add1! (-> cas-box/c number?)]
          [box-sub1! (-> cas-box/c number?)]))

;; -----------------------------------------------------------------------------

(define cas-box/c (and/c box? (not/c immutable?) (not/c impersonator?)))

(define (box-cas-update!* b f)
  (let retry ()
    (define old (unbox b))
    (define-values [result new] (f old))
    (if (box-cas! b old new)
        result
        (retry))))

(define (box-cas-update! b f)
  (box-cas-update!* b (λ (old)
                        (define new (f old))
                        (values new new))))

(define (box-add1! b)
  (box-cas-update! b add1))
(define (box-sub1! b)
  (box-cas-update! b sub1))
