    <div border="1" class="<%= (or (assoc-ref (assoc-ref boards board) 'theme) "none") %> threadwrapper">
      <div class="thread">
        <% (format #t (if image "<a href=/thread/~a/~a ><img class=\"OPimg\" src=\"/pub/img/~a/~a/~a\"></a>" "") board threadnum board threadnum thumb) %>
        <br>
        <%= (if sticky "<img src='/pub/img/sticky.png' title='Sticky'>" "") %>
        <% (format #t "<span class=\"shade\">~a Replies</span>" (- postcount 1)) %><br>
        <b>【<%= threadnum %>】<a class="title" href=<%= (format #f "/thread/~a/~a" board threadnum) %> > <%= subject %> </a> [<a href=<%= (format #f "'/board/~a'" board) %>>/<%= board %>/</a>]</b><br>
        <p><%= comment %></p>
      </div>
    </div>
