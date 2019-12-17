<%= (fill-header rc (or (assoc-ref (assoc-ref boards board) 'theme) "none")
                    (format #f "/~a/ - ~a - ~a" board board-title website-title)
                    (format #f "<h2>/~a/ - ~a</h2>" board board-title)
                    style admin #:class "threadbg") %>

<form enctype="multipart/form-data" action="/mod-posts" method="post">

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

  [<a href="/board/<%= board %> ">Return</a>]

  <%= (build-threads rc mtable board thread) %>

  [<a href="/board/<%= board %> ">Return</a>]
  <br>
  <span>Delete Post: <input type="submit" name="delete-button" value="Delete"></span>
</form>


    <form enctype="multipart/form-data" method="post">
      <table class="postform" border="1">
        <tr>
          <td class="field">Options</td><td><input type="text" name="options" size="20"></td>
          <td class="field">Password</td><td><input type="text" name="password" size="20" placeholder="Use IP address if blank" value=<%= (get-password rc cookies) %>></td>
        </tr><tr>
          <td class="field">Name</td><td colspan="3"><input type="text" name="name" size="45"><input type="submit" name="submit" value="Post"></td>
        </tr><tr>
          <td class="field">Comment</td><td colspan="3"><textarea rows="5" cols="50" name="comment"></textarea></td>
        </tr><tr>
          <td class="field">File</td><td colspan="3"><input type="file" name="file"></td>
        </tr>
      </table>
    </form>

<%= (fill-footer rc styles) %>
