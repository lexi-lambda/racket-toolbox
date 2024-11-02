#lang racket/base

(require db/base
         (prefix-in db: db/base)
         racket/contract
         racket/match
         toolbox/logging
         toolbox/who
         toolbox/private/logger)

(provide (logger-out toolbox:db)
         define-toolbox:db-logger
         (contract-out
          [current-db (parameter/c (or/c connection? #f))]
          [get-db (->* [symbol?] connection?)]

          [exn:fail:sql:busy? predicate/c]
          [exn:fail:sql:constraint? predicate/c]

          [in-transaction? (->* [] [#:db connection?] boolean?)]
          [call-with-transaction
           (->* [(-> any)]
                [#:db connection?
                 #:isolation (or/c transaction-isolation/c #f)
                 #:option any/c
                 #:nested transaction-nested/c]
                any)]
          [current-max-transaction-retries (parameter/c (or/c exact-nonnegative-integer? +inf.0))]
          [current-transaction-retry-delay (parameter/c (>=/c 0))]
          [call-with-transaction/retry
           (->* [(-> any)]
                [#:db connection?
                 #:isolation (or/c transaction-isolation/c #f)
                 #:option any/c
                 #:nested transaction-nested/c
                 #:max-retries (or/c exact-nonnegative-integer? +inf.0)
                 #:retry-delay (>=/c 0)]
                any)]))

;; -----------------------------------------------------------------------------

(define-toolbox-logger toolbox:db)

(define current-db (make-parameter #f))

(define/who (get-db [who who])
  (or (current-db)
      (raise-arguments-error who "no current db")))

;; -----------------------------------------------------------------------------

(define ((make-exn:fail:sql-pred sqlstate) exn)
  (and (exn:fail:sql? exn)
       (eq? (exn:fail:sql-sqlstate exn) sqlstate)))

(define exn:fail:sql:busy? (make-exn:fail:sql-pred 'busy))
(define exn:fail:sql:constraint? (make-exn:fail:sql-pred 'constraint))

;; -----------------------------------------------------------------------------

(define/who (in-transaction? #:db [db (get-db who)])
  (db:in-transaction? db))

(define current-max-transaction-retries (make-parameter 10))
(define current-transaction-retry-delay (make-parameter 0.1))

(define transaction-isolation/c (or/c 'serializable
                                      'repeatable-read
                                      'read-committed
                                      'read-uncommitted))

(define transaction-nested/c (or/c 'allow 'omit 'fail))

(define/who (call-with-transaction proc
                                   #:db [db (get-db who)]
                                   #:isolation [isolation #f]
                                   #:option [option #f]
                                   #:nested [nested 'omit])
  (call-with-transaction/retry proc
                               #:who who
                               #:db db
                               #:isolation isolation
                               #:option option
                               #:nested nested
                               #:max-retries 0
                               #:retry-delay 0))

(define/who (call-with-transaction/retry thunk
                                         #:who [who who]
                                         #:db [db (get-db who)]
                                         #:isolation [isolation #f]
                                         #:option [option #f]
                                         #:nested [nested 'omit]
                                         #:max-retries [max-retries (current-max-transaction-retries)]
                                         #:retry-delay [retry-delay (current-transaction-retry-delay)])
  (if (in-transaction? #:db db)
      (match nested
        ['allow (db:call-with-transaction db thunk)]
        ['omit  (thunk)]
        ['fail  (raise-arguments-error who "already in transaction")])
      (let retry ([retries-left max-retries]
                  [option option])
        (if (<= retries-left 0)
            (db:call-with-transaction db thunk #:isolation isolation #:option option)
            (with-handlers* ([exn:fail:sql:busy?
                              (λ (exn)
                                (sleep retry-delay)
                                (retry (sub1 retries-left)
                                       (match option
                                         ['deferred 'immediate]
                                         [_         option])))])
              (db:call-with-transaction db thunk #:isolation isolation #:option option))))))
