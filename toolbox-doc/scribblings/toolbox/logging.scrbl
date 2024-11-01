#lang scribble/manual

@(require "private/common.rkt")

@title[#:tag "logging"]{Logging}
@defmodule[toolbox/logging]

@(define (log-id-level-fns)
   (define id @racketvarfont{id})
   @list{@racketplainfont{@|id|-logger}, @racketplainfont{log-@|id|-fatal}, @racketplainfont{log-@|id|-error}, @racketplainfont{log-@|id|-warning}, @racketplainfont{log-@|id|-info}, and @racketplainfont{log-@|id|-debug}})

@defform[#:kind "provide syntax"
         (logger-out id)]{
When used in @racket[provide], exports @log-id-level-fns[].}

@defform[(define-log-message-transformers id logger-expr)
         #:contracts ([logger-expr logger?])]{
Defines @log-id-level-fns[] as forms like @racket[log-fatal], @racket[log-error], @racket[log-warning], @racket[log-info], and @racket[log-debug], with two differences:
@itemlist[
 @item{The defined forms log messages to @racket[logger-expr] instead of the @reftech{current logger}.}
 @item{A @racket[log-message-info] structure is sent to the logger instead of @racket[(current-continuation-marks)].}]}

@defform[(define-root-logger id
           option ...)
         #:grammar ([option (code:line #:topic topic-expr)
                            (code:line #:parent parent-expr)])
         #:contracts ([topic-expr (or/c symbol? #f)]
                      [parent-expr (or/c logger? #f)])]{
Defines @racketplainfont{@racket[id]-logger} as a new @reftech{logger}. The logger’s default topic is the result of @racket[topic-expr], or @racket['@#,racket[id]] if no @racket[topic-expr] is provided. The logger’s parent is the result of @racket[parent-expr], or @racket[(current-logger)] if no @racket[parent-expr] is provided.

The @racket[define-root-logger] form also defines @log-id-level-fns[] in the same way as @racket[define-log-message-transformers], with @racketplainfont{@racket[id]-logger} as the target logger.

Finally, @racket[define-root-logger] defines @racketplainfont{define-@racket[id]-logger} as a form like @racket[define-root-logger] itself, except @racketplainfont{@racket[id]-logger} is always used as the parent logger (and the @racket[#:parent] option is not allowed). This form can be used to conveniently define child loggers to form a logging hierarchy.

@(toolbox-examples
  (define-root-logger toolbox)
  (define toolbox-receiver (make-log-receiver toolbox-logger 'debug))
  (log-toolbox-info "message on the root logger")
  (sync toolbox-receiver)
  (define-toolbox-logger toolbox:example)
  (log-toolbox:example-debug "message on a child logger")
  (sync toolbox-receiver))}

@defstruct[log-message-info ([milliseconds rational?]
                             [continuation-marks continuation-mark-set?])]{
A structure type used by the forms defined by @racket[define-log-message-transformers] to record when and from where a message was sent to a logger. The value of the @racket[milliseconds] field should be @racket[(current-inexact-milliseconds)] and the value of the @racket[continuation-marks] field should be @racket[(current-continuation-marks)].

The @racket[log-message-info] structure type implements @racket[gen:moment-provider] using the value of the @racket[milliseconds] field.}

@section[#:tag "logging:writers"]{Log writers}

@(define log-writer-eval (make-toolbox-eval))
@defproc[(spawn-pretty-log-writer [receiver (evt/c (vector/c log-level/c string? any/c (or/c symbol? #f)))]
                                  [#:out out output-port? (current-output-port)]
                                  [#:process-name process-name any/c #f]
                                  [#:millis? millis? any/c #f]
                                  [#:color? color? any/c (terminal-port? out)])
         log-writer?]{
Starts a new @reftech{thread} that repeatedly synchronizes on @racket[receiver] (which is usually the result of a call to @racket[make-log-receiver]) and writes a formatted version of each @reftech{synchronization result} to @racket[out]. The result of @racket[spawn-pretty-log-writer] is a @deftech{log writer} handle that can be used to flush or terminate the writer thread.

@(toolbox-examples
  #:eval log-writer-eval
  (define-root-logger toolbox)
  (define writer (spawn-pretty-log-writer
                  (make-log-receiver toolbox-logger 'debug)))
  (eval:alts (log-toolbox-info "an informational message")
             (begin
               (log-toolbox-info "an informational message")
               (flush-log-writer writer)))
  (eval:alts (log-toolbox-fatal "a fatal message!!")
             (begin
               (log-toolbox-fatal "a fatal message!!")
               (close-log-writer writer)))
  (close-log-writer writer))

Because log messages are written asynchronously, most programs should explicitly call @racket[close-log-writer] to ensure all log messages are flushed before exiting. Otherwise, messages logged immediately prior to termination may be lost.

If @racket[process-name] is not @racket[#f], it is written after the topic and log level using @racket[display]:

@(toolbox-interaction
  #:eval log-writer-eval
  (eval:alts (spawn-pretty-log-writer (make-log-receiver toolbox-logger 'debug)
                                      #:process-name 'worker)
             (begin
               (define writer (spawn-pretty-log-writer (make-log-receiver toolbox-logger 'debug)
                                                       #:process-name 'worker))
               writer))
  (eval:alts (log-toolbox-info "message from a worker process")
             (begin
               (log-toolbox-info "message from a worker process")
               (close-log-writer writer))))

If the third element of the result of @racket[receiver] implements @racket[gen:moment-provider], @racket[->moment] is used to extract a timestamp for the message. Otherwise, the timestamp is based on the moment the message is received, rather than when the message was logged, which can be substantially less accurate. The logging forms defined by @racket[define-log-message-transformers] send a @racket[log-message-info] structure with each message, which @emph{do} implement @racket[gen:moment-provider] and supply a reliable timestamp.

If @racket[millis?] is not @racket[#f], timestamps are written with millisecond precision. However, see the caveat about timestamp accuracy from the previous paragraph.

@(toolbox-examples
  #:eval log-writer-eval
  (eval:alts (spawn-pretty-log-writer (make-log-receiver toolbox-logger 'debug)
                                      #:millis? #t)
             (begin
               (define writer (spawn-pretty-log-writer (make-log-receiver toolbox-logger 'debug)
                                                       #:millis? #t))
               writer))
  (eval:alts (log-toolbox-info "high-precision message")
             (begin
               (log-toolbox-info "high-precision message")
               (close-log-writer writer))))

If @racket[color?] is not @racket[#f], @hyperlink["https://en.wikipedia.org/wiki/ANSI_escape_code"]{ANSI escape codes} are included in the formatted output to colorize the output for log levels other than @racket['info].}
@(close-eval log-writer-eval)

@defproc[(log-writer? [v any/c]) boolean?]{
Returns @racket[#t] if @racket[v] is a @tech{log writer} handle returned by @racket[spawn-pretty-log-writer], otherwise returns @racket[#f].}

@defproc[(close-log-writer [writer log-writer?]
                           [#:wait? wait? any/c #t])
         void?]{
Closes the given @tech{log writer} by flushing all pending log messages and terminating the writer thread. If @racket[wait?] is not @racket[#f], the call to @racket[close-log-writer] blocks until the shutdown is complete. If @racket[writer] is already closed, @racket[close-log-writer] has no effect.}

@defproc[(log-writer-closed? [writer log-writer?]) boolean?]{
Returns @racket[#t] if the given @tech{log writer} has been closed by @racket[close-log-writer] or if its writer thread has been killed by some other means. Otherwise, @racket[log-writer-closed?] returns @racket[#f].}

@defproc[(flush-log-writer [writer (and/c log-writer? (not/c log-writer-closed?))]) void?]{
Forces the given @tech{log writer} to write any pending messages, blocking until all messages have been written.

This function is not generally necessary, as @racket[spawn-pretty-log-writer] calls @racket[flush-output] after writing each log message it receives @emph{regardless} of whether @racket[flush-log-writer] is used. The @emph{only} effect of @racket[flush-log-writer] is to block the calling thread until the log writer thread has had a chance to receive and write any pending messages. However, this can rarely be useful if the calling thread writes to the same output port and wants to avoid output being interleaved, for example.}
