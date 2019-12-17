(CSS
 (body
  (font-size "13px")
  (font-family "\"Liberation Sans\", \"Arial\"")
  (color ,text-color)
  (padding "0px")
  (margin "0px")
  (background ,body-bg))

 (a:link
  (color ,new-link-color))
 (a:visited
  (color ,old-link-color))

 ;; This exists because italic tags are needed for terminal
 ;; browsers to display quoted text differently, but we
 ;; don't actually want it italicized in a browser */
 (i
  (color ,quote-color)
  (font-style "normal"))

 (td
  (border "none"))
 (th
  (border "4px solid" ,table-border)
  (background ,th-bg)
  (padding "5px"))

 (ul
  (margin "0px"))

 (hr
  (margin "0px")
  (border "2px solid" ,hr-border))

 ;(.thread-separator
 ; (border-width "2px")
 ; (margin-bottom "15px")
 ; (display "none"))

 ((input textarea)
  (font-size "13px")
  (font-family "\"Liberation Sans\", \"Arial\"")
  (color ,textbox-color)
  (background ,textbox-bg))

 (.site-name
  (color ,site-name-color)
  (font-size "32px")
  (font-weight "bold"))

 (.nav
  (background ,nav-bg)
  (padding "2px 10px 2px 2px"))

 (.title
  (font-weight "bold")
  (font-size "24px"))

 (((.post blockquote))
  (white-space "pre-wrap /* css-3 */")
  (white-space "-moz-pre-wrap /* Mozilla, since 1999 */")
  (white-space "-pre-wrap /* Opera 4-6 */")
  (white-space "-o-pre-wrap /* Opera 7 */")
  (word-wrap "break-word /* Internet Explorer 5.5+ */")

  ;(overflow-wrap "break-word")
  ;(word-wrap "break-word")
  ;(-ms-word-break "break-all")
  ;(word-break "break-all")
  ;(-ms-hyphens "auto")
  ;(-moz-hyphens "auto")
  ;(-webkit-hyphens "auto")
  ;(hyphens "auto")

  (margin-left "10px"))

 (.post-frame
  (border-collapse "collapse"))

 (.style-picker
  (position "absolute")
  (top "4px")
  (left "4px"))

 (.header
  (background ,header-bg)
  (margin "0px")
  (padding "5px"))

 (.mid
  ;(padding "0px 10px 0px 5px")
  (background ,mid-bg)
  (border-left "5px solid transparent")
  ;(background-image "url(\"/pub/img/solaris.png\")")
  )

 ((.mid.preview .mid.infopage)
  (border-left "10px double" ,hr-border))

 (.mid.links
  (padding-left "5px")
  (border-left "10px dashed" ,hr-border))

 (.news
  (padding "0px 0px 10px 5px")
  (border-top "2px groove" ,hr-border))

 (.thread
  (padding "5px 0px 0px 0px"))

 (((.preview .thread))
  (border-top "2px groove" ,hr-border))

 ;(.catalog
 ; (border-collapse"collapse")
 ; (border "4px solid" ,table-border))
 (.catalog
  (display "flex")
  (flex-wrap "wrap")
  (justify-content "center")
  (text-align "center"))
 (((.catalog .thread))
  ;(border "4px solid" ,stack-border)
  (margin "10px")
  (width "180px"))
 (((.catalog .thread .OPimg))
  (float "none")
  (max-width "180px")
  (max-height "180px"))
 (((.catalog .thread .title))
  (font-size "14px"))

 (.footer
  (padding "5px"))

 (.stack
  (max-width "800px")
  (padding "2px 10px 2px 2px")
  (background ,stack-bg)
  (border "4px solid" ,stack-border))

 (.odd
  (background ,odd-bg))
 (.even
  (background ,even-bg)
  (border "1px solid" ,th-bg))

 ;; FIXME
 ;; .odd td, .even td {
 (((.odd td) (.even td))
  (font-weight "bold")
  (padding "2px 5px")
  (text-align "center"))

 (.post
  (padding "2px 10px 2px 2px")
  (background ,post-bg)
  (border "3px double" ,post-border)
  ;(border-left "4px double" ,indicator-color)
  (margin "1px"))
 (.postform
  (background ,stack-bg)
  (background ,post-form-border))
 (.field
  (color ,post-form-field-text)
  (text-align "right")
  (font-weight "bold")
  (background ,post-form-field-bg))
 (.name
  (color ,name-color))
 (.capcode
  (color ,capcode-color))
 (.date
  (color ,date-color))
 (.shade
  (color ,shade))
 (.aa
  (font-family "\"MS PGothic\", \"Konatu\", \"Mona\", \"Textar\", \"Monapo\", \"IPAMonaPGothic\"")
  (font-size "16px"))

 (.OPimg
  (margin "0px 10px 10px 10px")
  (float "left"))

 (*:target
  (background ,post-highlight))
)
