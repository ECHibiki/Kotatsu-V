<%= (fill-header rc "none" (string-append "Notes - " website-title) "<h2>Personal Notes</h2>" style admin #:class "infopage") %>

<%= (build-note-listing rc mtable admin #:personal #t) %>

<%= (fill-footer rc styles) %>
