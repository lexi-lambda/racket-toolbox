#lang info

(define version "1.0")
(define license 'ISC)

(define collection 'multi)

(define deps
  '("base"))
(define build-deps
  '("gregor-doc"
    "gregor-lib"
    "racket-doc"
    "scribble-lib"
    ["toolbox-lib" #:version "1.0"]))
