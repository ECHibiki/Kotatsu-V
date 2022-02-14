<%= (fill-header rc "none" (string-append "Mod Logoff - " website-title) "<h2>Mod Logoff</h2>" style #f #:class "infopage") %>

      <% (mod-logoff rc) %>

      <h1>Successfully logged off.</h1>

<%= (fill-footer rc styles) %>
