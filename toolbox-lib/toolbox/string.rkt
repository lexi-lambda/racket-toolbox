#lang racket/base

(require (for-syntax racket/base)
         syntax/parse/define)

(provide when/string unless/string)

;; -----------------------------------------------------------------------------

(define-syntax-parse-rule (when/string cond-e:expr body ...+)
  #:with {~var body-e (expr/c #'string? #:name "body")}
         (syntax/loc this-syntax
           (let () body ...))
  (if cond-e body-e.c ""))

(define-syntax-parse-rule (unless/string cond-e:expr body ...+)
  #:with {~var body-e (expr/c #'string? #:name "body")}
         (syntax/loc this-syntax
           (let () body ...))
  (if cond-e "" body-e.c))
