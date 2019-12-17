;;;-*-guile-*-scheme-*-;;;

(define body-bg "#e2e2e2")
(define site-name-color "#34345c")

(define nav-bg "#eef2ff")

(define header-bg "#d1d5ee")
(define hr-width "1px")
(define hr-style "dotted")
(define hr-color "#b7c5d9")
;(define hr-color "#9988ee")

(define mid-bg "#eef2ff")

(define stack-bg "#eef2ff")
(define stack-border "#b7c5d9")

(define table-border "#eef2ff")

(define th-bg "#9988ee")
(define even-bg "#eef2ff")
(define odd-bg "#e0e5f6")

(define note-color "#3b3")
(define notice-color "#3bb")
(define public-color "#bb3")
(define news-color "#b33")

(define post-form-field-bg "#9988ee")
(define post-form-field-text "#000")
(define post-form-border "#eef2ff")
(define textbox-color "#000")
(define textbox-bg "#fff")

(define title-bg "#bbd0f0")
(define thread-bg "#eef2ff")
(define thread-border-width "0px")
(define thread-border-style "inset")
(define thread-border-color "#eef2ff")
(define post-bg "#d6daf0")
(define post-border "#b7c5d9")
(define post-highlight "#d6bad0")
(define indicator-color "#c00")
(define subthread-bg thread-bg)
(define subthread-border-width "1px")
(define subthread-border-style "solid")
(define subthread-border-color post-border)
(define subpost-fg "#888")

(define text-color "#000")
(define new-link-color "#cc1105")
(define old-link-color "#34345c")
(define name-color "#174")
(define capcode-color "#c00")
(define date-color "#000")
(define quote-color "#484")
(define shade "#888")
(define warning "#c00")
(define spoiler-color text-color)


(when (not %output-path)
  (set-output-file (%current-path) "../yotsubab.css"))

(include-css (%current-path) "GENERIC.scm" (prfx))
