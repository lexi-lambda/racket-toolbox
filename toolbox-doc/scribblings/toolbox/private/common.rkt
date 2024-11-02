#lang racket/base

(require (for-syntax racket/base
                     racket/syntax)
         scribble/manual
         scribble/example
         syntax/parse/define
         (for-label (only-in db sqlite3-connect)
                    gregor
                    (except-in racket/base date? date)
                    racket/contract
                    racket/format
                    racket/lazy-require
                    racket/list
                    racket/logging
                    racket/match
                    racket/string
                    toolbox/boolean
                    toolbox/box
                    toolbox/db/base
                    toolbox/db/sqlite3
                    toolbox/format
                    toolbox/gregor
                    toolbox/lazy-require
                    toolbox/list
                    toolbox/logger
                    toolbox/logging
                    toolbox/printing-block
                    toolbox/string
                    toolbox/web/dispatch
                    toolbox/who
                    web-server/dispatch))

(provide m...
         reftech
         dbtech
         define-id-referencer
         make-toolbox-eval
         close-eval
         toolbox-examples
         toolbox-interaction
         (for-label (all-from-out db
                                  gregor
                                  racket/base
                                  racket/contract
                                  racket/format
                                  racket/lazy-require
                                  racket/list
                                  racket/logging
                                  racket/match
                                  racket/string
                                  toolbox/boolean
                                  toolbox/box
                                  toolbox/db/base
                                  toolbox/db/sqlite3
                                  toolbox/format
                                  toolbox/gregor
                                  toolbox/lazy-require
                                  toolbox/list
                                  toolbox/logger
                                  toolbox/logging
                                  toolbox/printing-block
                                  toolbox/string
                                  toolbox/web/dispatch
                                  toolbox/who
                                  web-server/dispatch)))

(define m... (racketmetafont "..."))

(define (reftech . pre-content)
  (apply tech pre-content #:doc '(lib "scribblings/reference/reference.scrbl")))
(define (dbtech . pre-content)
  (apply tech pre-content #:doc '(lib "db/scribblings/db.scrbl")))

(define (id-from-modname-elem id-elem mod-name-elem)
  (list id-elem " from " mod-name-elem))

(begin-for-syntax
  (define (make-id-referencer-transformers mod-name)
    (values
     (syntax-parser
       [(_ x:id)
        #`(racket #,(datum->syntax mod-name (syntax-e #'x) #'x #'x))])
     (syntax-parser
       [(_ x:id)
        #`(id-from-modname-elem
           (racket #,(datum->syntax mod-name (syntax-e #'x) #'x #'x))
           (racketmodname #,mod-name))]))))

(define-syntax-parse-rule (define-id-referencer name:id mod-name:id)
  #:with name-id (format-id #'name "~a-id" #'name #:subs? #t)
  #:with id-from-name (format-id #'name "id-from-~a" #'name #:subs? #t)
  #:do [(define introducer (make-syntax-introducer #t))]
  #:with mod-name* (introducer (datum->syntax #f (syntax-e #'mod-name) #'mod-name #'mod-name))
  (begin
    (require (for-label mod-name*))
    (define-syntaxes [name-id id-from-name]
      (make-id-referencer-transformers (quote-syntax mod-name*)))))

(define make-toolbox-eval (make-eval-factory '(db/sqlite3
                                               racket/match
                                               racket/string
                                               toolbox/boolean
                                               toolbox/box
                                               toolbox/db/base
                                               toolbox/db/sqlite3
                                               toolbox/format
                                               toolbox/gregor
                                               toolbox/lazy-require
                                               toolbox/list
                                               toolbox/logger
                                               toolbox/logging
                                               toolbox/printing-block
                                               toolbox/string
                                               toolbox/web/dispatch
                                               toolbox/who
                                               web-server/dispatch)))

(begin-for-syntax
  (define-splicing-syntax-class eval-body
    #:description #f
    #:attributes [e]
    (pattern {~seq body:expr #:hidden hidden:expr}
      #:attr e #'(eval:alts body (begin0 body hidden)))
    (pattern {~seq #:hidden hidden:expr body:expr}
      #:attr e #'(eval:alts body (begin hidden body)))
    (pattern body:expr
      #:attr e #'body)))

(define-syntax-parse-rule
  (toolbox-examples {~alt {~optional {~seq #:eval eval-e:expr}}
                          {~optional {~seq #:label label-e:expr}}}
                    ...
                    body:eval-body ...)
  (examples {~? {~@ #:eval eval-e}
                {~@ #:eval (make-toolbox-eval) #:once}}
            {~? {~@ #:label label-e}}
            body.e ...))

(define-syntax-parse-rule (toolbox-interaction body ...)
  (toolbox-examples #:label #f body ...))
