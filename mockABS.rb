class MockABS

	@@maxDepth = 3
	@@branchRate = 0.2
	@@declareToAssign = 0.3
	@@elseRatio = 0.7
	@@avgFuncBodySize = 10
	@@avgBlockSize = 4

	def initialize
		@scope = Scope.new
	end

	def mockProgram
		res =  "module MockABS;\n\n"
		res += "data Spec = Ensures(Bool) | Requires(Bool);\n\n"
		res += "// Static base definitions\n"
		res += "interface I { Int n(); Bool b(); }\n"
		res += "interface J { Unit m(Int v); I getI(Bool flag, Int c); }\n"
		res += "class D implements I { Int n() { return 0; } Bool b() { return False; } }\n"
		res += "class E implements J { Unit m(Int v) { } I getI(Bool flag, Int c) { I res = new D(); return res; } }\n\n"

		res += "class Generated {\n"
		res += "Int fint = 0;\n"
		res += "Bool fb = True;\n"
		res += "Fut<Int> ff;\n"
		res += "Fut<Bool> ffb;\n"
		res += "I fi = null;\n"
		res += "J fj = null;\n\n"
		res += "[Spec : Ensures(result == 0)]\n"
		res += "Int gen() {\n"

		@scope = Scope.new

		@scope.defineField("fint", Type.newInt())
		@scope.defineField("fb", Type.newBool())
		@scope.defineField("ff", Type.newFuture(Type.newInt()))
		@scope.defineField("ffb", Type.newFuture(Type.newBool()))
		@scope.defineField("fi", Type.newObjI())
		@scope.defineField("fj", Type.newObjJ())

		@scope.defineFunc("n", Type.newInt(), [Type.newObjI()], [])
		@scope.defineFunc("b", Type.newBool(), [Type.newObjI()], [])
		@scope.defineFunc("m", Type.newUnit(), [Type.newObjJ()], [Type.newInt()])
		@scope.defineFunc("getI", Type.newObjI(), [Type.newObjJ()], [Type.newBool(), Type.newInt()])

		res += MockABS.prettyPrint(generateFuncBody())
		res += "}\n"
		res += "}\n"
		res += "{}"

		res
	end

	def generateFuncBody
		size = exponentialRandomInt(@@avgFuncBodySize)
		"#{generateCodeBlock(size)} #{generateReturn(Type.newInt())}"
	end

	def generateCodeBlock(size = exponentialRandomInt(@@avgBlockSize))
		stmts = []
		size.times do
			stmts.push(generateInstruction())
		end

		stmts.join(" ")
	end

	def generateInstruction
		if chance(@@branchRate)
			generateBranch()
		elsif chance(@@declareToAssign)
			generateDeclare()
		else
			generateAssign()
		end
	end

	def generateBranch
		allowNewScope = @scope.currentDepth < @@maxDepth
		branchType = ((allowNewScope ? [:if, :while] : []) + [:await]).sample # disabled scall for crowbar support
		case branchType
		when :if 
			generateIf()
		when :while
			generateWhile()
		when :await
			generateAwait()
		when :scall
			generateSyncCallAssign()
		end
	end

	def generateIf
		guard = generatePureExpr(Type.newBool)
		@scope.descend
		ifblock = generateCodeBlock()
		@scope.exit

		res = "if( #{guard}) { #{ifblock} } "

		if chance(@@elseRatio)
			@scope.descend
			elseblock = generateCodeBlock()
			@scope.exit
			res += " else { #{elseblock} } "
		end

		res
	end

	def generateWhile
		guard = generatePureExpr(Type.newBool)
		@scope.descend
		whileblock = generateCodeBlock()
		@scope.exit

		"while( #{guard} ) { #{whileblock} } "
	end

	def generateAwait
		if chance(0.75)
			fut = @scope.getFuture.to_str
			"await #{fut}? ;"
		else
			expr = generatePureExpr(Type.newBool)
			"await #{expr} ;"
		end
	end

	def generateDeclare
		type = randomAvailableType
		lhs = @scope.getFreeVarId(type)
		expr = generateExpr(type, false)
		@scope.defineVar(lhs, type)
		"#{type.to_str} #{lhs} = #{expr} ;"
	end

	def generateAssign
		lhs = @scope.getAssignableIdentifier
		type = lhs.dataType
		expr = generateExpr(type, false)
		"#{lhs.to_str} = #{expr} ;"
	end

	def generateSyncCallAssign
		fun = @scope.getFunction
		callee = fun.availIn.sample
		args = fun.args.map { |arg| generatePureExpr(arg) }

		if fun.dataType.isUnit
			"#{generatePureExpr(callee)}.#{fun.to_str}(#{args.join(", ")}) ;"
		else
			lhs = @scope.thingsOfType(fun.dataType).sample
			"#{lhs.to_str} = #{generatePureExpr(callee)}.#{fun.to_str}(#{args.join(", ")}) ;"
		end
	end

	def generateReturn(type)
		expr = generatePureExpr(type)
		"return #{expr} ;"
	end

	def generateExpr(type, allowBranch)
		if chance(0.1) && !type.isFut && @scope.hasThingOfType(Type.newFuture(type))
			"#{generatePureExpr(Type.newFuture(type))}.get"
		elsif type.isObject && chance(0.5)
			"new #{type.typeSymbol == :obji ? "D" : "E"}()"
		elsif type.isFut && chance(0.7) && (funcs = @scope.funcOfType(type.resolvedType)).length > 0
			fun = funcs.sample
			callee = fun.availIn.sample
			args = fun.args.map { |arg| generatePureExpr(arg) }
			"#{generatePureExpr(callee)}!#{fun.to_str}(#{args.join(", ")})"
		elsif allowBranch && chance(0.1) && (funcs = @scope.funcOfType(type)).length > 0
			fun = funcs.sample
			callee = fun.availIn.sample
			args = fun.args.map { |arg| generatePureExpr(arg) }
			"#{generatePureExpr(callee)}.#{fun.to_str}(#{args.join(", ")})"
		else
			generatePureExpr(type)
		end
	end

	def generatePureExpr(type)
		generateCompare(type)
	end

	def generateCompare(type)
		if type.isBool && chance(0.15)
			cmptype = Type.newInt()
			cmpop = ["==", "<=", ">=", "!=", ">", "<"].sample
			return "#{generateOr(cmptype)} #{cmpop} #{generateOr(cmptype)}"
		elsif type.isBool && chance(0.15)
			cmptype = randomAvailableType()
			return "#{generateOr(cmptype)} == #{generateOr(cmptype)}"
		else
			return generateOr(type)
		end
	end

	def generateOr(type)
		if type.isBool && chance(0.2)
			return "#{generateAnd(type)} || #{generateOr(type)}"
		else
			return generateAnd(type)
		end
	end

	def generateAnd(type)
		if type.isBool && chance(0.2)
			return "#{generateNot(type)} && #{generateAnd(type)}"
		else
			return generateNot(type)
		end
	end

	def generateNot(type)
		if type.isBool && chance(0.2)
			return "! #{generateAddSub(type)}"
		else
			return generateAddSub(type)
		end
	end

	def generateAddSub(type)
		if (type.isInt) && chance(0.2)
			op = ["+", "-"].sample
			return "#{generateAddSub(type)} #{op} #{generateMulDiv(type)}"
		else
			return generateMulDiv(type)
		end
	end

	def generateMulDiv(type)
		if (type.isInt) && chance(0.2)
			op = ["*"].sample # no division because we don't support rationals
			return "#{generateMulDiv(type)} #{op} #{generateUnaryMinus(type)}"
		else
			return generateUnaryMinus(type)
		end
	end

	def generateUnaryMinus(type)
		if type.isInt && chance(0.2)
			return "- #{generateAtom(type)}"
		else
			return generateAtom(type)
		end
	end

	def generateAtom(type)
		if chance(0.1)
			"( #{generatePureExpr(type)} )"
		elsif type.hasLiteral && chance(0.7)
			type.getLiteral()
		else
			availableIds = @scope.thingsOfType(type)
			raise "No identifier available of type #{type.to_str}" if availableIds.length == 0
			availableIds.sample.to_str()
		end
	end

	def chance(prob)
		Random::rand() < prob
	end

	def exponentialRandomValue(lambda)
		(-Math.log(Random::rand())) / lambda
	end

	def exponentialRandomInt(expected)
		exponentialRandomValue(1.to_f/expected).ceil.to_i
	end

	def randomAvailableType(noFuture = false)
		type = nil

		loop do
			type = randomType(noFuture)
			break if type.hasLiteral() or @scope.hasThingOfType(type)
		end

		type
	end

	def randomType(noFuture = false)
		if chance(0.8) || noFuture
			return Type.new([:int, :int, :bool, :bool, :obji, :objj].sample)
		else
			return Type.new(:fut, randomType(true))
		end
	end

	def self.prettyPrint(program)
		indentLevel = 0
		res = ""
		wasNewline = true
		lastWord = ""
		program.split(' ').each.with_index { |word, i|
			if word == '{'
				indentLevel += 1
				res = res + (wasNewline ? "{\n" : " {\n") + self.indentation(indentLevel)
				wasNewline = true
			elsif word == '}'
				indentLevel -= 1
				res = res + "\n" + self.indentation(indentLevel) + "}\n" + self.indentation(indentLevel)
				wasNewline = true
			elsif word == ';'
				res = res + ";\n" + self.indentation(indentLevel)
				wasNewline = true
			elsif word == '(' || word == ')' || word == ']' || word == ',' || word == '!' || lastWord == '(' || lastWord == '['
				res = res + word
				wasNewline = false
			else
				res = res + (wasNewline ? "" : " ") + word
				wasNewline = false
			end

			lastWord = word
		}
		return res
	end

	def self.indentation(level)
		(["\t"]*(level < 0 ? 0 : level)).join('')
	end
end

class Type

	def self.newBool
		Type.new(:bool)
	end

	def self.newInt
		Type.new(:int)
	end

	def self.newFuture(resolvedType)
		Type.new(:fut, resolvedType)
	end

	def self.newObjI
		Type.new(:obji)
	end

	def self.newObjJ
		Type.new(:objj)
	end

	def self.newUnit
		Type.new(:unit)
	end

	def initialize(primType, rType = nil)
		@type = primType
		@resolved = rType
	end

	def ==(o)
		@type == o.typeSymbol && @resolved == o.resolvedType
	end

	def typeSymbol
		@type
	end

	def resolvedType
		@resolved
	end

	def isBool
		@type == :bool
	end

	def isInt
		@type == :int
	end

	def isFut
		@type == :fut
	end

	def isUnit
		@type == :unit
	end

	def isObject
		@type == :objj || @type == :obji
	end

	def hasLiteral
		@type == :int || @type == :bool
	end

	def getLiteral
		case @type
		when :int
			(Random::rand()*1000).to_i.to_s
		when :bool
			["True", "False"].sample
		else raise "Cannot generate literal of type #{to_str()}"
		end
	end

	def to_str
		case @type
		when :int
			return "Int"
		when :bool
			return "Bool"
		when :void
			return "Unit"
		when :obji
			return "I"
		when :objj
			return "J"
		when :fut
			return "Fut<#{@resolved.to_str()}>"
		end
	end
end

class Scope

	def initialize
		@stack = [[]]
		@stackIndex = 0
	end

	def currentDepth
		@stackIndex
	end

	def defineField(id, type)
		@stack[@stackIndex].push(ScopeEntry.new(:field, type, id))
	end

	def defineVar(id, type)
		@stack[@stackIndex].push(ScopeEntry.new(:var, type, id))
	end

	def defineFunc(id, type, availableIn, argTypes)
		@stack[@stackIndex].push(ScopeEntry.new(:fun, type, id, availableIn, argTypes))
	end

	def descend
		@stack.push([])
		@stackIndex += 1
	end

	def exit
		@stack.pop()
		@stackIndex -= 1
	end

	private def functions
		@stack.flatten.keep_if{ |entry| entry.structureType == :fun }
	end

	def thingsOfType(type)
		@stack.flatten.keep_if{ |entry| entry.structureType != :fun && entry.hasDataType(type) }
	end

	def hasThingOfType(type)
		@stack.flatten.any? { |entry| entry.structureType != :fun && entry.hasDataType(type) }
	end

	def funcOfType(type)
		functions.keep_if{ |entry| entry.hasDataType(type) }
	end

	def getFuture
		@stack.flatten.keep_if{ |entry| entry.structureType != :fun && entry.dataType.isFut }.sample
	end

	def getFunction
		functions.sample
	end

	def getAssignableIdentifier
		@stack.flatten.keep_if{ |entry| entry.structureType != :fun }.sample
	end

	def getFreeVarId(type)
		choice = NameGenerator::varName(type)
		
		while @stack.flatten.index{ |stackEntry| stackEntry.id == choice } != nil
			choice = NameGenerator::varName(type)
		end

		return choice
	end
end

class ScopeEntry
	def initialize(type, datatype, id, availableIn = nil, argTypes = nil)
		@type = type
		@datatype = datatype
		@id = id
		@availIn = availableIn
		@args = argTypes
	end

	def hasDataType(dtype)
		@datatype == dtype
	end

	def dataType
		@datatype
	end

	def id
		@id
	end

	def structureType
		@type
	end

	def availIn
		@availIn
	end

	def args
		@args
	end

	def to_str
		if(@type == :field)
			"this.#{@id}"
		else
			@id
		end
	end
end

class NameGenerator
	@@intNames = [
		[["i", "j", "k", "l", "m", "n", "res", "value", "arg"]],
		[["stack", "system", "process", "event", "queue", "list"], ["count", "counter", "amount", "depth"]]
	]
	
	@@booleanNames = [
		[["is", "can", "will"], ["load", "save", "read", "write", "exec"]],
		[["config", "system", "send", "read", "write", "exec", "restore", "ready", "pause", "state", "process", "storage"], ["toggle", "flag", "enabled", "override"]],
		[["is", "has"], ["loaded", "saveed", "done", "ready"]]
	]

	@@objNames = [
		[["data", "client", "server", "packet", "io"], ["object", "representation", "struct", "unit", "node"]],
		[["packet", "person", "message", "tree", "node"]]
	]

	@@futNames = [
		[["apply", "sync", "flush", "reset"], ["changes", "updates", "reload", "state", "call", "request", "flag"]],
		[["result", "res", "return", "resolve"], ["data", "state", "info"]],
		[["x", "y", "z", "a", "b", "q", "p"]]
	]

	@@genericNames = @@intNames
	
	def self.varName(type)
		if type.isBool
			return self.pickFrom(@@booleanNames)
		elsif type.isInt
			return self.pickFrom(@@intNames)
		elsif type.isObject
			return self.pickFrom(@@objNames)
		elsif type.isFut
			return self.pickFrom(@@futNames)
		else
			return self.pickFrom(@@genericNames)
		end
	end

	def self.pickFrom(nameArray)
		generated = nameArray.sample.map.with_index{ |field, i| i > 0 ? field.sample.capitalize : field.sample }
		return generated.join('')
	end
end
