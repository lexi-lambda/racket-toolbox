#lang scribble/manual

@(begin
   (require "private/common.rkt")
   (define-id-referencer db db/base))

@title[#:tag "db"]{Database}

@section[#:tag "db:base"]{Extended DB API}
@defmodule[toolbox/db/base]

The @racketmodname[toolbox/db/base] module improves and extends @racketmodname[db/base]. In addition to the bindings documented in this section, it re-exports all bindings from @racketmodname[db/base] (except those that have the same name as one of the bindings documented in this section).

The interface provided by @racketmodname[toolbox/db/base] is @emph{mostly} drop-in compatible with that of @racketmodname[db/base], with two major exceptions:

@itemlist[
 @item{Most functions have been changed to no longer require an explicit database connection argument. Instead, the value of the @racket[current-db] parameter is used.}

 @item{Nested uses of @racket[call-with-transaction] do not create @dbtech{nested transactions} by default. The @racket[#:nested 'allow] option must be supplied if true nested transactions are desired.}]

@defparam[current-db db (or/c connection? #f) #:value #f]{
A parameter that determines the @deftech{current database connection}, which many functions use implicitly if a connection is not explicitly provided.}

@defproc[(get-db [who symbol? 'get-db]) connection?]{
Obtains the @tech{current database connection}. If @racket[(current-db)] is @racket[#f], an @racket[exn:fail:contract] exception is raised (with @racket[who] inserted at the start of the error message).}

@defproc[(in-transaction? [#:db db connection? (current-db)]) boolean?]{
Like @id-from-db[in-transaction?], but uses the @tech{current database connection} by default.}

@defproc[(call-with-transaction [thunk (-> any)]
                                [#:db db connection? (current-db)]
                                [#:isolation isolation-level
                                 (or/c 'serializable
                                       'repeatable-read
                                       'read-committed
                                       'read-uncommitted
                                       #f)
                                 #f]
                                [#:option option any/c #f]
                                [#:nested nested-mode (or/c 'allow 'omit 'fail) 'omit])
         any]{
Like @id-from-db[call-with-transaction], but uses the @tech{current database connection} by default, and behavior when already inside a transaction differs depending on @racket[nested-mode]:

@itemlist[
 @item{If @racket[nested-mode] is @racket['omit] (the default), @racket[call-with-transaction] has no effect when already inside a transaction: @racket[thunk] is invoked directly, without starting a @dbtech{nested transaction}.}

 @item{If @racket[nested-mode] is @racket['allow], @racket[call-with-transaction] applies @racket[thunk] within a @dbtech{nested transaction}. (This is the behavior of @id-from-db[call-with-transaction].)}

 @item{If @racket[nested-mode] is @racket['fail], @racket[call-with-transaction] raises an @racket[exn:fail:contract] exception if already inside a transaction.}]

The default value of @racket['omit] makes @racket[call-with-transaction] ensure that @racket[thunk] is executed in the context of @emph{some} transaction, but it does not allow the effects of @racket[thunk] to be selectively rolled back. In practice, partial rollbacks are rarely useful, and creating savepoints to permit them can have significant performance overhead, so this is usually the right choice.}

@defproc[(call-with-transaction/retry
          [thunk (-> any)]
          [#:db db connection? (current-db)]
          [#:isolation isolation-level
           (or/c 'serializable
                 'repeatable-read
                 'read-committed
                 'read-uncommitted
                 #f)
           #f]
          [#:option option any/c #f]
          [#:nested nested-mode (or/c 'allow 'omit 'fail) 'omit]
          [#:max-retries max-retries (or/c exact-nonnegative-integer? +inf.0) (current-max-transaction-retries)]
          [#:retry-delay retry-delay-secs (>=/c 0) (current-transaction-retry-delay)])
         any]{
Like @racket[call-with-transaction], except that @racket[thunk] may be retried if it raises an @racket[exn:fail:sql:busy?] exception. Retrying is not possible if @racket[call-with-transaction/retry] is called from within another transaction, so if a transaction is already started, @racket[call-with-transaction/retry] behaves identically to @racket[call-with-transaction].

Assuming retrying is possible, @racket[thunk] may be executed up to @racket[max-retries] times before giving up. Before each retry attempt, @racket[call-with-transaction/retry] sleeps for @racket[retry-delay-secs] seconds.

When @racket[db] is a SQLite connection and @racket[option] is @racket[#f] or @racket['deferred], retry attempts will automatically use @racket['immediate] for @racket[option], instead. This is usually enough to ensure that @racket[thunk] itself is only executed at most twice, though the retry limit may still be reached if @racket[call-with-transaction/retry] is unable to successfully acquire a write transaction.

Note that the retry mechanism of @racket[call-with-transaction/retry] is used @emph{in addition to} the retry mechanism used for all SQLite operations, which is controlled separately via the @racket[#:busy-retry-limit] and @racket[#:busy-retry-delay] arguments to @racket[sqlite3-connect]. For multi-statement transactions, the retry mechanism of @racket[call-with-transaction/retry] is often substantially more useful, as a @tt{SQLITE_BUSY} failure may indicate that the entire transaction must be restarted, in which case retrying the last statement will never succeed and serves no purpose. However, the intrinsic retry mechanism can be more useful in other situations, especially when the @racket[#:use-place] argument to @racket[sqlite3-connect] is @racket['os-thread], as it can use @hyperlink["https://www.sqlite.org/c3ref/busy_handler.html"]{SQLite’s built-in busy handler}.}

@defparam[current-max-transaction-retries max-retries
          (or/c exact-nonnegative-integer? +inf.0) #:value 10]{
A parameter that controls the number of times @racket[call-with-transaction/retry] will attempt to retry a transaction that fails with a @racket[exn:fail:sql:busy?] exception.}

@defparam[current-transaction-retry-delay retry-delay-secs (>=/c 0) #:value 0.1]{
A parameter that controls the number of seconds @racket[call-with-transaction/retry] will wait between attempts to retry a transaction that fails with a @racket[exn:fail:sql:busy?] exception.}

@defproc[(query [stmt (or/c string? virtual-statement? prepared-statement?)]
                [arg any/c] ...
                [#:db db connection? (current-db)]
                [#:log? log? any/c (current-log-db-queries?)]
                [#:explain? explain? any/c (current-explain-db-queries?)]
                [#:analyze? analyze? any/c (current-analyze-db-queries?)])
         (or/c simple-result? rows-result?)]{
Like @id-from-db[query], but uses the @tech{current database connection} by default and supports automatic query logging and instrumentation. If enabled, all log messages are written to @racket[toolbox:db-logger] on topic @racket['toolbox:db:query] at level @racket['info].

If @racket[log?] is not @racket[#f], the SQL text of @racket[stmt] is logged before the query is executed, and the query’s (wall clock) execution time is logged after the execution completes.

If @racket[explain?] is not @racket[#f], a textual representation of the database system’s query plan is logged before the query is executed. Currently, this option is only supported with SQLite; an @racket[exn:fail:unsupported] exception will be raised with other database systems.

If @racket[analyze?] is not @racket[#f], the query plan is logged in the same way as for @racket[explain?], but the plan is logged @emph{after} executing the query, and it is annotated with performance information collected during the query’s execution. Like @racket[explain?], this option is currently only supported with SQLite.

@(toolbox-examples
  #:hidden (define log-writer
             (spawn-pretty-log-writer (make-log-receiver toolbox:db-logger 'debug)))
  (current-db (sqlite3-connect #:database 'memory))
  (query
   #:log? #t
   #:analyze? #t
   (string-join
    '("WITH RECURSIVE"
      "  fib(i,a,b) AS"
      "  (SELECT 1, 0, 1"
      "   UNION ALL"
      "   SELECT i+1, b, a+b FROM fib"
      "   WHERE i <= 10)"
      "SELECT b FROM fib ORDER BY i")
    "\n"))
  #:hidden (close-log-writer log-writer))}

@(define (make-query-proc-flow id-from-db-elem)
   @list{Like @id-from-db-elem, but uses the @tech{current database connection} by default and supports automatic query logging and instrumentation like @racket[query]. See the documentation for @racket[query] for information about the behavior of @racket[_log?], @racket[_explain?], and @racket[_analyze?].})

@(define-syntax-rule (defqueryproc proc-id result-ctc)
   @defproc[(proc-id [stmt (or/c string? virtual-statement? prepared-statement?)]
                     [arg any/c] (... ...)
                     [#:db db connection? (current-db)]
                     [#:log? log? any/c (current-log-db-queries?)]
                     [#:explain? explain? any/c (current-explain-db-queries?)]
                     [#:analyze? analyze? any/c (current-analyze-db-queries?)])
            result-ctc]{
   @(make-query-proc-flow @id-from-db[proc-id])})

@defqueryproc[query-exec void?]

@defproc[(query-rows [stmt (or/c string? virtual-statement? prepared-statement?)]
                     [arg any/c] ...
                     [#:db db connection? (current-db)]
                     [#:group groupings
                      (let* ([field/c (or/c string? exact-nonnegative-integer?)]
                             [grouping/c (or/c field/c (vectorof field/c))])
                        (or/c grouping/c (listof grouping/c)))
                      '()]
                     [#:group-mode group-mode
                      (listof (or/c 'preserve-null 'list))
                      '()]
                     [#:log? log? any/c (current-log-db-queries?)]
                     [#:explain? explain? any/c (current-explain-db-queries?)]
                     [#:analyze? analyze? any/c (current-analyze-db-queries?)])
         result-ctc]{
@(make-query-proc-flow @id-from-db[query-rows])}

@defqueryproc[query-list list?]
@defqueryproc[query-row vector?]
@defqueryproc[query-maybe-row (or/c vector? #f)]
@defqueryproc[query-value any/c]
@defqueryproc[query-maybe-value any/c]

@defboolparam[current-log-db-queries? log? #:value #f]{
A parameter that controls whether functions like @racket[query] should log each query’s SQL text; see the documentation for @racket[query] for details.}

@defboolparam[current-explain-db-queries? explain? #:value #f]{
A parameter that controls whether functions like @racket[query] should log each query’s query plan before execution; see the documentation for @racket[query] for details.}

@defboolparam[current-analyze-db-queries? analyze? #:value #f]{
A parameter that controls whether functions like @racket[query] should log each query’s profiled query plan after execution; see the documentation for @racket[query] for details.}

@defproc[(query-changes [#:db db connection? (current-db)])
         exact-nonnegative-integer?]{
Returns the number of database rows that were changed, inserted, or deleted by the most recently completed @tt{INSERT}, @tt{DELETE}, or @tt{UPDATE} statement. Currently only supported with SQLite; an @racket[exn:fail:unsupported] exception will be raised with other database systems.}

@defthing[toolbox:db-logger logger?]{
A @reftech{logger} used by various functions in @racketmodname[toolbox/db/base].}

@defproc[(exn:fail:sql:busy? [v any/c]) boolean?]{
Returns @racket[#t] if @racket[v] is an @racket[exn:fail:sql] exception and @racket[(exn:fail:sql-sqlstate v)] is @racket['busy]. Otherwise, returns @racket[#f].}

@defproc[(exn:fail:sql:constraint? [v any/c]) boolean?]{
Returns @racket[#t] if @racket[v] is an @racket[exn:fail:sql] exception and @racket[(exn:fail:sql-sqlstate v)] is @racket['constraint]. Otherwise, returns @racket[#f].}
