;;; TODO:
;;;   * If comment is too long and contains tags like <span> or <i> it can cut off before the closing tag
;;;   * Delimg doesn't delete actual file for swf/html5, only the container
;;;   * code blocks like [code]1[/code] [code]2[/code] will give:  1[/code][code]2 as the block
;;;   * prune-unlisted is currently not used. We don't want to run it often.
;;;     - Perhaps run it on scheduled occasions, a field can be added to a meta table to record the next time it should be executed

(define-module (modules imageboard)
  #:use-module (artanis artanis)
  #:use-module (artanis utils)
  #:use-module (artanis cookie)
  #:use-module (artanis config)

  #:use-module (web uri)
  #:use-module (rnrs bytevectors)
  #:use-module (ice-9 regex)
  #:use-module (ice-9 i18n) ; for lowercase conversion
  ;#:use-module (ice-9 popen) ; for system pipes, used to read total zipfile size
  ;#:use-module (ice-9 rdelim) ;^^^
  #:use-module (ice-9 ftw)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-19)

  #:use-module (modules utils)
  #:use-module (modules migrations-sqlite3)
  #:use-module (modules database-calls)
  #:use-module (modules settings)
  #:use-module (modules templates)
  #:use-module (modules file-uploads) ; FIXME: is this needed in utils or imageboard.scm ?

  #:export (init-database
            root-page
            normal-pages
            admin-pages
            serve-board
            serve-catalog
            serve-thread
            serve-posts
            make-thread
            make-post
            refilter-comments
            build-javascript
            note-editor
            set-style
            mod-login
            change-password
            post-note
            mod-posts))

(set! *random-state* (random-state-from-platform))
;(define conn #f)
;(define mtable #f)

(define (init-database conn)
  ;(initialize-sqlite3-database (string-append db-name ".db") conn
  (initialize-sqlite3-database conn (map-table-from-DB conn)))

;(define (database-connection-init)
;  (set! conn (connect-db 'sqlite3 (string-append db-name ".db")))
;  (set! mtable (map-table-from-DB conn))
;  (init-database))





(define (root-page rc)
  (if (not javascript-enabled)
    (tpl->response (frames-tpl))
    (let* ((mtable (map-table-from-DB (:conn rc)))
           (path (cdr (string-split (rc-path rc) #\/)))
           (cookies (get-cookie-alist rc))
           (admin (get-admin rc mtable cookies))
           (styles (get-style rc cookies))
           (style-menu (build-style-menu styles))
           (style (car styles)))
      (tpl->response (index-tpl style style-menu admin (build-note-listing rc mtable admin #:type "news" #:limit 3))))))

(define (normal-pages rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (path (cdr (string-split (rc-path rc) #\/)))
         (cookies (get-cookie-alist rc))
         (admin (get-admin rc mtable cookies))
         (styles (get-style rc cookies))
         (style-menu (build-style-menu styles))
         (style (car styles)))
    (tpl->response
     (case (string->symbol (car path))
       ((index) (index-tpl style style-menu admin (build-note-listing rc mtable admin #:type "news" #:limit 3)))
       ((frames) (frames-tpl))
       ((frame-nav) (frame-nav-tpl style admin))
       ((about) (about-tpl style style-menu admin))
       ((rules) (rules-tpl style style-menu admin))
       ((news) (news-tpl style style-menu admin (build-note-listing rc mtable admin #:type "news")))
       ((contact) (contact-tpl style style-menu admin))
       ((login) (login-tpl style style-menu admin))
       ((logoff) (logoff-tpl style style-menu admin (mod-logoff rc mtable cookies)))))))

(define (admin-pages rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (path (cdr (string-split (rc-path rc) #\/)))
         (cookies (get-cookie-alist rc))
         (admin (get-admin rc mtable cookies))
         (styles (get-style rc cookies))
         (style-menu (build-style-menu styles))
         (style (car styles)))
    (if admin
      (tpl->response
       (case (string->symbol (car path))
         ((panel) (panel-tpl style style-menu admin
                             (build-note-listing rc mtable admin #:template note-short-tpl #:type '("notice" "public") #:limit 3)
                             (build-note-listing rc mtable admin #:template note-short-tpl #:type "note" #:shared #t #:links-target "noticeboard")
                             (build-note-listing rc mtable admin #:template note-short-tpl #:limit 3 #:personal #t)))
         ((noticeboard) (noticeboard-tpl style style-menu admin
                                         (build-note-listing rc mtable admin #:type '("notice" "public"))
                                         (build-note-listing rc mtable admin #:type "note" #:shared #t #:links-target "noticeboard")))
         ((notes-view) (notes-view-tpl style style-menu admin (build-note-listing rc mtable admin #:personal #t)))))
      (throw 'artanis-err 401 get "Unauthorized"))))

(define (serve-board rc)
  (define templates ; FIXME: Is there a better way to do this?
    `((board-tpl . (,board-tpl .
                    ,(lambda (mtable board post-template)
                       (build-threads rc mtable board #f #:mode 'preview #:page (get-from-qstr rc "page")
                                      #:preview-OP-template post-template))))
      (board-flash-tpl . (,board-flash-tpl .
                          ,(lambda (mtable board post-template)
                             (build-threads rc mtable board #f #:mode 'preview #:page (get-from-qstr rc "page")
                                            #:preview-OP-template post-template
                                            #:post-preview-count-override 0))))
      (post-OP . ,post-OP-tpl)
      (post-OP-flash . ,post-OP-flash-tpl)))
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (path (cdr (string-split (rc-path rc) #\/)))
         (cookies (get-cookie-alist rc))
         (admin (get-admin rc mtable cookies))
         (styles (get-style rc cookies))
         (style-menu (build-style-menu styles))
         (style (car styles))
         (board (escape-brd (uri-decode (cadr path))))
         (board-html (escape-str board))
         (board-uri (uri-encode board))
         (board-title (assq-ref (assoc-ref boards board) 'title))
         (password (get-password rc cookies))
         (page-count (or (assq-ref (assoc-ref boards board) 'pages) default-page-count))
         (page-len (or (assq-ref (assoc-ref boards board) 'page-len) default-page-len))
         (board-template (car (assq-ref templates
                                        (or (assq-ref (assoc-ref boards board) 'board-template) default-board-template))))
         (post-template (assq-ref templates
                                  (or (assq-ref (assoc-ref boards board) 'preview-OP-template) default-OP-template)))
         (threads ((cdr (assq-ref templates
                                  (or (assq-ref (assoc-ref boards board) 'board-template) default-board-template)))
                   mtable board post-template)))
    (tpl->response (board-template style style-menu admin board board-html board-uri board-title password page-count
                                   (build-note-listing rc mtable admin #:template note-short-tpl #:type "news" #:limit 3)
                                   threads))))

(define (serve-catalog rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (cookies (get-cookie-alist rc))
         (admin (get-admin rc mtable cookies))
         (styles (get-style rc cookies))
         (style-menu (build-style-menu styles))
         (style (car styles))
         (path (cdr (string-split (rc-path rc) #\/)))
         (board (escape-brd (uri-decode (cadr path))))
         (board-html (escape-str board))
         (board-uri (uri-encode board))
         (board-title (assq-ref (assoc-ref boards board) 'title))
         (template "catalog")
         (page-count (or (assq-ref (assoc-ref boards board) 'pages) default-page-count))
         (page-len (or (assq-ref (assoc-ref boards board) 'page-len) default-page-len)))
    (tpl->response (catalog-tpl style style-menu admin board board-html board-uri board-title
                                (build-threads rc mtable board #f #:mode 'preview #:page (get-from-qstr rc "page") #:page-len (* page-len page-count)
                                               #:preview-OP-template catalog-thread-tpl
                                               #:post-preview-count-override 0)))))

(define (serve-thread rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (path (cdr (string-split (rc-path rc) #\/)))
         (cookies (get-cookie-alist rc))
         (admin (get-admin rc mtable cookies))
         (styles (get-style rc cookies))
         (style-menu (build-style-menu styles))
         (style (car styles))
         (board (escape-brd (uri-decode (cadr path))))
         (board-html (escape-str board))
         (board-uri (uri-encode board))
         (thread (caddr path))
         (board-title (assq-ref (assoc-ref boards board) 'title))
         (password (get-password rc cookies))
         (last (let* ((tst (get-from-qstr rc "last"))
                      (num (and tst (string->number tst))))
                 (if (and num (> num 0))
                     num #f))))
    (tpl->response (thread-tpl style style-menu admin board board-html board-uri board-title password
                               (build-threads rc mtable board thread #:last last)))))

(define (serve-posts rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (cookies (get-cookie-alist rc))
         (admin (get-admin rc mtable cookies))
         (path (cdr (string-split (rc-path rc) #\/)))
         (board (escape-brd (uri-decode (cadr path))))
         (board-html (escape-str board))
         (board-uri (uri-encode board))
         (threadnum (caddr path))
         (postnums (cadddr path))
         (styles (get-style rc cookies))
         (style-menu (build-style-menu styles))
         (style (car styles)))
    (tpl->response (post-list-tpl style style-menu admin board board-html board-uri threadnum postnums
                                  (build-threads rc mtable board threadnum #:mode postnums)))))

(define (make-thread rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (path (cdr (string-split (rc-path rc) #\/)))
         (board (escape-brd (uri-decode (cadr path)))))
    (save-post rc mtable board)))

(define (make-post rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (path (cdr (string-split (rc-path rc) #\/)))
         (board (escape-brd (uri-decode (cadr path))))
         (thread (if (equal? (car path) "thread")
                     (string->number (caddr path))
                     #f)))
    (save-post rc mtable board #:existing-thread thread)))

; see reluctant-code-tags for usage
(define (make-reluctant-processor tagspec outputopen outputclose)
  (let* ((tagnames   (string-split tagspec #\space))
         (tagor      (string-join tagnames "|"))
         (regexpopen (make-regexp (string-append "\\[(" tagor ")\\]")))
         (table      (make-hash-table)))
    (for-each (lambda (s) (hash-set! table s (make-regexp (string-append "\\[/" s "\\]")))) tagnames)
    (letrec ((outside (lambda (s outlistrev)
               (let ((m (regexp-exec regexpopen s)))
                 (if m
                     (inside (match:suffix m)
                             (cons* (match:substring m)
                                    (match:prefix m)
                                    outlistrev)
                             (match:substring m 1))
                     (string-concatenate-reverse outlistrev s)))))
             (inside  (lambda (s outlistrev open)
               (let ((m (regexp-exec (hash-ref table open) s)))
                 (if m
                     (outside (match:suffix m)
                              (cons* outputclose
                                     (match:prefix m)
                                     outputopen
                                     (cdr outlistrev)))
                     (string-concatenate-reverse outlistrev s))))))
      (lambda (s) (outside s '())))))

(define reluctant-code-tags
  (make-reluctant-processor
    "codeblock code c"
    "<div class=''code''>"
    "</div>"))



(define (refilter-comments rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (cookies (get-cookie-alist rc))
         (admin (get-admin rc mtable cookies)))
    (if admin
      (begin (database-refilter mtable
              (lambda (comment board threadnum postnum)
                (format #t "refiltering: /thread/~a/~a#~a\n" board threadnum postnum)
                (comment-filter (unfilter-comment comment)
                                board (number->string threadnum))))
             (tpl->response (message-tpl "Done.")))
      (throw 'artanis-err 401 get "Unauthorized."))))

(define (unfilter-comment comment)
  (let ((tag #f))
    (regexp-substitute/global #f "<[^>]*>" comment
      'pre (lambda (m)
             (cond
              ((equal? (match:substring m) "<br>")
               "\n")
              ((string-contains (match:substring m) "/")
               (case tag
                 ((aa) (set! tag #f) "[/aa]")
                 ((spoiler) (set! tag #f) "[/spoiler]")
                 ((code) (set! tag #f) "[/code]")
                 (else "")))
              ((string-contains (match:substring m) "aa")
               (set! tag 'aa)
               "[aa]")
              ((string-contains (match:substring m) "spoiler")
               (set! tag 'spoiler)
               "[spoiler]")
              ((string-contains (match:substring m) "code")
               (set! tag 'code)
               "[code]")
              (else "")))
      'post)))


(define (build-javascript)
  (write-file "pub/js/main.js"
    (let ((sidebar-data (tpl->html (sidebar-data-tpl #f))))
      (tpl->html "pub/js/main.js.tpl" (the-environment)))))







;(define* (fill-header rc body-class pagetitle message style admin #:key (class "none"))
;  (tpl->response (string-append "pub/" (if admin master-mod-header master-header) ".tpl") (the-environment)))

;(define* (fill-footer rc styles)
;  (let ((style-menu (build-style-menu styles)))
;    (tpl->response (string-append "pub/" master-footer ".tpl") (the-environment))))

(define (check-bans mtable ip)
  (let ((bans (database-get-bans mtable ip)))
    (if (null? bans)
        #f
        "ur b&")))

(define (check-cooldown mtable ip)
  (let ((temp (database-get-cooldowns mtable ip))
        (ctime (time-second (current-time time-utc))))
    (if (null? temp)
      (begin
        (database-add-cooldowns mtable ip ctime)
        (cons #t ""))
      (let ((tier1 (assoc-ref (car temp) "tier1"))
            (tier2 (assoc-ref (car temp) "tier2"))
            (tier2-counter (assoc-ref (car temp) "counter")))
        (if (< ctime (+ tier2 tier2-cooldown))
          (if (>= tier2-counter tier2-post-limit)
            (cons #f (format #f "Error: You have made ~a posts in the last ~a seconds\nwhich is more than the configured maximum.\nPlease wait ~a more seconds and try posting again." tier2-counter tier2-cooldown (- (+ tier2 tier2-cooldown) ctime)))
            (if (< ctime (+ tier1 tier1-cooldown))
              (cons #f (format #f "Error: Post cooldown - Please wait ~a seconds and try again." (- (+ tier1 tier1-cooldown) ctime)))
              (begin
                (database-update-cooldowns mtable ip ctime)
                (cons #t ""))))
          (if (< ctime (+ tier1 tier1-cooldown))
            (cons #f (format #f "Error: Post cooldown - Please wait ~a seconds and try again." (- (+ tier1 tier1-cooldown) ctime)))
            (begin
              (database-update-tier2-cooldown mtable ip ctime)
              (cons #t ""))))))))

(define* (build-note-listing rc mtable admin #:key (id #f) (limit #f) (type "note") (order 'desc) (template note-tpl) (personal #f) (shared #f) (links-target #f))
  (let* ((notes (if id
                  (database-get-note mtable id)
                  (if personal
                    (database-get-notes-for-admin mtable order limit admin)
                    (let ((full (database-get-notes-by-type mtable order limit type)))
                      (if (not shared)
                        full
                        (remove (lambda (x)
                                  (not (member (assoc-ref (car admin) "name") (string-split (assoc-ref x "read") #\space))))
                                full)))))))
    (string-join
     (map (lambda (note)
            (let ((id (assoc-ref note "id"))
                  (type (assoc-ref note "type"))
                  (subject (assoc-ref note "subject"))
                  (name (assoc-ref note "name"))
                  (edited (assoc-ref note "edited"))
                  (date (assoc-ref note "date"))
                  ;(body (assoc-ref note "body"))
                  (body (replace (replace (assoc-ref note "body") "\\u3000" "　") "\\\\" "\\")) ; FIXME: why are these necessary? Bashslashes are not properly converted when reading from database? May need to send bug report. But this works for now.
                  (links-target (if links-target links-target
                                  (case (string->symbol (if (list? type) (car type) type))
                                    ((note) "notes-view")
                                    ((notice) "noticeboard")
                                    ((public) "noticeboard")
                                    ((news) "news")))))
              (tpl->html (template id type links-target subject name date admin body edited))))
              ;(format #f template id id subject name date (replace (replace body "\\r\\n" "<br>") "\\n" "<br>") subject (replace (replace body "\\r\\n" "\n") "\\n" "\n"))))
          notes)
     "\n")))

(define (note-editor rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (path (cdr (string-split (rc-path rc) #\/)))
         (cookies (get-cookie-alist rc))
         (admin (get-admin rc mtable cookies)) ; FIXME: is this needed if there's a built-in function to get cookie alist?
         (styles (get-style rc cookies))
         (style-menu (build-style-menu styles))
         (style (car styles))
         (board (car path))
         (id (cadr path)))
    (if (not admin)
      (throw 'artanis-err 401 get "Unauthorized.")
      (if (equal? id "new")
          (let ((note '())
                (type "note")
                (editable #t)
                (name (assoc-ref (car admin) "name"))
                (perms-read '())
                (perms-write '()))
            (tpl->response (note-editor-tpl style style-menu admin editable id type #f name #f #f #f note perms-read perms-write)))
          (let* ((note (database-get-note mtable id))
                 (name (assoc-ref (car note) "name"))
                 (type (assoc-ref (car note) "type"))
                 (perms-read (string-split (assoc-ref (car note) "read") #\space))
                 (perms-write (string-split (assoc-ref (car note) "write") #\space))
                 (readable (and admin
                                (or (member type '("notice" "public" "news"))
                                    (equal? name (assoc-ref (car admin) "name")) ;owner
                                    (member (assoc-ref (car admin) "name") perms-read))))
                 (editable (and admin
                                (or (equal? type "public")
                                    (equal? name (assoc-ref (car admin) "name")) ;owner
                                    (member (assoc-ref (car admin) "name") perms-write))))
                 (subject (assoc-ref (car note) "subject"))
                 (date (assoc-ref (car note) "date"))
                 ;(body (replace (replace (replace (assoc-ref (car note) "body") "\\u3000" "　") "\\\\" "\\") "<br>" "\n")) ; FIXME: why are these necessary? Bashslashes are not properly converted when reading from database? May need to send bug report. But this works for now.
                 (body (unfilter-comment (assoc-ref (car note) "body"))) ; FIXME: why are these necessary? Bashslashes are not properly converted when reading from database? May need to send bug report. But this works for now.
                 ;(body (replace (assoc-ref (car note) "body") "<br>" "\n")) ; FIXME: why are these necessary? Bashslashes are not properly converted when reading from database? May need to send bug report. But this works for now.
                 (links-target (case (string->symbol (if (list? type) (car type) type))
                                 ((note) "notes-view")
                                 ((notice) "noticeboard")
                                 ((public) "noticeboard")
                                 ((news) "news"))))
            (if readable
                (tpl->response (note-editor-tpl style style-menu admin editable id type links-target name date subject body note perms-read perms-write))
                (throw 'artanis-err 401 note-editor "Permission Denied.")))))))

(define (get-style rc cookies) ;; FIXME: This should not be needed
  (let* ((cookie-style (assoc-ref cookies "style")))
    (if cookie-style
      (let ((style (car cookie-style)))
        (if (member style styles)
          (cons style (delete style styles))
          styles))
      styles)))

(define (set-style rc)
  (let* ((data (bv->alist (rc-body rc)))
         (style (default (assoc-ref data 'style) "default"))
         (request ((record-accessor (record-type-descriptor rc) 'request) rc))
         (headers ((record-accessor (record-type-descriptor request) 'headers) request))
         (referer (assoc-ref headers 'referer))
         (scheme ((record-accessor (record-type-descriptor referer) 'scheme) referer)))
    (rc-set-cookie! rc `(,(new-cookie #:npv `(("style" . ,style)) #:expires 315360000 #:http-only #f)))
    ;(:cookies-set! rc 'cc "style" style)
    ;(:cookies-setattr! rc 'cc #:expires 315360000 #:path "/" #:secure #f #:http-only #f)
    ;(:cookies-update! rc) ;; FIXME: Documentation says this isn't needed, but it seems to be
    (redirect-to rc (uri-path referer))))

(define (mod-login rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (ip (get-ip rc))
         (cooldown (check-cooldown mtable (get-ip rc))))
    (if (not (car cooldown))
      (tpl->response (message-tpl (cdr cooldown)))

      (let* ((data (bv->alist (rc-body rc)))
             (name (assoc-ref data 'name))
             (password (assoc-ref data 'password))
             (mod (database-get-mod mtable name password)))
        (if (null? mod)
          (tpl->response (message-tpl "Error: Invalid login."))
          (begin
            (let ((new-key (random-string 60)))
              (database-set-mod-key mtable new-key name)
              (rc-set-cookie! rc `(,(new-cookie #:npv `(("mod-key" . ,new-key)) #:expires 315360000 #:http-only #f)))
              ;(:cookies-set! rc 'cc "admin" "1")
              ;(:cookies-setattr! rc 'cc #:expires 315360000 #:path "/" #:secure #f #:http-only #f)
              ;(:cookies-update! rc) ;; FIXME: Documentation says this isn't needed, but it seems to be

              ;; -----------------------------------------------
              (let* ((request ((record-accessor (record-type-descriptor rc) 'request) rc))
                     (headers ((record-accessor (record-type-descriptor request) 'headers) request))

                     (referer (assoc-ref headers 'referer))
                     (scheme ((record-accessor (record-type-descriptor referer) 'scheme) referer))
                     (host ((record-accessor (record-type-descriptor referer) 'host) referer))
					 (direct_uri (build-uri scheme #:host host #:path "/panel")))
                ;; -----------------------------------------------
                ;; -----------------------------------------------
                (redirect-to rc direct_uri)
				)
			))
		  ))
		)
	))

(define (mod-logoff rc mtable cookies)
  (let ((key (assoc-ref cookies "mod-key")))
    (when key
      (database-disable-mod-key mtable key))
    (rc-set-cookie! rc `(,(new-cookie #:npv `(("mod-key" . "none")) #:expires 0 #:http-only #f)))))

(define (change-password rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (data (bv->alist (rc-body rc)))
         (name (assoc-ref data 'name))
         (current-password (assoc-ref data 'current-password))
         (new-password (assoc-ref data 'new-password))
         (confirm-password (assoc-ref data 'confirm-password)))
    (if (not (equal? new-password confirm-password))
      (tpl->response (message-tpl "Error: New password doesn't match confirmation field"))
      (let ((mod (database-get-mod-pass mtable name current-password)))
        (if (null? mod)
          (tpl->response (message-tpl (format #f "Error: Invalid Credentials: ~a : ~a" name current-password)))
          (begin
            (database-set-mod-pass mtable name new-password)
            (tpl->response (message-tpl "Password updated successfully."))))))))

(define* (get-password rc #:optional cookies)
  (let* ((cookies (if cookies
                      cookies (get-cookie-alist rc)))
         (pass (assoc-ref cookies "password")))
    (if pass (car pass) "")))

(define (set-password rc newpass)
  (let ((oldpass (get-password rc)))
    (when (not (equal? newpass oldpass))
      (rc-set-cookie! rc `(,(new-cookie #:npv `(("password" . ,newpass)) #:expires 315360000 #:http-only #f))))))
      ;(:cookies-set! rc 'cc "password" newpass)
      ;(:cookies-setattr! rc 'cc #:expires 315360000 #:path "/" #:secure #f #:http-only #f)
      ;(:cookies-update! rc)))) ;; FIXME: Documentation says this isn't needed, but it seems to be

(define* (get-session-id rc #:optional cookies) ; FIXME: perhaps parent functions can pass IP into this function, instead of using get-ip?
  (let ((pass (get-password rc (if cookies cookies (get-cookie-alist rc)))))
    (if (equal? pass "")
      (get-ip rc)
      pass)))

(define* (get-admin rc mtable #:optional cookies)
  (let* ((cookies (if cookies
                      cookies (get-cookie-alist rc)))
         (key (assoc-ref cookies "mod-key")))
    ;  ;; FIXME: very inelegant
    (if (and key
             (not (equal? "none" (car key))))
      (let ((mod (database-get-mod-by-key mtable key)))
        (if (null? mod)
          #f
          mod))
      #f)))

(define (build-style-menu styles)
  (string-join
    (map (lambda (n style)
           (string-append "<option value=\"" style "\">" style "</option>" (if (= n 0) "<option disabled>----------</option>" "")))
         (iota (length styles))
         styles)
    "\n"))

(define (post-string->list str)
  (define (range->list rng i)
    (let* ((a (string->number (substring rng 0 i)))
           (b (string->number (substring rng (+ i 1)))))
      (if (<= a b)
        (map number->string (iota (- b a -1) a 1))
        (map number->string (iota (- a b -1) b 1)))))

  (let loop ((lst (string-split str #\,)))
    (if (null? lst)
      '()
      (let ((i (string-contains (car lst) "-")))
        `(,@(if i (range->list (car lst) i)
                  `(,(car lst)))
          ,@(loop (cdr lst)))))))

(define (comment-filter comment board thread)
  (fold (lambda (filt str)
          (filt str))
        ;(replace (replace (replace comment "\"" "&quot;") "<" "&lt;") ">" "&gt;") ; FIXME: this is extra escaping, it seems the normal escape function misses them sometimes. Maybe needs a bug report?
        comment
        (list
          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
          ;; BEGIN LIST OF FILTER FUNCTIONS ;;
          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
          (lambda (p) ; Convert \r\n format newlines to \n newlines
            (regexp-substitute/global #f "\r\n" p
              'pre "\n" 'post))
          (lambda (p) ; URL matching
            (regexp-substitute/global #f "(http://|https://|ftp://|magnet:?)[^\r\n \\'\\\"<]+[^\r\n \\'\\\"<&.,;:?!@^$\\-]" p
              'pre
              (lambda (m)
                (let ((parts (string-split (match:substring m) #\/)))
                  (string-append "<a target=''_top'' href=''"
                                 ;(string-join
                                 ; (append `(,(car parts))
                                 ;         (map (lambda (x)
                                 ;                (uri-encode x))
                                 ;              (cdr parts)))
                                 ; "/")
                                 (match:substring m)
                                 "''>" (match:substring m) "</a>")))
                'post)) ; FIXME : add quotes around the href and target once you figure out how to escape chars properly
          (lambda (p) ; Board link
            (regexp-substitute/global #f "&gt;&gt;&gt;/*[^/]+/([^0-9]|$)" p
              'pre
              (lambda (m)
                (let* ((brd (substring (match:substring m) 13 (- (string-length (match:substring m)) 1))))
                  (format #f "<a href=''/board/~a''>~a</a>" brd (match:substring m))))
              'post))
          (lambda (p) ; Cross-page link matching
            ;(regexp-substitute/global #f "&gt;&gt;&gt;[a-zA-Z0-9/,-\\#]*[a-zA-Z0-9]" p
            (regexp-substitute/global #f "&gt;&gt;&gt;/*[^/]+/[0-9/,\\-]*[0-9]" p ; NOTE: Just make this end with a number. If you want to link to pages like >>>about#format then make a new filter
              'pre
              (lambda (m)
                (let* ((post-string (substring (match:substring m) 12))
                       (post-list (let ((tmp (string-split post-string #\/)))
                                    (if (equal? "" (car tmp))
                                      (cdr tmp) tmp))))
                  (if (not (equal? "" (car post-list)))
                    (cond
                      ((= 2 (length post-list))
                       (let ((brd (car post-list))
                             (trd (cadr post-list)))
                         (if ;(and (assoc-ref boards brd)
                             (string->number trd)
                           (string-append "<a href=/thread/" brd "/" trd ">" (match:substring m) "</a>")
                           (match:substring m))))
                      ((= 3 (length post-list))
                       (let* ((brd (car post-list))
                              (trd (cadr post-list))
                              (psts (caddr post-list))
                              (lnks (post-string->list psts)))
                         (if ;(and (assoc-ref boards brd)
                             (string->number trd)
                           ;(string-append "<a href=/thread/" brd "/" trd
                           ;               (if (= (length lnks) 1)
                           ;                 (string-append "#" psts "p")
                           ;                 (string-append "/" psts))
                           ;               ">" (match:substring m) "</a>")
                           (format #f "<a href=''/~a/~a/~a~a''>~a</a>"
                                   (if (= (length lnks) 1) "thread" "posts")
                                   brd trd
                                   (if (= (length lnks) 1) (string-append "#" psts "p")
                                                           (string-append "/" psts))
                                   (match:substring m))
                           (match:substring m))))
                      (else (match:substring m)))
                    (match:substring m))))
                    ;(cond
                    ;  ((= 1 (length post-list))
                    ;   (string-append "<a href=/" post-string ">" (match:substring m) "</a>"))
                    ;  (else (match:substring m))))))
              'post))
          (lambda (p) ; Same-thread link matching
            (regexp-substitute/global #f "&gt;&gt;[0-9/,\\-]*[0-9]" p
              ;; FIXME : ids are currently have a p suffix, this needs to be a p prefix, but there is some difficulty with the templating
              'pre
              (lambda (m)
                (let* ((post-string (substring (match:substring m) 8))
                       (post-list (string-split post-string #\/)))
                  (if (equal? "" (car post-list))
                    (match:substring m)
                    (cond
                      ((= 2 (length post-list))
                       (let* ((trd (car post-list))
                              (psts (cadr post-list))
                              (lnks (post-string->list psts)))
                         (if (string->number trd)
                           ;(string-append "<a href=/thread/" board "/" trd
                           ;               (if (= (length lnks) 1)
                           ;                 (string-append "#" psts "p")
                           ;                 (string-append "/" psts))
                           ;               ">" (match:substring m) "</a>")
                           (format #f "<a href=''/~a/~a/~a~a''>~a</a>"
                                   (if (= (length lnks) 1) "thread" "posts")
                                   board trd
                                   (if (= (length lnks) 1) (string-append "#" psts "p")
                                                           (string-append "/" psts))
                                   (match:substring m))
                           (match:substring m))))
                      ((= 1 (length post-list))
                       (let* ((psts (car post-list))
                              (lnks (post-string->list psts)))
                         ;(string-append "<a href=/thread/" board "/" thread
                         ;               (if (= (length lnks) 1)
                         ;                 (string-append "#" psts "p")
                         ;                 (string-append "/" psts))
                         ;               ">" (match:substring m) "</a>")))
                         (format #f "<a href=''/~a/~a/~a~a''>~a</a>"
                                 (if (= (length lnks) 1) "thread" "posts")
                                 board thread
                                 (if (= (length lnks) 1) (string-append "#" psts "p")
                                                         (string-append "/" psts))
                                 (match:substring m))))
                      (else (match:substring m))))))
              'post)) ; FIXME : add quotes around the href once you figure out how to escape chars properly
          (lambda (p) ; Quote matching
            (regexp-substitute/global #f "(^|\n)&gt;[^\n]+" p
              'pre (lambda (m) (string-append "<i>" (match:substring m) "</i>")) 'post))
          (lambda (p) ; Spoiler matching
            (regexp-substitute/global #f "\\[spoiler\\].*\\[/spoiler\\]" p
              'pre (lambda (m) (string-append "<span class=''spoiler''>" (substring (match:substring m) 9 (- (string-length (match:substring m)) 10)) "</span>")) 'post))
          (lambda (p) ; AA matching
            (regexp-substitute/global #f "\\[aa\\].*\\[/aa\\]" p
              'pre (lambda (m) (string-append "<span class=''aa''>" (substring (match:substring m) 4 (- (string-length (match:substring m)) 5)) "</span>")) 'post))
			 (lambda (p) ; Code matching
			 (newline)(newline)  (display p)(newline)(newline)
		 (reluctant-code-tags p))
		  ;(regexp-substitute/global #f "\\[code\\].*\\[/code\\]" p
			  ;    'pre (lambda (m) (string-append "<div class=''code''>" (substring (match:substring m) 6 (- (string-length (match:substring m)) 7)) "</div>")) 'post))

          (lambda (p) ; Convert all newlines to <br>, this is done last because matching \n in regex is easier than matching <br>
            (regexp-substitute/global #f "\n" p
              'pre "<br>" 'post)))))
          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Available modes: 'default 'preview (list of post links)
(define* (build-threads rc mtable board threadnum #:key (mode 'normal) (page 1) page-len preview-OP-template post-preview-count-override last) ; FIXME: Remove rc from args when all db calls use mtable
  (define* (build-post mtable threadnum board post #:optional postcount subject replies old sticky)
    (let (;(OP-tpl (or preview-OP-template (assq-ref (assoc-ref boards board) 'OP-template) default-OP-template)) ; FIXME: does this or statement need to be here?
          (OP-tpl (or preview-OP-template post-OP-tpl))
          ;(post-tpl-func (or (assq-ref (assoc-ref boards board) 'post-template) default-post-template))
          (post-tpl-func post-tpl)
          (postnum (assoc-ref post "postnum"))
          (post-preview-count (if sticky 1 post-preview-count))
          (name (assoc-ref post "name"))
          (date (assoc-ref post "date"))
          (ctime (assoc-ref post "ctime"))
          (image (assoc-ref post "image"))
          (thumb (assoc-ref post "thumb"))
          (iname (assoc-ref post "iname"))
          (size (assoc-ref post "size"))
          (comment (replace (replace (assoc-ref post "comment") "\\u3000" "　") "\\\\" "\\")) ; FIXME: why are these necessary? Bashslashes are not properly converted when reading from database? May need to send bug report. But this works for now.
          (subposts (if (eq? (assoc-ref post "subposts") 1)
                      (database-get-subposts mtable board threadnum (assoc-ref post "postnum"))
                      #f)))
      ;(tpl->html (string-append "pub/" (if (or (not replies) (string? mode))
      ;                                       post-tpl OP-tpl)
      ;                              ".tpl") (the-environment))
      (if (or (not replies) (string? mode))
        (tpl->html (post-tpl-func mode (uri-encode board) threadnum postnum name date image iname thumb size comment subposts replies))
        (tpl->html (OP-tpl mode board (escape-str board) (uri-encode board) threadnum postcount subject name date image iname thumb size comment old sticky replies)))
        ;(tpl->html (string-append "pub/" OP-tpl ".tpl") (the-environment)))
      ;(tpl-render
      ; (if (or (not replies) (string? mode))
      ;   test-post-tpl
      ;   test-OP-tpl)
      ; (the-environment)
      ; #f)

    ;(call-with-output-string
    ;  (lambda (port)
    ;    (parameterize ((current-output-port port))
    ;      (local-eval-string
    ;       (if (or (not replies) (string? mode))
    ;         test-post-tpl
    ;         test-OP-tpl)
    ;       (the-environment)))))

      ))

  (string-join
      (let* ((page-len (or page-len (assq-ref (assoc-ref boards board) 'page-len) default-page-len))
             (listing (if (eq? mode 'preview)
                        (case (assq-ref (assoc-ref boards board) 'special)
                         ((all) (database-get-all-thread-previews mtable page page-len))
                         ((listed) (database-get-listed-thread-previews mtable boards page page-len))
                         ((unlisted) (database-get-unlisted-thread-previews mtable boards page page-len))
                         (else (database-get-thread-previews mtable board page page-len)))
                        (database-get-thread mtable board threadnum))))
        (map (lambda (thread)
               (let* ((sticky (eq? 1 (assoc-ref thread "sticky")))
                      (to-threadnum (assoc-ref thread "threadnum"))
                      (to-board (assoc-ref thread "board"))
                      ;(subject (cdaar ((cdr CM) 'get 'threads #:columns '(subject) #:condition (where #:id threadnum))))
                      (subject (assoc-ref thread "subject"))
                      (postcount (assoc-ref thread "postcount"))
                      ;(table (if (eq? mode 'preview)
                      ;         ((cdr CM) 'get (string->symbol threadname) #:order-by '(id asc) #:condition (where (format #f "id=1 or id>~a-~a" maxid post-preview-count)))
                      ;         ((cdr CM) 'get (string->symbol threadname) #:order-by '(id asc))))
                      (posts (case mode
                               ((normal)  (database-get-posts mtable to-board to-threadnum last))
                               ;((preview) ((cdr CM) 'get 'posts #:order-by '(postnum asc) #:condition (where (format #f "board='~a' and threadnum=~a and (postnum=1 or postnum>~a-~a)" board threadnum postcount post-preview-count))))
                               ((preview) (database-get-preview-posts rc to-board to-threadnum (if sticky 1 (or post-preview-count-override post-preview-count))))
                               ;(else       ((cdr CM) 'get (string->symbol threadname) #:order-by '(id asc)))))
                               (else      (database-get-posts-from-list mtable to-board to-threadnum (string-join (post-string->list mode) ", ")))))
                      (replies (string-join (map (lambda (post)
                                                   (build-post mtable to-threadnum to-board post))
                                                 (cdr posts))
                                            "\n"))
                      ;(old (if (not (eq? 0 (assoc-ref thread "old"))) (assoc-ref thread "old") #f)))
                      (old (assoc-ref thread "old")))
                 (build-post mtable to-threadnum to-board (car posts) postcount subject replies old sticky)))
                 ;(format #f "table: ~a" table)))
             listing))
    "\n"))

;(define* (build-catalog board #:key (catalog-tpl catalog-thread-template))
;  (define* (build-post mtable threadnum post #:optional postcount subject)
;    (let ((image (assoc-ref post "image"))
;          (thumb (assoc-ref post "thumb"))
;          (comment (replace (replace (assoc-ref post "comment") "\\u3000" "　") "\\\\" "\\"))) ; FIXME: why are these necessary? Bashslashes are not properly converted when reading from database? May need to send bug report. But this works for now.
;      (tpl->response (string-append "pub/catalog-thread.tpl") (the-environment))))
;
;  (string-join
;      (let ((listing (database-get-threads-from-board mtable board)))
;        (map (lambda (thread)
;               (let* ((threadnum (assoc-ref thread "threadnum"))
;                      (subject (assoc-ref thread "subject"))
;                      (postcount (assoc-ref thread "postcount"))
;                      (posts (database-get-OP mtable board threadnum)))
;                 (build-post mtable threadnum (car posts) postcount subject)))
;                 ;(format #f "table: ~a" table)))
;             listing))
;    "\n"))

(define (process-name-codes admin name)
  (let ((cc (string-contains name " ## ")))
    (if (and admin
             cc (>= cc 1)
             (equal? (assoc-ref (car admin) "name")
                     (substring name 0 cc)))
        (string-append "<span class=capcode>" (assoc-ref (car admin) "name") " ## " (substring name (+ cc 4)) " <img title=''Mod'' style=''vertical-align:bottom'' src=''/pub/img/capcode.png''></span>")
        name)))

(define (get-threadnum mtable board)
  (let ((val (database-get-board-threadcount mtable board)))
    (if (null? val)
        1
        (+ 1 (assoc-ref (car val) "threadcount")))))

(define* (save-post rc mtable board #:key existing-thread)
  (let* ((ip (get-ip rc))
         (cooldown (check-cooldown mtable ip))
         (bans (check-bans mtable ip)))
    (cond
     (bans (tpl->response (message-tpl bans)))
     ((not (car cooldown)) (tpl->response (message-tpl (cdr cooldown))))
     ((assq-ref (assoc-ref boards board) 'posting-disabled) (tpl->response (message-tpl (format #f "Posting is disabled on /~a/ at this time." board))))
     (else
      (let* ((threadnum (or existing-thread (get-threadnum mtable board)))
             ;(mfds (get-mfds-op-from-post rc))
             ;(subject (escape-str (or-blank (mfds-op-ref rc mfds "subject") default-subject)))
             (data (parse-body (string->utf8 (string-append "--" (content-type-is-mfd? rc))) ; FIXME: parse-body is our own function, there should be a built-in one
                               (rc-body rc)))
             (cookies (get-cookie-alist rc))
             (admin (get-admin rc mtable cookies)) ; FIXME: is this needed if there's a built-in function to get cookie alist?
             (subject (escape-str (or-blank (assoc-ref data 'subject) default-subject)))
             ;(name (process-name-codes admin (escape-str (or-blank (assoc-ref data 'name)
             ;                                                                        (assq-ref (assoc-ref boards board) 'name)
             ;                                                                        default-name))))
             (name (escape-str (or-blank (assoc-ref data 'name)
                                         (assq-ref (assoc-ref boards board) 'name)
                                         default-name)))

             (options (string-split (or (assoc-ref data 'options) "") #\space))
             ;(sage (lset-intersection equal? '("sage" "SAGE" "さげ" "下げ") options))
             (sage '())
             (noko (or (and noko-enabled (member "noko" options))
                       (and (not noko-enabled) (not (member "nonoko" options)))))
             ;(nokosage (member "nokosage" options))
             (nokosage '() )

			 (subpost (filter string->number options))
             (pass (or (assoc-ref data 'password) ""))
             ;(date (date->string (current-date) "(~k:~M) ~a ~b ~e, ~Y"))
             (date (get-datestring))
             (ctime (time-second (current-time time-utc)))
             (raw-comment (assoc-ref data 'comment))
             (comment (or-blank (comment-filter (escape-str raw-comment) board (number->string threadnum)) default-comment))
             (thread (if existing-thread
                         (car (database-get-thread mtable board threadnum))
                         #f))
             (postnum (if existing-thread
                          (+ 1 (assoc-ref thread "postcount"))
                          1))
             (btime (assoc-ref thread "btime")))
             ;(tname (string->symbol (string-append "thread" (number->string threadnum)))))

        ;; FIXME: There's probably a better way to do this

        (set-password rc pass)

        (let ((file-info (store-uploaded-files rc #:path (string-append (getcwd) "/pub/img/upload")
                                               #:uid #f
                                               #:gid #f
                                               #:simple-ret? #f
                                               #:mode #o664
                                               #:path-mode #o775
                                               #:sync #t)))
          (let* ((filename (if (null? (caddr file-info)) "" (caaddr file-info)))
                 (mimetype (get-mimetype (string-append (getcwd) "/pub/img/upload/" filename)))
                 (mimetypes-OP-blacklist (or (assq-ref (assoc-ref boards board) 'mimetypes-OP-blacklist) default-OP-mimetypes-blacklist))
                 (mimetypes-blacklist (or (assq-ref (assoc-ref boards board) 'mimetypes-blacklist) default-mimetypes-blacklist))
                 (mimetypes-OP-whitelist (or (assq-ref (assoc-ref boards board) 'mimetypes-OP-whitelist) default-OP-mimetypes-whitelist))
                 (mimetypes-whitelist (or (assq-ref (assoc-ref boards board) 'mimetypes-whitelist) default-mimetypes-whitelist))
                 (extension (cdr (separate-extension filename))))
            (if (cond
                 ((equal? "" filename) #f)
                 (existing-thread
                  (if (null? mimetypes-whitelist)
                    (member mimetype mimetypes-blacklist)
                    (not (member mimetype mimetypes-whitelist))))
                 (else
                  (if (null? mimetypes-OP-whitelist)
                    (member mimetype mimetypes-OP-blacklist)
                    (not (member mimetype mimetypes-OP-whitelist)))))
              (tpl->response (message-tpl (format #f "Error: Not an allowed mimetype for this board<br>uploaded mimetype: <span style=\"color:#c00\">~a</span><br><br>OP posts on <span style=\"color:#00c\">/~a/</span>:<br>whitelisted mimetypes: <span style=\"color:#0c0\">~a</span><br>blacklisted mimetypes: <span style=\"color:#c00\">~a</span><br><br>Non-OP posts on <span style=\"color:#00c\">/~a/</span>:<br>whitelisted mimetypes: <span style=\"color:#0c0\">~a</span><br>blacklisted mimetypes: <span style=\"color:#c00\">~a</span>" mimetype board mimetypes-OP-whitelist mimetypes-OP-blacklist board mimetypes-whitelist mimetypes-blacklist)))
              (let* ((fsize (if (or (null? (cadr file-info))
                                    (= 0 (caadr file-info)))
                              "0B" (convert-size (caadr file-info))))
                     (file-required (and (not existing-thread)
                                         (or (assq-ref (assoc-ref boards board) 'OP-file-required) default-OP-file-required)))
                     (max-dimensions (number->string (if existing-thread max-thumb-size max-thumb-size-OP)))
                     (finfo (if (equal? filename "")
                              (cons* #f #f #f #f)
                              (let* ((boarddir (string-append (getcwd) "/pub/img/" board))
                                     (threaddir (string-append boarddir "/" (number->string threadnum)))
                                     (timestring (number->string (get-timestamp13)))
                                     (newfile (string-append timestring (if extension (string-append "." (string-downcase extension)) "")))
                                     (newthumb (string-append timestring "s"))
                                     (fullpath (string-append threaddir "/" newfile))
                                     (fullthumb (string-append threaddir "/" newthumb)))
                                (unless (file-exists? boarddir) (mkdir boarddir))
                                (unless (file-exists? threaddir) (mkdir threaddir))
                                (rename-file (string-append (getcwd) "/pub/img/upload/" filename) fullpath)
                                ;(cons newname newthumbname)))))
                                ;; FIXME: replace this extension case with actual mimetype detection?
				(display mimetype)
                                (case mimetype
                                  ((GIF JPEG PNG WEBP) ; IMAGES
                                   (make-image-thumbnail fullpath max-dimensions (string-append fullthumb "." extension))
                                   (cons* newfile (string-append newthumb "." extension) mimetype
                                          (get-image-dimensions fullpath)))
                                  ((FLAC M4A MKV MP3 MP4 OCTET OGG WAV WMA WEBM) ; Audio/Video/Octet-streams
                                   (make-video-thumbnail fullpath max-dimensions (string-append fullthumb ".jpg"))
                                   (if (file-exists? (string-append fullthumb ".jpg"))
                                     (cons* newfile (string-append newthumb ".jpg") mimetype
                                            (get-image-dimensions (string-append fullthumb ".jpg")))
                                     (begin
                                       (copy-file "pub/img/mimetype-audio.png"
                                                  (string-append fullthumb ".png"))
                                       (cons* newfile (string-append newthumb ".png") mimetype #f))))
                                  ((SWF) ; FLASH
                                   (let* (;(port (open-input-pipe
                                          ;       (string-append "ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 " fullpath)))
                                          (dimensions (get-video-dimensions fullpath))
                                          (dims (string-split (or dimensions "0x0") #\x))
                                          (width (string-append (car dims) "px"))
                                          (height (string-append (cadr dims) "px"))
                                          (entrypoint (string-append timestring ".swf")))
                                     (write-file (string-append threaddir "/" timestring ".html")
                                                 (tpl->html (sandbox-tpl (uri-encode board) threadnum filename timestring extension (format #f "~a, ~a, ~a" mimetype fsize dimensions) entrypoint width height)))
                                     (copy-file "pub/img/mimetype-flash.png"
                                                (string-append fullthumb ".png"))
                                     (cons* (string-append timestring ".html")
                                            (string-append newthumb ".png")
                                            mimetype dimensions)))
                                  ((HTML5) ; HTML5
                                   (let ((size (get-uncompressed-size fullpath))
                                         (width "100%")
                                         (height "100%")
                                         (entrypoint (string-append timestring "/main.html")))
                                     (when (and size
                                                (<= size (get-conf '(upload size))))
                                       (mkdir (string-append threaddir "/" timestring))
                                       (uncompress fullpath (string-append threaddir "/" timestring))
                                       (write-file (string-append threaddir "/" timestring ".html")
                                                   (tpl->html (sandbox-tpl (uri-encode board) threadnum filename timestring extension (format #f "~a, ~a, ~ax~a" mimetype fsize width height) entrypoint width height))))
                                     (copy-file "pub/img/mimetype-html5.png"
                                                (string-append fullthumb ".png"))
                                     (cons* (string-append timestring ".html")
                                            (string-append newthumb ".png")
                                            mimetype (string-append width "x" height))))
                                  (else ; OTHER
                                   (copy-file "pub/img/mimetype-other.png"
                                              (string-append fullthumb ".png"))
                                   (cons* newfile (string-append newthumb ".png") mimetype #f)))))))
                (when (and (not (null? subpost))
                           (> (string->number (car subpost)) 1)
                           (not (equal? filename ""))
                           (file-exists? (string-append (getcwd) "/pub/img/upload/" filename)))
                  (delete-file (string-append (getcwd) "/pub/img/upload/" filename)))
                (cond
                  ((not (or-blank filename
                                  (and (not file-required)
                                       raw-comment)))
                   (tpl->response (message-tpl (if file-required "Error: A file is required when creating a new thread on this board."
                                                                 "Error: Blank post."))))
                  ((check-string-limits subject max-name-length #:length-error "Error: Subject length too long"
                                                                #:lines-error "Error: Subject has too many lines") => (lambda (message) (tpl->response (message-tpl message))))
                  ((check-string-limits name max-name-length #:length-error "Error: Name length too long"
                                                             #:lines-error "Error: Name has too many lines") => (lambda (message) (tpl->response (message-tpl message))))
                  ((check-string-limits comment max-comment-length #:max-lines max-comment-lines
                                                                   #:linebreak "<br>"
                                                                   #:length-error "Error: Comment is too long"
                                                                   #:lines-error "Error: Comment has too many lines") => (lambda (message) (tpl->response (message-tpl message))))
                  ((check-string-limits filename max-filename-length #:length-error "Error: Filename length too long"
                                                                     #:lines-error "Error: Filename has too many lines") => (lambda (message) (tpl->response (message-tpl message))))
                  (else
                   (if (and (not (null? subpost))
                            (> (string->number (car subpost)) 1))
                     (database-save-subpost mtable board threadnum (string->number (car subpost)) ip (process-name-codes admin name) date ctime comment)
                     (begin
			;filename is not safe for html output so save to db in safe format
                       (database-save-post mtable board threadnum postnum ip (or nokosage sage) (process-name-codes admin name) date ctime finfo (escape-str filename) fsize comment)
                       (if existing-thread
                         (database-update-thread mtable board threadnum postnum (or nokosage sage) ctime btime)
                         (begin
                           (database-create-thread mtable board threadnum subject date ctime)
                           (database-add-thread-to-board mtable board threadnum)))))
                   (prune-board rc mtable board ctime)
                   (when (>= postnum active-post-limit)
                     (mark-thread-old mtable board threadnum ctime #:force #t))

                   ;; -----------------------------------------------
                   ;; FIXME: These aren't needed except to get the scheme
              (let* ((request ((record-accessor (record-type-descriptor rc) 'request) rc))
                     (headers ((record-accessor (record-type-descriptor request) 'headers) request))

                     (referer (assoc-ref headers 'referer))
                     (scheme ((record-accessor (record-type-descriptor referer) 'scheme) referer))
                     (host ((record-accessor (record-type-descriptor referer) 'host) referer))
					 )

                   ;; -----------------------------------------------
                   ;; -----------------------------------------------
                     (if (or noko nokosage)
                       (redirect-to rc (string-append "/thread/" (uri-encode board) "/" (number->string threadnum)))
                       (redirect-to rc (string-append "/board/" (uri-encode board))))))))))))))))

(define (post-note rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (admin (get-admin rc mtable)))
    (if (not admin)
      (throw 'artanis-err 401 post-note "Unauthorized.")

      (let* ((path (cdr (string-split (rc-path rc) #\/)))
             (id (cadr path))
             (data (parse-body (string->utf8 (string-append "--" (content-type-is-mfd? rc))) ; FIXME: pare-body is our own function, there should be a built-in one
                               (rc-body rc)))
             (name (assoc-ref (car admin) "name"))
             (subject (assoc-ref data 'subject))
             (date (date->string (current-date 0) "~5"))
             (ctime (time-second (current-time time-utc)))
             (body (comment-filter (escape-str (assoc-ref data 'body)) "example" "0"))
             (type (assoc-ref data 'type))
             (perms-read (string-join (default (get-all-alist-keys data 'perm-read) '()) " "))
             (perms-write (string-join (default (get-all-alist-keys data 'perm-write) '()) " "))
             (del (string-join (default (get-all-alist-keys data 'delete) '()) " "))
             ;; -----------------------------------------------
             ;; FIXME: These aren't needed except to get the scheme
             (request ((record-accessor (record-type-descriptor rc) 'request) rc))
             (headers ((record-accessor (record-type-descriptor request) 'headers) request))
             (referer (assoc-ref headers 'referer))
             (scheme ((record-accessor (record-type-descriptor referer) 'scheme) referer))
             (host ((record-accessor (record-type-descriptor referer) 'host) referer)))
             ;; -----------------------------------------------
             ;; -----------------------------------------------
        (if (equal? id "new")
          (begin
            (database-new-note mtable type name perms-read perms-write subject ctime date body)
            (redirect-to rc (build-uri scheme #:host host #:path "/panel")))

          (let* ((note (database-get-note mtable id))
                 (creator (assoc-ref (car note) "name"))
                 (init-type (assoc-ref (car note) "type"))
                 (init-perms-write (string-split (assoc-ref (car note) "write") #\space))
                 (editable (and admin
                                (or (equal? init-type "public")
                                    (equal? creator name) ;owner
                                    (member name init-perms-write)))))
            (if editable
              (begin
                (if (equal? del "delete")
                  (database-delete-note rc id)
                  (database-update-note mtable type perms-read perms-write subject ctime name date body id))
                (redirect-to rc (build-uri scheme #:host host #:path "/panel")))
              (throw 'artanis-err 401 post-note "Unauthorized."))))))))

(define (prune-unlisted rc mtable ctime) ; FIXME: replace rc with mtable once the database calls can use mtable only
  (for-each (lambda (thread-lst)
              (delete-thread rc (assoc-ref thread-lst "board") (assoc-ref thread-lst "threadnum")))
            (database-prune-unlisted mtable boards ctime unlisted-factor default-page-count default-page-len prune-time)))

(define (prune-board rc mtable board ctime) ; FIXME: replace rc with mtable once the database calls can use mtable only
  (let ((page-count (or (assq-ref (assoc-ref boards board) 'page-count) default-page-count))
        (page-len (or (assq-ref (assoc-ref boards board) 'page-len) default-page-len)))
    (for-each (lambda (threadnum-lst)
                (delete-thread rc board (assoc-ref threadnum-lst "threadnum")))
              (database-prune-board mtable board ctime page-count page-len prune-time))))

(define (delete-thread rc board threadnum) ; FIXME: replace rc with mtable once the database calls can use mtable only
  (database-delete-thread-posts rc board threadnum)
  (database-delete-thread rc board threadnum)
  (let* ((boarddir (format #f "pub/img/~a" board))
         (threaddir (format #f "~a/~a" boarddir threadnum)))
    (when (file-exists? boarddir)
      (when (file-exists? threaddir)
        (nftw threaddir
              (lambda (filename statinfo flag base level)
                (case flag
                  ((regular)
                   (delete-file filename))
                  ((directory-processed)
                   (rmdir filename)))
                #t)
              'depth 'mount 'physical))
      (when (null? (scandir boarddir))
        (rmdir boarddir)))))

(define (delete-post rc board threadnum postnum)
  (database-delete-post rc board threadnum postnum))

(define (delete-post-image mtable board threadnum postnum)
  (let* ((data (car (database-get-post-image mtable board threadnum postnum)))
         (file (format #f "pub/img/~a/~a/~a" board threadnum (assoc-ref data "image")))
         (thumb (format #f "pub/img/~a/~a/~a" board threadnum (assoc-ref data "thumb"))))
    (when (file-exists? file) (delete-file file))
    (when (file-exists? thumb) (copy-file "pub/img/deleted.png" thumb))))

(define (ban-user mtable board threadnum postnum)
  (database-ban-user mtable board threadnum postnum 0))

(define (sticky-thread mtable board threadnum)
  (database-toggle-sticky-thread mtable board threadnum))

(define* (mark-thread-old mtable board threadnum ctime #:key force)
  (database-toggle-old-thread mtable board threadnum ctime force))

(define (mod-posts rc)
  (let* ((mtable (map-table-from-DB (:conn rc)))
         (ip (get-ip rc))
         (data (parse-body (string->utf8 (string-append "--" (content-type-is-mfd? rc))) ; FIXME: pare-body is our own function, there should be a built-in one
                           (rc-body rc)))
         (cookies (get-cookie-alist rc))
         (admin (get-admin rc mtable cookies)) ; FIXME: is this needed if there's a built-in function to get cookie alist?
         (delete-button (assoc-ref data 'delete-button))
         (modaction (if delete-button 'del
                        (string->symbol (default (assoc-ref data 'modaction) ""))))
         (posts (default (get-all-alist-keys data 'posts) '())))
    (case modaction
      ((del)
       (let ((statuses
              (fold ;;; FIXME: This option is available to normal users, and queries the database once per post in the list so it could potentially be used to slow down the server
                (lambda (post status)
                  (let ((lst (string-split post #\/)))
                    (if (= (length lst) 3)
                      (let* ((board (uri-decode (car lst)))
                             (threadnum (cadr lst))
                             (postnum (caddr lst))
                             (table (database-get-post-with-ip mtable board threadnum postnum ip))
                             (ctime (time-second (current-time time-utc))))
                        (if (or admin
                                (and (not (null? ctime))
                                     (< (- ctime (assoc-ref (car table) "ctime")) post-deletion-period)))
                          (begin
                            (if (equal? postnum "1")
                              (delete-thread rc board threadnum)
                              (delete-post rc board threadnum postnum))
                            (cons (string-append post ": <span style=\"color:#0c0\">SUCCESS</span>") status))
                          (cons (string-append post ": <span style=\"color:#c00\">FAILED</span> - TIME EXPIRED, OR PERMISSION DENIED") status)))
                      (cons (string-append post ": <span style=\"color:#c00\">FAILED</span> - BAD FORMAT") status))))
                '()
                posts)))
         (tpl->response (message-tpl (format #f "Post Deletions:<br>~a" (string-join statuses "<br>"))))))
      ((delimg)
       (let ((statuses
              (fold ;;; FIXME: This option is available to normal users, and queries the database once per post in the list so it could potentially be used to slow down the server
                (lambda (post status)
                  (let ((lst (string-split post #\/)))
                    (if (= (length lst) 3)
                      (let* ((board (uri-decode (car lst)))
                             (threadnum (cadr lst))
                             (postnum (caddr lst))
                             (table (database-get-post-with-ip mtable board threadnum postnum ip))
                             (ctime (time-second (current-time time-utc))))
                        (if (or admin
                                (and (not (null? ctime))
                                     (< (- ctime (assoc-ref (car table) "ctime")) post-deletion-period)))
                          (begin
                            (delete-post-image mtable board threadnum postnum)
                            (cons (string-append post ": <span style=\"color:#0c0\">SUCCESS</span>") status))
                          (cons (string-append post ": <span style=\"color:#c00\">FAILED</span> - TIME EXPIRED, OR PERMISSION DENIED") status)))
                      (cons (string-append post ": <span style=\"color:#c00\">FAILED</span> - BAD FORMAT") status))))
                '()
                posts)))
         (tpl->response (message-tpl (format #f "Image Deletions:<br>~a" (string-join statuses "<br>"))))))
      ((ban)
       (let ((statuses
              (fold
                (lambda (post status)
                  (let ((lst (string-split post #\/)))
                    (if (= (length lst) 3)
                      (let* ((board (uri-decode (car lst)))
                             (threadnum (cadr lst))
                             (postnum (caddr lst)))
                        (if admin
                          (begin
                            (ban-user mtable board threadnum postnum)
                            (cons (string-append post ": <span style=\"color:#0c0\">SUCCESS</span>") status))
                          (cons (string-append post ": <span style=\"color:#c00\">FAILED</span> - PERMISSION DENIED") status)))
                      (cons (string-append post ": <span style=\"color:#c00\">FAILED</span> - BAD FORMAT") status))))
                '()
                posts)))
         (tpl->response (message-tpl (format #f "Bans:<br>~a" (string-join statuses "<br>"))))))
      ((sticky)
       (let ((statuses
              (fold
                (lambda (post status)
                  (let ((lst (string-split post #\/)))
                    (if (= (length lst) 3)
                      (let* ((board (uri-decode (car lst)))
                             (threadnum (cadr lst))
                             (postnum (caddr lst)))
                        (if (and admin
                                 (equal? postnum "1"))
                          (let ((toggle (sticky-thread mtable board threadnum)))
                            (cons (string-append post ": <span style=\"color:#0c0\">" toggle "</span>") status))
                          (cons (string-append post ": <span style=\"color:#c00\">FAILED</span> - Permission denied or post is not the OP") status)))
                      (cons (string-append post ": <span style=\"color:#c00\">FAILED</span> - BAD FORMAT") status))))
                '()
                posts)))
         (tpl->response (message-tpl (format #f "Statuses:<br>~a" (string-join statuses "<br>"))))))
      ((old)
       (let ((statuses
              (fold
                (lambda (post status)
                  (let ((lst (string-split post #\/)))
                    (if (= (length lst) 3)
                      (let* ((board (uri-decode (car lst)))
                             (threadnum (cadr lst))
                             (postnum (caddr lst))
                             (ctime (time-second (current-time time-utc))))
                        (if (and admin
                                 (equal? postnum "1"))
                          (let ((toggle (mark-thread-old mtable board threadnum ctime)))
                            (cons (string-append post ": <span style=\"color:#0c0\">" toggle "</span>") status))
                          (cons (string-append post ": <span style=\"color:#c00\">FAILED</span> - Permission denied or post is not the OP") status)))
                      (cons (string-append post ": <span style=\"color:#c00\">FAILED</span> - BAD FORMAT") status))))
                '()
                posts)))
         (tpl->response (message-tpl (format #f "Statuses:<br>~a" (string-join statuses "<br>"))))))
      (else
       (tpl->response (message-tpl "Mod command not understood."))))))
