    <br>
    </div>
    <hr>
    </section>

    <footer>
      <a target="_top" href="https://www.gnu.org/software/guile/"><img style="vertical-align:middle" src="/pub/img/guile.png"></a> <a target="_top" href="https://www.gnu.org/software/artanis/"><img style="vertical-align:middle" src="/pub/img/artanis.png" height="25"></a> ♦ <a href="/contact">Contact</a>
    </div>

    <div class="style-picker">
      <form enctype="multipart/form-data" action="/set-style" method="post">
        Stylesheet:
        <select name="style" autocomplete="off">
            <%= style-menu %>
        </select>
        <input type="submit" name="submit" value="Submit">
      </form>

      <% (format #t "~a" (string-join (map (lambda (board)
                                             (format #f "<a href=\"/board/~a\">/~a/</a>"
                                               (car board) (car board)))
                                           boards)
                                      " ･ ")) %>

    </footer>
  </body>
</html>
