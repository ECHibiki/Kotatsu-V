<%= (fill-header rc "none" (string-append "Admin Panel - " website-title) "<h2>Admin Panel</h2>" style admin #:class "infopage") %>

      <div class="stack" style="margin:5px">
        <b>Messages:</b>
        <br><br>
        <ul>
          <li><a href="/noticeboard">Noticeboard</a></li>
          <ul>
            
            <table style="width:100%"><tr>
                <th style="padding:0px">Notices</th> <th style="padding:0px">Private notes being shared with you</th>
              </tr><tr style="vertical-align:top"><td>
                  <%= (build-note-listing rc mtable admin #:template "pub/note-short.tpl" #:type '("notice" "public") #:limit 3) %>
                </td><td style="padding-left:12px">
                  <%= (build-note-listing rc mtable admin #:template "pub/note-short.tpl" #:type "note" #:shared #t #:links-target "noticeboard") %>
            </td></tr></table>

          </ul>
          <br>
          <li><a href="/notes-view">Personal Notes</a></li>
          <ul>
            <%= (build-note-listing rc mtable admin #:template "pub/note-short.tpl" #:limit 3 #:personal #t) %>
          </ul>
          <br>
          <li><a href="/note-editor/new">New Note</a></li>
          <li><a href="/private-messages">PM Inbox</a></li>
        </ul>

        <br><br>
        
        <b>Aministration:</b> (work in progress)
        <br><br>
        <ul>
          <li>Report Queue</li>
          <li>Ban List</li>
          <li>Manage Users</li>
          <li>Moderation Log</li>
        </ul>
      </div>
      <p><b>Info:</b><br>
        To post with your moderator capcode <b><span class="name"><span class="capcode"><%= (assoc-ref (car admin) "name") %> ## SysOP <img title="Mod" style="vertical-align:bottom" src="/pub/img/capcode.png"></span></span></b> just make sure you're signed in, then when making a post put in the name field: <b><span class="name"><%= (assoc-ref (car admin) "name") %> ## SysOp</span></b><br>
        (The first part must be your mod name, but you can replace "SysOp" with anything you want. Please don't use the capcode for casual posting.)<br>
        <br>
        To create News or a Noticeboard entries start by clicking <b><u>New Note</u></b> above.<br>
        On the new note page you can select where you want the note to appear and which other mods can access it.<br>
        You can also edit notes and turn existing ones into news items or noticeboard entries at a later time.<br>
      </p>

      <br><hr><br>
      
      <div style="display:table">
        <b>Change Password</b>
        <form enctype="multipart/form-data" method="post">
          <table class="postform" border="1" style="margin:5px">
            <tr>
              <td class="field">Name</td><td><input type="text" name="name" size="50"></td>
            </tr><tr>
              <td class="field">Current Password</td><td><input type="password" name="current-password" size="50"></td>
            </tr><tr>
              <td class="field">New Password</td><td><input type="password" name="new-password" size="50"></td>
            </tr><tr>
              <td class="field">Confirm Password</td><td><input type="password" name="confirm-password" size="50"></td>
            </tr><tr>
              <td class="field">Submit</td><td><input type="submit" name="submit" value="Submit"></td>
            </tr>
          </table>
        </form>
      </div>

<%= (fill-footer rc styles) %>
