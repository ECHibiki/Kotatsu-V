<%= (fill-header rc "none" (string-append "Mod Login - " website-title) "<h2>Mod Login</h2>" style admin #:class "infopage") %>

      <h3>Moderator Login:</h3>
      <div style="display:table">
        <form enctype="multipart/form-data" method="post">
          <table class="postform" border="1">
            <tr>
              <td class="field">Name</td><td><input type="text" name="name" size="50"></td>
            </tr><tr>
              <td class="field">Password</td><td><input type="password" name="password" size="50"></td>
            </tr><tr>
              <td class="field">Submit</td><td><input type="submit" name="submit" value="Submit"></td>
            </tr>
          </table>
        </form>
      </div>

<%= (fill-footer rc styles) %>
