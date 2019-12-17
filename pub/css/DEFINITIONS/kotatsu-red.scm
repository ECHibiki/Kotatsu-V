;;;-*-guile-*-scheme-*-;;;

(define body-bg "#e2e2e2")
(define site-name-color "#eee")

(define nav-bg "#ccd3dd")
(define nav-bg "#fffaee")

(define header-bg "#caa")
;(define hr-border "#fffaee")
(define hr-width "1px")
(define hr-style "dotted")
;(define hr-color "#ccd3dd")
;(define hr-color "#bbc2cc")
;(define hr-color "#a98")
(define hr-color "#ff4646")

(define mid-bg "#fffaee")

(define stack-bg "#eee4dd")
(define stack-border "#ccc2bb")

;(define table-border "#dcb")
(define table-border "#fffaee")

(define th-bg "#dcb")
(define even-bg "#fffaee")
(define odd-bg "#eee4dd")

(define note-color "#3b3")
(define notice-color "#3bb")
(define public-color "#bb3")
(define news-color "#b33")

(define post-form-field-bg "#dcb")
(define post-form-field-text "#005")
(define post-form-border "#dcb")
(define textbox-color "#000")
(define textbox-bg "#fff")

;(define title-bg "#ff4646")
(define title-bg "#caa")
(define thread-bg "#fffaee")
(define thread-border-width "0px")
(define thread-border-style "inset")
(define thread-border-color "#fffaee")
;(define post-bg "#eee4dd")
(define post-bg "#edc")
;(define post-border "#ddd3cc")
(define post-border "#caa")
(define post-highlight "#ccd3dd")
(define indicator-color "#c00")
(define subthread-bg thread-bg)
(define subthread-border-width "1px")
(define subthread-border-style "solid")
(define subthread-border-color post-border)
(define subpost-fg "#888")

(define text-color "#335")
(define new-link-color "#55c")
(define old-link-color "#55a")
(define name-color "#174")
(define capcode-color "#c00")
(define date-color "#447")
(define quote-color "#484")
(define shade "#888")
(define warning "#c00")
(define spoiler-color text-color)


(when (not %output-path)
  (set-output-file (%current-path) "../kotatsu-red.css"))

(include-css (%current-path) "GENERIC.scm" (prfx))
