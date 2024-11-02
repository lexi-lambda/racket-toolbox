#lang racket/base

(require "../logging.rkt")

(provide (logger-out toolbox)
         define-toolbox-logger)

(define-root-logger toolbox)
