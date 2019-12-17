(define-module (modules file-uploads)
  #:use-module (ice-9 match)
  #:use-module (artanis utils)
  #:use-module (rnrs bytevectors)

  #:export (*valid-meta-header*
            meta-header-length
            headline?
            subbv=?
            header-trim
            ->mfd-header
            parse-body))


(define *valid-meta-header* (string->utf8 "Content-Disposition:"))
(define meta-header-length (bytevector-length *valid-meta-header*))
(define (headline? body boundary from)
  (define blen (bytevector-length boundary))
  (let ((start (+ from blen 2)))
    (and (subbv=? body boundary from (+ from blen -1)) ; first line is boundary
         (subbv=? body *valid-meta-header* start
                  (+ start meta-header-length -1)))))
(define* (subbv=? bv bv2 #:optional (start 0) (end (1- (bytevector-length bv))))
  (and (<= (bytevector-length bv2) (bytevector-length bv))
       (let lp((i end) (j (1- (bytevector-length bv2))))
         (cond
          ((< i start) #t)
          ((= (bytevector-u8-ref bv i) (bytevector-u8-ref bv2 j))
           (lp (1- i) (1- j)))
          (else #f)))))
(define (header-trim s)
  ;; NOTE: We need to trim #\return.
  ;;       Since sometimes we encounter "\n\r" rather than "\n" as newline.
  (string-trim-both s (lambda (c) (member c '(#\sp #\" #\return)))))
(define (->mfd-header line)
  (define (-> l)
    (define (-? x) (= 1 (length x)))
    (let lp((n l) (ret '()))
      (cond
       ((null? n) (reverse! ret))
       (else
        (let* ((p (car n))
               (z (string-split p #\=))
               (y (if (-? z)
                      (string-trim-both p)
                      (map header-trim z))))
          (lp (cdr n) (cons y ret)))))))
  (match (string-split line #\:)
    ((k v)
     (-> `(,k ,@(string-split v #\;))))
    (else (throw 'artanis-err 400 ->mfd-header
                 "->mfd-headers: Invalid MFD header!" line))))

(define (parse-body boundary body)
  (define-syntax-rule (-> h k) (and=> (assoc-ref h k) car))
  (define len (bytevector-length body))
  (define blen (bytevector-length boundary))
  (define (is-boundary? from)
    (subbv=? body boundary from (+ from blen -1)))
  (define (is-end-line? from)
    (and (is-boundary? from)
         (subbv=? body #vu8(45 45) (+ from blen) (+ from blen 1))))
  (define (blankline? from)
    (subbv=? body #u8(13 10) from (+ from 1)))
  (define (get-headers from)
    (cond
     ((headline? body boundary from)
      ;(let ((start (+ from blen 2)) (end (bv-read-line body (+ from blen 2))))
      ;  (if (blankline? start)
      ;    (let ((start (+ start (- end 1))) (end bv-read-line body (+ start (- end 1))))
      ;      (subbv->string body "utf-8" start end))
      ;    #f))
      (let lp((start (+ from blen 2)) (end (bv-read-line body (+ from blen 2))) (ret '()))
        (cond
         ((blankline? start) (cons ret (1+ end))) ; end of headers
         (else
          (let ((line (subbv->string body "utf-8" start end))
                (llen (- end start -1)))
            (lp (+ start llen) (bv-read-line body (+ start llen))
                (cons (->mfd-header line) ret)))))))
     (else (throw 'artanis-err 400 get-headers
                  "Invalid Multi Form Data header!" body))))
  (define (get-content-end from)
    (define btable (build-bv-lookup-table boundary))
    (let lp((i from))
      (cond
       ((and (< (+ i blen) len)
             (not (hash-ref btable (bytevector-u8-ref body (+ i blen -1)))))
        (lp (+ i blen)))
       ((is-boundary? i) i)
       (else (lp (1+ i))))))
  ;; ENHANCEMENT: use Fast String Matching to move forward quicker
  ;;(lp (1+ (bv-read-line body i)))))))
  (let lp((i 0) (mfds '()))
    (cond
     ((is-end-line? i) mfds)
     ((<= i len)
      (let* ((hp (get-headers i))
             (headers (car hp))
             (start (cdr hp))
             (end (get-content-end start))
             (dispos (assoc-ref headers "Content-Disposition"))
             (filename (-> dispos "filename"))
             (name (-> dispos "name"))
             (type (-> headers "Content-Type"))
             ;(mfd (make-mfd (car dispos) name filename start end type)))
             (val (if filename #f (cons (string->symbol name) (subbv->string body "utf-8" start (- end 2))))))
        (lp end (cons val mfds))))
     (else (throw 'artanis-err 422 parse-body
                  "Wrong multipart form body!")))))
