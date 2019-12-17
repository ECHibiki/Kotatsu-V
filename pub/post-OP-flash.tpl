    <tbody class="<%= (or (assoc-ref (assoc-ref boards board) 'theme) "none") %> ">
      <tr>
        <td>
          <%= (if sticky " <img src='/pub/img/sticky.png' title='Sticky'>" "") %><input type="checkbox" name="posts" value=<%= (format #f "'~a/~a/~a'" board threadnum postnum) %>>
          <%= threadnum %>
        </td>
        <td>
          <b><span id="1p" class="name"><%= name %></span></b>
        </td>
        <td>
          <a href=<%= (format #f "'/~a'" board) %>>/<%= board %>/</a>
        </td>
        <td>
          <%= (format #f (if image "<a title='~a' href=\"/pub/img/~a/~a/~a\">~a</a>" "") iname board threadnum image (shorten iname max-filename-display-length)) %>
        </td>
        <td>
          <%= (format #f (if image "(~aB)" "") size) %>
        </td>
        <td>
          <b><a href=<%= (format #f "'/thread/~a/~a'" board threadnum) %>> <%= subject %> </a></b>
        </td>
        <td>
          <span class="date"><%= date %></span>
        </td>
        <td>
          <%= (format #f "<span>~a Replies</span>" (- postcount 1)) %>
        </td>
      </tr>
    </tbody>
