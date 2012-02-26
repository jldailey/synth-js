require("./common")
synth = require("../synth").synth
fs = require('fs')

testPattern = (patt, expected, context = {}, debug = 0) ->
	() ->
		try
			output = synth(patt,context,debug).toString()
		catch e
			output = e.toString()
		assertEqual(output, expected)

fs.readdir './tests', (err, files) ->
	throw err if err?
	tests = {}
	for f in files
		if /\.in$/.test(f)
			(() ->
				testname = f.replace /\.in$/, ''
				infile = './tests/' + testname + ".in"
				outfile = './tests/' + testname + ".out"
				datafile = './tests/' + testname + ".data"
				tests[testname] = () ->
					input = fs.readFileSync infile, 'utf8'
					expected = fs.readFileSync outfile, 'utf8'
					try
						data = fs.readFileSync datafile, 'utf8'
					catch e
						data = "{}"
					context = eval data
					output = synth input, context
					assertEqual output, expected
			)()

		
	testGroup("Synth", tests)
	testReport()

