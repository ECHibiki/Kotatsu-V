<%= (fill-header rc "none" (string-append "Note Editor - " website-title) "<h2>Note Editor</h2>" style admin #:class "infopage") %>

<%= (if (equal? id "new")
      ""
      (format #f "
    <div id=note~a class=\"~a\">
      <h3><b><a class=\"link\" href=/~a#note~a >~a</a></b> by <b>~a</b> [~a:~a]</h3>
      <span style=\"font-size:11px\">~a</span>
      <blockquote>~a</blockquote>
    </div>" id type links-target id subject name type id date (replace (replace body "\\r\\n" "<br>") "\\n" "<br>"))) %>

    <center>
      <h3>Note Editor:</h3>
      <%= (if editable "" "<span class=\"warning\">EDITING DISABLED: No write permissions</span><br>") %>
      <div style="display:table">
        <form enctype="multipart/form-data" method="post">
          <table class="postform" border="1">
            <tr>
              <td class="field">Subject</td><td><input type="text" name="subject" size="44" value=<%= (if (null? note) "''" (format #f "'~a'" subject)) %><%= (if editable "" " disabled") %>><%= (if editable "<input type=\"submit\" name=\"submit\" value=\"Post\">" "") %></td>
            </tr><tr>
              <td class="field">Body<br>(HTML format)</td><td><textarea rows="5" cols="50" name="body"<%= (if editable "" " disabled") %>><%= (if (null? note) "" (replace (replace body "\\r\\n" "\n") "\\n" "\n")) %></textarea></td>
            </tr><tr>
              <td class="field">Type</td>
              <td>
                <input type='radio' name='type' value='note'<%= (if (equal? type "note") " checked" "") %><%= (if editable "" " disabled") %>>Note</input>
                <input type='radio' name='type' value='notice'<%= (if (equal? type "notice") " checked" "") %><%= (if editable "" " disabled") %>>Notice</input>
                <input type='radio' name='type' value='public'<%= (if (equal? type "public") " checked" "") %><%= (if editable "" " disabled") %>>Public</input>
                <input type='radio' name='type' value='news'<%= (if (equal? type "news") " checked" "") %><%= (if editable "" " disabled") %>>News</input>
              </td>
            </tr><tr>
              <td class="field">Extra<br>Permissions</td>
              <td style="border:2px groove #888;vertical-align:top">
                <b>Read / Write</b><br>
                <%= (let ((editable-str (if editable "" " disabled")))
                      (string-join (map (lambda (mod)
                                          (format #f "<input type='checkbox' name='perm-read' value='~a'~a~a> / <input type='checkbox' name='perm-write' value='~a'~a~a> ~a" mod (if (member mod perms-read) " checked" "") editable-str mod (if (member mod perms-write) " checked" "") editable-str mod))
                                        (delete name (map car mods)))
                                   "<br>")) %>
                <!--<input type='checkbox' name='perm-read' value='2'> / <input type='checkbox' name='perm-write' value='2'> SomeMod<br>-->
          </table>
          <%= (if (equal? name (assoc-ref (car admin) "name"))
                "<input type='checkbox' name='delete' value='delete'> Delete this note<br>"
                "") %>
        </form>
        <p>
          <b>Note:</b> A private note only you can see and edit, additional permissions apply.<br>
          <b>Notice:</b> A note that all other mods can see, additional write permissions apply.<br>
          <b>Public:</b> A note that all other mods can both see and edit, additional permissions are ignored.<br>
          <b>News:</b> A public news item any visitor will see, additional write permissions apply.<br>
        </p>
      </div>
    </center>
    <br>

<%= (fill-footer rc styles)) %>
