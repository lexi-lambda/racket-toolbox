#lang racket/base

(require (for-syntax racket/base)
         racket/contract
         racket/format
         racket/list
         racket/match
         racket/string
         syntax/parse/define
         threading
         toolbox/format
         toolbox/who
         "base.rkt")

(provide ~stmt
         (contract-out
          [sql:id (-> (or/c symbol? string?) string?)]
          [sql:string (-> string? string?)]

          [pre-sql? predicate/c]
          [~sql (-> pre-sql? ... string?)]
          [sql:seq (-> pre-sql? ... string?)]
          [sql:seq* (-> pre-sql? ... (listof pre-sql?) string?)]
          [sql:tuple (-> pre-sql? ... string?)]
          [sql:tuple* (-> pre-sql? ... (listof pre-sql?) string?)]

          [query:bag (-> (listof pre-sql?) string?)]
          [query:indexed-list (-> (listof pre-sql?) string?)]
          [query:rows (->* [(listof (vectorof pre-sql?))]
                           [#:columns (or/c exact-nonnegative-integer? #f)]
                           string?)]))

;; -----------------------------------------------------------------------------

(define (sql:id v)
  (~> (if (symbol? v) (symbol->string v) v)
      (string-replace "\"" "\"\"")
      (string-append "\"" _ "\"")))

(define (sql:string str)
  (~> (string-replace str "'" "''")
      (string-append "'" _ "'")))

;; -----------------------------------------------------------------------------

(define (pre-sql? v)
  (or (string? v)
      (symbol? v)
      (rational? v)
      (sql-null? v)))

(define ~sql
  (case-lambda
    [() ""]
    [(v)
     (match v
       [(? string?)        v]
       [(? symbol?)        (sql:id v)]
       [(? exact-integer?) (number->string v)]
       [(? rational?)      (number->string (real->double-flonum v))]
       [(? sql-null?)      "NULL"])]
    [vs
     (string-append* (map ~sql vs))]))

(define-syntax-parse-rule (~stmt arg ...)
  #:declare arg (expr/c #'pre-sql?)
  (lifted-statement (~sql arg.c ...)))

(define (sql:seq . vs)
  (string-join (map ~sql vs) ","))
(define sql:seq*
  (case-lambda
    [(vs)
     (apply sql:seq vs)]
    [(v . vs)
     (apply apply sql:seq v vs)]))

(define (sql:tuple . vs)
  (~a "(" (sql:seq* vs) ")"))
(define sql:tuple*
  (case-lambda
    [(vs)
     (apply sql:tuple vs)]
    [(v . vs)
     (apply apply sql:tuple v vs)]))

(define (query:bag lst)
  (if (empty? lst)
      "SELECT NULL WHERE 0"
      (~sql "VALUES " (sql:seq* (map sql:tuple lst)))))

(define/who (query:rows rows #:columns [given-num-columns #f])
  (cond
    [(empty? rows)
     (if given-num-columns
         (~sql "SELECT " (sql:seq* (make-list given-num-columns "NULL")) " WHERE 0")
         (raise-arguments-error who (string-append "cannot infer number of columns;\n"
                                                   " no rows given and #:columns not specified")))]
    [else
     (define num-columns (or given-num-columns (vector-length (first rows))))
     (define sql-rows
       (for/list ([(row i) (in-indexed (in-list rows))])
         (unless (= (vector-length row) num-columns)
           (cond
             [given-num-columns
              (raise-arguments-error who "wrong number of columns for row"
                                     "expected" num-columns
                                     "given" (vector-length row)
                                     "row" row
                                     "row index" i)]
             [else
              (define ith (ordinal (add1 i) #:word? #t))
              (raise-arguments-error who "inconsistent number of columns per row"
                                     "first row" (first rows)
                                     (~a ith " row") row
                                     "first row columns" num-columns
                                     (~a ith " row columns") (vector-length row))]))
         (sql:tuple* (vector->list row))))
     (~sql "VALUES " (sql:seq* sql-rows))]))

(define (query:indexed-list lst)
  (query:rows
   #:columns 2
   (for/list ([(group-id i) (in-indexed (in-list lst))])
     (vector-immutable i group-id))))
