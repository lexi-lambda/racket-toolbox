#lang racket/base

(require (for-syntax racket/base
                     racket/syntax)
         scribble/manual
         scribble/example
         syntax/parse/define
         (for-label data/order
                    (only-in db sqlite3-connect)
                    gregor
                    (except-in racket/base date? date)
                    racket/class
                    racket/contract
                    racket/draw
                    racket/format
                    racket/lazy-require
                    racket/list
                    racket/logging
                    racket/match
                    racket/math
                    racket/pretty
                    racket/string
                    toolbox/boolean
                    toolbox/box
                    toolbox/color
                    toolbox/db/base
                    toolbox/db/define
                    toolbox/db/sql
                    toolbox/db/sqlite3
                    toolbox/format
                    toolbox/gregor
                    toolbox/lazy-require
                    toolbox/lift
                    toolbox/list
                    toolbox/logger
                    toolbox/logging
                    toolbox/order
                    toolbox/pict
                    toolbox/print
                    toolbox/printing-block
                    toolbox/string
                    toolbox/web/dispatch
                    toolbox/who
                    web-server/dispatch))

(provide m...
         reftech
         datatech
         dbtech
         drawtech
         pictech
         define-id-referencer
         make-toolbox-eval
         close-eval
         toolbox-examples
         toolbox-interaction
         (for-label (all-from-out data/order
                                  db
                                  gregor
                                  racket/base
                                  racket/class
                                  racket/contract
                                  racket/draw
                                  racket/format
                                  racket/lazy-require
                                  racket/list
                                  racket/logging
                                  racket/match
                                  racket/math
                                  racket/pretty
                                  racket/string
                                  toolbox/boolean
                                  toolbox/box
                                  toolbox/color
                                  toolbox/db/base
                                  toolbox/db/define
                                  toolbox/db/sql
                                  toolbox/db/sqlite3
                                  toolbox/format
                                  toolbox/gregor
                                  toolbox/lazy-require
                                  toolbox/lift
                                  toolbox/list
                                  toolbox/logger
                                  toolbox/logging
                                  toolbox/order
                                  toolbox/pict
                                  toolbox/print
                                  toolbox/printing-block
                                  toolbox/string
                                  toolbox/web/dispatch
                                  toolbox/who
                                  web-server/dispatch)))

(define m... (racketmetafont "..."))

(define (reftech #:key [key #f] . pre-content)
  (apply tech pre-content #:key key #:doc '(lib "scribblings/reference/reference.scrbl")))
(define (datatech #:key [key #f] . pre-content)
  (apply tech pre-content #:key key #:doc '(lib "data/scribblings/data.scrbl")))
(define (dbtech #:key [key #f] . pre-content)
  (apply tech pre-content #:key key #:doc '(lib "db/scribblings/db.scrbl")))
(define (drawtech #:key [key #f] . pre-content)
  (apply tech pre-content #:key key #:doc '(lib "scribblings/draw/draw.scrbl")))
(define (pictech #:key [key #f] . pre-content)
  (apply tech pre-content #:key key #:doc '(lib "pict/scribblings/pict.scrbl")))

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

(define make-toolbox-eval (make-eval-factory '(data/order
                                               db/sqlite3
                                               racket/class
                                               racket/draw
                                               racket/format
                                               racket/list
                                               racket/match
                                               racket/math
                                               racket/pretty
                                               racket/string
                                               toolbox/boolean
                                               toolbox/box
                                               toolbox/color
                                               toolbox/db/base
                                               toolbox/db/define
                                               toolbox/db/sql
                                               toolbox/db/sqlite3
                                               toolbox/format
                                               toolbox/gregor
                                               toolbox/lazy-require
                                               toolbox/lift
                                               toolbox/list
                                               toolbox/logger
                                               toolbox/logging
                                               toolbox/order
                                               toolbox/pict
                                               toolbox/print
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
