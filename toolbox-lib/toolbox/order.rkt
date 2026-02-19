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

          [lexico/o (-> order? ... order?)]
          [list/o (-> order? ... order?)]
          [property/o (->* [(-> any/c any/c)
                            order?]
                           [#:name symbol?
                            #:domain contract?]
                           order?)]))

;; -----------------------------------------------------------------------------

(define (ordering-reverse v)
  (match v
    ['< '>]
    ['= '=]
    ['> '<]))

(define (lexico-ordering a b-thunk)
  (if (eq? a '=) (b-thunk) a))

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

(define/who (lexico/o . os)
  (define comparators (map order-comparator os))
  (order
   who
   (apply and/c (map order-domain-contract os))
   (λ (a b)
     (for/foldr ([continue '=] #:delay-with thunk)
                ([comparator (in-list comparators)])
       (lexico-ordering (comparator a b) continue)))))

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
       (lexico-ordering (comparator a b) continue)))))

(define/who (property/o accessor o
                        #:name [name (if (symbol? (object-name accessor))
                                         (object-name accessor)
                                         who)]
                        #:domain [domain-ctc any/c])
  (define compare (order-comparator o))
  (order
   name
   domain-ctc
   (λ (a b) (compare (accessor a) (accessor b)))))
