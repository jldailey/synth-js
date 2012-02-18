require("./common")
synth = require("../synth").synth

testPattern = (patt, expected, context = {}, debug = 0) ->
	() ->
		try
			output = synth(patt,context,debug).toString()
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
		""", "<a><!-- comment--><b/></a>", 0)
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
	comment_conditional: testPattern("""
		a
			!? lt IE 9
				b
			c
		""", '<a><!--[if lt IE 9]><b/><![endif]--><c/></a>')
	var_dq: testPattern(
		'a "Hello, @{name}."',
		"<a>Hello, Joe.</a>",
		{ name: "Joe" }
	)
	var_sq: testPattern(
		"a 'Hi, @{name}.'",
		"<a>Hi, Joe.</a>",
		{ name: "Joe" }
	)
	var_attr: testPattern(
		"a[href=@{href}] 'Hello'",
		'<a href="/">Hello</a>',
		{ href: "/" }
	)
	var_dots: testPattern(
		"span 'Email: @{user.email}'",
		'<span>Email: a@b.com</span>',
		{ user: { email: "a@b.com" } }
	)
	var_list: testPattern(
		"span 'Email: @{users.0.email}'",
		'<span>Email: a@b.com</span>',
		{ users: [ { email: "a@b.com" } ] }
	)

###
	each: testPattern("""
		ul
			each[of=@{users}][as=user]
				li '@{user.name}'
		""", "<ul><li>A</li><li>B</li><li>C</li></ul>",
		{ users: [ {name: "A"}, {name: "B"}, {name: "C"} ] }
	)
###

})

testReport()
