<%= (fill-header rc (assq-ref (assoc-ref boards board) 'theme)
                    (format #f "Links /~a/~a - ~a" board thread website-title)
                    (format #f "<h2>Links from /~a/~a</h2>" board thread)
                    style admin #:class "links") %>

<h2>Posts: <%= postnums %><br>
from thread <%= (format #f "<a href=\"/thread/~a/~a\">/~a/~a</a>" board thread board thread) %></h2>

<%= (build-threads rc mtable board thread #:mode postnums) %>

[<a href="<%= (format #f "/~a/~a" board thread) %> ">Return to thread</a>]

<%= (fill-footer rc styles) %>
