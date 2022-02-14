<%= (fill-header rc "none" (string-append "Rules - " website-title) "<h2>Rules</h2>" style admin #:class "infopage") %>

    <center>
      <table border="2" valign="top">
        <tr><td class="stack">

          <ol>
            <li>
              <b>Some rule.</b><br>
            </li>
            <li>
              <b>Some other rule.</b><br>
            </li>
          </ol>

        </td></tr>
      </table>
    </center>

<%= (fill-footer rc styles) %>
