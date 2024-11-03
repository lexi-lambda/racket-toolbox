#lang info

(define version "1.0")
(define license 'ISC)

(define collection 'multi)

(define deps
  '("base"))
(define build-deps
  '("db-doc"
    "db-lib"
    "gregor-doc"
    "gregor-lib"
    "racket-doc"
    "scribble-doc"
    "scribble-lib"
    ["toolbox-db-lib" #:version "1.0"]
    ["toolbox-lib" #:version "1.0"]
    ["toolbox-web-lib" #:version "1.0"]
    "web-server-doc"
    "web-server-lib"))
