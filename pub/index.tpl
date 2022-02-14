<%= (fill-header rc "none" website-title greeting style admin #:class "infopage") %>

    <center>
      <table><tr><td>

        <h3>
        <%= (call-with-values
              (lambda () (partition
                           (lambda (board) (member (assq-ref (cdr board) 'special) '(all listed unlisted)))
                           boards))
              (lambda (specials normals)
                (string-append
                  (string-join
                    (map (lambda (board)
                           (format #f "<a href=\"/board/~a\">~a</a>" (car board) (assq-ref (cdr board) 'title)))
                         specials)
                    "\n")
                  "<br><hr>Boards:<br>"
                  (string-join
                    (map (lambda (board)
                           (format #f "<a href=\"/board/~a\">~a</a>" (car board) (assq-ref (cdr board) 'title)))
                         normals)
                    "\n")))) %>
        </h3>

      </td></tr></table>
    </center>

    <br>

    [<a href="/news">View all news postings</a>]<br>
    <hr style="border-style:groove;border-width:0px 0px 2px 0px">

<%= (build-note-listing rc mtable admin #:type "news" #:limit 3) %>

<%= (fill-footer rc styles) %>
