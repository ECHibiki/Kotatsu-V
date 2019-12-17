#! /run/current-system/profile/bin/guile
;;;-*-guile-scheme-*-;;; !#

(define-module (modules settings))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Edit the settings below ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-public website-title "下葉ちゃんねる")
(define-public greeting "")
(define-public default-comment "ｷﾀ━━━(ﾟ∀ﾟ)━━━!!") ; Default comment if left blank by user
(define-public javascript-enabled #t)

(define-public max-thumb-size 150) ; Image thumbnail size
(define-public max-thumb-size-OP 250) ; Image thumbnail size for OP images

;;; Custom function for date format. Default format is ISO-8601
(use-modules (srfi srfi-19))
(define-public (get-datestring)
  (date->string (current-date 0) "~5"))

;;; Cooldowns - A 2 tier system is good for bot spam
;(define-public tier1-cooldown 15) ; Tier 1: A flat cooldown (in seconds) on all posts. Set to 0 to disable Tier 1
;(define-public tier2-post-limit 50) ; Tier 2: Maximum amount of posts that can be made within
;(define-public tier2-cooldown 3600) ;         <-- this period of time (seconds). Set tier2-cooldown to 0 to disable Tier 2
(define-public tier1-cooldown 15) ; Tier 1: A flat cooldown (in seconds) on all posts. Set to 0 to disable Tier 1
(define-public tier2-post-limit 1000) ; Tier 2: Maximum amount of posts that can be made within
(define-public tier2-cooldown 3600) ;         <-- this period of time (seconds). Set tier2-cooldown to 0 to disable Tier 2

;;; Thread pruning
;;;   - After a thread falls below (* page-len pages) active threads then it gets "marked as old"
;;;     Note: This only counts active (not "old") threads. For instance, if page-len=15 and pages=10 then the 150th thread is active, and although bumping an "old" thread will knock it off the last page (so it's the 151st thread) it's still the 150th active thread and won't be marked as old.
;;;   - After a thread has been "old" for prune-time amount of seconds then it is deleted
(define-public prune-time 604800) ; default = 604800 seconds = 1 week
(define-public active-post-limit 500) ; After this many posts the thread is marked "old"
(define-public post-deletion-period 3600) ; Period in seconds where users can delete posts after making them

;;; Maximum field lengths
(define-public max-subject-length 60)
(define-public max-name-length 40)
(define-public max-comment-length 4000)
(define-public max-comment-lines 80)
(define-public max-comment-preview-lines 40) ; longer posts will be truncated on board preview, but displayed in full within threads
(define-public max-filename-length 200)
(define-public max-filename-display-length 30) ; filenames will be shortened, but full filename will be displayed as tooltip
;(define-public max-session-length 40)
(define-public max-board-name-length 10)

;;; Main template files
;;; NOTE: The purpose of this is to make it easy to switch templates
;;;       (e.g. switch to holiday themed templates, you can even add scheme code to check the date and apply templates accordingly)
(define-public default-board-template 'board-tpl) ; Template for boards
(define-public default-OP-template 'post-OP) ; Template function for thread OP's

;(define-public default-post-template post-tpl) ; Template function for normal posts
(define-public default-name "Nameless")
(define-public default-subject "Untitled") ; Default new thread subject if left blank by user
(define-public default-board-message "<span class=\"shade\">【File uploads are unmodified. Please use caution when downloading.】</span>")
(define-public default-page-count 10)
(define-public default-page-len 15)
(define-public unlisted-factor 10)

;;; Enable/Disable banners and stylesheets (files will be searched in pub/img/ and pub/css/ respectively)
(define-public banner-rotation-period 300) ; in seconds
(define-public banners '("banner1.jpg" "banner2.jpg" "banner3.jpg"))
(define-public styles '("multi-theme" "kotatsu" "tomorrow" "pseud0ch" "yotsuba" "yotsubab" "ergonomic" "computer"))
(define-public default-style "kotatsu-red")

;;; Define boards here
(define-public post-preview-count 5) ; Amount of posts to display under a thread when viewing from a board page
(define-public allow-unlisted-boards #t) ; If #f then visiting unlisted boards will serve the user a 404.
(define-public noko-enabled #f) ; Enabled: returns to board after posting, type "noko" in options field to be sent to the thread. Diabled: sends you to the thread after posting, type "nonoko" in options field to be sent back the board instead.
(define-public default-OP-file-required #f) ; Set to #t to force OP posts to require a file
(define-public default-OP-mimetypes-whitelist '()) ; Allow these filetypes, set to '() to allow any filetype by default
(define-public default-mimetypes-whitelist '())
(define-public default-OP-mimetypes-blacklist '(SWF HTML5)) ; Block these filetypes, set to '() to not block any files
(define-public default-mimetypes-blacklist '(SWF HTML5))
;;; NOTE: New boards added to this list are automatically added to the database, however removing boards which have threads on them will not remove them from the database, but will make them innaccessible to users
(define-public boards `(("all" . ((title    . "All Threads")
                                  (special  . all)
                                  (posting-disabled . #t)
                                  (theme    . "none")
                                  (message  . ,(string-append "This board shows threads from all other boards.<br>" default-board-message))))
                        ("listed" . ((title  . "Listed Threads")
                                    (special . listed)
                                    (posting-disabled  . #t)
                                    (theme    . "none")
                                    (message  . ,(string-append "This board shows threads from all listed boards.<br>" default-board-message))))
                        ("unlisted" . ((title  . "Unlisted Threads")
                                      (special . unlisted)
                                      (posting-disabled  . #t)
                                      (theme   . "none")
                                      (message . ,(string-append "This board shows threads from all unlisted boards.<br>" default-board-message))))
                        ("a"    . ((title    . "Anime & Manga")
                                   (theme    . "yotsubab")))
                        ("ni"  . ((title    . "日本裏")
                                  (message  . ,(string-append "<div style=\"text-align:left;width:260px\"><span class=\"aa\">　 　　 　./＼　　　　　　　 /＼<br>
　　　　 /:::::::ヽ＿＿＿＿/::::::::ヽ、<br>
　　　 ／　::. ＿　　.:::::::::::::　 ＿::::ヽ_<br>
　　／　／　°ヽ_ヽｖ /:／　°ヽ::::::ヽ<br>
　/　／.（￣（￣＿＿丶 ..（￣（＼　 ::::|<br>
. |　.:::::::: ）　 ）/ / ｔｰｰｰ|ヽ） 　）　.::::: ::|<br>
. |　.::::...（　 （..|｜.　　　 |　（　 （　　　 ::|<br>
. |　:::.　 ）　 ）| |⊂ニヽ .| !　） 　）　 　::::|<br>
　|　:　 （　 （ | |　 |:::T::::.|　（　 （　　 　::|</span></div><br>" default-board-message))
                                  (name     . "名無しさん")
                                  (theme    . "pseud0ch")))
                        ("d"   . ((title    . "二次元エロ")
                                  (message  . ,(string-append "Welcome to the 2D erotic board.<br>Please try to keep most of the content Japanese.<br>" default-board-message))
                                  (name     . "変態")
                                  (theme    . "yotsuba")))
                        ("cc"  . ((title    . "Computer Club")
                                  (message  . ,(string-append "Hi, welcome to the computer club, I'll be your guide! :(){ :|:& };:<br>" default-board-message))
                                  (name     . "guest@cc")
                                  (theme    . "computer")))
                        ("f"   . ((title    . "Flash & HTML5")
                                  (theme    . "yotsuba")
                                  (message  . ,(string-append "[embed flash banner here]<br>"default-board-message))
                                  (page-len . 30)
                                  (page-count . 1)
                                  (OP-file-required . #t)
                                  (mimetypes-OP-whitelist . (SWF HTML5))
                                  (mimetypes-blacklist . ())
                                  (board-template . board-flash-tpl)
                                  (preview-OP-template . post-OP-flash)))
                        ("v"   . ((title    . "Video Games")
                                  (name     . "Player")
                                  (theme    . "kotatsu")))
                        ("ho"  . ((title    . "Other")
                                  (message  . ,(string-append "Welcome to the Other board.<br>Enjoy your stay.<br>" default-board-message))
                                  (theme    . "yotsuba")))))

;;; Define mods:
(define-public mods `(; NAME      PERMISSIONS  DEFAULT_PASSWORD(this field is only used until the mod changes their password)
                      ("Admin"   "*"          "abc123")
                      ("SomeMod" "*"          "abc123")))

;(define-public admin-only-pages '("panel" "note-editor" "notes-view" "logoff")) ; These are pages which should throw and "unauthorized" error if accessed by non-moderators
