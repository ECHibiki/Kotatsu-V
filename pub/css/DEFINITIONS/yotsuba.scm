;;;-*-guile-*-scheme-*-;;;

(define body-bg "#e2e2e2")
(define site-name-color "#900")

(define nav-bg "#ffe")

(define header-bg "#fed6af")
(define hr-width "1px")
(define hr-style "dotted")
;(define hr-color "#d9bfb7")
(define hr-color "#ea8")

(define mid-bg "#ffe")

(define stack-bg "#ffe")
(define stack-border "#d9bfb7")

(define table-border "#ffe")

(define th-bg "#ea8")
(define even-bg "#ffffee")
(define odd-bg "#ede2d4")

(define note-color "#3b3")
(define notice-color "#3bb")
(define public-color "#bb3")
(define news-color "#b33")

(define post-form-field-bg "#ea8")
(define post-form-field-text "#800")
(define post-form-border "#ffe")
(define textbox-color "#000")
(define textbox-bg "#fff")

(define title-bg "#fc9")
(define thread-bg "#ffe")
(define thread-border-width "0px")
(define thread-border-style "inset")
(define thread-border-color "#ffe")
(define post-bg "#f0e0d6")
(define post-border "#d9bfb7")
(define post-highlight "#f0c0b0")
(define indicator-color "#00c")
(define subthread-bg thread-bg)
(define subthread-border-width "1px")
(define subthread-border-style "solid")
(define subthread-border-color post-border)
(define subpost-fg "#888")

(define text-color "#800")
(define new-link-color "#00e")
(define old-link-color "#008")
(define name-color "#174")
(define capcode-color "#c00")
(define date-color "#800")
(define quote-color "#484")
(define shade "#888")
(define warning "#c00")
(define spoiler-color text-color)


(when (not %output-path)
  (set-output-file (%current-path) "../yotsuba.css"))

(include-css (%current-path) "GENERIC.scm" (prfx))
