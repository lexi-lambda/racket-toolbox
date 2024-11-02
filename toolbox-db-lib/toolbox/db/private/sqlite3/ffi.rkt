#lang racket/base

(require db/private/sqlite3/ffi
         ffi/unsafe
         racket/match)

(provide sqlite3_statement?
         sqlite3_reset

         SQLITE_EXPLAIN_NORMAL
         SQLITE_EXPLAIN_EXPLAIN
         SQLITE_EXPLAIN_QUERY_PLAN

         (protect-out sqlite3_stmt_isexplain
                      sqlite3_stmt_explain)

         SQLITE_SCANSTAT_COMPLEX

         SQLITE_SCANSTAT_NLOOP
         SQLITE_SCANSTAT_NLOOP
         SQLITE_SCANSTAT_NVISIT
         SQLITE_SCANSTAT_EST
         SQLITE_SCANSTAT_NAME
         SQLITE_SCANSTAT_EXPLAIN
         SQLITE_SCANSTAT_SELECTID
         SQLITE_SCANSTAT_PARENTID
         SQLITE_SCANSTAT_NCYCLE

         (protect-out sqlite3_stmt_scanstatus_reset
                      sqlite3_stmt_scanstatus_v2)

         sqlite3-stmt-scanstatus-enabled?
         check-sqlite3-stmt-scanstatus-enabled)

;; -----------------------------------------------------------------------------

;; These are not actually defined by SQLite, but they’re useful.
(define SQLITE_EXPLAIN_NORMAL 0)
(define SQLITE_EXPLAIN_EXPLAIN 1)
(define SQLITE_EXPLAIN_QUERY_PLAN 2)

(define-sqlite sqlite3_stmt_isexplain
  (_fun _sqlite3_statement -> _int))

(define-sqlite sqlite3_stmt_explain
  (_fun _sqlite3_statement
        _int
        -> [result : _int]
        -> (unless (= result SQLITE_OK)
             (error 'sqlite3_stmt_explain "could not change statement explain mode"
                    "error code" result)))
  #:fail (λ () #f))

;; -----------------------------------------------------------------------------

(define SQLITE_SCANSTAT_COMPLEX  1)

(define SQLITE_SCANSTAT_NLOOP    0)
(define SQLITE_SCANSTAT_NVISIT   1)
(define SQLITE_SCANSTAT_EST      2)
(define SQLITE_SCANSTAT_NAME     3)
(define SQLITE_SCANSTAT_EXPLAIN  4)
(define SQLITE_SCANSTAT_SELECTID 5)
(define SQLITE_SCANSTAT_PARENTID 6)
(define SQLITE_SCANSTAT_NCYCLE   7)

(define-sqlite sqlite3_stmt_scanstatus_reset
  (_fun _sqlite3_statement -> _void)
  #:fail (λ () #f))

(define-sqlite sqlite3_stmt_scanstatus_v2
  (_fun _sqlite3_statement
        [idx : _int]
        [scan-status-op : _int]
        [flags : _int]
        [out : (_ptr o (match scan-status-op
                         [(or (== SQLITE_SCANSTAT_SELECTID)
                              (== SQLITE_SCANSTAT_PARENTID))
                          _int]
                         [(or (== SQLITE_SCANSTAT_NLOOP)
                              (== SQLITE_SCANSTAT_NVISIT)
                              (== SQLITE_SCANSTAT_NCYCLE))
                          _int64]
                         [(== SQLITE_SCANSTAT_EST)
                          _double]
                         [(or (== SQLITE_SCANSTAT_NAME)
                              (== SQLITE_SCANSTAT_EXPLAIN))
                          _pointer]))]
        -> [result : _int]
        -> (if (zero? result)
               (match scan-status-op
                 [(or (== SQLITE_SCANSTAT_NAME)
                      (== SQLITE_SCANSTAT_EXPLAIN))
                  (cast out _pointer _string/utf-8)]
                 [_ out])
               #f))
  #:fail (λ () #f))

(define (sqlite3-stmt-scanstatus-enabled?)
  (and sqlite3_stmt_scanstatus_v2 #t))

(define (check-sqlite3-stmt-scanstatus-enabled who message)
  (unless (sqlite3-stmt-scanstatus-enabled?)
    (raise (exn:fail:unsupported
            (format (string-append "~a: ~a;\n"
                                   " SQLite was not compiled with SQLITE_ENABLE_STMT_SCANSTATUS")
                    who
                    message)
            (current-continuation-marks)))))
