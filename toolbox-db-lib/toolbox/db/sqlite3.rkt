#lang racket/base

(require gregor
         racket/contract
         racket/match
         "private/sqlite3/ffi.rkt")

(provide (contract-out
          [sqlite3-stmt-scanstatus-enabled? (-> boolean?)]

          [boolean->integer (-> any/c (or/c 0 1))]
          [integer->boolean (-> (or/c 0 1) boolean?)]

          [->posix/integer (-> datetime-provider? exact-integer?)]
          [->jd/double (-> datetime-provider? (and/c rational? flonum?))]))

;; -----------------------------------------------------------------------------

(define (boolean->integer v)
  (if v 1 0))

(define (integer->boolean v)
  (match v [0 #f] [1 #t]))

(define (->posix/integer v)
  (floor (->posix v)))

(define (->jd/double v)
  (real->double-flonum (->jd v)))
