<!--
THIS IS JUST A SANDBOX FILE.
TO VIEW THE ACTUAL FILE DATA VISIT THE src LINK BELOW.
-->

<html>
  <head>
    <meta charset="utf-8">
    <meta name="robots" content="noarchive">
    <meta name="description" content="Flash/HTML5 sandbox page">
    <@icon favicon.ico %>
    <title>Flash/HTML5 Sandbox Page</title>
  </head>
  <body style="margin:0px;background:#333">

    <table style="border-collapse:collapse;width:100%;height:100%">
      <tr style="height:15px;font-size:12px;text-align:center;background:#FED">
        <td>
          <a href=<%= (format #f "\"/pub/img/~a/~a/~a.~a\"" board threadnum timestamp extension) %>>DOWNLOAD FILE</a>: <%= (format #f "~a (w:~a h:~a ~aB)" filename width height fsize) %>
        </td>
      </tr>
      <tr>
        <td style="text-align:center">
          <iframe style=<%= (format #f "\"margin-left:auto;margin-right:auto;border:none;width:~a;height:~a\"" width height) %> src=<%= (format #f "\"/pub/img/~a/~a/~a\"" board threadnum entrypoint) %> sandbox="allow-scripts" allowfullscreen></iframe>
        </td>
      </tr>
    </table>

  </body>
</html>
