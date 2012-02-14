#!/usr/bin/env coffee

# NOTE to self: this could be expanded to a template language by
# recognizing special tags: with,each,include
# and special sigil: @, recognized within text and attribute values
# 
# Example:
# synth("""
# with[user=@users[0]]
#  p span "Name: @user.name"
#  p span "Email: @user.email"
# """, {
#  users: [ { name: "Joe", email: "joe@mama.com" } ]
# })
#
# synth("""
# each[of=@users][as=user]
#  p span "Name: @user.name"
#  p span "Email: @user.email"
# """, {
#  users: [ ... ]
# })


applyAll = (f, c, a) -> # helper to keep calling functions until they stop returning functions
	x = f?.apply c, a
	if typeof x is "function"
		return applyAll x, c, a
	return x

operator = (f, label='unlabeled') -> # defines a pattern for operator functions in the synth state machines
	(next) ->
		() =>
			console.log "state: #{@state}, operator '#{label}', next: #{next}" if @debug > 0
			if f.length > 0 # if the wrapped func expects arguments
				a = [@stack.join ''] # pull them off the stack
				@stack = [] # clear the stack
			applyAll f, @, a
			@jmp next

get = (o, key, def) -> # get(o, "foo.bar.2.baz", default) will fetch o.foo.bar[2].baz or return a default 
	return def if not o?
	dot = key.indexOf '.'
	if dot isnt -1
		return get(get(o, key.substring(0,dot)), key.substring(dot+1), def)
	if key of o
		return o[key]
	return def

class StateMachine
	constructor: () -> @reset()
	reset: () ->
		console.log "reset." if @debug > 0
		@state = 0
		@entered = false
		@stack = []
		if document?
			@document = document
		else
			@document = require("domjs/dom").createDocument()
	jmp: (state) ->
		() =>
			console.log "jmp'ing to #{state}" if @debug > 1
			@entered = (@state is state)
			@state = state
	call: (state) ->
		() =>
			@stack.push @state
			@jmp state
	called: (f) ->
		(a...) =>
			next = @stack.pop()
			f.apply @, a
			@jmp next
	push: (a) ->
		(c) =>
			console.log "push'ing #{a or c}" if @debug > 1
			@stack.push a or c
	err: (label) -> (c) => throw new Error("#{label}: char: #{c}")
	runOne: (c) ->
		console.log "state: #{@state} c: #{escape(c)}" if @debug > 0
		modeline = @table[@state]
		# console.log "keys: #{ k for k of @table }"
		args = [c]
		if not @entered
			@entered = true
			applyAll modeline.enter, @, args
			if not @entered # we went into a new state while inside the handler
				@runOne(c)
		applyAll modeline.every, @, args
		if not @entered # we went into a new state while inside the handler
			@runOne(c)
		if c of modeline
			applyAll modeline[c], @, args
		else
			applyAll modeline[""], @, args
	eval: (input) ->
		console.log "eval'ing '#{input}'" if @debug > 1
		for c in input
			@runOne(c)
			console.log "'#{c}' is consumed." if @debug > 2
		console.log "EOF. state: #{@state}" if @debug > 0
		applyAll @table[@state]?.eof, @
	getOutput: () -> @stack.join('')
	run: (input) ->
		@eval(input)
		@getOutput()

class Synth extends StateMachine
	constructor: (context) ->
		super()
		# state names
		INIT = "INIT"
		READ_TAG = "READ_TAG"
		READ_CLASS = "READ_CLASS"
		READ_ID = "READ_ID"
		READ_KEY = "READ_KEY"
		START_VALUE = "START_VALUE"
		READ_UQ_VAL = "READ_UQ_VAL"
		READ_DQ_VAL = "READ_DQ_VAL"
		READ_SQ_VAL = "READ_SQ_VAL"
		ESCAPED = "ESCAPED"
		END_ATTR = "END_ATTR"
		READ_SQ_TEXT = "READ_SQ_TEXT"
		READ_DQ_TEXT = "READ_DQ_TEXT"
		START_COMMENT = "START_COMMENT"
		CONT_COMMENT = "CONT_COMMENT"
		READ_COMMENT = "READ_COMMENT"
		READ_CONDITION = "READ_CONDITION"
		COUNT_TABS = "COUNT_TABS"
		START_TABS = "START_TABS"
		READ_CLASS = "READ_CLASS"
		FINAL = "FINAL"
		@state = INIT
		@table = {
			INIT: {
				enter: () ->
					@reset()
					# really these three values should be computed based on the first line of the input
					# right now, 0, 1, -1, assumes/allows no global offset to the indentation in the file
					@tabs = 0
					@dtabs = 1
					@ptabs = -1
					@root = @document.createDocumentFragment()
					@cursor = @root
					@attr = { key: null, val: undefined }
					@jmp READ_TAG
			}
			READ_TAG: {
				"": @push()
				" ": @endTag(READ_TAG)
				'"': @endTag(READ_DQ_TEXT)
				"'": @endTag(READ_SQ_TEXT)
				".": @endTag(READ_CLASS)
				"#": @endTag(READ_ID)
				"[": @endTag(READ_KEY)
				"!": @endTag(START_COMMENT)
				"\r": @endTag(START_TABS)
				"\n": @endTag(START_TABS)
				eof: @endTag(FINAL)
			}
			START_COMMENT: {
				"-": @jmp CONT_COMMENT
				"?": @jmp READ_CONDITION
			}
			CONT_COMMENT: {
				"-": @jmp READ_COMMENT
			}
			READ_COMMENT: {
				"": @push()
				"\n": @endComment(COUNT_TABS)
				"\r": @endComment(COUNT_TABS)
				eof: @endComment(FINAL)
			}
			READ_CONDITION: {
				"": @push()
				"\n": @endCondition(COUNT_TABS)
				"\r": @endCondition(COUNT_TABS)
				eof: @endCondition(FINAL)
			}
			READ_DQ_TEXT: {
				"": @push()
				"\\": @call(ESCAPED)
				'"': @endText(READ_TAG)
				eof: @err("syntax: unclosed double-quote")
			}
			READ_SQ_TEXT: {
				"": @push()
				"\\": @call(ESCAPED)
				"'": @endText(READ_TAG)
				eof: @err("syntax: unclosed single-quote")
			}
			READ_CLASS: {
				"": @push()
				" ": @endClass(READ_TAG)
				".": @endClass(READ_CLASS)
				"#": @endClass(READ_ID)
				"[": @endClass(READ_KEY)
				"\r": @endClass(START_TABS)
				"\n": @endClass(START_TABS)
				eof: @endClass(FINAL)
			}
			READ_ID: {
				"": @push()
				" ": @endId(READ_TAG)
				".": @endId(READ_CLASS)
				"#": @endId(READ_ID)
				"[": @endId(READ_KEY)
				"\r": @endId(START_TABS)
				"\n": @endId(START_TABS)
				eof: @endId(FINAL)
			}
			READ_KEY: {
				"": @push()
				"=": @endKey(START_VALUE)
				"]": @endKey(READ_TAG)
				eof: @err("syntax: unclosed attribute block, expected ] or =")
			}
			START_VALUE: {
				"": (c) -> @stack.push(c); @jmp(READ_UQ_VAL)
				'"': @jmp(READ_DQ_VAL)
				"'": @jmp(READ_SQ_VAL)
				"]": @endVal(READ_TAG)
				eof: @err("syntax: unclosed attribute block, expected ] or value")
			}
			READ_UQ_VAL: {
				"": @push()
				"]": @endVal(READ_TAG)
				eof: @err("syntax: unclosed unquoted attribute value")
			}
			READ_DQ_VAL: {
				"": @push()
				"\\": @call(ESCAPED)
				'"': @endVal(END_ATTR)
				eof: @err("syntax: unclosed double-quoted attribute value")
			}
			READ_SQ_VAL: {
				"": @push()
				"\\": @call(ESCAPED)
				"'": @endVal(END_ATTR)
				eof: @err("syntax: unclosed single-quoted attribute value")
			}
			ESCAPED: {
				"n": @called () -> @stack.push("\n")
				"r": @called () -> @stack.push("\r")
				"t": @called () -> @stack.push("\t")
				"": @called (c) -> @stack.push(c)
				eof: @err("syntax: unterminated string ended on an escape char '\\'")
			}
			END_ATTR: {
				"]": @endAttr(READ_TAG)
				"": @err('syntax: expected closing ]')
				eof: @err('syntax: expected closing ]')
			}
			START_TABS: {
				enter: () ->
					@tabs = 1
					@jmp(COUNT_TABS)
			}
			COUNT_TABS: {
				"\r": () -> @tabs = 1
				"\n": () -> @tabs = 1
				"\t": () -> @tabs += 1
				'"': @jmp READ_DQ_TEXT
				"'": @jmp READ_SQ_TEXT
				"!": (c) ->
					@ptabs += (@dtabs = @tabs - @ptabs)
					@jmp START_COMMENT
				"": (c) ->
					@ptabs += (@dtabs = @tabs - @ptabs)
					@stack.push c
					@jmp READ_TAG
				eof: @endTag(FINAL)
			}
			FINAL: {
				enter: () ->
					console.log "FINAL" if @debug > 0
			}
		}
	endTag: operator (tagName, 'endTag') ->
		if tagName?.length > 0
			node = @document.createElement(tagName)
			if @cursor?
				if @dtabs isnt 1
					# close (-dtabs + 1) nodes
					n = (-@dtabs) + 1
					console.log "closing #{n} times" if @debug > 1
					while n-- > 0
						@cursor = @cursor.parentNode
				console.log "appending child" if @debug > 2
				@cursor.appendChild node
			else
				console.log "no cursor?" if @debug > 0
			@cursor = node
	endComment: operator (commentBody, 'endComment') ->
		if commentBody?.length > 0
			node = @document.createComment(commentBody)
			@cursor?.appendChild node
	endCondition: operator (condition) ->
		if condition?.length > 0
			node = @document.createComment("[if " + condition + "]>" + body + "<![endif]")
			# create an un-attached div
			div = @document.createElement("div")
			# dont attach it exactly, but leave enough of a trail
			# that we can get back into the real tree
			# after we descend into the body
			p = @cursor
			div.__defineGetter__ 'parentNode', () -> p
			@cursor = div
			
	endClass: operator (className, 'endClass') ->
		if @cursor? and className?.length > 0
			if @cursor.className.length > 0
				@cursor.className += " " + className
			else
				@cursor.className += className
	endId: operator (id, 'endId') ->
		if @cursor? and id?.length > 0
			@cursor.id = id
	endKey: operator (key, 'endKey') ->
		if key?.length > 0
			@attr.key = key
	endVal: operator (val, 'endVal') ->
		@attr.val = val
		@endAttr()()
	endAttr: operator (_, 'endAttr') ->
		if @cursor? and @attr.key?.length > 0
			@cursor.setAttribute(@attr.key, @attr.val)
			@attr = { key: null, val: undefined }
	endText: operator (text, 'endText') ->
		node = @document.createTextNode(text)
		@cursor?.appendChild node
	getOutput: () ->
		return @root

synth = (text, context = {}) ->
	m = new Synth(context)
	return m.run(text)

exports?.synth = synth
window?.synth = synth

if process?.argv.length > 2
	fs = require('fs')
	argv = process.argv.splice(2)
	console.log "argv: #{argv}"
	for f in argv
		fs.readFile f, (err, data) ->
			throw err if err?
			output = synth(data)
			outputFile = "#{f}.html"
			console.log "Writing #{output.length} bytes to #{outputFile}"
			fs.writeFile outputFile, output, 'utf8', (err) ->
				throw err if err?

