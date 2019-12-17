<%= (fill-header rc "none" (string-append "Noticeboard - " website-title) "<h2>Noticeboard</h2>" style admin #:class "infopage") %>

<table style="width:100%;max-width:1800px"><tr>
    <th style="width:50%">Notices</th> <th>Private notes being shared with you</th>
  </tr><tr style="vertical-align:top"><td>
      <%= (build-note-listing rc mtable admin #:type '("notice" "public")) %>
    </td><td>
      <%= (build-note-listing rc mtable admin #:type "note" #:shared #t #:links-target "noticeboard") %>
</td></tr></table>

<%= (fill-footer rc styles) %>
