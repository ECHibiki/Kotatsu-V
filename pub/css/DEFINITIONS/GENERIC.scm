(CSS
 ;(@font-face
 ; (font-family "'TextarWebfont'")
 ; (src "url('/pub/fonts/textar.woff') format('woff')"))
 (@font-face
  (font-family "'submona-web-font'")
  (src "url('/pub/fonts/submona-web-font/submona.woff') format('woff')"))

 ((body header section footer)
  (font-size "13px")
  (font-family "'Liberation Sans', 'Arial'")
  (color ,text-color)
  (padding "0px")
  (margin "0px")
  (background ,body-bg))

 (footer
   (padding "5px"))

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
  ;(border "4px solid" ,table-border)
  ;(padding "5px")
  (background ,th-bg))

 (ul
  (margin "0px"))

 (hr
  (margin "0px")
  (border ,hr-width ,hr-style ,hr-color))

 ;(.thread-separator
 ; (border-width "2px")
 ; (margin-bottom "15px")
 ; (display "none"))

 ((input textarea)
  (font-size "13px")
  (font-family "'Liberation Sans', 'Arial'")
  (color ,textbox-color)
  (background ,textbox-bg))

 (,(string->symbol "input[type='checkbox']")
  (background "#c00"))

 (.site-name
  (color ,site-name-color)
  (font-size "32px")
  (font-weight "bold"))

 (.nav
  (background ,nav-bg)
  (padding "2px 10px 2px 2px"))
 (.sidebar
  (display "none")
  (border-right "1px" "solid" "#000")
  (position "fixed")
  (z-index "1")
  (top "0")
  (left "0")
  (height "100%")
  (width "110px")
  (padding "0px"))

 (.mid
  ;(padding "0px 10px 0px 5px")
  (background ,mid-bg)
  (border-left "5px solid transparent")
  ;(background-image "url('/pub/img/solaris.png')")
  )
 (.mid.threadbg
  (background ,thread-bg))

 ((.mid.preview .mid.infopage)
  (border-left "10px double" ,hr-color))

 (.mid.links
  (padding-left "5px")
  (border-left "10px dashed" ,hr-color))

 (.news-box
  ;(border "inset 1px" ,hr-color)
  (display "table")
  (margin "5px auto")
  ;(width "500px")
  (overflow "contain"))
 (((.note) (.notice) (.public) (.news))
  (background ,stack-bg)
  ;(padding "0px 0px 10px 5px")
  (border-bottom "2px groove" ,hr-color))
 (((.note h3) (.notice h3) (.public h3) (.news h3))
  (margin "0px")
  (font-weight "normal"))
 (((.note .link))
  (margin "0px")
  (color ,note-color))
 (((.notice .link))
  (margin "0px")
  (color ,notice-color))
 (((.public .link))
  (margin "0px")
  (color ,public-color))
 (((.news .link))
  (margin "0px")
  (color ,news-color))

 (.warning
  (color ,indicator-color)
  (font-weight "bold"))

 (((.preview .thread))
  (border-top "2px groove" ,hr-color))

 (.threadwrapper
  ;(padding "2px 2px 2px 0px"))
  (margin "4px 10px 8px 2px"))
 (.thread
  (min-width "500px")
  (max-width "1800px")
  (padding "0px")
  ;(margin "2px 10px 8px 2px")
  (width "auto")
  (color ,text-color)
  (background ,thread-bg)
  (border ,thread-border-width ,thread-border-style ,thread-border-color))

 (((.flash ,(string->symbol "tbody:nth-child(even)")))
  (background ,even-bg))
 (((.flash ,(string->symbol "tbody:nth-child(odd)")))
  (background ,odd-bg))
 (((.flash td))
  (padding "1px" "4px"))

 (.title-bar
  (margin "0px")
  (font-weight "bold")
  (background ,title-bg))
 ;(a.title
 (.title
  (font-size "24px")
  (text-decoration "none"))

 (.post-frame
  (border-collapse "collapse"))

 (blockquote
  (white-space "pre-wrap /* css-3 */")
  (white-space "-moz-pre-wrap /* Mozilla, since 1999 */")
  (white-space "-pre-wrap /* Opera 4-6 */")
  (white-space "-o-pre-wrap /* Opera 7 */")
  (word-wrap "break-word /* Internet Explorer 5.5+ */")
  (overflow-wrap "break-word")

  ;(overflow-wrap "break-word")
  ;(word-wrap "break-word")
  ;(-ms-word-break "break-all")
  ;(word-break "break-all")
  ;(-ms-hyphens "auto")
  ;(-moz-hyphens "auto")
  ;(-webkit-hyphens "auto")
  ;(hyphens "auto")

  (margin-left "10px"))

 (.post
  (padding "2px 10px 2px 2px")
  (background ,post-bg)
  (border "3px double" ,post-border)
  ;(border-left "4px double" ,indicator-color)
  (margin "1px"))
 (.postform
  (background ,stack-bg)
  (border ,post-form-border))
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
  (color ,shade)
  (font-size "11px"))
 (.warning
  (color ,warning)
  (fong-weight "bold"))
 (.aa
  (font-family "'MS PGothic', 'MS Pゴシック', 'Konatu', 'Mona', 'Monapo', 'Textar', 'submona-web-font'")
  (font-size "16px"))
 (.spoiler
  (color ,spoiler-color)
  (background ,spoiler-color))
 (.code
  (font-family "monospace")
  (background ,thread-bg)
  (border "1px" "solid" ,post-border))

 (.OPimg
  (margin "0px 10px 10px 10px")
  (float "left"))

 (.subthread
  (background ,subthread-bg)
  (border ,subthread-border-width ,subthread-border-style ,subthread-border-color)
  (width "220px")
  (height "20px")
  (overflow-x "hidden")
  (overflow-y "hidden")
  (resize "both"))

 (((.subpost blockquote) (.subpost .name) (.subpost .date))
  (color ,subpost-fg)
  (font-size "11px"))

 (.top-nav
  (position "absolute")
  (top "4px")
  (left "4px"))

 (.header
  (background ,header-bg)
  (margin "0px")
  (padding "5px"))
 (.board-message
  ;(display "table")
  (border "1px" "inset" ,hr-color)
  (background ,hr-color)
  (margin-bottom "5px"))
 ;(((.board-message .post))
 ; (min-width "500px")
 ; (padding "5px 20px"))

 ;(.catalog
 ; (border-collapse"collapse")
 ; (border "4px solid" ,table-border))
 (.catalog
  ;(display "flex")
  ;(flex-wrap "wrap")
  (justify-content "center")
  (text-align "center"))
 (((.catalog .threadwrapper))
  (float "left")
  (min-width "200px!important")
  (max-width "200px!important")
  (width "200px!important")
  (min-height "250px!important")
  (max-height "250px!important")
  (height "250px!important")
  (margin "2px"))
 (((.catalog .thread))
  (overflow "hidden")
  (min-width "200px!important")
  (max-width "200px!important")
  (width "200px!important")
  (min-height "250px!important")
  (max-height "250px!important")
  (height "250px!important"))
 (((.catalog .thread .OPimg))
  (float "none")
  (max-width "100px")
  (max-height "100px"))
 (((.catalog .thread .title))
  (font-size "14px"))

 (.stack
  (max-width "1000px")
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

 ((*:target .highlight)
  (background ,post-highlight "!important"))
)
