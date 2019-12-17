    <center>
        <form enctype="multipart/form-data" method="post">
          <table class="postform" border="1">
            <tr>
              <td class="field">Options</td><td><input type="text" name="options" size="20"></td>
              <td class="field">Password</td><td><input type="password" name="password" size="20" placeholder="Use IP address if blank" value=<%= (get-password rc cookies) %>></td>
            </tr><tr>
              <td class="field">Subject</td><td colspan="3"><input type="text" name="subject" size="51"></td>
            </tr><tr>
              <td class="field">Name</td><td colspan="3"><input type="text" name="name" size="45"><input type="submit" name="submit" value="Post"></td>
            </tr><tr>
              <td class="field">Comment</td><td colspan="3"><textarea rows="5" cols="50" name="comment"></textarea></td>
            </tr><tr>
              <td class="field">File</td><td colspan="3"><input type="file" name="file"></td>
            </tr>
          </table>
        </form>
    </center>

    <br>
