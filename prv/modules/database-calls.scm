;;;-*-guile-scheme-*-;;;

(define-module (modules database-calls)
  #:use-module (artanis artanis))


(define-public (database-get-bans mtable ip)
  (mtable 'get 'banlist #:condition (where #:ip ip)))

(define-public (database-get-cooldowns mtable ip)
  (mtable 'get 'cooldowns #:condition (where #:ip ip)))

(define-public (database-add-cooldowns mtable ip ctime)
  (mtable 'set 'cooldowns #:ip ip #:tier1 ctime #:tier2 ctime #:counter 1))

(define-public (database-update-cooldowns mtable ip ctime)
  (mtable 'set 'cooldowns (format #f "tier1=~a,counter=counter+1 where ip='~a'" ctime ip)))

(define-public (database-update-tier2-cooldown mtable ip ctime)
  (mtable 'set 'cooldowns (format #f "tier1=~a,tier2=~a,counter=1 where ip='~a'" ctime ctime ip)))

(define-public (database-get-note mtable id)
  (mtable 'get 'notes #:condition (where #:id id)))

(define-public (database-get-notes-for-admin mtable order limit admin)
  (mtable 'get 'notes #:order-by `(ctime ,order) #:ret limit #:condition (where #:name (assoc-ref (car admin) "name"))))

(define-public (database-get-notes-by-type mtable order limit type)
  (mtable 'get 'notes #:order-by `(ctime ,order) #:ret limit #:condition (where #:type type)))

(define-public (database-new-note mtable type name perms-read perms-write subject ctime date body)
  (let* ((notes (mtable 'get 'notes #:columns '(id) #:order-by `(id desc) #:ret 1))
         (id (if (null? notes) 1 (+ 1 (assoc-ref (car notes) "id")))))
    (mtable 'set 'notes #:id id #:type type #:name name #:read perms-read #:write perms-write #:subject subject #:ctime ctime #:btime ctime #:date date #:edited "" #:body body)))

(define-public (database-update-note mtable type perms-read perms-write subject ctime name date body id)
  (mtable 'set 'notes #:type type #:read perms-read #:write perms-write #:subject subject #:btime ctime #:edited (format #f "~a on ~a" name date) #:body body (where #:id id)))

(define-public (database-delete-note rc id)
  (:conn rc (format #f "DELETE FROM notes WHERE id=~a;" id)))

(define-public (database-get-mod mtable name password)
  (mtable 'get 'mods #:columns '(name) #:condition (where #:name name #:password password)))

(define-public (database-get-mod-by-key mtable key)
  (mtable 'get 'mods #:condition (where #:session (car key))))

(define-public (database-set-mod-key mtable new-key name)
  (mtable 'set 'mods (format #f "session=\"~a\" where name=\"~a\"" new-key name)))

(define-public (database-disable-mod-key mtable key)
  (mtable 'set 'mods (format #f "session=\"~a\" where session=\"~a\"" "none" key)))

(define-public (database-get-mod-pass mtable name current-password)
  (mtable 'get 'mods #:columns '(password) #:condition (where #:name name #:password current-password)))

(define-public (database-set-mod-pass mtable name new-password)
  (mtable 'set 'mods (format #f "password=\"~a\" where name=\"~a\"" new-password name)))

(define-public (database-get-all-thread-previews mtable page page-len)
  (mtable 'get 'threads #:condition (where (format #f "1=1 order by btime desc limit ~a offset ~a" page-len (* (if (and page (string->number page))
                                                                                                                   (- (string->number page) 1)
                                                                                                                   0)
                                                                                                               page-len)))))
(define-public (database-get-listed-thread-previews mtable boards page page-len)
  (let ((ors (string-join
              (map (lambda (board)
                     (format #f "board='~a'" (car board)))
                   boards)
              " or ")))
    (mtable 'get 'threads #:condition (where (format #f "~a order by btime desc limit ~a offset ~a" ors page-len (* (if (and page (string->number page))
                                                                                                                        (- (string->number page) 1)
                                                                                                                        0)
                                                                                                                    page-len))))))
(define-public (database-get-unlisted-thread-previews mtable boards page page-len)
  (let ((ands (string-join
               (map (lambda (board)
                      (format #f "board!='~a'" (car board)))
                    boards)
               " and ")))
    (mtable 'get 'threads #:condition (where (format #f "~a order by btime desc limit ~a offset ~a" ands page-len (* (if (and page (string->number page))
                                                                                                                        (- (string->number page) 1)
                                                                                                                        0)
                                                                                                                    page-len))))))

(define-public (database-get-thread-previews mtable board page page-len)
  (mtable 'get 'threads #:condition (where (format #f "board='~a' order by sticky desc, btime desc limit ~a offset ~a" board page-len (* (if (and page (string->number page))
                                                                                                                                (- (string->number page) 1)
                                                                                                                                0)
                                                                                                                            page-len)))))

(define-public (database-get-thread mtable board threadnum)
  ;1st call: (mtable 'get 'threads #:order-by '(btime desc) #:condition (where #:threadnum threadnum #:board board))
  ;2nd call: (mtable 'get 'threads #:columns '(postcount ctime btime) #:condition (where (format #f "board='~a' and threadnum=~a" board threadnum)))
  (mtable 'get 'threads #:condition (where #:board board #:threadnum threadnum)))

(define-public (database-get-threads-from-board mtable board)
  (mtable 'get 'threads #:order-by '(btime desc) #:condition (where #:board board)))

(define-public (database-delete-thread-posts rc board threadnum)
  (:conn rc (format #f "delete from posts where board='~a' and threadnum=~a;" board threadnum)))

(define-public (database-delete-thread rc board threadnum)
  (:conn rc (format #f "delete from threads where board='~a' and threadnum=~a;" board threadnum)))

(define-public (database-delete-post rc board threadnum postnum)
  (:conn rc (format #f "delete from posts where board='~a' and threadnum=~a and postnum=~a;" board threadnum postnum)))

(define-public (database-get-post-image mtable board threadnum postnum)
  (mtable 'get 'posts #:columns '(image thumb) #:condition (where #:board board #:threadnum threadnum #:postnum postnum)))

(define-public (database-ban-user mtable board threadnum postnum expiration-time)
  (let ((data (mtable 'get 'posts #:columns '(ip session) #:condition (where #:board board #:threadnum threadnum #:postnum postnum))))
    (when (not (null? data))
      (mtable 'set 'banlist #:ip (assoc-ref (car data) "ip") #:session (assoc-ref (car data) "session") #:expiration 0))))

(define-public (database-toggle-sticky-thread mtable board threadnum)
  (let ((sticky (if (not (assoc-ref (car (mtable 'get 'threads #:columns '(sticky) #:condition (where #:board board #:threadnum threadnum))) "sticky"))
                    1 #f)))
    (mtable 'set 'threads (format #f "sticky=~a where board='~a' and threadnum=~a" sticky board threadnum))
    (if (not sticky)
        "UNSTICKIED" "STICKIED")))

(define-public (database-toggle-old-thread mtable board threadnum ctime force)
  (let ((setold (if (not (assoc-ref (car (mtable 'get 'threads #:columns '(old) #:condition (where #:board board #:threadnum threadnum))) "old"))
                 ctime #f)))
    (if (and force
             (not setold))
      "NO CHANGE"
      (begin
        (mtable 'set 'threads (format #f "old=~a where board='~a' and threadnum=~a" setold board threadnum))
        (if (not setold)
          "MARKED ACTIVE" "MARKED OLD")))))

(define-public (database-get-post-with-ip mtable board threadnum postnum ip)
  (mtable 'get 'posts #:condition (where (format #f "board='~a' and threadnum=~a and postnum=~a and ip='~a'" board threadnum postnum ip))))

(define-public (database-get-posts mtable board threadnum last)
  (if (not last)
    ;(mtable 'get 'posts #:order-by '(postnum asc) #:condition (where (format #f "board='~a' and threadnum=~a" board threadnum)))
    (mtable 'get 'posts #:order-by '(postnum asc) #:condition (where #:board board #:threadnum threadnum))

    (let ((tail-posts (reverse (mtable 'get 'posts #:order-by '(postnum desc) #:ret last #:condition (where #:board board #:threadnum threadnum)))))
      (if (= 1 (assoc-ref (car tail-posts) "postnum"))
        tail-posts
        (append (mtable 'get 'posts #:condition (where #:board board #:threadnum threadnum #:postnum 1))
                tail-posts)))))

(define-public (database-get-subposts mtable board threadnum postnum)
  (mtable 'get 'subposts #:order-by '(ctime desc) #:condition (where (format #f "board='~a' and threadnum=~a and postnum=~a" board threadnum postnum))))

(define-public (database-get-preview-posts rc board threadnum post-preview-count)
  (:conn rc (format #f "SELECT * FROM (SELECT * FROM posts WHERE board='~a' AND threadnum=~a AND postnum=1) UNION SELECT * FROM (SELECT * FROM posts WHERE board='~a' AND threadnum=~a ORDER BY POSTNUM DESC LIMIT ~a);" board threadnum board threadnum post-preview-count))
  (DB-get-all-rows (:conn rc)))

(define-public (database-get-posts-from-list mtable board threadnum postnums)
  (mtable 'get 'posts #:order-by '(id asc) #:condition (where (format #f "board='~a' and threadnum=~a and (postnum in (~a))" board threadnum postnums))))

(define-public (database-get-OP mtable board threadnum)
  (mtable 'get 'posts #:condition (where (format #f "board='~a' and threadnum=~a and postnum=1" board threadnum))))

(define-public (database-get-board-threadcount mtable board)
  (mtable 'get 'boards #:columns '(threadcount) #:condition (where #:board board)))

(define-public (database-save-post mtable board threadnum postnum ip sage name date ctime finfo filename fsize comment)
  (mtable 'set 'posts #:board board #:threadnum threadnum #:postnum postnum #:ip ip #:name
          (if (or (not sage)
                  (null? sage)
                  (equal? (car sage) "nokosage"))
            name
            (format #f "<a class=''sage'' href=''mailto:~a''>~a</a>" (car sage) name))
          #:date date #:ctime ctime #:image (car finfo) #:thumb (cadr finfo) #:iname filename #:size (format #f "~a, ~a, ~a" (caddr finfo) fsize (cdddr finfo)) #:comment comment))

(define-public (database-save-subpost mtable board threadnum postnum ip name date ctime comment)
  (mtable 'set 'posts (format #f "subposts=~a where board='~a' and threadnum=~a and postnum=~a" 1 board threadnum postnum))
  (mtable 'set 'subposts #:board board #:threadnum threadnum #:postnum postnum #:ip ip #:name name
          #:date date #:ctime ctime #:comment comment))

(define-public (database-update-thread mtable board threadnum postnum sage ctime btime)
  (mtable 'set 'threads (format #f "btime=~a,postcount=~a where board='~a' and threadnum=~a" (if (null? sage) ctime btime) postnum board threadnum)))

(define-public (database-create-thread mtable board threadnum subject date ctime)
  (mtable 'set 'threads #:board board #:threadnum threadnum #:postcount 1 #:subject subject #:date date #:ctime ctime #:btime ctime))

(define-public (database-prune-unlisted mtable boards ctime unlisted-factor default-page-len default-page-count prune-time)
  (let ((ands (string-join
               (map (lambda (board)
                      (format #f "board!='~a'" (car board)))
                    boards)
               " AND ")))
    (mtable 'set 'threads (format #f "old=~a WHERE old=0 AND ~a AND threadnum NOT IN (SELECT threadnum FROM threads WHERE old=0 AND ~a ORDER BY btime DESC LIMIT ~a);" ctime ands ands (* unlisted-factor default-page-count default-page-len)))
    (mtable 'get 'threads #:columns '(board threadnum) #:condition (where (format #f "~a AND old>0 AND old<=~a-~a" ands ctime prune-time)))))

(define-public (database-prune-board mtable board ctime page-count page-len prune-time)
  (mtable 'set 'threads (format #f "old=~a WHERE old IS NULL AND board='~a' AND threadnum NOT IN (SELECT threadnum FROM threads WHERE old IS NULL AND board='~a' ORDER BY btime DESC LIMIT ~a);" ctime board board (* page-count page-len)))
  (mtable 'get 'threads #:columns '(threadnum) #:condition (where (format #f "board='~a' AND old>0 AND old<=~a-~a" board ctime prune-time))))

(define-public (database-add-thread-to-board mtable board threadnum)
  (if (= threadnum 1)
    (mtable 'set 'boards #:threadcount 1 #:board board)
    (mtable 'set 'boards (format #f "threadcount=~a where board='~a'" threadnum board))))

(define-public (database-refilter mtable refilter-func)
  (format #t "@@@@@@@@@@@@@@@@ here.\n")
  (let ((posts (mtable 'get 'posts)))
    (for-each
     (lambda (post)
       (let ((comment (assoc-ref post "comment"))
             (board (assoc-ref post "board"))
             (threadnum (assoc-ref post "threadnum"))
             (postnum (assoc-ref post "postnum")))
         (mtable 'set 'posts #:comment (refilter-func comment board threadnum postnum) (where #:board board #:threadnum threadnum #:postnum postnum))))
     posts)))
