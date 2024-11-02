#lang racket/base

(require (for-syntax racket/base)
         scribble/manual
         scribble/example
         syntax/parse/define
         (for-label gregor
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
                    toolbox/format
                    toolbox/gregor
                    toolbox/lazy-require
                    toolbox/list
                    toolbox/logging
                    toolbox/printing-block
                    toolbox/string
                    toolbox/web/dispatch
                    toolbox/who
                    web-server/dispatch))

(provide m...
         reftech
         make-toolbox-eval
         close-eval
         toolbox-examples
         toolbox-interaction
         (for-label (all-from-out gregor
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
                                  toolbox/format
                                  toolbox/gregor
                                  toolbox/lazy-require
                                  toolbox/list
                                  toolbox/logging
                                  toolbox/printing-block
                                  toolbox/string
                                  toolbox/web/dispatch
                                  toolbox/who
                                  web-server/dispatch)))

(define m... (racketmetafont "..."))

(define (reftech . pre-content)
  (apply tech pre-content #:doc '(lib "scribblings/reference/reference.scrbl")))


(define make-toolbox-eval (make-eval-factory '(racket/match
                                               toolbox/boolean
                                               toolbox/box
                                               toolbox/format
                                               toolbox/gregor
                                               toolbox/lazy-require
                                               toolbox/list
                                               toolbox/logging
                                               toolbox/printing-block
                                               toolbox/string
                                               toolbox/web/dispatch
                                               toolbox/who
                                               web-server/dispatch)))

(define-syntax-parse-rule
  (toolbox-examples {~alt {~optional {~seq #:eval eval-e:expr}}
                          {~optional {~seq #:label label-e:expr}}}
                    ...
                    body ...)
  (examples {~? {~@ #:eval eval-e}
                {~@ #:eval (make-toolbox-eval) #:once}}
            {~? {~@ #:label label-e}}
            body ...))

(define-syntax-parse-rule (toolbox-interaction body ...)
  (toolbox-examples #:label #f body ...))
