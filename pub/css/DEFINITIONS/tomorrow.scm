;;;-*-guile-*-scheme-*-;;;

(define body-bg "#1d1f21")
(define site-name-color "#c5c8c6")

(define nav-bg "#34345c")

(define header-bg "#282a2e")
(define hr-width "1px")
(define hr-style "dotted")
(define hr-color "#34345c")

(define mid-bg "#1d1f21")

(define stack-bg "#1d1f21")
(define stack-border "#282a2e")

(define table-border "#282a2e")

(define th-bg "#34345c")
(define even-bg "#303236")
(define odd-bg "#282a2e")

(define note-color "#3b3")
(define notice-color "#3bb")
(define public-color "#bb3")
(define news-color "#b33")

(define post-form-field-bg "#34345c")
(define post-form-field-text "#c5c8c6")
(define post-form-border "#282a2e")
(define textbox-color "#c5c8c6")
(define textbox-bg "#282a2e")

(define title-bg "#34345c")
(define thread-bg "#1d1f21")
(define thread-border-width "0px")
(define thread-border-style "inset")
(define thread-border-color "#fffaee")
(define post-bg "#282a2e")
(define post-border "#34345c")
(define post-highlight "#484a4e")
(define indicator-color "#c00")
(define subthread-bg thread-bg)
(define subthread-border-width "1px")
(define subthread-border-style "solid")
(define subthread-border-color post-border)
(define subpost-fg "#888")

(define text-color "#c5c8c6")
(define new-link-color "#81a2be")
(define old-link-color "#5f89ac")
(define name-color "#74a2be")
(define capcode-color "#c00")
(define date-color "#c5c8c6")
(define quote-color "#484")
(define shade "#888")
(define warning "#c00")
(define spoiler-color text-color)


(when (not %output-path)
  (set-output-file (%current-path) "../tomorrow.css"))

(include-css (%current-path) "GENERIC.scm" (prfx))
