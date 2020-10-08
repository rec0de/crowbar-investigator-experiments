require_relative "mockABS"
require "fileutils"
require "json"

mock = MockABS.new
startat = 0
batchSize = 300 - startat
basepath = "data"
maxsize = 3500

batchSize.times { |j|
	i = j + startat
	puts "Generating mock program \##{i}..."
	code = ""

	loop do
		code = mock.mockProgram()
		break if code.length <= maxsize
	end

	blockid = "%02d" % (i/10)
	fileid = "%03d" % i
	outpath = "#{basepath}/#{blockid}/#{fileid}"
	`mkdir -p #{outpath}`
	filepath = "#{outpath}/m#{fileid}.abs"
	File.open(filepath, 'w') { |file| file.write(code) }
	puts "Saved program"

	puts "CE size: #{code.length}"

	puts "Attempting verification..."
	puts `java -jar "/home/user/Documents/Uni/Bachelor Thesis/crowbar-tool/build/libs/crowbar-0.1-all.jar" --method="MockABS.Generated.gen" --investigate #{filepath}`

	puts "Moving generated counterexamples..."
	`mv /tmp/crowbar-ce* #{outpath}/`
}

def countloc(code, includeComments = true)
	lineregex = includeComments ? /^\s*$/ : /^\s*(\/\/.*)?$/
	code.split("\n").count { |l| not lineregex.match?(l) }
end

sizes = []

batchSize.times { |i|
	blockid = "%02d" % (i/10)
	fileid = "%03d" % i
	filepath = "#{basepath}/#{blockid}/#{fileid}"
	abspath = "#{filepath}/m#{fileid}.abs"

	abs = File.read(abspath)
	dataItem = { "id" => i, "size" => abs.length, "loc" => countloc(abs), "sloc" => countloc(abs, false), "ces" => [] }

	Dir.each_child(filepath){ |file| 
		next unless file.start_with?("crowbar-ce")
		ce = File.read(filepath + "/" + file)
		ceItem = { "size" => ce.length, "loc" => countloc(ce), "sloc" => countloc(ce, false) }
		dataItem["ces"].push(ceItem)
	}
	sizes.push(dataItem)
}

File.open("#{basepath}/all.json", 'w') { |file| file.write(JSON.dump(sizes)) }

bytepairs = sizes.map { |e| 
	absBytes = e["size"]
	e["ces"].map{ |ce| { "x" => absBytes, "y" => ce["size"] } }
}.flatten()

locpairs = sizes.map { |e| 
	absLoc = e["loc"]
	e["ces"].map{ |ce| { "x" => absLoc, "y" => ce["loc"] } }
}.flatten()

slocpairs = sizes.map { |e| 
	absSloc = e["sloc"]
	e["ces"].map{ |ce| { "x" => absSloc, "y" => ce["sloc"] } }
}.flatten()

cecount = sizes.map { |e| 
	{ "x" => e["loc"], "y" => e["ces"].length }
}

File.open("#{basepath}/bytePairs.json", 'w') { |file| file.write(JSON.dump(bytepairs)) }
File.open("#{basepath}/locPairs.json", 'w') { |file| file.write(JSON.dump(locpairs)) }
File.open("#{basepath}/slocPairs.json", 'w') { |file| file.write(JSON.dump(slocpairs)) }
File.open("#{basepath}/ceCountsLoc.json", 'w') { |file| file.write(JSON.dump(cecount)) }