require("./common")

Synth = require("../synth").Synth

testPattern = (patt, expected) ->
	() ->
		m = new Synth()
		m.debug = 0
		try
			output = m.run(patt).toString()
		catch e
			output = e.toString()
		assertEqual(output, expected)

testGroup("Synth", {
	basic1: testPattern("p", "<p/>")
	basic2: testPattern("p h", "<p><h/></p>")
	basic_child: testPattern("""
s
	p
""","<s><p/></s>")
	basic_grandchild: testPattern("""
a
	b
		c
""", "<a><b><c/></b></a>")
	basic_sibling: testPattern("""
a
	b
	c
""", "<a><b/><c/></a>")
	basic_family: testPattern("""
a
	b
		c
	d
""", "<a><b><c/></b><d/></a>")
	className: testPattern("a.b", '<a class="b"/>')
	className2: testPattern("""
a.b
	b.c
""", '<a class="b"><b class="c"/></a>')
	className_sibling: testPattern("""
foo.bar
	goo.baz
		hoo.bap
		a
""", '<foo class="bar"><goo class="baz"><hoo class="bap"/><a/></goo></foo>')

	class_id: testPattern("foo.bar#baz", '<foo class="bar" id="baz"/>')
	attr: testPattern("foo[bar=baz]", '<foo bar="baz"/>')
	attr_spaces: testPattern("foo[bar='b az']", '<foo bar="b az"/>')
	attr_singlequote: testPattern('foo[bar="b az"]', '<foo bar="b az"/>')
	attr_class: testPattern('foo[bar="b az"].cls', '<foo bar="b az" class="cls"/>')
	attr_id: testPattern('foo[bar="b az"]#xxx', '<foo bar="b az" id="xxx"/>')
	attr_escaped: testPattern('foo[bar="b \\"az"]', '<foo bar="b "az"/>')
	comment: testPattern("""
a
	!-- comment
""", "<a><!-- comment--></a>")
	comment_sibling: testPattern("""
a
	!-- comment
	b
""", "<a><!-- comment--><b/></a>")
	comment_sibling2: testPattern("""
a
	!-- comment
	!-- second line
""", "<a><!-- comment--><!-- second line--></a>")
	text: testPattern("""
a "Hello World"
""", "<a>Hello World</a>")
	text_newline: testPattern("""
a
	"Hello"
""", "<a>Hello</a>")
	text_multiline: testPattern("""
a
	"Hello,
	World"
""", "<a>Hello,\n\tWorld</a>")
	text_singlequote: testPattern("""
a
	'Hello'
""", "<a>Hello</a>")
	text_squote_mline: testPattern("""
a
	'Hello
	World'
""", "<a>Hello\n\tWorld</a>")

})

testReport()
