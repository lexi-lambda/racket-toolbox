#lang racket/base

(require data/order
         racket/contract
         racket/function
         racket/match
         "who.rkt")

(provide (rename-out
          [real-order real/o]
          [datum-order datum/o])
         (contract-out
          [ordering-reverse (-> ordering/c ordering/c)]

          [order-reverse (-> order? order?)]
          [order->? (-> order? (-> any/c any/c ordering/c))]
          [order-<=? (-> order? (-> any/c any/c ordering/c))]
          [order->=? (-> order? (-> any/c any/c ordering/c))]
          [order-<>? (-> order? (-> any/c any/c ordering/c))]

          [list/o (-> order? ... order?)]))

;; -----------------------------------------------------------------------------

(define (ordering-reverse v)
  (match v
    ['< '>]
    ['= '=]
    ['> '<]))

;; -----------------------------------------------------------------------------

(define (order-reverse o)
  (define comparator (order-comparator o))
  (order (string->symbol (format "reversed:~a" (object-name o)))
         (order-domain-contract o)
         (λ (a b) (ordering-reverse (comparator a b)))))

(define (order->? o)
  (define compare (order-comparator o))
  (λ (a b) (eq? (compare a b) '>)))

(define (order-<=? o)
  (define compare (order-comparator o))
  (λ (a b)
    (define v (compare a b))
    (or (eq? v '=) (eq? v '<))))

(define (order->=? o)
  (define compare (order-comparator o))
  (λ (a b)
    (define v (compare a b))
    (or (eq? v '=) (eq? v '>))))

(define (order-<>? o)
  (define compare (order-comparator o))
  (λ (a b)
    (define v (compare a b))
    (or (eq? v '<) (eq? v '>))))

;; -----------------------------------------------------------------------------

(define/who (list/o . elem-os)
  (define num-elems (length elem-os))

  (define (check v)
    (unless (list? v)
      (raise-argument-error who "list?" v))
    (unless (= (length v) num-elems)
      (raise-arguments-error who "list has wrong number of elements"
                             "expected" num-elems
                             "given" (length v)
                             "list" v)))

  (define comparators (map order-comparator elem-os))
  (order
   who
   (apply list/c (map order-domain-contract elem-os))
   (λ (as bs)
     (check as)
     (check bs)
     (for/foldr ([continue '=] #:delay-with thunk)
                ([comparator (in-list comparators)]
                 [a (in-list as)]
                 [b (in-list bs)])
       (match (comparator a b)
         ['= (continue)]
         [result result])))))
