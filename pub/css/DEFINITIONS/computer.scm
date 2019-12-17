;;;-*-guile-*-scheme-*-;;;

(define body-bg "#e2e2e2")
(define site-name-color "#005")

(define nav-bg "#edc")
;(define nav-bg "#ccc")

;(define header-bg "#ccd3dd")
;(define header-bg "#d3ccdd")
(define header-bg "#8ab")
(define hr-width "1px")
(define hr-style "dotted")
;(define hr-color "#bbc2cc")
(define hr-color "#79a")

(define mid-bg "#e2e2e2")

(define stack-bg "#eee4dd")
(define stack-border "#ccc2bb")

;(define table-border "#dcb")
(define table-border "#e2e2e2")

(define th-bg "#79a")
(define even-bg "#fffaee")
(define odd-bg "#eee4dd")

(define note-color "#3b3")
(define notice-color "#3bb")
(define public-color "#bb3")
(define news-color "#b33")

(define post-form-field-bg "#aec0ca")
(define post-form-field-text "#005")
(define post-form-border "#dcb")
(define textbox-color "#000")
(define textbox-bg "#fff")

;(define title-bg hr-color)
(define title-bg "#8ab")
;(define title-bg "#7ab")
(define thread-bg "#e2e2e2")
(define thread-border-width "0px")
(define thread-border-style "inset")
(define thread-border-color "#e2e2e2")
(define post-bg "#eee4dd")
(define post-border "#ccc2bb")
(define post-highlight "#aec0ca")
(define indicator-color "#c00")
(define subthread-bg thread-bg)
(define subthread-border-width "1px")
(define subthread-border-style "solid")
(define subthread-border-color post-border)
(define subpost-fg "#888")

(define text-color "#005")
(define new-link-color "#55c")
(define old-link-color "#55a")
(define name-color "#174")
(define capcode-color "#c00")
(define date-color "#558")
(define quote-color "#484")
(define shade "#888")
(define warning "#c00")
(define spoiler-color text-color)


(when (not %output-path)
  (set-output-file (%current-path) "../computer.css"))

(include-css (%current-path) "GENERIC.scm" (prfx))
