#lang racket/base

(require (for-syntax racket/base
                     racket/syntax
                     syntax/transformer)
         racket/lazy-require
         racket/promise
         racket/runtime-path
         syntax/parse/define)

(provide lazy-require lazy-require/value)

(begin-for-syntax
  (define-syntax-class import-spec
    #:description "import spec"
    #:attributes [export-id import-id]
    #:commit
    (pattern export-id:id
      #:attr import-id #'export-id)
    (pattern [export-id:id import-id:id]))

  (define-syntax-class lazy-require-clause
    #:description "lazy-require clause"
    #:attributes [{defn 1}]
    #:commit
    (pattern [module-path {spec:import-spec ...}]
      #:with mpi-id (generate-temporary #'module-path)
      #:with [promise-id ...] (generate-temporaries (attribute spec.import-id))
      #:with [defn ...]
      #'[(define-runtime-module-path-index mpi-id 'module-path)
         {~@ (define promise-id (delay (dynamic-require mpi-id 'spec.export-id)))
             (define-syntax spec.import-id (make-variable-like-transformer
                                            (quote-syntax (force promise-id))))}
         ...])))

(define-syntax-parser lazy-require/value
  [(_ clause:lazy-require-clause ...)
   #'(begin clause.defn ... ...)])
