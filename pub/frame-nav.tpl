<!DOCTYPE html>
<html lang="en-US">
  <head>
    <meta charset="utf-8">
    <meta name="robots" content="noarchive">
    <meta name="description" content="iframes">
    <link rel="stylesheet" href="/pub/css/<%= style %>.css ">
    <title><%= website-title %></title>
  </head>

  <body class="nav">
    <a href="/index" target="main"><img src="/favicon.ico"></a>
    <br>
    [<a target="_top" href="/index">Remove Frames</a>]<br>
    <br>

    <%= (call-with-values
          (lambda () (partition
                       (lambda (board) (member (assq-ref (cdr board) 'special) '(all listed unlisted)))
                       boards))
          (lambda (specials normals)
            (string-append
              (string-join
                (map (lambda (board)
                       (format #f "<div style=\"padding-bottom:5px\"><a href=\"/board/~a\" target=\"main\">~a</a></div>" (car board) (assq-ref (cdr board) 'title)))
                     specials)
                "\n")
              "<br><hr><h3>Boards</h3>"
              (string-join
                (map (lambda (board)
                       (format #f "<div style=\"padding-bottom:5px\"><a href=\"/board/~a\" target=\"main\">~a</a></div>" (car board) (assq-ref (cdr board) 'title)))
                     normals)
                "\n")))) %>

    <br><hr><br>

    <%= (if admin
          (format #f "<h3>Admin Links</h3>
                      <div style=\"padding-bottom:5px\"><a href=\"/panel\" target=\"main\">Admin Panel</a></div>
                      <div style=\"padding-bottom:5px\"><a href=\"/logoff\" target=\"main\">Log Off</a></div>")
          "") %>
      
    <h3>Information</h3>
    <div style="padding-bottom:5px"><a href="/" target="_top">HOME</a></div>
    <div style="padding-bottom:5px"><a href="/about" target="main">About</a></div>
    <div style="padding-bottom:5px"><a href="/rules" target="main">Rules</a></div>
    <div style="padding-bottom:5px"><a href="/news" target="main">News</a></div>
  </body>
</html>
