; Run test on code blocks
(add-to-load-path "../../prv")
(use-modules (artanis artanis)
             (modules settings)
             (modules utils)
             (modules imageboard))

(newline)(newline)
(newline)(newline)

(display "Must Pass Code tests")(newline)
(display (string=? (reluctant-code-tags "a [code]1[/code] [code]2[/code] b") "a <div class=''code''>1</div> <div class=''code''>2</div> b"))
(newline)(newline)
(display (string=? (reluctant-code-tags "a [codeblock][code]1[/code][/codeblock] b [code]2[/code] c") "a <div class=''code''>[code]1[/code]</div> b <div class=''code''>2</div> c"))

(newline)(newline)

(display "Must Fail Code tests")(newline)
(display (string=? (reluctant-code-tags "a [code]1[/code] [code]2[/code] b") "a <div class=''code''>1[/code] [code]2</div> b"))
(newline)(newline)
(display (string=? (reluctant-code-tags "a [codeblock][code]1[/code][/codeblock] b [code]2[/code] c") "a <div class=''code''>1[/code][/codeblock] b [code]2</div> c"))
(newline)(newline)

