#lang info

(define version "1.0")
(define license 'ISC)

(define collection 'multi)

(define deps
  '("base"
    "db-lib"
    "gregor-lib"
    "threading-lib"
    ["toolbox-lib" #:version "1.0"]))
(define build-deps
  '())
