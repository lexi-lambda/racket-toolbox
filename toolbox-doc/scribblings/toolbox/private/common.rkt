#lang racket/base

(require (for-syntax racket/base)
         scribble/manual
         scribble/example
         syntax/parse/define
         (for-label gregor
                    (except-in racket/base date? date)
                    racket/contract
                    racket/lazy-require
                    racket/logging
                    toolbox/box
                    toolbox/gregor
                    toolbox/lazy-require
                    toolbox/logging
                    toolbox/printing-block
                    toolbox/who))

(provide m...
         reftech
         make-toolbox-eval
         close-eval
         toolbox-examples
         toolbox-interaction
         (for-label (all-from-out gregor
                                  racket/base
                                  racket/contract
                                  racket/lazy-require
                                  racket/logging
                                  toolbox/box
                                  toolbox/gregor
                                  toolbox/lazy-require
                                  toolbox/logging
                                  toolbox/printing-block
                                  toolbox/who)))

(define m... (racketmetafont "..."))

(define (reftech . pre-content)
  (apply tech pre-content #:doc '(lib "scribblings/reference/reference.scrbl")))


(define make-toolbox-eval (make-eval-factory '(toolbox/box
                                               toolbox/gregor
                                               toolbox/lazy-require
                                               toolbox/logging
                                               toolbox/printing-block
                                               toolbox/who)))

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
