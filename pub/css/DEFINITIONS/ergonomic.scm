;;;-*-guile-*-scheme-*-;;;

(define body-bg "#aba")
(define site-name-color "#050")

(define nav-bg "#bcb")

(define header-bg "#aba")
(define hr-width "1px")
(define hr-style "dotted")
(define hr-color "#898")

(define mid-bg "#bcb")

(define stack-bg "#bcb")
(define stack-border "#898")

(define table-border "#898")

(define th-bg "#898")
(define even-bg "#bcb")
(define odd-bg "#aba")

(define note-color "#3b3")
(define notice-color "#3bb")
(define public-color "#bb3")
(define news-color "#b33")


(define post-form-field-bg "#9a9")
(define post-form-field-text "#000")
(define post-form-border "#898")
(define textbox-color "#000")
(define textbox-bg "#ddd")

(define title-bg "#898")
(define thread-bg "#bcb")
(define thread-border-width "0px")
(define thread-border-style "inset")
(define thread-border-color "#bcb")
(define post-bg "#aba")
(define post-border "#898")
(define post-highlight "#9a9")
(define indicator-color "#050")
(define subthread-bg thread-bg)
(define subthread-border-width "1px")
(define subthread-border-style "solid")
(define subthread-border-color post-border)
(define subpost-fg "#777")

(define text-color "#000")
(define new-link-color "#080")
(define old-link-color "#050")
(define name-color "#174")
(define capcode-color "#c00")
(define date-color "#030")
(define quote-color "#262")
(define shade "#888")
(define warning "#c00")
(define spoiler-color text-color)


(when (not %output-path)
  (set-output-file (%current-path) "../ergonomic.css"))

(include-css (%current-path) "GENERIC.scm" (prfx))
