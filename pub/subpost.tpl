    <div class="subpost">
      <input type="checkbox" name="posts" value=<%= (format #f "'~a/~a/~a/~a'" board threadnum postnum (assoc-ref subpost "id")) %>><b><span class="name"><%= (assoc-ref subpost "name") %></span> <span class="date"><%= (assoc-ref subpost "date") %></span></b><br>
      <blockquote><%= (assoc-ref subpost "comment") %></blockquote>
    </div>
