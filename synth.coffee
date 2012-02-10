#!/usr/bin/env coffee

applyAll = (f, c, a) ->
	x = f?.apply c, a
	if typeof x is "function"
		return applyAll x, c, a
	return x

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
	constructor: () ->
		super()

		endTag = (next) =>
			() =>
				tagName = @stack.join('')
				console.log "ending tag: #{tagName} next: #{next}" if @debug > 0
				@stack = []
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
				@jmp next

		endComment = (next) =>
			() =>
				commentBody = @stack.join('')
				console.log "ending comment: #{commentBody} next: #{next}" if @debug > 0
				@stack = []
				if commentBody?.length > 0
					node = @document.createComment(commentBody)
					@cursor?.appendChild node
				@jmp next

		endCondition = (next) =>
			() =>
				condition = @stack.join ''
				console.log "ending comment: #{commentBody} next: #{next}" if @debug > 0
				@stack = []
				if condition?.length > 0
					#TODO: how to compute the body most correctly!??
					node = @document.createComment("[if " + condition + "]>" + body + "<![endif]")
				@jmp next

		endClass = (next) =>
			() =>
				className = @stack.join('')
				console.log "ending class: '#{className}' next: #{next}" if @debug > 0
				@stack = []
				if className?.length > 0 and @cursor?
					if @cursor.className.length > 0
						@cursor.className += " " + className
					else
						@cursor.className += className
				@jmp next

		endId = (next) =>
			() =>
				id = @stack.join('')
				console.log "ending id: '#{id}' next: #{next}" if @debug > 0
				@stack = []
				if id?.length > 0 and @cursor?
					@cursor.id = id
				@jmp next

		endKey = (next) =>
			() =>
				key = @stack.join('')
				console.log "ending key: '#{key}' next: #{next}" if @debug > 0
				@stack = []
				@attr.key = key
				@jmp next

		endVal = (next) =>
			() =>
				val = @stack.join('')
				console.log "ending val: '#{val}' next: #{next}" if @debug > 0
				@stack = []
				@attr.val = val
				endAttr(next)()

		endAttr = (next) =>
			() =>
				if @cursor? and @attr.key?.length > 0
					@cursor.setAttribute(@attr.key, @attr.val)
					@attr = { key: null, val: undefined }
				@jmp next

		endText = (next) =>
			() =>
				text = @stack.join('')
				@stack = []
				node = @document.createTextNode(text)
				@cursor?.appendChild node
				@jmp next


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
		@state = INIT = "INIT"
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
				" ": endTag(READ_TAG)
				'"': endTag(READ_DQ_TEXT)
				"'": endTag(READ_SQ_TEXT)
				".": endTag(READ_CLASS)
				"#": endTag(READ_ID)
				"[": endTag(READ_KEY)
				"!": endTag(START_COMMENT)
				"\r": endTag(START_TABS)
				"\n": endTag(START_TABS)
				eof: endTag(FINAL)
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
				"\n": endComment(COUNT_TABS)
				"\r": endComment(COUNT_TABS)
				eof: endComment(FINAL)
			}
			READ_CONDITION: {
				"": @push()
				"\n": endCondition(COUNT_TABS)
				"\r": endCondition(COUNT_TABS)
				eof: endCondition(FINAL)
			}
			READ_DQ_TEXT: {
				"": @push()
				"\\": @call(ESCAPED)
				'"': endText(READ_TAG)
				eof: @err("syntax: unclosed double-quote")
			}
			READ_SQ_TEXT: {
				"": @push()
				"\\": @call(ESCAPED)
				"'": endText(READ_TAG)
				eof: @err("syntax: unclosed single-quote")
			}
			READ_CLASS: {
				"": @push()
				" ": endClass(READ_TAG)
				".": endClass(READ_CLASS)
				"#": endClass(READ_ID)
				"[": endClass(READ_KEY)
				"\r": endClass(START_TABS)
				"\n": endClass(START_TABS)
				eof: endClass(FINAL)
			}
			READ_ID: {
				"": @push()
				" ": endId(READ_TAG)
				".": endId(READ_CLASS)
				"#": endId(READ_ID)
				"[": endId(READ_KEY)
				"\r": endId(START_TABS)
				"\n": endId(START_TABS)
				eof: endId(FINAL)
			}
			READ_KEY: {
				"": @push()
				"=": endKey(START_VALUE)
				"]": endKey(READ_TAG)
				eof: @err("syntax: unclosed attribute block, expected ] or =")
			}
			START_VALUE: {
				"": (c) -> @stack.push(c); @jmp(READ_UQ_VAL)
				'"': @jmp(READ_DQ_VAL)
				"'": @jmp(READ_SQ_VAL)
				"]": endVal(READ_TAG)
				eof: @err("syntax: unclosed attribute block, expected ] or value")
			}
			READ_UQ_VAL: {
				"": @push()
				"]": endVal(READ_TAG)
				eof: @err("syntax: unclosed unquoted value")
			}
			READ_DQ_VAL: {
				"": @push()
				"\\": @call(ESCAPED)
				'"': endVal(END_ATTR)
				eof: @err("syntax: unclosed double-quoted value")
			}
			READ_SQ_VAL: {
				"": @push()
				"\\": @call(ESCAPED)
				"'": endVal(END_ATTR)
				eof: @err("syntax: unclosed single-quoted value")
			}
			ESCAPED: {
				"n": @called(() -> @stack.push("\n"))
				"r": @called(() -> @stack.push("\r"))
				"t": @called(() -> @stack.push("\t"))
				"": @called((c) -> @stack.push(c))
				eof: @err("syntax: unterminated string ended on an escape char '\\'")
			}
			END_ATTR: {
				"]": endAttr(READ_TAG)
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
				eof: endTag(FINAL)
			}
			FINAL: {
				enter: () ->
					console.log "FINAL" if @debug > 0
			}
		}
	getOutput: () ->
		return @root

synth = (text, debug = 0) ->
		m = new Synth()
		m.debug = debug
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



