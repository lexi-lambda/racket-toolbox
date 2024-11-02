#lang racket/base

(require racket/contract
         "private/sqlite3/ffi.rkt")

(provide (contract-out
          [sqlite3-stmt-scanstatus-enabled? (-> boolean?)]))
