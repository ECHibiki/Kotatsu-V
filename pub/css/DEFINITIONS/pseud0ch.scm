;;;-*-guile-*-scheme-*-;;;

(define body-bg "#eee")
(define site-name-color "#34345c")

(define nav-bg "#edc")

(define header-bg "#cec")
(define hr-width "1px")
(define hr-style "dotted")
(define hr-color "#ecc")

(define mid-bg "#eee;\n    background-image:url('data:image/gif;base64,R0lGODdhPAA8AJkAANCznMWtmbOektzApiwAAAAAPAA8AAAC/5SPqcvtCJ6c1IUAsgZ48wuG4qV1njYMZxmkbjYGQpipJeDmuo7zdYoTRSwiRGuFg3lio4HpswF9SJzhobpMSXsZAVQoS6KcpoH3MsPIZsAtVWAbDoVYziuZ3nhhnavWVASVFkYVNdbixKbH0mXQQ8I0FdERVnOi4tXWcqFVZXKAqAbJNEoTdUT28vSlZvUoFRmpxIdh87LXw1Z4cAc5wzFIulIbt+FS6MELVBJsMPK7utqTAmfrbAPoqAlCVknaOkWsclej7VzlRyYJAhc+slTllDNFbZBIq+10I3WGJks77cc4bCSgAcsUp1SESd9+hRv4Q9wiT/aWwWIHMEQaXP/GyNn52EEfjIrYoGGkpVHaGEuF2kTZiFASvm8qp+2YR4xlophqHEKpcwlFOWjO0IB6cGRQMBlMm86oAFXBnzVRHcwbs2xFDkQ8lt28aSzMPHWFCHHNKkaDo44etk5LM7DerFJ/6hSTM6xSWrUkgGDieOIIl46IgNJxl7JwrnY34tzViuQiw2c1+k662wmoVhqC3yD29YOPLnhIbqBE9hOl0tBmLht6VDqy5NPPOKmQYabFRko+I7OAtEQYoTZeTAaLPQslI3d8RHPWzXiQpc3DlnsD468Wy+g1p58S9WTL7yItG5E5DgPtxOa/v7u5sgSOP62ARWr+GFimUcEsurX/wraQcslVFxgVIdhSgg243GZfW7EBAo+BCwqFW3L+hSYGf0pYhAsT9ghESFo7CHRXNIq5ch86cCxw0FI0ZXdOEQlQtQCNMjqjwIvi6YgaSV/9qENIQA75VXCzxdBIgJ005NBF2rBz23MxKKVMN/14otYezXyYR4bAuccOfFFK80lZfWDAESAGAhQOAlvpFU1yKUmnJikuUjXNc5J0GSZT0iUE3gf9+IejRwO+duYay+3DzkWBIPSYkZHYc1h7NLGB0IEjPahHP0Zl9A4TrW2TJVmBYNTneJfSkGmKoi1ayjmqIjlZcaGwFxxtbjB1ymd2ihVprgaWEqqHUzZajSYFKYq3J7FgZneqn1zAgtxIomQEqilTFjcYcibimlodUjrKrXqyOWqZFAUAADs=')")

(define stack-bg "#eee")
(define stack-border "#b7c5d9")

(define table-border "#eee")

(define th-bg "#ecc")
(define even-bg "#eee")
(define odd-bg "#dcc")

(define note-color "#3b3")
(define notice-color "#3bb")
(define public-color "#bb3")
(define news-color "#b33")

(define post-form-field-bg "#ecc")
(define post-form-field-text "#000")
(define post-form-border "#eee")
(define textbox-color "#000")
(define textbox-bg "#fff")

(define title-bg "#ada")
(define thread-bg "#eee")
(define thread-border-width "2px")
(define thread-border-style "ridge")
(define thread-border-color "#eee")
(define post-bg "#ddd")
(define post-border "#bbb")
(define post-highlight "#bbb")
(define indicator-color "#c00")
(define subthread-bg thread-bg)
(define subthread-border-width "1px")
(define subthread-border-style "solid")
(define subthread-border-color post-border)
(define subpost-fg "#888")

(define text-color "#000")
(define new-link-color "#b00")
(define old-link-color "#d00")
(define name-color "#174")
(define capcode-color "#c00")
(define date-color "#000")
(define quote-color "#484")
(define shade "#888")
(define warning "#c00")
(define spoiler-color text-color)


(when (not %output-path)
  (set-output-file (%current-path) "../pseud0ch.css"))

(include-css (%current-path) "GENERIC.scm" (prfx))
;(string-append
;  (include-css (%current-path) "GENERIC.scm" (prfx))
;  "\n"
;  (CSS
;   (body
;    (font-size "16px")
;    (font-family "'MS PGothic', 'MS Pゴシック', 'Konatu', 'Mona', 'Monapo', 'Textar', 'submona-web-font'"))
;   (.thread
;    (font-size "16px")
;    (font-family "'MS PGothic', 'MS Pゴシック', 'Konatu', 'Mona', 'Monapo', 'Textar', 'submona-web-font'"))))
