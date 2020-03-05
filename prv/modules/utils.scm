(define-module (modules utils)
  #:use-module (artanis artanis)
  #:use-module (artanis utils)
  #:use-module (rnrs bytevectors)
  #:use-module (ice-9 iconv)
  #:use-module (ice-9 i18n)
  #:use-module (ice-9 popen) ; for system pipes
  #:use-module (ice-9 rdelim) ;^^^
  #:use-module (ice-9 textual-ports) ;^^^
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-19)

  #:export (escape-brd
            escape-str
            convert-size
            get-image-dimensions
            get-video-dimensions
            get-uncompressed-size
            get-mimetype
            make-image-thumbnail
            make-video-thumbnail
            uncompress
            write-file
            human-readable-interval
            check-string-limits
            truncate-comment
            get-all-alist-keys
            random-string
            separate-extension
            shorten
            get-ip
            get-timestamp13
            get-timestamp10
            ;send-html
            ;send-error
            get-cookie-alist
            default
            or-blank
            read-file
            bv->alist
            split-form
            replace))

(define (escape-brd brd)
  (let next-char ((board
                   (string->list
                    (escape-str brd #:char-encoding '((#\" . "")
                                                      (#\' . "")
                                                      (#\/ . ""))))))
    (if (and (not (null? board))
             (eq? #\. (car board)))
      (next-char (cdr board))
      (if (null? board)
        #f
        (list->string board)))))
    
(define* (escape-str str #:key
                     (char-encoding
                      '((#\< . "&lt;")
                        (#\> . "&gt;")
                        (#\& . "&amp;")
                        (#\" . "&quot;")
                        (#\' . "&#x27;")
                        (#\\ . "&#92;"))))
  (let ((bad-chars (list->char-set (map car char-encoding))))
    (let ((bad-pos (string-index str bad-chars 0))
          (port (open-output-string)))
      (if (not bad-pos)
          (display str port)          ; str had all good chars
          (let loop ((from 0) (to bad-pos))
            (cond
             ((>= from (string-length str)) *unspecified*)
             ((not to)
              (display (substring str from (string-length str)) port))
             (else
              (let ((quoted-char
                     (cdr (assv (string-ref str to) char-encoding)))
                    (new-to
                     (string-index str bad-chars (+ 1 to))))
                (if (< from to)
                    (display (substring str from to) port))
                (display quoted-char port)
                (loop (1+ to) new-to))))))
      (let ((out (get-output-string port)))
        (close-output-port port)
        out))))

(define (convert-size size)
  (let* ((idx (inexact->exact (floor (/ (log size) (log 1024)))))
         (pow (expt 1024 idx))
         (csize (/ (inexact->exact (round (* (/ size pow) 100))) 100.0)))
    (if (> csize 0)
      (string-append
       (number->string csize)
       (list-ref '("B" "KB" "MB") idx))
      "0B")))

(define (get-image-dimensions file)
  (let* ((port (open-pipe* OPEN_READ "identify" "-format" "%wx%h" (string-append file "[0]")))
         (dims (read-line port)))
    (close-pipe port)
(display file)(newline)
    (if (string-prefix? "identify:" dims)
      #f
      dims)))

(define (get-video-dimensions video)
  (let* ((port (open-pipe* OPEN_READ "ffprobe" "-v" "error" "-select_streams" "v:0" "-show_entries" "stream=width,height" "-of" "csv=s=x:p=0" video))
         (dims (read-line port)))
    (close-pipe port)
	(display dims)(newline)
    (if (or (eof-object? dims) (string-contains dims "Invalid"))
      #f
      dims)))

(define (get-uncompressed-size file)
  (let* ((port (open-pipe* OPEN_READ "gzip" "-l" file)) ; | tail -1 | awk '{print $2}'")))
         (out (string-split (get-string-all port) #\newline)))
    (close-pipe port)
    (if (= 3 (length out))
      (string->number (cadr (delete "" (string-split (cadr out) #\space))))
      #f)))

(define (get-mimetype file)
  (let* ((port (open-pipe* OPEN_READ "file" "-b" "--mime-type" file))
         (mime (string->symbol (read-line port))))
    (close-pipe port)
    (case mime
      ((image/gif) 'GIF)
      ((image/jpeg) 'JPEG)
      ((image/png) 'PNG)
      ((image/webp) 'WEBP)
      ((video/mp4) 'MP4)
      ((video/x-matroska) 'MKV)
      ((video/webm) 'WEBM)
      ((audio/flac) 'FLAC)
      ((audio/x-m4a) 'M4A)
      ((audio/mpeg) 'MP3)
      ((audio/ogg) 'OGG)
      ((audio/x-wav) 'WAV)
      ((audio/x-ms-asf) 'WMA)
      ((application/x-shockwave-flash) 'SWF)
      ((application/x-gzip application/gzip)
       (if (equal? "html5" (string-downcase (cdr (separate-extension file))))
           'HTML5 'GZIP))
      ((application/octet-stream) 'OCTET)
      (else mime))))

(define (make-image-thumbnail infile max-dimensions outfile)
  (let ((port (open-pipe* OPEN_READ "convert" (string-append infile "[0]")
                          "-resize" (string-append max-dimensions "x" max-dimensions ">")
                          outfile)))
    (close-pipe port)
    #t))

(define (make-video-thumbnail infile max-dimensions outfile)
  (let* ((port (open-pipe* OPEN_READ "ffmpeg" "-i" infile
                           "-vf" (string-append "thumbnail,scale=w=" max-dimensions ":h=" max-dimensions ":force_original_aspect_ratio=decrease")
                           "-frames:v" "1"
                           "-f" "singlejpeg"
                           outfile)))
    (close-pipe port)
    #t))

(define (uncompress inpath outpath)
  (let* ((port (open-pipe* OPEN_READ
                           "tar" "xfz" inpath "-C" outpath)))
    (close-pipe port)
    #t))

(define (write-file filename str)
  (with-output-to-file filename
    (lambda ()
      (let loop ((ls1 (string->list str)))
        (if (not (null? ls1))
          (begin
            (write-char (car ls1))
            (loop (cdr ls1))))))))

(define (human-readable-interval seconds)
  (car (fold (lambda (interval current)
               (let ((val (quotient (cdr current) (cdr interval))))
                 (if (= val 0)
                   current
                   `(,(format #f "~a~a~a" (car current) val (car interval)) . ,(- (cdr current) (* val (cdr interval)))))))
             `("" . ,seconds)
             '((" years " . 31536000)
               (" months " . 2592000)
               (" days " . 86400)
               ("h " . 3600)
               ("m " . 60)
               ("s" . 1)))))


(define* (check-string-limits str max-length #:key (max-lines 1) (linebreak "\n") (length-error "Error: String length too long") (lines-error "Error: Too many lines"))
  (let ((len (string-length str))
        (lin (length (string-split2 str linebreak))))
    (cond
      ((> len max-length) (format #f "~a (~a/~a)" length-error len max-length))
      ((> lin max-lines) (format #f "~a (~a/~a)" lines-error lin max-lines))
      (else #f))))

(define (truncate-comment comment max-lines mode)
  (case mode
    ((normal) comment)
    ((preview) (let ((csplit (string-split2 comment "<br>")))
                 (if (> (length csplit) max-lines)
                   (string-append (string-join (take csplit max-lines)
                                               "<br>")
                                  "<br><span class=\"shade\">Comment too long. View thread to read entire comment.</span>")
                   comment)))
    (else comment)))

(define (string-split2 str del)
  (let loop ((str2 str))
    (let ((idx (string-contains str2 del)))
      (if idx
        (cons (substring str2 0 idx)
              (loop (substring str2 (+ idx (string-length del)))))
        (list str2)))))

(define (get-all-alist-keys alist key)
  (let next-val ((lst alist))
    (if (null? lst)
      '()
      (if (equal? (caar lst) key)
        ;(cons (eliminate-evil-HTML-entities (cdar lst)) (next-val (cdr lst)))
        (cons (escape-str (cdar lst)) (next-val (cdr lst)))
        (next-val (cdr lst))))))

(define (random-string len)
  (let ((pool "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"))
    (list->string (list-tabulate len (lambda (x) (string-ref pool (random 62)))))))

(define (separate-extension str)
  (let ((idx (string-index-right str #\.)))
    (if idx
      (cons (substring str 0 idx)
            (substring str (+ idx 1)))
      (cons str #f))))

(define* (shorten str max-len)
  (if (> (string-length str) max-len)
    (string-append (substring str 0 max-len) "…")
    str))

(define (get-ip rc) ; FIXME: we have a lot of functions accessing request and headers, can we simplify it so it only occurs 1 time per request?
  (let* ((request ((record-accessor (record-type-descriptor rc) 'request) rc))
         (headers ((record-accessor (record-type-descriptor request) 'headers) request))
         (ip (assoc-ref headers 'x-forwarded-for))
         (ip-cf (assoc-ref headers 'cf-connecting-ip)))
    (cond
      (ip-cf ip-cf)
      (ip ip)
      (else "none"))))

(define (get-timestamp13)
  (let ((ctime (current-time time-utc)))
    (inexact->exact
      (floor
        (+ (* (time-second ctime) 1000.)
           (/ (time-nanosecond ctime) 1000000.))))))
(define (get-timestamp10)
  (let ((ctime (current-time time-utc)))
    (inexact->exact
      (floor
        (+ (* (time-second ctime) 1000.)
           (/ (time-nanosecond ctime) 1000000.))))))

;(define* (send-html response #:optional (status 200))
;  (let* ((response-length (bytevector-length (string->bytevector response "utf8"))))
;    (response-emit response #:status status #:headers `((content-type . (text/html))
;                                                     (content-length . ,response-length)))))

;(define (send-error error-message env)
;  (let ((error-message error-message))
;    (send-html (tpl->response "pub/error.tpl" (the-environment)))))

(define (get-cookie-alist rc) ; FIXME: This gets run 2 times
  (let ((cookie-lst (rc-cookie rc)))
    (if (null? cookie-lst)
      '()
      (let* ((cookies (car cookie-lst))
             (nvps ((record-accessor (record-type-descriptor cookies) 'nvp) cookies)))
        (if (null? nvps)
          '()
          nvps)))))

;;; FIXME: Let's remove this function
(define (default option def)
  (if (or (null? option)
          (eq? option #f)
          (equal? option ""))
    def
    option))
(define (or-blank . rest)
  (let next-string ((str-lst rest))
    (if (null? str-lst)
      #f
      (if (or (eq? (car str-lst) #f)
              (equal? (car str-lst)  ""))
        (next-string (cdr str-lst))
        (car str-lst)))))

(define (read-file filename)
  (with-input-from-file filename
    (lambda ()
      (let loop ((ls1 '()) (c (read-char)))
        (if (eof-object? c)
          (list->string (reverse ls1))
          (loop (cons c ls1) (read-char)))))))

(define (bv->alist bv)
  (if (not bv)
    '()
    (let ((str (utf8->string bv))
          (head "\r\nContent-Disposition: form-data; name=\""))
      ;(format #t "\n\nBYTEVECTOR-STRING=[~a]\n\n" str)
      (let ((test (string-contains str head)))
        (if (not test)
          (begin (display "ERROR READING FORM DATA\n") '())
          (split-form str (substring str 0 test) (string-append (substring str 0 test) head)))))))

(define (split-form form-str token separator)
  (let loop ((str form-str)
             (idx (string-length token)))
    (if (not (string-prefix? separator str))
      '()
      (let* ((key (substring str (string-length separator) (string-index str #\" (string-length separator))))
             (end (string-contains str token idx)))
        (cons (cons (string->symbol key)
                    (substring str (+ (string-length separator) (string-length key) 5) (- end 2)))
              (loop (substring str end)
                    idx))))))

(define (replace str old new) ; FIXME: This function is shit, and shouldn't be needed anyway
  (let loop ((str str)
             (idx 0))
    (let ((jdx (string-contains str old idx)))
      (if jdx
        (loop (string-append
                (substring str 0 jdx)
                new
                (substring str (+ jdx (string-length old)) (string-length str)))
              (+ jdx (string-length new)))
        str))))
