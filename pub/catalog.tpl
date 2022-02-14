<%= (fill-header rc (or (assoc-ref (assoc-ref boards board) 'theme) "none")
                    (format #f "Catalog: /~a/ - ~a - ~a" board board-title website-title)
                    (format #f "<h2>Catalog: /~a/ - ~a</h2>" board board-title)
                    style admin #:class "preview") %>

    <div class="catalog">
      <%= (build-threads rc mtable board #f #:mode 'preview #:page (get-from-qstr rc "page")
                         #:preview-OP-template "catalog-thread"
                         #:post-preview-count-override 0) %>
    </div>
    <br style="clear:both">

<%= (fill-footer rc styles) %>
