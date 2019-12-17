    <form enctype="multipart/form-data" action="<%= action %> " method="post">
      <table class="postform" border="1">
        <tr>
          <td class="field">Name</td><td><input type="text" name="name" size="50"></td>
        </tr><tr>
          <td class="field">Options</td><td><input type="text" name="options" size="44"><input type="submit" name="submit" value="Post"></td>
        </tr><tr>
          <td class="field">Comment</td><td><textarea rows="5" cols="50" name="comment"></textarea></td>
        </tr><tr>
          <td class="field">File</td><td><input type="file" name="file"></td>
        </tr>
      </table>
    </form>
