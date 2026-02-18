#lang info

(define version "1.0")
(define license 'ISC)

(define collection 'multi)

(define deps
  '("base"))
(define build-deps
  '("data-doc"
    "data-lib"
    "db-doc"
    "db-lib"
    "draw-doc"
    "draw-lib"
    "gregor-doc"
    "gregor-lib"
    "pict-doc"
    "pict-lib"
    "ppict"
    "racket-doc"
    "scribble-doc"
    "scribble-lib"
    ["toolbox-db-lib" #:version "1.0"]
    ["toolbox-draw-lib" #:version "1.0"]
    ["toolbox-lib" #:version "1.0"]
    ["toolbox-web-lib" #:version "1.0"]
    "web-server-doc"
    "web-server-lib"))
