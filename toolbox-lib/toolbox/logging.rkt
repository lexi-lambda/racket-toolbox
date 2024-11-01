#lang racket/base

(require (for-syntax racket/base
                     racket/provide-transform
                     racket/syntax)
         data/mvar
         gregor
         racket/contract
         racket/format
         racket/logging
         racket/match
         syntax/parse/define
         "who.rkt")

(provide logger-out
         define-root-logger
         define-log-message-transformers

         (contract-out
          (struct log-message-info ([milliseconds rational?]
                                    [continuation-marks continuation-mark-set?]))
          [log-writer? predicate/c]
          [log-writer-closed? (-> log-writer? boolean?)]
          [flush-log-writer (-> log-writer? void?)]
          [close-log-writer (->* [log-writer?] [#:wait? any/c] void?)]
          [spawn-pretty-log-writer
           (->* [(evt/c (vector/c log-level/c string? any/c (or/c symbol? #f)))]
                [#:out output-port?
                 #:process-name any/c
                 #:millis? any/c
                 #:color? any/c]
                log-writer?)]))

;; -----------------------------------------------------------------------------

(begin-for-syntax
  (define log-level-syms '(fatal error warning info debug))
  (define (make-logger-id name-id)
    (format-id name-id "~a-logger" name-id #:subs? #t))
  (define (make-log-message-id name-id level)
    (format-id name-id "log-~a-~a" name-id level #:subs? #t))
  (define (make-logger-definer-id name-id)
    (format-id name-id "define-~a-logger" name-id #:subs? #t)))

(define-syntax logger-out
  (make-provide-transformer
   (λ (stx modes)
     (syntax-parse stx
       [(_ name:id)
        (expand-export
         #`(combine-out
            #,(make-logger-id #'name)
            #,@(for/list ([level (in-list log-level-syms)])
                 (make-log-message-id #'name level)))
         modes)]))))

(struct log-message-info (milliseconds continuation-marks)
  #:transparent
  #:methods gen:moment-provider
  [(define (->moment self)
     (posix->moment (/ (log-message-info-milliseconds self) 1000) "Etc/UTC"))])

(define (current-log-message-info)
  (log-message-info (current-inexact-milliseconds)
                    (current-continuation-marks)))

(begin-for-syntax
  (define (make-log-message-transformer logger-id level-sym)
    (syntax-parser
      [(_ {~or* str:expr {~seq format-str:expr val:expr ...+}})
       #`(when (log-level? #,logger-id '#,level-sym)
           (log-message #,logger-id
                        '#,level-sym
                        {~? (format format-str val ...) str}
                        (current-log-message-info)
                        #f))])))

(define-syntax-parser define-log-message-transformers
  [(_ name:id {~var logger-e (expr/c #'logger?)})
   (define/with-syntax logger (generate-temporary #'name))
   #`(begin
       (define logger logger-e.c)
       #,@(for/list ([level (in-list log-level-syms)])
            #`(define-syntax #,(make-log-message-id #'name level)
                (make-log-message-transformer (quote-syntax logger) '#,level))))])

(define symbol-or-false/c (or/c symbol? #f))
(define logger-or-false/c (or/c logger? #f))

(begin-for-syntax
  (define (make-logger-definer-transformer parent-logger-id)
    (syntax-parser
      [(_ name:id
          {~alt {~optional {~seq #:topic {~var topic-e (expr/c #'symbol-or-false/c #:name "topic")}}
                           #:defaults ([topic-e.c #''name])}
                {~optional {~seq {~fail #:when (and parent-logger-id #t)}
                                 #:parent {~var parent-e (expr/c #'logger-or-false/c #:name "parent logger")}}
                           #:defaults ([parent-e.c (or parent-logger-id #'(current-logger))])}}
          ...)
       (define/with-syntax name-logger (make-logger-id #'name))
       (define/with-syntax define-name-logger (make-logger-definer-id #'name))
       #`(begin
           (define name-logger (make-logger topic-e.c parent-e.c))
           (define-syntax define-name-logger
             (make-logger-definer-transformer (quote-syntax name-logger)))
           (define-log-message-transformers name name-logger))])))

(define-syntax define-root-logger (make-logger-definer-transformer #f))

;; -----------------------------------------------------------------------------

(define tty:reset  #"\e[m")
(define tty:bold   #"\e[1m")
(define tty:red    #"\e[31m")
(define tty:yellow #"\e[33m")
(define tty:blue   #"\e[34m")

(struct log-writer
  (process-name
   flush-mv    ; filled to initiate a flush, emptied when flush is complete
   shutdown-mv ; filled to initiate a shutdown, stays full
   dead-evt)
  #:property prop:custom-write
  (λ (self out mode)
    (define name (log-writer-process-name self))
    (if name
        (fprintf out "#<log-writer:~a>" name)
        (write-string "#<log-writer>" out))))

(define (log-writer-closed-evt lw)
  (choice-evt (mvar-peek-evt (log-writer-shutdown-mv lw))
              (log-writer-dead-evt lw)))

(define (log-writer-closed? lw)
  (and (sync/timeout 0 (log-writer-closed-evt lw)) #t))

(define/who (flush-log-writer lw)
  (define flush-mv (log-writer-flush-mv lw))
  (mvar-try-put! flush-mv #t)
  (sync (mvar-empty-evt flush-mv)
        (handle-evt
         (log-writer-closed-evt lw)
         (λ (x)
           (raise-arguments-error who "log writer is closed"
                                  "log writer" lw))))
  (void))

(define (close-log-writer lw #:wait? [wait? #t])
  (mvar-try-put! (log-writer-shutdown-mv lw) #t)
  (when wait?
    (sync (log-writer-dead-evt lw)))
  (void))

(define (spawn-pretty-log-writer receiver
                                 #:out [out (current-output-port)]
                                 #:process-name [process-name #f]
                                 #:millis? [millis? #f]
                                 #:color? [color?* (terminal-port? out)])
  (define color? (and color?* #t))
  (define timestamp-format (if millis?
                               "yyyy-MM-dd HH:mm:ss.SSS"
                               "yyyy-MM-dd HH:mm:ss"))
  (define process-name-str (and process-name (~a process-name)))

  (define (write-log-message level topic msg value)
    (define timestamp (if (moment-provider? value)
                          (adjust-timezone (->moment value) (current-timezone))
                          (now)))
    (when color?
      (match level
        [(or 'fatal 'error)
         (write-bytes tty:bold out)
         (write-bytes tty:red out)]
        ['warning
         (write-bytes tty:bold out)
         (write-bytes tty:yellow out)]
        ['info
         (void)]
        ['debug
         (write-bytes tty:blue out)]))
    (write-string
     (~a "[" (~t timestamp timestamp-format) "] ["
         (if topic (~a topic "/") "")
         (match level
           ['fatal   "FATAL"]
           ['error   "ERROR"]
           ['warning "WARN"]
           ['info    "INFO"]
           ['debug   "DEBUG"])
         (if process-name-str (~a "@" process-name-str) "")
         "] "
         msg
         (if color?
             (match level
               ['info ""]
               [_ tty:reset])
             ""))
     out)
    (when color?
      (match level
        ['info (void)]
        [_ (write-bytes tty:reset out)]))
    (newline out)
    (flush-output out))

  (define flush-mv (make-mvar))
  (define shutdown-mv (make-mvar))
  (define writer-thread
    (thread
     (λ ()
       (define (do-flush)
         (let flush-loop ()
           (match (sync/timeout 0 receiver)
             [(vector level msg value topic)
              (write-log-message level topic msg value)
              (flush-loop)]
             [#f
              (void)])))

       (define flush-evt (handle-evt (mvar-peek-evt flush-mv) (λ (v) 'flush)))
       (define shutdown-evt (handle-evt (mvar-peek-evt shutdown-mv) (λ (v) 'shutdown)))
       (let loop ()
         (match (sync receiver flush-evt shutdown-evt)
           [(vector level msg value topic)
            (write-log-message level topic msg value)
            (loop)]
           ['flush
            (do-flush)
            (mvar-try-take! flush-mv)
            (loop)]
           ['shutdown
            (do-flush)])))))

  (log-writer process-name-str
              flush-mv
              shutdown-mv
              (thread-dead-evt writer-thread)))
