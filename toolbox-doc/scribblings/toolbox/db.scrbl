#lang scribble/manual

@(begin
   (require "private/common.rkt")
   (define-id-referencer db db/base))

@title[#:tag "db" #:style 'toc]{Database}

@local-table-of-contents[]

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

If @racket[analyze?] is not @racket[#f], the query plan is logged in the same way as for @racket[explain?], but the plan is logged @emph{after} executing the query, and it is annotated with performance information collected during the query’s execution. Like @racket[explain?], this option is currently only supported with SQLite, but @racket[analyze?] additionally requires that SQLite was compiled with the @tt{SQLITE_ENABLE_STMT_SCANSTATUS} compile-time option. The @racket[sqlite3-stmt-scanstatus-enabled?] function can be used to check whether this is the case.

@(toolbox-examples
  #:hidden (define log-writer
             (spawn-pretty-log-writer (make-log-receiver toolbox:db-logger 'debug)))
  (current-db (sqlite3-connect #:database 'memory))
  (define can-analyze? (sqlite3-stmt-scanstatus-enabled?))
  (query
   #:log? #t
   #:explain? (not can-analyze?)
   #:analyze? can-analyze?
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
         (listof vector?)]{
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

@defproc[(map-sql-nullable [proc (-> any/c any/c)] [v any/c]) any/c]{
If @racket[v] is @racket[sql-null], returns @racket[sql-null], otherwise returns @racket[(proc v)].

@(toolbox-examples
  (eval:check (map-sql-nullable add1 1) 2)
  (eval:check (map-sql-nullable add1 sql-null) sql-null))}

@defform[(lifted-statement expr)
         #:contracts ([expr (or/c string? (-> dbsystem? string?))])]{
Equivalent to @racket[(#%lift (virtual-statement expr))]. That is, @racket[lifted-statement] is like @racket[virtual-statement], except that it is implicitly lifted to the top of the enclosing module (so @racket[expr] may not reference local variables). This allows a @dbtech{virtual statement} to be declared inline, where it is used.

Also see @racket[~stmt], which combines @racket[lifted-statement] and @racket[~sql].}

@defthing[toolbox:db-logger logger?]{
A @reftech{logger} used by various functions in @racketmodname[toolbox/db/base]. Its parent logger is @racket[toolbox-logger].}

@defproc[(exn:fail:sql:busy? [v any/c]) boolean?]{
Returns @racket[#t] if @racket[v] is an @racket[exn:fail:sql] exception and @racket[(exn:fail:sql-sqlstate v)] is @racket['busy]. Otherwise, returns @racket[#f].}

@defproc[(exn:fail:sql:constraint? [v any/c]) boolean?]{
Returns @racket[#t] if @racket[v] is an @racket[exn:fail:sql] exception and @racket[(exn:fail:sql-sqlstate v)] is @racket['constraint]. Otherwise, returns @racket[#f].}

@section[#:tag "db:sql"]{Formatting SQL}
@defmodule[toolbox/db/sql]

@defproc[(~sql [v pre-sql?] ...) string?]{
Converts each @racket[v] argument to a string then concatenates the results. The arguments are converted according to the following rules:

@itemlist[
 @item{If @racket[v] is a @reftech{string}, it is used directly.}
 @item{If @racket[v] is a @reftech{symbol}, it is formatted as a SQL identifier using @racket[sql:id].}
 @item{If @racket[v] is an @reftech[#:key "exact number"]{exact} @reftech{integer}, it is converted using @racket[number->string].}
 @item{If @racket[v] is any other @reftech{rational number}, it is converted to a @reftech{flonum} using @racket[real->double-flonum], then converted to a string using @racket[number->string].}
 @item{If @racket[v] is @racket[sql-null], it is converted to the string @racket["NULL"].}]

@(toolbox-examples
  (~sql "SELECT " 'id " FROM " 'comment " WHERE " 'rating " > " 0.75))

The @racket[~sql] function is especially useful when used @seclink["reader" #:doc '(lib "scribblings/scribble/scribble.scrbl")]|{@ syntax}| via the @racketmodname[at-exp] language.

Example:

@codeblock[#:keep-lang-line? #f]|{
 #lang at-exp racket/base
 @~sql{SELECT name FROM user WHERE id IN @sql:tuple*[user-ids]}}|}

@defform[(~stmt expr ...)
         #:contracts ([expr pre-sql?])]{
Equivalent to @racket[(lifted-statement (~sql expr #,m...))]. The @racket[expr] forms may not reference local variables.}

@defproc[(sql:id [name (or/c symbol? string?)]) string?]{
Quotes @racket[name] as a SQL identifier by surrounding it with double quotes. If @racket[name] contains double quotes, they are escaped by doubling.

@(toolbox-examples
  (eval:check (sql:id "hello") "\"hello\"")
  (eval:check (sql:id "weird\"id") "\"weird\"\"id\""))}

@defproc[(sql:string [name (or/c symbol? string?)]) string?]{
Quotes @racket[name] as a SQL string literal by surrounding it with single quotes. If @racket[name] contains single quotes, they are escaped by doubling.

@(toolbox-examples
  (eval:check (sql:string "hello") "'hello'")
  (eval:check (sql:string "it's") "'it''s'"))}

@defproc[(sql:seq [v pre-sql?] ...) string?]{
Converts each @racket[v] to a string using @racket[~sql], then concatenates the results with @racket[","] between consecutive items.

@(toolbox-examples
  (eval:check (sql:seq 1 2 3) "1,2,3"))}

@defproc[(sql:seq* [v pre-sql?] ... [vs (listof pre-sql?)]) string?]{
Like @racket[sql:seq], but the last argument is used as a list of arguments for @racket[sql:seq]. In other words, the relationship between @racket[sql:seq] and @racket[sql:seq*] is the same as the one between @racket[string-append] and @racket[string-append*].

@(toolbox-examples
  (eval:check (sql:seq* 1 2 '(3 4)) "1,2,3,4"))}

@defproc[(sql:tuple [v pre-sql?] ...) string?]{
Like @racket[sql:seq], but the resulting string is additionally wrapped in parentheses.

@(toolbox-examples
  (eval:check (sql:tuple 1 2 3) "(1,2,3)"))}

@defproc[(sql:tuple* [v pre-sql?] ... [vs (listof pre-sql?)]) string?]{
Like @racket[sql:tuple], but the last argument is used as a list of arguments for @racket[sql:tuple]. In other words, the relationship between @racket[sql:tuple] and @racket[sql:tuple*] is the same as the one between @racket[string-append] and @racket[string-append*].

@(toolbox-examples
  (eval:check (sql:tuple* 1 2 '(3 4)) "(1,2,3,4)"))}

@defproc[(query:bag [vs (listof pre-sql?)]) string?]{
Builds a SQL query that returns rows of exactly one column, where each element of @racket[vs] is an expression that supplies the value of one of the rows.

@(toolbox-examples
  (query:bag '(1 2 3))
  (query:bag '()))

In a sense, @racket[query:bag] is the inverse of @racket[query-list]. However, because the query contains no @tt{ORDER BY} clause, the order of the resulting rows cannot be guaranteed. If the order of @racket[vs] is important, @racket[query:indexed-list] should be used instead.}

@defproc[(query:indexed-list [vs (listof pre-sql?)]) string?]{
Like @racket[query:bag], but the resulting query contains two columns. The first column is a (zero-based) index corresponding to the index of each element @racket[_v] in @racket[vs], while the second column is the value of the expression @racket[_v] itself.

@(toolbox-examples
  #:hidden (current-db (sqlite3-connect #:database 'memory))
  (query:indexed-list '(1 2 3))
  (query:indexed-list '())
  (eval:check (query-list
               (~sql "WITH nums(i,n) AS (" (query:indexed-list (range 10)) ")\n"
                     "SELECT n*n FROM nums ORDER BY i"))
              '(0 1 4 9 16 25 36 49 64 81)))}

@defproc[(query:rows [rows (listof (vectorof pre-sql?))]
                     [#:columns num-columns (or/c exact-nonnegative-integer? #f) #f])
         string?]{
Builds a SQL query that returns a row for each element @racket[_row] of @racket[rows], where each element of @racket[_row] is an expression that supplies the value of one of the columns in the row. Each @racket[_row] must have the same length.

If @racket[num-columns] is not @racket[#f], it supplies the number of columns the query should return. Otherwise, the number of columns is inferred from the length of the elements of @racket[rows]. If @racket[num-columns] is @racket[#f] and no rows are provided, an @racket[exn:fail:contract] exception is raised.

@(toolbox-examples
  (query:rows '(#(1 2) #(3 4) #(5 6)))
  (query:rows '() #:columns 2)
  (eval:error (query:rows '())))}

@defproc[(pre-sql? [v any/c]) boolean?]{
Returns @racket[#t] if @racket[v] is a @deftech{pre-SQL} value: a raw SQL @reftech{string}, a @reftech{symbol}, a @reftech{rational number}, or @racket[sql-null]. Otherwise, returns @racket[#f].

Pre-SQL values can be converted to SQL strings using @racket[~sql].}

@section[#:tag "db:define"]{Defining SQL accessors}
@defmodule[toolbox/db/define]

In addition to the bindings documented in this section, the @racketmodname[toolbox/db/define] module also re-exports @racket[field] from @racketmodname[racket/class], which is recognized as part of the syntax of @racket[define-sql-table].

@defform[#:literals [field]
         (define-sql-table table-name-id
           table-option ...
           (field field-name-id
             field-option ...)
           ...)
         #:grammar ([table-option (code:line #:sql-name table-name-expr)
                                  (code:line #:resolve resolve-expr)
                                  (code:line #:deleter maybe-name-id)]
                    [field-option (code:line #:sql-name field-name-expr)
                                  (code:line #:getter maybe-name-id)
                                  (code:line #:setter maybe-name-id)
                                  (code:line #:convert sql->racket-expr racket->sql-expr)]
                    [table-name-expr name-expr]
                    [field-name-expr name-expr]
                    [maybe-name-id (code:line)
                                   name-id])
         #:contracts ([name-expr symbol?]
                      [resolve-expr (or/c (-> any/c #:who symbol? exact-positive-integer?) #f)]
                      [sql->racket-expr (-> any/c any/c)]
                      [racket->sql-expr (-> any/c any/c)])]{
Defines functions for performing simple SQL queries against a SQL table.

The name of the SQL table is given by the result of @racket[table-name-expr]. If no @racket[table-name-expr] is provided, the SQL table name is inferred from @racket[table-name-id] by replacing all occurrences of @litchar{-} with @litchar{_} and replacing a trailing @litchar{?} with the prefix @litchar{is_}. For example, if @racket[table-name-id] were @tt{user-friend?}, the inferred SQL name would be @tt{is_user_friend}.

If the @racket[#:deleter name-id] option is provided, @racket[name-id] is defined as a deleter procedure produced by @racket[make-sql-deleter]. If @racket[#:deleter] is provided with no @racket[name-id], the name @racketplainfont{delete-@racket[table-name-id]!} is used, instead.

Each provided @racket[field] clause controls generation of getter and setter procedures for individual fields (columns) of the table. The SQL name of each field is given by @racket[field-name-expr]. If no @racket[field-name-expr] is provided, the SQL name is inferred from @racket[field-name-id] in the same way the table name may be inferred from @racket[table-name-id].

If the @racket[#:getter name-id] option is provided for a field, @racket[name-id] is defined as a getter procedure produced by @racket[make-sql-getter]. If @racket[#:getter] is provided with no @racket[name-id], the name @racketplainfont{@racket[table-name-id]-@racket[field-name-id]} is used, instead.

Likewise, if the @racket[#:setter name-id] option is provided for a field, @racket[name-id] is defined as a setter procedure produced by @racket[make-sql-setter]. If @racket[#:setter] is provided with no @racket[name-id], the name @racketplainfont{set-@racket[table-name-id]-@racket[field-name-id]!} is used, instead.

If the @racket[#:convert] option is provided for a field, the @racket[sql->racket-expr] and @racket[racket->sql-expr] expressions are used as the @racket[#:convert] arguments to @racket[make-sql-getter] and @racket[make-sql-setter], respectively.

If the @racket[#:resolve] table option is provided, the procedure produced by @racket[resolve-expr] is used as the @racket[#:resolve] argument to @racket[make-sql-deleter], @racket[make-sql-getter], and @racket[make-sql-setter].

@(toolbox-examples
  (current-db (sqlite3-connect #:database 'memory))
  (query-exec
   (~sql "CREATE TABLE user"
         "( id       INTEGER NOT NULL PRIMARY KEY"
         ", name     TEXT    NOT NULL"
         ", is_admin INTEGER NOT NULL DEFAULT (0)"
         "           CHECK (is_admin IN (0, 1)) )"))
  (define-sql-table user
    (field name #:getter #:setter)
    (field admin? #:getter #:setter
      #:convert integer->boolean boolean->integer))
  (query-exec
   (~sql "INSERT INTO user(id, name) VALUES (1, 'Alyssa'), (2, 'Ben')"))
  (eval:check (user-name 1) "Alyssa")
  (eval:check (user-name 2) "Ben")
  (set-user-admin?! 1 #t)
  (eval:check (user-admin? 1) #t)
  (eval:check (user-admin? 2) #f))}

@defproc[(make-sql-deleter [#:table table-name symbol?]
                           [#:who who symbol?]
                           [#:resolve resolve-proc
                            (or/c (-> any/c #:who symbol? exact-positive-integer?) #f)
                            #f])
         (->* [any/c] [#:who symbol? #:resolve? any/c] void?)]{
Builds a deleter procedure that accepts a primary key for the SQL table given by @racket[table-name] and executes the following query:

@nested[#:style 'code-inset]{@verbatim{DELETE FROM @racket[(sql:id table-name)] WHERE id = ?}}

If @racket[resolve-proc] is not @racket[#f], it is used to compute a primary key from the argument provided to the deleter procedure unless @racket[#:resolve? #f] is supplied. The call to @racket[resolve-proc] and the @tt{DELETE} statement are both executed within the same database transaction.

The @racket[who] argument is used as the name of the deleter procedure, as returned by @racket[object-name], and it is used in error messages reported by the deleter procedure. It is also passed to @racket[resolve-proc], if provided, via the @racket[#:who] keyword argument.}

@defproc[(make-sql-getter [#:table table-name symbol?]
                          [#:field field-name symbol?]
                          [#:who who symbol?]
                          [#:resolve resolve-proc
                           (or/c (-> any/c #:who symbol? exact-positive-integer?) #f)
                           #f]
                          [#:convert convert-proc (-> any/c any/c) values])
         (->* [any/c] [#:who symbol? #:resolve? any/c] any/c)]{
Builds a getter procedure that accepts a primary key for the SQL table given by @racket[table-name] and executes the following query:

@nested[#:style 'code-inset]{@verbatim{SELECT @racket[(sql:id field-name)] FROM @racket[(sql:id table-name)] WHERE id = ?}}

The @racket[convert-proc] argument is applied to the result of the @tt{SELECT} statement to produce a result for the getter procedure.

If @racket[resolve-proc] is not @racket[#f], it is used to compute a primary key from the argument provided to the getter procedure unless @racket[#:resolve? #f] is supplied. The call to @racket[resolve-proc] and the @tt{SELECT} statement are both executed within the same database transaction.

The @racket[who] argument is used as the name of the getter procedure, as returned by @racket[object-name], and it is used in error messages reported by the getter procedure. It is also passed to @racket[resolve-proc], if provided, via the @racket[#:who] keyword argument.}

@defproc[(make-sql-setter [#:table table-name symbol?]
                          [#:field field-name symbol?]
                          [#:who who symbol?]
                          [#:resolve resolve-proc
                           (or/c (-> any/c #:who symbol? exact-positive-integer?) #f)
                           #f]
                          [#:convert convert-proc (-> any/c any/c) values])
         (->* [any/c any/c] [#:who symbol? #:resolve? any/c] void?)]{
Builds a setter procedure that accepts a primary key and a value for the SQL table and column given by @racket[table-name] and @racket[field-name] and executes the following query:

@nested[#:style 'code-inset]{@verbatim{UPDATE @racket[(sql:id table-name)] SET @racket[(sql:id field-name)] = ? WHERE id = ?}}

The @racket[convert-proc] argument is applied to the second argument of the of the setter procedure to produce a value to be used as the first parameter of the @tt{UPDATE} statement.

If @racket[resolve-proc] is not @racket[#f], it is used to compute a primary key from the first argument provided to the setter procedure unless @racket[#:resolve? #f] is supplied. The call to @racket[resolve-proc] and the @tt{UPDATE} statement are both executed within the same database transaction.

The @racket[who] argument is used as the name of the setter procedure, as returned by @racket[object-name], and it is used in error messages reported by the setter procedure. It is also passed to @racket[resolve-proc], if provided, via the @racket[#:who] keyword argument.}

@section[#:tag "db:sqlite3"]{SQLite}
@defmodule[toolbox/db/sqlite3]

@defproc[(sqlite3-stmt-scanstatus-enabled?) boolean?]{
Returns @racket[#t] if the loaded SQLite library was compiled with @tt{SQLITE_ENABLE_STMT_SCANSTATUS}, which is required if query profiling is enabled in @racket[query] via the @racket[#:analyze?] option. Otherwise, returns @racket[#f].}

@defproc[(boolean->integer [v any/c]) (or/c 0 1)]{
If @racket[v] is @racket[#f], returns @racket[0], otherwise returns @racket[1].}

@defproc[(integer->boolean [v (or/c 0 1)]) boolean?]{
If @racket[v] is @racket[0], returns @racket[#f], otherwise returns @racket[#t].}

@defproc[(->posix/integer [v datetime-provider?]) exact-integer?]{
Equivalent to @racket[(floor (->posix v))].}

@defproc[(->jd/double [v datetime-provider?]) (and/c rational? flonum?)]{
Equivalent to @racket[(real->double-flonum (->jd v))].}
