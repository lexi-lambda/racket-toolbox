#lang racket/base

(require gregor
         racket/contract)

(provide UTC
         (contract-out
          [posix->moment/utc (-> rational? moment?)]
          [jd->moment (->* [rational?] [tz/c] moment?)]
          [jd->moment/utc (-> rational? moment?)]))

;; -----------------------------------------------------------------------------

(define (posix->moment/utc v)
  (posix->moment v UTC))

(define (jd->moment/utc v)
  (with-timezone (jd->datetime v) UTC))

(define (jd->moment v [tz (current-timezone)])
  (adjust-timezone (jd->moment/utc v) tz))
