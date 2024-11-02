#lang racket/base

(require db/private/sqlite3/ffi
         ffi/unsafe
         racket/match)

(provide sqlite3_statement?
         (protect-out (all-defined-out)))

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
  (_fun _sqlite3_statement -> _void))

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
               #f)))
