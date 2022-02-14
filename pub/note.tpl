<div id=<%= (format #f "\"note~a\"" id) %> class=<%= (format #f "\"~a\"" type) %>>
  <h3><b><a class="link" href=<%= (format #f "\"/~a#note~a\"" links-target id) %> ><%= subject %></a></b> by <b><%= name %></b> [<%= (format #f "~a:~a" type id) %>]</h3>
  <span style="font-size:11px"><%= date %><%= (if admin (format #f " <a href=\"/note-editor/~a\">(edit)</a>" id) "") %></span>
  <blockquote><%= (replace (replace body "\\r\\n" "<br>") "\\n" "<br>") %></blockquote>
  <%= (if (equal? edited "") "" (format #f "<span class=\"shade\">Last edited by: ~a</span>" edited)) %>
</div>
