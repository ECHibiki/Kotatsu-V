    <div class="<%= (or (assoc-ref (assoc-ref boards board) 'theme) "none") %> threadwrapper">
      <div class="thread">
        <%= (if (eq? mode 'preview) "<div class=\"title-bar\">" "<div>") %><u><%= (if sticky " <img src='/pub/img/sticky.png' title='Sticky'>" "") %><input type="checkbox" name="posts" value=<%= (format #f "'~a/~a/~a'" board threadnum postnum) %>>【<%= threadnum %>】<a class="title" href=<%= (format #f "'/thread/~a/~a'" board threadnum) %>> <%= subject %> </a> [<a href=<%= (format #f "'/board/~a'" board) %>>/<%= board %>/</a>]</u></div><br>
        <b><a href=<%= (format #f "\"/thread/~a/~a#1p\"" board threadnum) %>>1</a> <span id="1p" class="name"><%= name %></span> <span class="date"><%= date %></span> <% (format #t (if image " <span class=\"imgops\">[<a href=\"https://imgops.com/http://~a/pub/img/~a/~a/~a\" target=\"_blank\">ImgOps</a>]</span>" "") (get-conf '(host name)) board threadnum image) %></b><br>
        <%= (format #f (if image "File: <a title='~a' href=\"/pub/img/~a/~a/~a\">~a</a> (~aB)<br>" "") iname board threadnum image (shorten iname max-filename-display-length) size) %>
        <%= (format #f (if image "<a target=\"_top\" href=\"/pub/img/~a/~a/~a\"><img class=\"OPimg\" src=\"/pub/img/~a/~a/~a\"></a>" "") board threadnum image board threadnum thumb) %>
        <blockquote><%= (truncate-comment comment max-comment-preview-lines mode) %></blockquote>
        <%= (format #f (if (and (eq? mode 'preview) (> postcount (+ post-preview-count 1))) "<span class=\"shade\">~a posts omitted</span>" "") (- postcount post-preview-count 1)) %>
        <%= (if old 
              (let ((remaining (- (+ old prune-time) (time-second (current-time time-utc)))))
                (if (> remaining 0)
                  (format #f "<u><span class='warning'>This thread has been marked old and will be deleted in ~a.</span></u>" (human-readable-interval remaining))
                  (format #f "<u><span class='warning'>This thread has been marked for deletion.</span></u>")))
              "") %>

        <%= replies %>

        <br style="clear:both">
      </div>
    </div>
