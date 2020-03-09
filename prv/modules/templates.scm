(define-module (modules templates)
  #:use-module (artanis config)
  #:use-module (modules settings)
  #:use-module (modules utils)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-19)
  #:use-module (ice-9 i18n)
  #:export (message-tpl
            index-tpl
            frames-tpl
            frame-nav-tpl
            sidebar-data-tpl
            about-tpl
            rules-tpl
            news-tpl
            contact-tpl
            login-tpl
            logoff-tpl
            note-tpl
            note-short-tpl
            panel-tpl
            noticeboard-tpl
            notes-view-tpl
            post-tpl
            board-tpl
            board-flash-tpl
            catalog-tpl
            thread-tpl
            catalog-thread-tpl
            post-list-tpl
            post-OP-tpl
            post-OP-flash-tpl
            note-editor-tpl
            sandbox-tpl))

(define (message-tpl message)
  `(h1 ,(format #f "~a" message)))

(define* (document-tpl title description style body)
  `("<!DOCTYPE html>"
    (html (@ (lang "en-US")
             (style "width:100%;height:100%"))
     (head
      (meta (@ (charset "utf-8")))
      (meta (@ (name "robots") (content "noarchive")))
      (meta (@ (name "description") (content ,description)))
      (link (@ (rel "icon") (href "/pub/img/favicon.ico") (type "image/x-icon")))
      (title ,title))
      ,(if style
         `(link (@ (rel "stylesheet") (href ,(format #f "/pub/css/~a.css" style))))
         '())
      ,(if javascript-enabled
         '(script (@ (type "text/javascript") (src "/pub/js/main.js")) #f)
         '())
     ,body)))

(define (master-tpl admin pagetitle style style-menu body-class mid-class message mid)
  (document-tpl pagetitle "Some message board" style
    `(body (@ (class ,body-class))
      ,(if javascript-enabled
         '(div (@ (id "sidebar") (class "nav sidebar")) #f)
         '())
      (header (@ (id "head"))
       (div (@ (class "header"))
        (a (@ (style "float:right") (href "#foot")) "▼")
        (center
         (span (@ (class "site-name")) ,website-title)
         (br)
         ,@(if admin
             `((span (@ (style "font-weight:bold;font-size:24px")
                        (class "name"))
                "Admin - " ,(assoc-ref (car admin) "name")) (br))
             '())
         (img (@ (src ,(format #f "/pub/img/~a"
                               (list-ref banners
                                         (modulo (round (/ (time-second (current-time time-utc))
                                                           banner-rotation-period))
                                                 (length banners)))))))
         (br)
         ,message
         ,@(if admin
             `("Admin links: [" (a (@ (href "/panel")) "Admin Panel") "] [" (a (@ (href "/logoff")) "Logoff") "]" (br))
             '())
         "[" (a (@ (href "/index")) "HOME") "] "
         "[" (a (@ (href "/frames") (target "_top")) "Frames") "] "
         "[" (a (@ (href "/about")) "About") "] "
         "[" (a (@ (href "/rules")) "Rules") "] "
         "[" (a (@ (href "/news")) "News") "] "))
       (hr))
      (section
       (div (@ (class ,(format #f "mid ~a" mid-class)))
        (br)
        ,mid
        (br))
       (hr))
      ,(footer-tpl style-menu))))

(define (footer-tpl style-menu)
  `(footer (@ (id "foot"))
    (a (@ (style "float:right") (href "#head")) "▲")
    (a (@ (target "_top") (href "https://www.gnu.org/software/guile/"))
     (img (@ (style "vertical-align:middle")
             (src "/pub/img/guile.png"))))
    " "
    (a (@ (target "_top")
          (href "https://www.gnu.org/software/artanis/"))
     (img (@ (style "vertical-align:middle")
             (src "/pub/img/artanis.png")
             (height "25"))))
    " ♦ "
    (a (@ (href "/contact")) "Contact")
    (div (@ (id "top-nav")
            (class "top-nav"))
     ,@(if javascript-enabled
         '((script (@ (type "text/javascript"))
            "initSidebar();")
           (a (@ (href "javascript:void(0);") (onclick "showSidebar();")) "⇥ Show Menu")
           (br))
         '())
     (form (@ (enctype "multipart/form-data")
              (action "/set-style")
              (method "post"))
      "Stylesheet:"
      (select (@ (name "style")
                 (autocomplete "off"))
       ,style-menu)
      (input (@ (type "submit") (name "submit") (value "Submit"))))
     ,@(cdr (apply append
                   (map (lambda (board)
                          `(" ･ " (a (@ (href "/board/" ,(car board))) ,(string-append "/" (car board) "/"))))
                        boards))))))

(define (index-tpl style style-menu admin news-block)
  (master-tpl admin website-title style style-menu "none" "infopage" greeting
    `((center
       (img (@ (src "/pub/img/logo.png")))
       (table
        (tr
         (td
          (h3
           ,(call-with-values
              (lambda () (partition
                          (lambda (board) (member (assq-ref (cdr board) 'special) '(all listed unlisted)))
                          boards))
              (lambda (specials normals)
                (string-append
                 (string-join
                  (map (lambda (board)
                         (format #f "<a href=\"/board/~a\">~a</a>" (car board) (assq-ref (cdr board) 'title)))
                       specials)
                  "\n")
                 "<br><hr>Boards:<br>"
                 (string-join
                  (map (lambda (board)
                         (format #f "<a href=\"/board/~a\">~a</a>" (car board) (assq-ref (cdr board) 'title)))
                       normals)
                  "\n")))))))))
      (br)
      "[" (a (@ (href "/news")) "View all news postings") "]"
      (br)
      (hr (@ (style "border-style:groove;border-width:0px 0px 2px 0px")))
      ,news-block)))

(define (frames-tpl)
  (document-tpl website-title "iframes" #f
    `(frameset (@ (cols "110px,*") (border "1"))
      (frame (@ (src "/frame-nav") (name "panel")))
      (frame (@ (src "/index") (name "main"))))))

(define (frame-nav-tpl style admin)
  (document-tpl website-title "iframes" style
    `(body (@ (class "nav"))
      ,(sidebar-data-tpl #t #:admin admin))))

(define* (sidebar-data-tpl frame? #:key admin)
  (let ((target (if frame? "main" "")))
    `((a (@ (href "/index") (target ,target)) (img (@ (src "/pub/img/favicon.ico"))))
      (br)
      "["
      ,(if frame?
         '(a (@ (target "_top") (href "/index")) "Remove Frames")
         '(a (@ (target "_top") (href "javascript:void(0);") (onclick "hideSidebar();")) "Hide Menu ⇤"))
      "]"
      (br)(br)
      ,(call-with-values
         (lambda () (partition
                     (lambda (board) (member (assq-ref (cdr board) 'special) '(all listed unlisted)))
                     boards))
         (lambda (specials normals)
           (string-append
            (string-join
             (map (lambda (board)
                    (format #f "<div style=\"padding-bottom:5px\"><a href=\"/board/~a\" target=\"~a\">~a</a></div>" (car board) target (assq-ref (cdr board) 'title)))
                  specials)
             "\n")
            "<br><hr><h3>Boards</h3>"
            (string-join
             (map (lambda (board)
                    (format #f "<div style=\"padding-bottom:5px\"><a href=\"/board/~a\" target=\"~a\">~a</a></div>" (car board) target (assq-ref (cdr board) 'title)))
                  normals)
             "\n"))))
      (br)(hr)(br)
      ,(if (and frame? (not admin))
        '()
        `((div (@ (id "sidebar-admin-links"))
           (h3 "Admin Links")
           (div (@ (style "padding-bottom:5px")) (a (@ (href "/panel") (target ,target)) "Admin Panel"))
           (div (@ (style "padding-bottom:5px")) (a (@ (href "/logoff") (target ,target)) "Log Off")))))
      (h3 "Information")
      (div (@ (style "padding-bottom:5px")) (a (@ (href "/") (target "_top")) "HOME"))
      (div (@ (style "padding-bottom:5px")) (a (@ (href "/about") (target ,target)) "About"))
      (div (@ (style "padding-bottom:5px")) (a (@ (href "/rules") (target ,target)) "Rules"))
      (div (@ (style "padding-bottom:5px")) (a (@ (href "/news") (target ,target)) "News")))))

(define (about-tpl style style-menu admin)
  (master-tpl admin (string-append "About - " website-title) style style-menu "none" "infopage" "<h2>About</h2>"
    `(center
      "Place holder." (br)
      (table (@ (border "2") (valign "top"))
       (tr (td (@ (class "stack"))
            (ul (li (a (@ (href "#what")) "What is Shitaba?"))
                (li (a (@ (href "#unlisted")) "What are unlisted boards?"))
                (li (a (@ (href "#side")) "What are side threads?"))
                (li (a (@ (href "#format")) "How are posts formatted?"))
                (li (a (@ (href "#html5")) "How do I upload HTML5 files?"))))))
      (br)(hr)(br)
      (table (@ (border "2") (valign "top"))
       (tr (td (@ (class "stack"))
            (div (@ (id "what"))
             (h3 "What is Shitaba?")
             (blockquote "Prounounced \"Shitaba\", it is an imageboard for discussing various hobbyist topics, modelled after Japanese style discussion and imageboards such as 2channel and Futaba, and English imageboards such as 4chan."))
            (div (@ (id "unlisted"))
             (h3 "What are unlisted boards?")
             (blockquote "A feature to give flexibility to the board list." (br)
                         (br)
                         "These are not user created/owned boards. Users can't give them a title or control them any differently from the main boards." (br)
                         "Unlisted boards may be purged and/or repurposed at any time. For more stability please use the main boards." (br)
                         (br)
                         "To use, simply modify the URL to point to the board label of your choice (e.g. <a href="/board/example">/board/example</a>) and start posting." (br)))
	    (div (@ (id "side"))
             (h3 "What are side threads?")
             (blockquote "Shitaba allows for users to create comment chains within posts."  (br) (br)

		"By putting a post number into the options field it will create a more direct response to a poster putting a box bellow his post with your comment in it. In order to respond to a side thread put the post number of the comment into the options field just like the previous poster did." (br)(br)
                         "The hope is to prevent threads from being derailed by arguments and flamewars. Overall a benefit to self moderation." (br)
                         (br)))
            (div (@ (id "format"))
             (h3 "How are posts formatted?")
             (blockquote "Unlike most sites, whitespace is not collapsed on Shitaba. If you add 5 spaces between words you'll get 5 spaces between words." (br)
                         "This gives you more control in formatting your posts. Additionally text next to images in posts will not wrap underneath the image so the formatting will be preserved." (br)
                         (br)>
                         "The following BBCodes are available:" (br)
                         (table (@ (border 1) (style "border-collapse:separate"))
                          (tr (th "What you type") (th "How it will appear"))
                          (tr (td (@ (style "border:1px solid #000")) "[code]A monospace code block.[/code]")
                              (td (@ (style "border:1px solid #000")) (span (@ (class "code")) "A monospace code block.")))
                          (tr (td (@ (style "border:1px solid #000")) "[aa]Text formatted to properly display Japanese style text art.[/aa]")
                              (td (@ (style "border:1px solid #000")) (span (@ (class "aa")) "Text formatted to properly display Japanese style text art.")))
                          (tr (td (@ (style "border:1px solid #000")) "[spoiler]Spoilered text.[/spoiler]")
                              (td (@ (style "border:1px solid #000"))
                               (span (@ (class "spoiler")) "Spoilered text.</span> <span class=\"shade\">(highlight with mouse to reveal the text)"))))))
            (div (@ (id "html5"))
             (h3 "How do I upload HTML5 files?")
             (blockquote "As Flash is being phased out, and will not be receiving updates in the future, a replacement is needed. The HTML5 specification has widely been used across the internet to replace Flash. Although it's not the same thing, it seems flexible enough to do the job, and mostly seems to be lacking tools to make development as easy as Flash, and lacking a single container filetype." (br)
                         (br)
                         "We are attempting to work around the 2nd deficiency by simply using .tar.gz files as the container for uploading media collections." (br)
                         (ul (li "Place all the necessary media files inside a single directory and make sure the final project is re-locatable (you should be able to move the location of the directory and still run the project).")
                             (li "The main entry point should be named " (b "main.html") " (this is the html page the user will run when they open the file).")
                             (li "Any file named " (b "index.html") " will be overwritten by the server when it unpacks the project.")
                             (li "Create the tar.gz archive of the project and make sure it has extension \".html5\":")
                             (ul (li (span (@ (class "code")) "~$ tar cfvz your-project.html5 project-directory")))
                             (li "Upload the .html5 archive."))))))))))

(define (rules-tpl style style-menu admin)
  (master-tpl admin (string-append "Rules - " website-title) style style-menu "none" "infopage" "<h2>Rules</h2>"
    `(center
      (table (@ (border "2") (valign "top"))
       (tr (td (@ (class "stack"))
            (ol (li (b "Don't post anything illegal under United States law.")) (br)
                (li (b "No excessive spam or advertising.")))))))))

(define (news-tpl style style-menu admin news-block)
  (master-tpl admin (string-append "News - " website-title) style style-menu "none" "infopage" "<h2>News</h2>"
    news-block))

(define (contact-tpl style style-menu admin)
  (master-tpl admin (string-append "Contact - " website-title) style style-menu default-style "infopage" "<h2>Contact</h2>"
    `(center
      "For feedback, suggestions, bug reports, or help:" (br)
      (table (@ (border "2") (valign "top"))
       (tr (td (@ (class "stack"))
            "GitHub: " (a (@ (href "https://github.com/ECHibiki/kotatsu")) "https://github.com/ECHibiki/kotatsu")))
       (tr (td (@ (class "stack"))
            "Email: " (img (@ (src "/pub/img/email.png")))))))))

(define (login-tpl style style-menu admin)
  (master-tpl admin (string-append "Login - " website-title) style style-menu "none" "infopage" "<h2>Login</h2>"
    `((h3 "Moderator Login:")
      (div (@ (style "display:table"))
       (form (@ (enctype "multipart/form-data") (method "post"))
        (table (@ (class "postform") (border "1"))
         (tr (td (@ (class "field")) "Name")
             (td (input (@ (type "text") (name "name") (size "50")))))
         (tr (td (@ (class "field")) "Password")
             (td (input (@ (type "password") (name "password") (size "50")))))
         (tr (td (@ (class "field")) "Submit")
             (td (input (@ (type "submit") (name "submit") (value "Submit")))))))))))

(define (logoff-tpl style style-menu admin logoff-result)
  (master-tpl admin (string-append "Logoff - " website-title) style style-menu "none" "infopage" "<h2>Logoff</h2>"
    `(,logoff-result
      (h1 "Successfully logged off."))))

(define (imgops-tpl image board-uri threadnum)
  (if image
    `(" " (span (@ (class "imgops"))
                "[" (a (@ (href ,(format #f "https://imgops.com/http://~a/pub/img/~a/~a/~a" (get-conf '(host name)) board-uri threadnum image))
                          (target "_blank"))
                       "ImgOps")
                "]"))
    '()))

(define (note-tpl id type links-target subject name date admin body edited)
  `(div (@ (id "note" ,id) (class ,type))
    (h3 (b (a (@ (class "link")
                 (href "/" ,links-target "#note" ,id))
            ,subject))
        " by " (b ,name) " [" ,type ":" ,(number->string id) "]")
    (span (@ (style "font-size:11px"))
     ,date
     ,@(if admin
        `(" " (a (@ (href "/note-editor/" ,id)) "(edit)"))
        '()))
    (blockquote ,body)
    ,(if (equal? edited "")
       '()
       `(span (@ (class "shade")) "Last edited by: " ,edited))))

(define (note-short-tpl id type links-target subject name date admin body edited)
  `(li (@ (class ,type)
          (id "note" ,id))
    (b (a (@ (class "link")
             (href "/" ,links-target "#note" ,id))
        ,subject))
    " by "
    (b ,name) " [" ,type ":" ,(number->string id) "] "
    (span (@ (span "font-size:11px"))
     ,date
     ,@(if admin
         `(" " (a (@ (href "/note-editor/" ,id)) "(edit)"))
         '()))))

(define (panel-tpl style style-menu admin notice-block shared-block note-block)
  (master-tpl admin (string-append "Admin Panel - " website-title) style style-menu "none" "infopage" "<h2>Admin Panel</h2>"
    `((div (@ (class "stack") (style "margin:5px"))
       (b "Message")
       (br)(br)
       (ul (li (a (@ (href "/noticeboard")) "Noticeboard"))
           (ul (table (@ (style "width:100%"))
                (tr (th (@ (style "padding:0px")) "Notices")
                    (th (@ (style "padding:0px")) "Private notes being shared with you"))
                (tr (@ (style "vertical-align:top"))
                 (td ,notice-block)
                 (td (@ (style "padding-left:12px")) ,shared-block))))
           (br)
           (li (a (@ (href "/notes-view")) "Personal Notes"))
           (ul ,note-block)
           (br)
           (li (a (@ (href "/note-editor/new")) "New Note")))
       (br)(br)
       (b "Administration:") "(work in progress)"             
       (br)(br)
       (ul (li "Report Queue")
           (li "Ban List")
           (li "Manage Users")
           (li "Moderation Log")))
      (p (b "Info")
         (br)
         "To post with your moderator capcode "
         (b (span (@ (class "name")) (span (@ (class "capcode"))
                                      ,(assoc-ref (car admin) "name")
                                      " ## SysOP "
                                      (img (@ (title "Mod") (style "vertical-align:bottom") (src "/pub/img/capcode.png"))))))
         " just make sure you're signed in, then when making a post put in the name field: "
         (b (span (@ (class "name"))
             ,(assoc-ref (car admin) "name")
             " ## SysOp"))
         (br)
         "(The first part must be your mod name, but you can replace \"SysOp\" with anything you want. Please don't use the capcode for casual posting.)"
         (br)(br)
         "To create News or a Noticeboard entries start by clicking " (b (u "New Note")) " above."
         (br)
         "On the new note page you can select where you want the note to appear and which other mods can access it."
         (br)
         "You can also edit notes and turn existing ones into news items or noticeboard entries at a later time."
         (br))
      (br)(hr)(br)
      (div (@ (style "display:table"))
       (b "Change Password")
       (form (@ (enctype "multipart/form-data") (method "post"))
        (table (@ (class "postform") (border "1") (style "margin:5px"))
         (tr (td (@ (class "field")) "Name")
             (td (input (@ (type "text") (name "name") (size "50")))))
         (tr (td (@ (class "field")) "Current Password")
             (td (input (@ (type "password") (name "current-password") (size "50")))))
         (tr (td (@ (class "field")) "New Password")
             (td (input (@ (type "password") (name "new-password") (size "50")))))
         (tr (td (@ (class "field")) "Confirm Password")
             (td (input (@ (type "password") (name "confirm-password") (size "50")))))
         (tr (td (@ (class "field")) "Submit")
             (td (input (@ (type "submit") (name "submit") (value "Submit")))))))))))

(define (noticeboard-tpl style style-menu admin notice-block shared-block)
  (master-tpl admin (string-append "Noticeboard - " website-title) style style-menu default-style "infopage" "<h2>Noticeboard</h2>"
    `(table (@ (style "width:100%;max-width:1800px"))
      (tr (th (@ (style "width:50%")) "Notices")
          (th "Private notes being shared with you"))
      (tr (@ (style "vertical-align:top"))
       (td ,notice-block)
       (td ,shared-block)))))

(define (notes-view-tpl style style-menu admin personal-block)
  (master-tpl admin (string-append "Notes - " website-title) style style-menu default-style "infopage" "<h2>Personal Notes</h2>"
    personal-block))
      
(define (post-tpl mode board-uri threadnum postnum name date image iname thumb size comment subposts replies)
  (display size)(newline)
  `((table (@ (class "post-frame"))
    (tr
     (td (@ (valign "top") (weight "bold")) "»")
     (td
      (div (@ (border "1") (id ,postnum "p") (class "post"))
       (input (@ (type "checkbox") (name "posts") (value ,board-uri "/" ,threadnum "/" ,postnum)))
       (b
        (a (@ (href "/thread/" ,board-uri "/" ,threadnum "#" ,postnum "p") (onclick "postNumClick(this)")) ,(number->string postnum)) " "
        (span (@ (class "name")) ,name) " "
        (span (@ (class "date")) ,date)
        ,(imgops-tpl image board-uri threadnum))
       (br)
       ,@(if image
           `("File: " (a (@ (title ,iname)
                            (href ,(format #f "/pub/img/~a/~a/~a" board-uri threadnum image))
                            (download ,iname))
                         ,(shorten iname max-filename-display-length))
             " (" ,size ")"
             (br))
           '())
       (table
        (tr (@ (valign "top"))
         ,(if image
            `(td (a (@ (target "_top")
                       (href ,(format #f "/pub/img/~a/~a/~a" board-uri threadnum image)))
                  (img (@ (src "/pub/img/" ,board-uri "/" ,threadnum "/" ,thumb)
                          (onclick "ret=thumbnailClick(this);return ret;")
			  (onload "swapIsLoaded(this)")
                          (data-swap-with "/pub/img/" ,board-uri "/" ,threadnum "/" ,image)
                          (data-mimetype ,(car (string-split size #\,)))))))
            '())
         (td
          (blockquote ,(truncate-comment comment max-comment-preview-lines mode))
          ,(if subposts
            `(div (@ (class "subthread"))
              ,@(map (lambda (subpost)
                       (subpost-tpl subpost board-uri threadnum postnum))
                     subposts))
            '()))))))))
    ;; replies is for tacking on other posts when visiting a complex link, like >>1-10
    ,(if replies replies '())))

(define (mod-bar-tpl admin)
  (if (not admin)
    '()
    `((span (@ (class "field")
               (style "padding:4px"))
       (b "Mod Actions:")
       (input (@ (type "radio") (name "modaction") (value "del"))) "Del"
       (input (@ (type "radio") (name "modaction") (value "delimg"))) "Del Img"
       (input (@ (type "radio") (name "modaction") (value "ban"))) "Ban"
       (input (@ (type "radio") (name "modaction") (value "sticky"))) "Toggle Sticky"
       (input (@ (type "radio") (name "modaction") (value "old"))) "Toggle Old"
       (input (@ (type "submit") (name "submit") (value "Submit"))))
      (br))))

(define* (post-form-tpl password #:key subject-field?)
  `(form (@ (enctype "multipart/form-data") (method "post"))
    (table (@ (class "postform") (border 1))
     (tr (td (@ (class "field")) "Options")
         (td (input (@ (type "text") (name "options") (size "20"))))
         (td (@ (class "field")) "Password")
         (td (input (@ (type "text") (name "password") (size "20") (placeholder "Use IP address if blank") (value ,password)))))
     ,(if subject-field?
        `(tr (td (@ (class "field")) "Subject")
             (td (@ (colspan "3")) (input (@ (type "text") (name "subject") (size "51")))))
        '())
     (tr (td (@ (class "field")) "Name")
         (td (@ (colspan "3")) (input (@ (type "text") (name "name") (size "45")))
                               (input (@ (type "submit") (name "submit") (value "Post")))))
     (tr (td (@ (class "field")) "Comment")
         (td (@ (colspan "3")) (textarea (@ (rows "5") (cols "50") (name "comment")) #f)))
     (tr (td (@ (class "field")) "File")
         (td (@ (colspan "3")) (input (@ (type "file") (name "file"))))))))

(define (board-tpl style style-menu admin board board-html board-uri board-title password page-count news-block threads)
  (let ((page-links `(,(map (lambda (page)
                              `("[" (a (@ (href "/board/" ,board-uri "?page=" ,(+ page 1))) ,(number->string (+ page 1))) "] "))
                            (iota page-count))
                      "[" (a (@ (href "/catalog/" ,board-uri)) "Catalog") "]")))
    (master-tpl admin (format #f "/~a/ - ~a - ~a" board-html board-title website-title)
                 style style-menu (or (assoc-ref (assoc-ref boards board) 'theme) default-style)
                 "preview"
                 (format #f "<h2>/~a/ - ~a</h2><div class=\"board-message\"><div class=\"post\">~a</div></div>" board-html board-title (or (assoc-ref (assoc-ref boards board) 'message) default-board-message))
      `((div (@ (class "news-box"))
         (ul ,news-block))
        ,@(if (assq-ref (assoc-ref boards board) 'posting-disabled)
           '()
           `((center ,(post-form-tpl password #:subject-field? #t)) (br)))
        ;; This form covers all thread and post boxes and is used for submitting actions such as post deletion
        (form (@ (enctype "multipart/form-data") (action "/mod-posts") (method "post"))
         ,@page-links
         (br)
         ,@(mod-bar-tpl admin)
         ,threads
         ,@page-links
         (span (@ (style "float:right")) "Delete Post: " (input (@ (type "submit") (name "delete-button") (value "Delete")))))))))

(define (board-flash-tpl style style-menu admin board board-html board-uri board-title password page-count news-block threads)
  (master-tpl admin (format #f "/~a/ - ~a - ~a" board-html board-title website-title)
               style style-menu (or (assoc-ref (assoc-ref boards board) 'theme) default-style)
               "preview"
               (format #f "<h2>/~a/ - ~a</h2><div class=\"board-message\"><div class=\"post\">~a</div></div>" board-html board-title (or (assoc-ref (assoc-ref boards board) 'message) default-board-message))
    `((div (@ (class "news-box"))
       (ul ,news-block))
      (form (@ (enctype "multipart/form-data") (action "/mod-posts") (method "post"))
       ,@(mod-bar-tpl admin)
       (center
        (table (@ (class "flash") (cellspacing "1px"))
         (thead (tr (th "No.")
                    (th "Name")
                    (th "Board")
                    (th "File")
                    (th "Size")
                    (th "Subject")
                    (th "Date")
                    (th "Replies")
                    (th "")))
         ,threads))
       (span (@ (style "float:right")) "Delete Post: " (input (@ (type "submit") (name "delete-button") (value "Delete")))))
      (br)(hr)(br)
      ,(if (assq-ref (assoc-ref boards board) 'posting-disabled)
         '()
         `(center ,(post-form-tpl password #:subject-field? #t))))))

(define (catalog-tpl style style-menu admin board board-html board-uri board-title threads)
  (master-tpl admin (format #f "Catalog: /~a/ - ~a - ~a" board-html board-title website-title)
               style style-menu (or (assoc-ref (assoc-ref boards board) 'theme) default-style)
               "preview"
               (format #f "<h2>Catalog: /~a/ - ~a</h2>" board-html board-title)
    `((div (@ (class "catalog"))
       ,threads)
      (br (@ (style "clear:both"))))))

(define (thread-tpl style style-menu admin board board-html board-uri board-title password posts)
  (master-tpl admin (format #f "/~a/ - ~a - ~a" board-html board-title website-title)
               style style-menu (or (assoc-ref (assoc-ref boards board) 'theme) default-style)
               "threadbg"
               (format #f "<h2>/~a/ - ~a</h2>" board-html board-title)
     ;; This form covers all thread and post boxes and is used for submitting actions such as post deletion
   `((form (@ (enctype "multipart/form-data") (action "/mod-posts") (method "post"))
      ,@(mod-bar-tpl admin)
      "[" (a (@ (href "/board/" ,board-uri)) "Return") "]"
      ,posts
      "[" (a (@ (href "/board/" ,board-uri)) "Return") "]"
      (br)
      (span "Delete Post: " (input (@ (type "submit") (name "delete-button") (value "Delete")))))

     ,(post-form-tpl password))))

(define (catalog-thread-tpl mode board board-html board-uri threadnum postcount subject name date image iname thumb size comment old sticky replies)
  `(div (@ (border 1) (class (string-append (or (assoc-ref (assoc-ref boards board) 'theme) default-style) " threadwrapper")))
    (div (@ (class "thread"))
     ,(if image
        `(a (@ (href "/thread/" ,board-uri "/" ,threadnum))
          (img (@ (class "OPimg")
                  (src "/pub/img/" ,board-uri "/" ,threadnum "/" ,thumb))))
        '())
     (br)
     ,(if sticky
        `(img (@ (src "/pub/img/sticky.png") (title "Sticky")))
        '())
     (span (@ (class "shade")) ,(number->string (- postcount 1)) " Replies")
     (br)
     (b
      (a (@ (class "title") (href "/thread/" ,board-uri "/" ,threadnum))
       "【" ,(number->string threadnum) "】"
       ,subject)
      " [" (a (@ (class "title") (href "/thread/" ,board-uri "/" ,threadnum "?last=50"))
            "last50") " "
           (a (@ (href "/board/" ,board-uri)) ,(string-append "/" board-html "/"))
      "]")
     (br)
     (p ,comment))))

(define (post-list-tpl style style-menu admin board board-html board-uri threadnum postnums posts)
  (master-tpl admin (format #f "Links /~a/~a - ~a" board-html threadnum website-title)
               style style-menu (or (assoc-ref (assoc-ref boards board) 'theme) default-style)
               "links"
               (format #f "<h2>Links from /~a/~a</h2>" board-html threadnum)
    `((h2 "Posts: " ,(format #f "~a" postnums) (br)
          "from thread "
          (a (@ (href "/thread/" ,board-uri "/" ,threadnum)) ,(format #f "/~a/~a" board-html threadnum)))
      ,posts
      "[" (a (@ (href "/" ,board-uri "/" ,threadnum)) "Return to thread") "]")))

(define (post-OP-tpl mode board board-html board-uri threadnum postcount subject name date image iname thumb size comment old sticky replies)
  (let ((name+ext (or (and iname (separate-extension iname)) '("" . #f)))
        (file+ext (or (and image (separate-extension image)) '("" . #f))))
    `(div (@ (class ,(string-append (or (assoc-ref (assoc-ref boards board) 'theme) default-style) " threadwrapper")))
      (div (@ (class "thread"))
       (div (@ (class ,(if (eq? mode 'preview) "title-bar" "")))
        (u ,@(if sticky `(" " (img (@ (src "/pub/img/sticky.png") (title "Sticky")))) '())
           (input (@ (type "checkbox") (name "posts") (value ,board-uri "/" ,threadnum "/" 1)))
           (a (@ (href "/thread/" ,board-uri "/" ,threadnum))
            "【" ,(number->string threadnum) "】"
            (span (@ (class "title"))
             ,subject " "))
            "[" (a (@ (href "/thread/" ,board-uri "/" ,threadnum "?last=50"))
                 "last50") " "
                (a (@ (href "/board/" ,board-uri)) "/" ,board-html "/")
            "]")
        ,(if old
           (let ((remaining (- (+ old prune-time) (time-second (current-time time-utc)))))
             (if (> remaining 0)
               `(u (span (@ (class "warning")) " This thread has been marked old and will be deleted in " ,(human-readable-interval remaining)))
               `(u (span (@ (class "warning")) " This thread has been marked for deletion"))))
           '()))
       (br)
       (b (a (@ (href "/thread/" ,board-uri "/" ,threadnum "#1p") (onclick "postNumClick(this)")) "1") " "
          (span (@ (id "1p") (class "name")) ,name) " "
          (span (@ (class "date")) ,date) " "
          ,(imgops-tpl image board-uri threadnum))
       (br)
       ,@(if image
           `("File: " (a (@ (title ,iname)
                            (href "/pub/img/" ,board-uri "/" ,threadnum "/" ,(if (member (string-downcase (cdr name+ext)) '("sfw" "html5"))
                                                                           (if (cdr name+ext) (string-append (car file+ext) "." (cdr name+ext)) "")
                                                                           image))
                            (download ,iname))
                         ,(shorten iname max-filename-display-length))
             " (" ,size ")"
             (br))
           '())
       ,(if image
          `(a (@ (target "_top")
                 (href "/pub/img/" ,board-uri "/" ,threadnum "/" ,image))
            (img (@ (class "OPimg")
                    (src "/pub/img/" ,board-uri "/" ,threadnum "/" ,thumb)
                    (onclick "ret=thumbnailClick(this);return ret;")
                    (onload "swapIsLoaded(this)")
		    (data-swap-with "/pub/img/" ,board-uri "/" ,threadnum "/" ,image)
                    (data-mimetype ,(car (string-split size #\,))))))
          '())
       (blockquote ,(truncate-comment comment max-comment-preview-lines mode))
       ,(if (and (eq? mode 'preview) (> postcount (+ post-preview-count 1)))
          `(span (@ (class "shade")) ,(number->string (- postcount post-preview-count 1)) " posts omitted")
          '())

       ,replies
       (br (@ (style "clear:both")))))))

(define (post-OP-flash-tpl mode board board-html board-uri threadnum postcount subject name date image iname thumb size comment old sticky replies)
  (let ((name+ext (or (and iname (separate-extension iname)) '("" . #f)))
        (file+ext (or (and image (separate-extension image)) '("" . #f))))
    `(tbody (@ (class ,(or (assoc-ref (assoc-ref boards board) 'theme) default-style)
                      ,(if (equal? "html5" (string-locale-downcase (or (cdr name+ext) "")))
                         " highlight" "")))
      (tr (td ,@(if sticky
                  `(" " (img (@ (src "/pub/img/sticky.png") (title "Sticky"))))
                  '())
              (input (@ (type "checkbox") (name "posts") (value ,board-uri "/" ,threadnum "/" 1)))
              ,(number->string threadnum))
          (td (b (span (@ (id "1p") (class "name")) ,name)))
          (td (a (@ (href "/board/" ,board-uri)) ,(string-append "/" board-html) "/"))
          (td (@ (style "text-align:center"))
           "[" (a (@ (title ,iname) (href "/pub/img/" ,board-uri "/" ,threadnum "/" ,image))
                ,(shorten (car name+ext) max-filename-display-length)) "]"
           " [" (a (@ (title ,iname)
                      (href "/pub/img/" ,board-uri "/" ,threadnum "/" ,(car file+ext) ,(if (cdr name+ext) (string-append "." (cdr name+ext)) ""))
                      (download ,iname))
                   "F")
           "]")
          (td "(" ,size ")")
          (td (b (a (@ (href "/thread/" ,board-uri "/" ,threadnum)) ,subject)))
          (td (span (@ (class "date")) ,date))
          (td (span ,(number->string (- postcount 1))))
          (td (a (@ (href "/thread/" ,board-uri "/" ,threadnum)) "View"))))))

(define (subpost-tpl subpost board-uri threadnum postnum)
  `(div (@ (class "subpost"))
    (input (@ (type "checkbox")
              (name "posts")
              (value ,(format #f "~a/~a/~a/~a" board-uri threadnum postnum (assoc-ref subpost "id")))))
    (b (span (@ (class "name"))
        ,(assoc-ref subpost "name")) " "
       (span (@ (class "date"))
        ,(assoc-ref subpost "date")))
    (br)
    (blockquote
     ,(assoc-ref subpost "comment"))))

(define (note-editor-tpl style style-menu admin editable id type links-target name date subject body note perms-read perms-write)
  (let ((disabled (if editable 'enabled 'disabled)))
    (master-tpl admin (string-append "Note Editor - " website-title) style style-menu default-style "infopage" "<h2>Note Editor</h2>"
      `(,(if (equal? id "new")
           '()
           `(div (@ (id "note" ,id) (class ,type))
             (h3 (b (a (@ (class "link") (href "/" ,links-target "#note" ,id)) ,subject))
                 " by "
                 (b ,name)
                 "[" ,type ":" ,id "]")
             (span (@ (style "font-size:11px")) ,date)
             (blockquote ,(replace (replace body "\\r\\n" "<br>") "\\n" "<br>"))))
        (center
         (h3 "Note Editor:")
         ,@(if editable
            '()
            `((span (@ (class "warning")) "EDITING DISABLED: No write permissions") (br)))
         (div (@ (style "display:table"))
          (form (@ (enctype "multipart/form-data") (method "post"))
           (table (@ (class "postform") (border 1))
            (tr (td (@ (class "field")) "Subject")
                (td (input (@ (type "text") (name "subject") (size "44")
                              (value ,(if (null? note) "" subject))
                              (,disabled)))
                    ,(if editable
                       `(input (@ (type "submit") (name "submit") (value "Post")))
                       '())))
            (tr (td (@ (class "field")) "Body" (br) "(HTML format)")
                (td (textarea (@ (rows "5") (cols "50") (name "body") (,disabled)) ,(if (null? note) "" body))))
            (tr (td (@ (class "field")) "Type")
                (td (input (@ (type "radio") (name "type") (value "note") (,(if (equal? type "note") 'checked 'unchecked)) (,disabled)) "Note")
                    (input (@ (type "radio") (name "type") (value "notice") (,(if (equal? type "notice") 'checked 'unchecked)) (,disabled)) "Notice")
                    (input (@ (type "radio") (name "type") (value "public") (,(if (equal? type "public") 'checked 'unchecked)) (,disabled)) "Public")
                    (input (@ (type "radio") (name "type") (value "news") (,(if (equal? type "news") 'checked 'unchecked)) (,disabled)) "News")))
            (tr (td (@ (class "field")) "Extra" (br) "Permissions")
                (td (@ (style "border:2px goorve #888;vertical-align:top"))
                 (b "Read / Write") (br)
                 ,@(map (lambda (mod)
                          `((input (@ (type "checkbox") (name "perm-read") (value ,mod) (,(if (member mod perms-read) 'checked 'unchecked)) (,disabled)))
                            " / "
                            (input (@ (type "checkbox") (name "perms-write") (value ,mod) (,(if (member mod perms-write) 'checked 'unchecked)) (,disabled)))
                            " " ,mod (br)))
                        (delete name (map car mods))))))
           ,@(if (equal? name (assoc-ref (car admin) "name"))
               `((input (@ (type "checkbox") (name "delete") (value "delete")) " Delete this note") (br))
               '()))
          (p (b "Note: ") "A private note only you can see and edit, additional permissions apply." (br)
             (b "Notice: ") "A note that all other mods can see, additional write permissions apply." (br)
             (b "Public: ") "A note that all other mods can both see and edit, additional permissions are ignored." (br)
             (b "News: ") "A public news item any visitor will see, additional write permissions apply." (br))))
        (br)))))

(define (sandbox-tpl board-uri threadnum filename timestamp extension fsize entrypoint width height)
  `("<!--
THIS IS JUST A SANDBOX FILE.
TO VIEW THE ACTUAL FILE DATA VISIT THE src LINK BELOW.
-->

"
    ,(document-tpl "Flash/HTML5 Sandbox Page" "Flash/HTML5 sandbox page" #f
       `(body (@ (style "margin:0px;background:#333;width:100%;height:100%"))
         (table (@ (style "border-collapse:collapse;width:100%;height:100%"))
          (tr (@ (style "height:15px;font-size:12px;text-align:center;background:#fed"))
           (td (a (@ (href "/pub/img/" ,board-uri "/" ,threadnum "/" ,timestamp "." ,extension)) "DOWNLOAD FILE")
               ": " ,(format #f "~a (w:~a h:~a ~a)" filename width height fsize)))
          (tr (@ (style "width:100%;height:100%"))
           (td (@ (style "text-align:center;width:100%;height:100%"))
               (iframe (@ (style "margin-left:auto;margin-right:auto;border:none;width:" ,width ";height:" ,height)
                          (src "/pub/img/" ,board-uri "/" ,threadnum "/" ,entrypoint)
                          (sandbox "allow-scripts")
                          (allowfullscreen "allowfullscreen")) #f))))))))
