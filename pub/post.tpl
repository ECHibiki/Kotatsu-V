    <table class="post-frame"><tr><td valign="top" weight="bold">»</td><td>
    <div border="1" id="<%= postnum %>p" class="post">
      <input type="checkbox" name="posts" value=<%= (format #f "'~a/~a/~a'" board threadnum postnum) %>><b><%= (format #f "<a href=\"/thread/~a/~a#~ap\">~a</a>" board threadnum postnum postnum) %> <span class="name"><%= name %></span> <span class="date"><%= date %></span><%= (format #f (if image " <span class=\"imgops\">[<a href=\"https://imgops.com/http://~a/pub/img/~a/~a/~a\" target=\"_blank\">ImgOps</a>]</span>" "") (get-conf '(host name)) board threadnum image) %></b><br>
      <%= (format #f (if image "File: <a title='~a' href=\"/pub/img/~a/~a/~a\">~a</a> (~aB)<br>" "") iname board threadnum image (shorten iname max-filename-display-length) size) %>
      <table><tr valign="top">
        <% (format #t (if image "<td><a target=\"_top\" href=\"/pub/img/~a/~a/~a\"><img src=\"/pub/img/~a/~a/~a\"></a></td>" "") board threadnum image board threadnum thumb) %>
        <td>
          <blockquote><%= (truncate-comment comment max-comment-preview-lines mode) %></blockquote>
          <%= (if subposts
                (format #f "<div class='subthread'>~a</div>"
                           (build-subposts board threadnum postnum subposts))
                "") %>
        </td>
      </tr></table>
    </div>
    </td></tr></table>

<%= (if replies replies "") %>
