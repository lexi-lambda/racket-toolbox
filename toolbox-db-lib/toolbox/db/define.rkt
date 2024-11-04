#lang racket/base

(require (for-syntax racket/base
                     racket/string
                     racket/syntax
                     threading)
         (only-in racket/class field)
         racket/contract
         syntax/parse/define
         "base.rkt"
         "sql.rkt")

(provide field
         define-sql-table
         (contract-out
          [make-sql-deleter (->* [#:who symbol?
                                  #:table symbol?]
                                 [#:resolve resolver/c]
                                 procedure?)]
          [make-sql-getter (->* [#:who symbol?
                                 #:table symbol?
                                 #:field symbol?]
                                [#:resolve resolver/c
                                 #:convert convert/c]
                                procedure?)]
          [make-sql-setter (->* [#:who symbol?
                                 #:table symbol?
                                 #:field symbol?]
                                [#:resolve resolver/c
                                 #:convert convert/c]
                                procedure?)]))

;; -----------------------------------------------------------------------------

(define id/c exact-positive-integer?)
(define resolver/c (or/c (-> any/c #:who symbol? id/c) #f))
(define convert/c (-> any/c any/c))

(define (maybe-resolve resolve-ref ref #:who who)
  (if resolve-ref (resolve-ref ref #:who who) ref))

(define (sqlite-statement who str)
  (virtual-statement
   (λ (sys)
     (define sys-name (dbsystem-name sys))
     (if (eq? sys-name 'sqlite3)
         str
         (raise (exn:fail:unsupported
                 (format "~a: dbsystem not supported\n  dbsystem name: ~e" who sys-name)
                 (current-continuation-marks)))))))

(define (make-sql-deleter #:who who
                          #:table table-name
                          #:resolve [resolve-ref #f])
  (define stmt (sqlite-statement who (~sql "DELETE FROM " table-name " WHERE id = ?")))
  (procedure-rename
   (λ (ref #:who [who who])
     (call-with-transaction/retry
      #:option 'immediate
      (λ ()
        (query-exec stmt (maybe-resolve resolve-ref ref #:who who)))))
   who))

(define (make-sql-getter #:who who
                         #:table table-name
                         #:field field-name
                         #:resolve [resolve-ref #f]
                         #:convert [convert-value values])
  (define stmt (sqlite-statement who (~sql "SELECT " field-name " FROM " table-name " WHERE id = ?")))
  (procedure-rename
   (λ (ref #:who [who who])
     (call-with-transaction/retry
      (λ ()
        (convert-value (query-value stmt (maybe-resolve resolve-ref ref #:who who))))))
   who))

(define (make-sql-setter #:who who
                         #:table table-name
                         #:field field-name
                         #:resolve [resolve-ref #f]
                         #:convert [convert-value values])
  (define stmt (sqlite-statement who (~sql "UPDATE " table-name " SET " field-name " = ?2 WHERE id = ?1")))
  (procedure-rename
   (λ (ref value #:who [who who])
     (call-with-transaction/retry
      #:option 'immediate
      (λ ()
        (query-exec stmt (maybe-resolve resolve-ref ref #:who who) (convert-value value)))))
   who))

;; -----------------------------------------------------------------------------

(begin-for-syntax
  (define (racket-name->sql-name name)
    (let* ([name (string-replace (symbol->string name) "-" "_")]
           [name (if (char=? (string-ref name (sub1 (string-length name))) #\?)
                     (string-append "is_" (substring name 0 (sub1 (string-length name))))
                     name)])
      (string->symbol name)))

  (define-syntax-class (table-field-decl table-name sql-table-name-e resolve-e)
    #:description "field declaration" #:no-delimit-cut
    #:attributes [{defn 1}]
    #:literals [field]
    (pattern (field ~! name:id
                    {~alt {~optional {~seq #:sql-name {~var sql-name-e* (expr/c #'symbol? #:name "#:sql-name argument")}
                                           {~bind [sql-name-e (generate-temporary #'name)]}}
                                     #:defaults ([sql-name-e #`(quote #,(racket-name->sql-name (syntax-e #'name)))])}
                          {~optional {~seq #:getter
                                           {~optional getter-name:id
                                                      #:defaults ([getter-name (format-id #'name "~a-~a" table-name #'name #:subs? #t)])}}}
                          {~optional {~seq #:setter
                                           {~optional setter-name:id
                                                      #:defaults ([setter-name (format-id #'name "set-~a-~a!" table-name #'name #:subs? #t)])}}}
                          {~optional {~seq #:convert
                                           {~var sql->racket-e (expr/c #'convert/c #:name "#:convert argument")}
                                           {~var racket->sql-e (expr/c #'convert/c #:name "#:convert argument")}
                                           {~bind [sql->racket (generate-temporary #'name)]
                                                  [racket->sql (generate-temporary #'name)]}}}}
                    ...)
      #:attr resolve-e resolve-e
      #:with [defn ...]
      #`[{~? (define sql-name-e sql-name-e*.c)}
         {~? {~@ (define sql->racket sql->racket-e.c)
                 (define racket->sql racket->sql-e.c)}}
         {~? (define getter-name
               (make-sql-getter #:who 'getter-name
                                #:table #,sql-table-name-e
                                #:field sql-name-e
                                {~? {~@ #:resolve resolve-e}}
                                {~? {~@ #:convert sql->racket}}))}
         {~? (define setter-name
               (make-sql-setter #:who 'setter-name
                                #:table #,sql-table-name-e
                                #:field sql-name-e
                                {~? {~@ #:resolve resolve-e}}
                                {~? {~@ #:convert racket->sql}}))}])))

(define-syntax-parser define-sql-table
  #:track-literals
  [(_ table-name:id
      {~alt {~optional {~seq #:sql-name {~var sql-name-e* (expr/c #'symbol? #:name "#:sql-name argument")}
                             {~bind [sql-name-e (generate-temporary #'table-name)]}}
                       #:defaults ([sql-name-e #`(quote #,(racket-name->sql-name (syntax-e #'table-name)))])}
            {~optional {~seq #:resolve {~var resolve-e* (expr/c #'resolver/c #:name "#:resolve argument")}
                             {~bind [resolve-e (generate-temporary #'table-name)]}}}
            {~optional {~seq #:deleter
                             {~optional deleter-name:id
                                        #:defaults ([deleter-name (format-id #'table-name "delete-~a!" #'table-name #:subs? #t)])}}}}
      ...
      {~var field-decl (table-field-decl #'table-name #'sql-name-e (attribute resolve-e))} ...)
   #`(begin
       {~? (define sql-name-e sql-name-e*.c)}
       {~? (define resolve-e resolve-e*.c)}
       {~? (define deleter-name
             (make-sql-deleter #:who 'deleter-name
                               #:table sql-name-e
                               {~? {~@ #:resolve resolve-e}}))}
       field-decl.defn ... ...)])
