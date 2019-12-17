<!DOCTYPE html>
<html lang="en-US">
  <head>
    <meta charset="utf-8">
    <meta name="robots" content="noarchive">
    <meta name="description" content="Some message board">
    <@icon favicon.ico %>
    <link rel="stylesheet" href="/pub/css/<%= style %>.css ">
    <title><%= pagetitle %></title>
  </head>

  <body class="<%= body-class %> ">
    <header>
      <div class="header">
        <center>
          <span class="site-name"><%= website-title %></span><br>
          <img src=<%= (format #f "'/pub/img/~a'"
                               (list-ref banners
                                         (modulo (round (/ (time-second (current-time time-utc))
                                                           banner-rotation-period))
                                                 (length banners)))) %>>
          <br>
          <%= message %>
          [<a href="/index">HOME</a>] [<a href="/" target="_top">Frames</a>] [<a href="/about">About</a>] [<a href="/rules">Rules</a>] [<a href="/news">News</a>]
        </center>
      </div>
      <hr>
    </header>

    <section>
      <div class="mid <%= class %> ">
      <br>
