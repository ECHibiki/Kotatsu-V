<%= (fill-header rc "none" (string-append "News - " website-title) "<h2>News</h2>" style admin #:class "infopage") %>

<%= (build-note-listing rc mtable admin #:type "news") %>

<%= (fill-footer rc styles) %>
