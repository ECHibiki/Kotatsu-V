<%= (fill-header rc (or (assoc-ref (assoc-ref boards board) 'theme) "none")
                    (format #f "/~a/ - ~a - ~a" board board-title website-title)
                    (format #f "<h2>/~a/ - ~a</h2><div class=\"board-message\"><div class=\"post\">~a</div></div>" board board-title (or (assoc-ref (assoc-ref boards board) 'message) default-board-message))
                    style admin #:class "preview") %>

        <div class="news-box">
          <ul>
            <%= (build-note-listing rc mtable admin #:template "pub/note-short.tpl" #:type "news" #:limit 3) %>
          </ul>
        </div>

    <form enctype="multipart/form-data" action="/mod-posts" method="post">
      <%= (format #f (if admin
                       "<span class=\"field\" style=\"padding:4px\">
                          <b>Mod Actions:</b> <input type=\"radio\" name=\"modaction\" value=\"del\">Delete
                                              <input type=\"radio\" name=\"modaction\" value=\"ban\">Ban
                                              <input type=\"radio\" name=\"modaction\" value=\"sticky\">Sticky
                                              <input type=\"submit\" value=\"submit\" value=\"Submit\">
                        </span><br>"
                       "")) %>

      <center>
        <table class="flash">
          <thead>
            <tr>
              <th>No.</th>
              <th>Name</th>
              <th>Board</th>
              <th>File</th>
              <th>Size</th>
              <th>Subject</th>
              <th>Date</th>
              <th>Replies</th>
            </tr>
          </thead>
          <%= (build-threads rc mtable board #f #:mode 'preview #:page (get-from-qstr rc "page")
                             #:preview-OP-template (or (assq-ref (assoc-ref boards board) 'preview-OP-template)
                                                       (assq-ref (assoc-ref boards board) 'OP-template)
                                                       default-OP-template)
                             #:post-preview-count-override 0) %>
        </table>
      <center>

      <span style="float:right">Delete Post: <input type="submit" name="delete-button" value="Delete"></span>
    </form>

    <br><hr><br>
    <%= (if (assq-ref (assoc-ref boards board) 'posting-disabled)
          ""
          (tpl->response "pub/thread-creation-form.tpl" (the-environment))) %>

<%= (fill-footer rc styles) %>
