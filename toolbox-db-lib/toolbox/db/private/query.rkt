#lang racket/base

(require (for-syntax racket/base
                     syntax/parse)
         racket/require
         (subtract-in db/base "base.rkt")
         (prefix-in db: db/base)
         (only-in db/private/generic/functions2 [in-query-helper db:in-query-helper])
         racket/class
         racket/contract
         racket/match
         racket/string
         toolbox/format
         toolbox/who
         "base.rkt"
         "sqlite3/explain.rkt"
         "sqlite3/ffi.rkt")

(provide (contract-out
          [current-log-db-queries? (parameter/c any/c boolean?)]
          [current-explain-db-queries? (parameter/c any/c boolean?)]
          [current-analyze-db-queries? (parameter/c any/c boolean?)]

          [query (query-func/c (or/c simple-result? rows-result?))]
          [query-exec (query-func/c void?)]
          [query-rows (->* [(or/c string? virtual-statement? prepared-statement?)]
                           [#:db connection?
                            #:group groupings/c
                            #:group-mode group-mode/c
                            #:log? any/c
                            #:explain? any/c
                            #:analyze? any/c]
                           #:rest any/c
                           (listof vector?))]
          [query-list (query-func/c list?)]
          [query-row (query-func/c vector?)]
          [query-maybe-row (query-func/c (or/c vector? #f))]
          [query-value (query-func/c any/c)]
          [query-maybe-value (query-func/c any/c)]

          [query-changes (->* [] [#:db connection?] exact-nonnegative-integer?)])

         (rename-out
          [in-query* in-query]))

;; -----------------------------------------------------------------------------

(define-toolbox:db-logger toolbox:db:query)

;; -----------------------------------------------------------------------------

(define current-log-db-queries? (make-parameter #f (λ (v) (and v #t))))
(define current-explain-db-queries? (make-parameter #f (λ (v) (and v #t))))
(define current-analyze-db-queries? (make-parameter #f (λ (v) (and v #t))))

(define (query-func/c result/c)
  (->* [(or/c string? virtual-statement? prepared-statement?)]
       [#:db connection?
        #:log? any/c
        #:explain? any/c
        #:analyze? any/c]
       #:rest any/c
       result/c))

(define field/c (or/c string? exact-nonnegative-integer?))
(define grouping/c (or/c field/c (vectorof field/c)))
(define groupings/c (or/c grouping/c (listof grouping/c)))
(define group-mode/c (listof (or/c 'preserve-null 'list)))
(define fetch-size/c (or/c exact-positive-integer? +inf.0))

(define (do-query stmt query-proc
                  #:who who
                  #:db db
                  #:log? log?
                  #:explain? explain?
                  #:analyze? analyze?)

  (define p-stmt (if (prepared-statement? stmt)
                     stmt
                     (db:prepare db stmt)))

  (define (maybe-log-query)
    (when log?
      (define sql (send p-stmt get-stmt))
      (if (string-contains? sql "\n")
          (log-toolbox:db:query-info "\n~a" sql)
          (log-toolbox:db:query-info "~a" sql))))

  (define (really-do-query)
    (cond
      [log?
       (define pre-ms (current-inexact-monotonic-milliseconds))
       (define result (query-proc p-stmt))
       (define post-ms (current-inexact-monotonic-milliseconds))
       (log-toolbox:db:query-info "~a ms" (~r* (- post-ms pre-ms) #:precision 1))
       result]
      [else
       (query-proc p-stmt)]))

  (match (dbsystem-name (connection-dbsystem db))
    ['sqlite3
     (when analyze?
       (check-sqlite3-stmt-scanstatus-enabled who "cannot analyze query"))
     (define ffi-stmt
       (and (or explain? analyze?)
            (let ()
              (define ffi-stmt (send p-stmt get-handle))
              (unless (sqlite3_statement? ffi-stmt)
                (error who "failed to obtain sqlite3 statement handle\n  handle: ~e" ffi-stmt))
              ffi-stmt)))

     (maybe-log-query)

     (define (log-query-plan-explanation root-node)
       (define out (open-output-string))
       (print-query-plan-explanation root-node out)
       (log-toolbox:db:query-info "~a" (string-trim (get-output-string out))))

     (cond
       [(or analyze? (and explain? (sqlite3-stmt-scanstatus-enabled?)))
        (sqlite3_stmt_scanstatus_reset ffi-stmt)
        ;; Use scanstatus for ordinary `explain?` when available, since it includes estimates.
        (when explain?
          (log-query-plan-explanation
           (build-query-plan-explanation/scan-status ffi-stmt)))]
       [explain?
        ;; Fall back to running an EXPLAIN QUERY PLAN query if scanstatus is not available.
        (cond
          ;; Try to use `sqlite3_stmt_explain` to avoid a re-prepare if possible.
          [sqlite3_stmt_explain
           (when (= (sqlite3_stmt_isexplain ffi-stmt) SQLITE_EXPLAIN_NORMAL)
             (define eqp-rows
               (dynamic-wind
                (λ ()
                  (sqlite3_reset ffi-stmt)
                  (sqlite3_stmt_explain ffi-stmt SQLITE_EXPLAIN_QUERY_PLAN))
                (λ ()
                  (db:query-rows db p-stmt))
                (λ ()
                  (sqlite3_reset ffi-stmt)
                  (sqlite3_stmt_explain ffi-stmt SQLITE_EXPLAIN_NORMAL))))
             (log-query-plan-explanation
              (build-query-plan-explanation eqp-rows)))]
          ;; Otherwise, just re-prepare the query.
          [else
           (log-query-plan-explanation
            (build-query-plan-explanation
             (db:query-rows db (string-append "EXPLAIN QUERY PLAN\n" (send p-stmt get-stmt)))))])])

     (define result (really-do-query))

     (when analyze?
       (log-query-plan-explanation
        (build-query-plan-explanation/scan-status ffi-stmt)))

     result]
    [sys-name
     (when explain?
       (raise (exn:fail:unsupported
               (format "~a: cannot explain query; unsupported dbsystem\n  dbsystem: ~e" who sys-name)
               (current-continuation-marks))))
     (when analyze?
       (raise (exn:fail:unsupported
               (format "~a: cannot analyze query; unsupported dbsystem\n  dbsystem: ~e" who sys-name)
               (current-continuation-marks))))
     (maybe-log-query)
     (really-do-query)]))

(define/who (query stmt
                   #:db [db (get-db who)]
                   #:log? [log? (current-log-db-queries?)]
                   #:explain? [explain? (current-explain-db-queries?)]
                   #:analyze? [analyze? (current-analyze-db-queries?)]
                   . args)
  (do-query
   #:who who
   #:db db
   #:log? log?
   #:explain? explain?
   #:analyze? analyze?
   stmt (λ (stmt) (apply db:query db stmt args))))

(define/who (query-exec stmt
                        #:db [db (get-db who)]
                        #:log? [log? (current-log-db-queries?)]
                        #:explain? [explain? (current-explain-db-queries?)]
                        #:analyze? [analyze? (current-analyze-db-queries?)]
                        . args)
  (do-query
   #:who who
   #:db db
   #:log? log?
   #:explain? explain?
   #:analyze? analyze?
   stmt (λ (stmt) (apply db:query-exec db stmt args))))

(define/who (query-rows stmt
                        #:db [db (get-db who)]
                        #:group [groupings '()]
                        #:group-mode [group-mode '()]
                        #:log? [log? (current-log-db-queries?)]
                        #:explain? [explain? (current-explain-db-queries?)]
                        #:analyze? [analyze? (current-analyze-db-queries?)]
                        . args)
  (do-query
   #:who who
   #:db db
   #:log? log?
   #:explain? explain?
   #:analyze? analyze?
   stmt (λ (stmt) (apply db:query-rows db stmt args
                         #:group groupings
                         #:group-mode group-mode))))

(define/who (query-list stmt
                        #:db [db (get-db who)]
                        #:log? [log? (current-log-db-queries?)]
                        #:explain? [explain? (current-explain-db-queries?)]
                        #:analyze? [analyze? (current-analyze-db-queries?)]
                        . args)
  (do-query
   #:who who
   #:db db
   #:log? log?
   #:explain? explain?
   #:analyze? analyze?
   stmt (λ (stmt) (apply db:query-list db stmt args))))

(define/who (query-row stmt
                       #:db [db (get-db who)]
                       #:log? [log? (current-log-db-queries?)]
                       #:explain? [explain? (current-explain-db-queries?)]
                       #:analyze? [analyze? (current-analyze-db-queries?)]
                       . args)
  (do-query
   #:who who
   #:db db
   #:log? log?
   #:explain? explain?
   #:analyze? analyze?
   stmt (λ (stmt) (apply db:query-row db stmt args))))

(define/who (query-maybe-row stmt
                             #:db [db (get-db who)]
                             #:log? [log? (current-log-db-queries?)]
                             #:explain? [explain? (current-explain-db-queries?)]
                             #:analyze? [analyze? (current-analyze-db-queries?)]
                             . args)
  (do-query
   #:who who
   #:db db
   #:log? log?
   #:explain? explain?
   #:analyze? analyze?
   stmt (λ (stmt) (apply db:query-maybe-row db stmt args))))

(define/who (query-value stmt
                         #:db [db (get-db who)]
                         #:log? [log? (current-log-db-queries?)]
                         #:explain? [explain? (current-explain-db-queries?)]
                         #:analyze? [analyze? (current-analyze-db-queries?)]
                         . args)
  (do-query
   #:who who
   #:db db
   #:log? log?
   #:explain? explain?
   #:analyze? analyze?
   stmt (λ (stmt) (apply db:query-value db stmt args))))

(define/who (query-maybe-value stmt
                               #:db [db (get-db who)]
                               #:log? [log? (current-log-db-queries?)]
                               #:explain? [explain? (current-explain-db-queries?)]
                               #:analyze? [analyze? (current-analyze-db-queries?)]
                               . args)
  (do-query
   #:who who
   #:db db
   #:log? log?
   #:explain? explain?
   #:analyze? analyze?
   stmt (λ (stmt) (apply db:query-maybe-value db stmt args))))

(define (in-query-helper stmt
                         #:result-arity [expected-result-arity #f]
                         #:db [db (get-db 'in-query)]
                         #:fetch [fetch-size +inf.0]
                         #:group [groupings '()]
                         #:group-mode [group-mode '()]
                         #:log? [log? (current-log-db-queries?)]
                         #:explain? [explain? (current-explain-db-queries?)]
                         #:analyze? [analyze? (current-analyze-db-queries?)]
                         . args)
  (do-query
   #:who 'in-query
   #:db db
   #:log? log?
   #:explain? explain?
   #:analyze? analyze?
   stmt (λ (stmt) (apply db:in-query-helper expected-result-arity db stmt args
                         #:fetch fetch-size
                         #:group groupings
                         #:group-mode group-mode))))

(define-module-boundary-contract in-query in-query-helper
  (->* [connection? statement?]
       [#:db connection?
        #:fetch fetch-size/c
        #:group groupings/c
        #:group-mode group-mode/c
        #:log? any/c
        #:explain? any/c
        #:analyze? any/c]
       #:rest list?
       sequence?)
  #:name-for-blame in-query
  #:name-for-contract in-query)

;; This is mostly copied from its definition in `db/base` because
;; `in-query-helper` is unfortunately a private API.
(define-sequence-syntax in-query*
  (λ () #'in-query)
  (syntax-parser
    [[(var ...) {~and form
                      (_ {~alt {~optional {~seq #:db db}}
                               {~optional {~seq #:fetch fetch-size}}
                               {~optional {~seq #:group groupings}}
                               {~optional {~seq #:group-mode group-mode}}
                               {~optional {~seq #:log? log?:expr}}
                               {~optional {~seq #:explain? explain?:expr}}
                               {~optional {~seq #:analyze? analyze?:expr}}
                               {~between arg:expr 1 +inf.0}}
                         ...)}]
     #:declare db (expr/c #'connection? #:context #'form) #:role "connection argument"
     #:declare fetch-size (expr/c #'fetch-size/c #:context #'form) #:role "fetch size argument"
     #:declare groupings (expr/c #'groupings/c #:context #'form) #:role "grouping fields argument"
     #:declare group-mode (expr/c #'group-mode/c #:context #'form) #:role "group mode argument"
     #:with [stmt q-arg ...] #'[arg ...]
     #:declare stmt (expr/c #'statement? #:context #'form) #:role "statement argument"
     #`[(var ...)
        #,(quasisyntax/loc #'form
            (in-query-helper stmt.c q-arg ...
                             #:result-arity #,(length (attribute var))
                             {~? {~@ #:db db.c}}
                             {~? {~@ #:fetch fetch-size.c}}
                             {~? {~@ #:group groupings.c}}
                             {~? {~@ #:group-mode group-mode.c}}
                             {~? {~@ #:log? log?}}
                             {~? {~@ #:explain? explain?}}
                             {~? {~@ #:analyze? analyze?}}))]]
    [_ #f]))

;; -----------------------------------------------------------------------------

(define/who (query-changes #:db [db (get-db who)])
  (match (dbsystem-name (connection-dbsystem db))
    ['sqlite3
     (db:query-value db "SELECT changes()")]
    [sys-name
     (raise (exn:fail:unsupported
             (format "~a: unsupported dbsystem\n  dbsystem: ~e" who sys-name)
             (current-continuation-marks)))]))
