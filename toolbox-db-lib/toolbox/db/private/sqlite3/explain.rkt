#lang racket/base

(require racket/contract
         racket/format
         racket/match
         racket/string
         toolbox/format
         toolbox/list
         "ffi.rkt")

(provide (contract-out
          [eqp-root? predicate/c]
          [build-query-plan-explanation (-> (listof vector?) eqp-root?)]
          [build-query-plan-explanation/scan-status (-> sqlite3_statement? eqp-root?)]
          [print-query-plan-explanation (->* [eqp-root?] [output-port?] void?)]))

;; -----------------------------------------------------------------------------

(struct eqp-root (cycles children) #:transparent)
(struct eqp-node (description stats children) #:transparent)
(struct eqp-stats (loops rows est cycles) #:transparent)

;; Builds a query plan explanation from the rows returned by EXPLAIN QUERY PLAN.
(define (build-query-plan-explanation rows)
  (match-define-values ['() nodes]
    (let loop ([rows rows]
               [parent-id 0])
      (match rows
        ['() (values '() '())]
        [(cons (vector this-id this-parent-id _ description) rows1)
         (cond
           [(= this-parent-id parent-id)
            (define-values [rows2 children] (loop rows1 this-id))
            (define this-node (eqp-node description #f children))
            (define-values [rows3 siblings] (loop rows2 parent-id))
            (values rows3 (cons this-node siblings))]
           [else
            (values rows '())])])))
  (eqp-root #f nodes))

;; Builds a query plan explanation using sqlite3_stmt_scanstatus_v2.
(define (build-query-plan-explanation/scan-status stmt)
  (define (stat* idx op)
    (sqlite3_stmt_scanstatus_v2 stmt idx op SQLITE_SCANSTAT_COMPLEX))
  (define (neg->false v)
    (if (negative? v) #f v))

  (match-define-values [#f nodes]
    (let loop ([idx 0]
               [parent-id 0])
      (define (stat op)
        (stat* idx op))
      (cond
        [(and idx (stat SQLITE_SCANSTAT_SELECTID))
         => (λ (this-id)
              (define this-parent-id (stat SQLITE_SCANSTAT_PARENTID))
              (define description (stat SQLITE_SCANSTAT_EXPLAIN))

              (define loops (neg->false (stat SQLITE_SCANSTAT_NLOOP)))
              (define rows (neg->false (stat SQLITE_SCANSTAT_NVISIT)))
              (define cycles (neg->false (stat SQLITE_SCANSTAT_NCYCLE)))
              (define stats
                (and (or loops rows cycles)
                     (eqp-stats loops
                                rows
                                (and loops rows (neg->false (stat SQLITE_SCANSTAT_EST)))
                                cycles)))
              (cond
                [(= this-parent-id parent-id)
                 (define-values [idx2 children] (loop (add1 idx) this-id))
                 (define this-node (eqp-node description stats children))
                 (define-values [idx3 siblings] (loop idx2 parent-id))
                 (values idx3 (cons this-node siblings))]
                [else
                 (values idx '())]))]
        [else
         (values #f '())])))

  (eqp-root (neg->false (stat* -1 SQLITE_SCANSTAT_NCYCLE)) nodes))

(define (print-query-plan-explanation root-node [out (current-output-port)])
  (match-define (eqp-root total-cycles nodes) root-node)

  (write-string "QUERY PLAN" out)
  (when total-cycles
    (fprintf out " [cycles=~a]" (~r* total-cycles)))
  (newline out)

  (define max-description-width
    (let loop ([start-width 2]
               [nodes nodes])
      (for/fold ([max-width start-width])
                ([node (in-list nodes)])
        (max max-width
             (+ start-width (string-length (eqp-node-description node)))
             (loop (+ start-width 2) (eqp-node-children node))))))

  (let loop ([nodes nodes]
             [prefix-str ""])
    (define num-nodes (length nodes))
    (for ([(node i) (in-indexed (in-list nodes))])
      (match-define (eqp-node description stats children) node)
      (define last? (= (add1 i) num-nodes))

      (define-values [this-prefix child-prefix]
        (if last?
            (values "╰╴" "  ")
            (values "├╴" "│ ")))

      (write-string prefix-str out)
      (write-string this-prefix out)
      (write-string description out)

      (when stats
        (match-define (eqp-stats loops rows est cycles) stats)

        (for ([i (in-range (add1 (- max-description-width
                                    (string-length prefix-str)
                                    (string-length this-prefix)
                                    (string-length description))))])
          (write-char #\space out))

        (cond
          [(and cycles total-cycles (not (zero? total-cycles)))
           (write-string (~r* (* (/ cycles total-cycles) 100)
                              #:min-width 5
                              #:precision '(= 1))
                         out)
           (write-string "% " out)]
          [else
           (write-string "       " out)])

        (write-char #\[ out)
        (write-string
         (string-join
          `[,@(when/list* est
                `[,(~a "est=" (~r* est #:precision '(= 1)))
                  ,@(when/list (not (zero? loops))
                      (~a "actual=" (~r* (/ rows loops) #:precision '(= 1))))])

            ,@(when/list loops (~a "loops=" (~r* loops)))
            ,@(when/list rows (~a "rows=" (~r* rows)))
            ,@(when/list cycles (~a "cycles=" (~r* cycles)))]
          " ")
         out)
        (write-char #\] out))

      (newline out)
      (loop children
            (string-append prefix-str child-prefix)))))

