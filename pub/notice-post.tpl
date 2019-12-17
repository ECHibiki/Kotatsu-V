<%= (fill-header rc "none" (string-append "Notice Editor - " website-title) "<h2>Notices</h2>" style admin #:class "infopage") %>

<center>
  <h3>New Notice Post:</h3>
  <div style="display:table">
    <form enctype="multipart/form-data" method="post">
      <table class="postform" border="1">
        <tr>
          <td class="field">Subject</td><td><input type="text" name="subject" size="44"><input type="submit" name="submit" value="Post"></td>
        </tr><tr>
          <td class="field">Body<br>(HTML format)</td><td><textarea rows="5" cols="50" name="body"></textarea></td>
        </tr>
      </table>
    </form>
  </div>
</center>
<br>

<%= (build-notice-listing "<div id=\"notice~a\" class=\"news\">
                           <h3><a href=\"/notice-post#notice~a\">~a</a> by ~a [~a]</h3>
                           <blockquote>~a</blockquote>
                         </div>") %>

<%= (fill-footer rc styles)) %>
