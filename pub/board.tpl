<%= (fill-header rc (or (assoc-ref (assoc-ref boards board) 'theme) "none")
                    (format #f "/~a/ - ~a - ~a" board board-title website-title)
                    (format #f "<h2>/~a/ - ~a</h2><div class=\"board-message\"><div class=\"post\">~a</div></div>" board board-title (or (assoc-ref (assoc-ref boards board) 'message) default-board-message))
                    style admin #:class "preview") %>

        <div class="news-box">
          <ul>
            <%= (build-note-listing rc mtable admin #:template "pub/note-short.tpl" #:type "news" #:limit 3) %>
          </ul>
        </div>

        <%= (if (assq-ref (assoc-ref boards board) 'posting-disabled)
              ""
              (tpl->response "pub/thread-creation-form.tpl" (the-environment))) %>

    <form enctype="multipart/form-data" action="/mod-posts" method="post">
      <%= (string-join (map (lambda (page)
                              (format #f "[<a href=\"/board/~a?page=~a\">~a</a>]" board (+ page 1) (+ page 1)))
                            (iota page-count))
                       " ") %>
      [<a href=<%= (format #f "'/catalog/~a'" board) %>>Catalog</a>]<br>
      <%= (format #f (if admin
                       "<span class=\"field\" style=\"padding:4px\">
                          <b>Mod Actions:</b> <input type=\"radio\" name=\"modaction\" value=\"del\">Del
                                              <input type=\"radio\" name=\"modaction\" value=\"delimg\">Del Img
                                              <input type=\"radio\" name=\"modaction\" value=\"ban\">Ban
                                              <input type=\"radio\" name=\"modaction\" value=\"sticky\">Toggle Sticky
                                              <input type=\"radio\" name=\"modaction\" value=\"old\">Toggle Old
                                              <input type=\"submit\" value=\"submit\" value=\"Submit\">
                        </span><br>"
                       "")) %>
      <%= (build-threads rc mtable board #f #:mode 'preview #:page (get-from-qstr rc "page")
                         #:preview-OP-template (or (assq-ref (assoc-ref boards board) 'preview-OP-template)
                                                   (assq-ref (assoc-ref boards board) 'OP-template)
                                                   default-OP-template)) %>
      <span style="float:right">Delete Post: <input type="submit" name="delete-button" value="Delete"></span>
    </form>

<%= (fill-footer rc styles) %>
