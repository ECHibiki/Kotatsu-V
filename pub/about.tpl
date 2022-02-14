<%= (fill-header rc "none" (string-append "About - " website-title) "<h2>About</h2>" style admin #:class "infopage") %>

    <center>
      Place holder.<br>
      <br>
      <table border="2" valign="top">
        <tr><td class="stack">

          <ul>
            <li><a href="#item1">Item 1</a></li>
            <li><a href="#item2">Item 2</a></li>
          </ul>

        </td></tr>
      </table>

      <br><hr><br>

      <table border="2" valign="top">
        <tr><td class="stack">

          <div id="item1">
            <h3>Item 1</h3>
            <blockquote>
              Item 1 description.
            </blockquote>
          </div>

          <div id="item2">
            <h3>Item 2</h3>
            <blockquote>
              Item 2 description.
            </blockquote>
          </div>

        </td></tr>
      </table>
    </center>

<%= (fill-footer rc styles) %>
