package hal.jrex.typed;
import hal.jrex.Java;
import hal.jrex.typed.Errors;
import hal.jrex.typed.JavaTyped;
import haxe.Log;
import haxe.PosInfos;

using Lambda;
/**
 * ...
 * @author waneck
 */

class TyperContext
{
	public static var ids:Int = 0;
	
	public var typed:StringMap<TDefinition>;
	public var typersLeft:Array<Typer>;
	
	public var tbyte:TTypeT;
	public var tshort:TTypeT;
	public var tchar:TTypeT;
	public var tint:TTypeT;
	public var tsingle:TTypeT;
	public var tfloat:TTypeT;
	public var tlong:TTypeT;
	public var tbool:TTypeT;
	public var tvoid:TTypeT;
	
	public var tstring:TTypeT;
	public var tobject:TTypeT;
	public var tenum:TTypeT;
	
	public function new()
	{
		this.typed = new StringMap();
		tbyte = TBasic(TByte); tshort = TBasic(TShort); tchar = TBasic(TChar); tsingle = TBasic(TSingle); tfloat = TBasic(TFloat);
		tlong = TBasic(TLong); tbool = TBasic(TBool); tvoid = TBasic(TVoid);
		
		///here
		tstring = null; //FIXME
		tobject = null; //FIXME
		tenum = null; //FIXME
	}
	
	public function allocVar(name:String, t:TType):Var
	{
		return {
			id : ids++,
			name : name,
			type : t
		};
	}
	
	public function allocTypeParam(name:String, extend:Array<TTypeT>)
	{
		return {
			id : ids++,
			name : name,
			extend : extend
		};
	}
	
	public function runPass2():Void
	{
		for (t in typersLeft)
		{
			untyped t.runPass2();
		}
		
		typersLeft = [];
	}
	
	public function tarray(t:TTypeT):TTypeT
	{
		return TTypeT.TArray(t);
	}
	
	public function tclass(t:TTypeT):TTypeT
	{
		///here
		return null; //TODO
	}
}

class Typer 
{
	static var tbasic = Type.enumIndex(TBasic(null));
	static var tenum = Type.enumIndex(TEnum(null));
	static var tinst = Type.enumIndex(TInst(null, null));
	static var tarray = Type.enumIndex(TTypeT.TArray(null));
	static var ttypeparam = Type.enumIndex(TTypeParam(null));
	static var tunk = Type.enumIndex(TUnknown(null));
	static var tlazy = Type.enumIndex(TLazy(null));
	
	private var ctx:TyperContext;
	private var imported:StringMap<TDefinition>;
	private var imports:Array< Array<String> >;
	private var contextVars:Array<StringMap<Var>>;
	private var topLevel:TDefinition;
	private var children:Array<TDefinition>;
	private var tparams:StringMap<Array<TypeParameter>>;
	
	private var current:Null<TDefinition>;
	
	public function new(ctx)
	{
		this.ctx = ctx;
		this.imported = new StringMap();
		this.contextVars = [];
		this.imports = [];
		this.children = [];
		this.tparams = new StringMap();
		
		ctx.typersLeft.push(this);
	}
	
	public dynamic function onTypeNotFound(typePath:Array<String>):Void
	{
		//throw errors if wanted.
		//by default, type will be typed as Unknown and typing will continue normally
	}
	
	public dynamic function lookup(path:String):Null<Program>
	{
		return throw "not implemented";
	}
	
	public dynamic function error(obj:Dynamic, pos:Pos):Dynamic
	{
		throw obj;
		return null;
	}
	
	public dynamic function warning(obj:Dynamic, pos:Pos, ?infos:PosInfos):Void
	{
		Log.trace(spos(pos) + ": WARNING " + obj, infos );
	}
	
	private function lookupVar(name:String):Null<Var>
	{
		var len = contextVars.length;
		for (i in 0...len)
		{
			var h = contextVars[len - i - 1];
			var ret = h.get(name);
			
			if (ret != null)
				return ret;
		}
		
		return null;
	}
	
	private function pushBlock()
	{
		contextVars.push(new StringMap());
	}
	
	private function popBlock()
	{
		contextVars.pop();
	}
	
	private function unifies(from:TType, to:TType, ?types:Array<TypeParameter>, ?inferredT:Array<TTypeT>):Bool
	{
		//if (from.final && !to.final) return false;
		return unifiesT(from.type, to.type, types, inferredT);
	}
	
	private function paramIndex(types:Array<TypeParameter>, t:TypeParameter):Int
	{
		for (i in 0...types.length)
		{
			if (types[i] == t)
				return i;
		}
		
		return -1;
	}
	
	private function getTypeParameter(from:TTypeT)
	{
		return switch(from)
		{
			case TTypeParam(t): t;
			default: throw "assert";
		}
	}
	
	private function getLazy(t:TTypeT): { ref : TTypeT }
	{
		return switch(t)
		{
		case TLazy(r):r;
		default: null;
		}
	}
	
	private function unifiesT(from:TTypeT, to:TTypeT, ?types:Array<TypeParameter>, ?inferredT:Array<TTypeT>):Bool
	{
		var ifrom = Type.enumIndex(from);
		var ito = Type.enumIndex(to);
		
		while (ifrom == tlazy)
		{
			var ref = getLazy(from);
			
			from = ref.ref;
			if (from == null)
			{
				ref.ref = to;
				return true;
			}
			
			ifrom = Type.enumIndex(from);
		}
		
		while (ito == tlazy)
		{
			var ref = getLazy(to);
			
			to = ref.ref;
			if (to == null)
			{
				ref.ref = from;
				return true;
			}
			
			ito = Type.enumIndex(to);
		}
		
		if (ifrom != ito)
		{
			//it could be:
			//a box operation, an unbox operation
			//a type parameter 
			//a cast from enum -> java.lang.Enum / Object
			
			if (ifrom == tbasic && (ito == tinst || ito == tunk)) { //box operation
				var pathTo = getPath(to);
				return pathTo == "java.lang.Object" || pathTo == "java.lang." + getBasicName(getBasic(from)) || pathTo == getBasicName(getBasic(from));
			} else if (ito == tbasic && (ifrom == tinst || ito == tunk)) { //unbox operation
				var pathFrom = getPath(from);
				return pathFrom == "java.lang." + getBasicName(getBasic(to)) || pathFrom == getBasicName(getBasic(to)); //java doesn't allow direct casting from Object to basic type
			} else if (ito == ttypeparam) { //type parameter
				//if it's a type parameter, let's see if we are in a type parameter context
				if (types == null)
				{
					//if not, TODO: add support for extends
					//by now, let's just return false and hope for the best
					return false;
				}
				
				var tparam = getTypeParameter(to);
				var idx = paramIndex(types, tparam);
				if (idx == -1)
				{
					//same as above; TODO: add support for extends
					return false;
				}
				
				var inferred = inferredT[idx];
				if (inferred == null) // first inferred
				{
					//we will infer this type parameter as the from type
					inferredT[idx] = from;
					return true;
				} else {
					//if it's already inferred, let's see if it unifies
					return unifiesT(from, inferred);
				}
			} else if (ito == tinst && getPath(to) == "java.lang.Object") { //generic box operation
				return true; //always possible
			} else if (ito == tinst && ifrom == tenum) {
				return getPath(to) == "java.lang.Enum";
			} else {
				trace (from + " -> " + to);
				return false;
			}
		}
		
		switch(to)
		{
		case TBasic(t):
			switch(t)
			{
			case TLong, TInt, TChar, TShort, TByte:
				return Type.enumIndex(t) <= Type.enumIndex(getBasic(from));
			case TFloat:
				var fb = getBasic(from);
				return fb != TLong && fb != TBool && fb != TVoid;
			default:
				return false;
			}
		case TEnum(e):
			return Type.enumEq(to, from);
		case TInst(cto, pto):
			if (pto != null && pto.length == 0)
				pto = null;
			while (from != null)
			{
				switch(from)
				{
				case TInst(cfrom, pfrom):
					if (cto == cfrom)
					{
						return unifiesTParam(pfrom, pto, types, inferredT);
					} else {
						from = cfrom.extend;
					}
				default: throw "assert";
				}
			}
		default:
		}
		
		return false;
	}
	
	private function unifiesTParam(from:Null<Array<TParam>>, to:Null<Array<TParam>>, ?types:Array<TypeParameter>, ?inferredT:Array<TTypeT>):Bool
	{
		if (from != null && from.length == 0)
			from = null;
		if (to != null && to.length == 0)
			to = null;
		if (from == null)
			return true;
		
		if ( (from == null) != (to == null) )
			return true; //contrary to what would be natural, not using type parameters is valid and doesn't need any cast
		
		if (from.length != to.length)
			return false; //now this should be an error
			
		var len = from.length;
		for (i in 0...len)
		{
			var pf = from[i];
			var pt = to[i];
			
			switch(pt)
			{
			case TWildcard(_, _): continue;
			case T(tf):
				switch(pf) 
				{
				case T(tt):
					if (unifiesT(tf, tt, types, inferredT))
						continue;
					else
						return false;
				case TWildcard(_, _): return false; //FIXME: I may just be guessing here, but I think you'll need a cast for that
				}
			}
		}
		
		return true;
	}
	
	private function applyParams2(types:Array<TypeParameter>, params:JavaTyped.TParams, t:TTypeT):TTypeT
	{
		if (types == null || types.length == 0)
			return t;
		
		var p = params.map(function(p)
			return switch(p)
			{
			case T(t):t;
			case TWildcard(ext, sup):
				if (ext != null)
					ext;
				else
					ctx.tobject;
			}
		).array();
		
		return applyParams(types, p, t);
	}
	
	private function tparamsToType(params:hal.jrex.typed.JavaTyped.TParams):Array<TTypeT>
	{
		if (params == null || params.length == 0)
			return null;
		
		return params.map(function(p)
			return switch(p)
			{
			case T(t):t;
			case TWildcard(ext, sup):
				if (ext != null)
					ext;
				else
					ctx.tobject;
			}
		).array();
	}
	
	private function applyParams(types:Array<TypeParameter>, params:Array<TTypeT>, t:TTypeT):TTypeT
	{
		if (types == null || types.length == 0)
			return t;
		
		return switch(follow(t))
		{
		case TTypeParam(p):
			var idx = types.indexOf(p);
			if (idx == -1)
				t;
			else
				params[idx];
		case TInst(c, p):
			TInst(c, p.map(function(p) return switch(p) {
				case T(t): T(applyParams(types,params,t));
				case TWildcard(_, _):p;
			}).array());
		case TArray(t):
			TTypeT.TArray(applyParams(types, params, t));
		default: t;
		};
	}
	
	//gets path of either a TUnknown, a TInst or a TEnum
	private function getPath(t:TTypeT):String
	{
		return switch(t)
		{
		case TInst(cl, _): spath(cl.pack, cl.name);
		case TEnum(e): spath(e.pack, e.name);
		case TUnknown(t):
			switch(t)
			{
			case TPath(p, _): p.join(".");
			default: null;
			}
		default: null;
		}
	}
	
	private function getBasic(t:TTypeT):BasicType
	{
		return switch(t)
		{
		case TBasic(b): b;
		default: throw "assert";
		}
	}
	
	private function getBasicName(b:BasicType):String
	{
		return switch(b)
		{
		case TByte: "Byte";
		case TShort: "Short";
		case TChar: "Character";
		case TInt: "Integer";
		case TSingle: "Float";
		case TFloat: "Double";
		case TLong: "Long";
		case TBool: "Boolean";
		case TVoid: "Void";
		}
	}
	
	///////////////////////////////
	// Typer 1st pass
	///////////////////////////////
	
	private function fromFullPath( path : String ) : Null<TDefinition>
	{
		var typed = ctx.typed.get(path);
		if (typed != null)
			return typed;
		
		var parsed = lookup(path);
		if (parsed != null)
			return new Typer(ctx).processFirstPass(parsed);
		
		return null;
	}
	
	private function processFirstPass(prog:Program):TDefinition
	{
		if (topLevel != null) throw "Typer must be empty";
		
		this.imports = prog.imports.copy();
		this.imports.push(["java", "lang", "*"]);
		
		var p = spath(prog.pack, prog.name);
		
		var t = ctx.typed.get(p);
		if (t != null)
			return t;
		
		switch(prog.def)
		{
		case EDef(e):
			return TEDef(processEnum(prog, e));
		case CDef(c):
			return TCDef(processClass(prog, c));
		}
	}
	
	private function processChild(prog:Program, parentName:String, def:Definition):TDefinition
	{
		var newPack = prog.pack.copy();
		var name = switch(def)
			{
			case EDef(e): e.name;
			case CDef(c): c.name;
			};
		
		newPack.push(parentName);
		var newProg = {
			header : [],
			pack : newPack,
			imports : prog.imports,
			name : name,
			def : def,
		};
		
		switch(def)
		{
		case EDef(e):
			return TEDef(processEnum(newProg, e));
		case CDef(c):
			return TCDef(processClass(newProg, c));
		}
	}
	
	private function processClass(prog:Program, c:ClassDef):TClassDef
	{
		var isInterface = false;
		for (kw in c.kwds)
		{
			switch(kw)
			{
			case "interface":
				isInterface = true;
			}
		}
		
		var implement = [], types = [];
		//to avoid infinite recursion
		var ret = {
			pack : prog.pack,
			meta : c.meta,
			kwds : c.kwds,
			name : c.name,
			implement : implement,
			
			ctors : [],
			
			orderedStatics : [],
			orderedFields : [],
			statics : new StringMap(),
			fields : new StringMap(),
			staticInit : null,
			instInit : null,
			pos : c.pos,
			
			isInterface : isInterface,
			types : types,
			extend : null
		};
		untyped ret._rel = c;
		
		var par = TCDef(ret);
		//avoiding infinite recursion
		ctx.typed.set( spath(prog.pack, c.name), par );
		
		this.imported.set(c.name, par);
		if (this.topLevel == null)
			topLevel = par;
		else
			children.push(par);
		
		for (def in c.childDefs)
		{
			processChild(prog, c.name, def);
		}
		
		for (t in c.types)
		{
			var t = tp( t );
			types.push( t );
		}
		
		pushTypes(types);
		
		if (c.extend != null)
		{
			ret.extend = t( c.extend ).type;
		} else if (spath(ret.pack, ret.name) != "java.lang.Object") {
			ret.extend = switch(fromFullPath("java.lang.Object"))
			{
				case TCDef(c): TInst(c, null);
				default: throw "assert";
			};
		}
		
		for (i in c.implement)
		{
			implement.push( t(i) );
		}
		
		for (c in c.fields)
		{
			processClassField1(par, c, cast ret);
		}
		
		popTypes(types);
		
		return ret;
	}
	
	private function processEnum(prog:Program, en:EnumDef):TEnumDef
	{
		var implement = [];
		//to avoid infinite recursion
		var ret = {
			pack : prog.pack,
			meta : en.meta,
			kwds : en.kwds,
			name : en.name,
			implement : implement,
			
			ctors : [],
			
			orderedStatics : [],
			orderedFields : [],
			statics : new StringMap(),
			fields : new StringMap(),
			staticInit : null,
			instInit : null,
			pos : en.pos,
			
			orderedConstrs : [],
			constrs : new StringMap(),
		};
		untyped ret._rel = en;
		
		var par = TEDef(ret);
		ctx.typed.set( spath(prog.pack, en.name), par );
		
		this.imported.set(en.name, par);
		if (this.topLevel == null)
			topLevel = par;
		else
			children.push(par);
		
		for (def in en.childDefs)
		{
			processChild(prog, en.name, def);
		}
		
		for (i in en.implement)
		{
			implement.push( t(i) );
		}
		
		for (c in en.constrs)
		{
			processEnumConstructor1(c, ret);
		}
		
		for (c in en.fields)
		{
			processClassField1(par, c, cast ret);
		}
		
		return ret;
	}
	
	private function getComments( exprs:Array<Expr> ) : String
	{
		var ret = new StringBuf();
		for (e in exprs)
		{
			switch(e.expr)
			{
			case JComment(s, _):
				ret.add(s);
				ret.add("\n");
			default: throw "assert";
			}
		}
		
		return ret.toString();
	}
	
	private function processClassField1( par : TDefinition, cf : ClassField, baseDef : TBaseDef ) : Null<String>
	{
		var isPrivate = false;
		var isOverride = false;
		var isStatic = false;
		var type = null;
		for (kw in cf.kwds)
		{
			switch(kw)
			{
			case "private", "protected": 
				isPrivate = true;
			case "static":
				isStatic = true;
			}
		}
		
		for (m in cf.meta)
		{
			if (m.name == "Override")
				isOverride = true;
		}
		
		var argsCount = -1;
		var args = null;
		
		var types = null;
		if (cf.types != null)
		{
			types = [];
			for (t in cf.types)
			{
				types.push( tp( t ) );
			}
		}
		
		pushTypes(types);
		
		switch(cf.kind)
		{
		case FComment:
			return getComments(cf.comments);
		case FFun(f):
			
			args = [t(f.ret)];
			for (arg in f.args)
			{
				args.push(t(arg.t));
			}
			
			if (f.varArgs != null) 
			{
				argsCount = -1;
				args.push(t(f.varArgs.t));
			} else {
				argsCount = f.args.length;
			}
			
		case FVar(t, _):
			type = this.t(t);
		}
		
		popTypes(types);
		
		var ret = {
			isMember : false,
			isPrivate : isPrivate,
			name : cf.name,
			meta : cf.meta,
			comments : getComments( cf.comments ),
			kwds : cf.kwds,
			kind : null,
			type : type,
			pos : cf.pos,
			def : par,
			docs : getComments(cf.comments),
			isOverride : isOverride,
			types : types,
			
			//for fast overload resolution
			argsCount : argsCount, //-1 if variable or var-args
			args : args, //null if variable
		};
		
		untyped ret._rel = cf;
		
		if (isStatic)
		{
			baseDef.orderedStatics.push(ret);
			var s = baseDef.statics.get(cf.name);
			if (s == null)
			{
				s = [];
				baseDef.statics.set(cf.name, s);
			}
			
			s.push(ret);
		} else if (cf.name == baseDef.name) { //constructor
			ret.name = "new";
			baseDef.ctors.push(ret);
		} else {
			baseDef.orderedFields.push(ret);
			var s = baseDef.fields.get(cf.name);
			if (s == null)
			{
				s = [];
				baseDef.fields.set(cf.name, s);
			}
			
			s.push(ret);
		}
		
		return null;
	}
	
	private function processEnumConstructor1( e : EnumField, def : TEnumDef ) : Void
	{
		var ret = {
			name : e.name,
			args : null,
			meta : e.meta,
			docs : null,
			pos : e.pos
		};
		
		untyped ret._rel = e;
		
		def.constrs.set(e.name, ret);
		def.orderedConstrs.push(ret);
	}
	
	///////////////////////////////
	// Typer 2nd pass
	///////////////////////////////
	
	private function runPass2():Void
	{
		//first process top level definition
		typeExpressions(topLevel);
	}
	
	private function pushParams(def:TDefinition)
	{
		switch(def)
		{
		case TCDef(c):
			pushTypes(c.types);
		default:
		}
	}
	
	private function popParams(def:TDefinition)
	{
		switch(def)
		{
		case TCDef(c):
			popTypes(c.types);
		default:
		}
	}
	
	private function pushTypes(t:Null<Array<TypeParameter>>)
	{
		if (t != null) for (t in t) {
			var a = this.tparams.get(t.name);
			if (a == null)
			{
				a = [];
				tparams.set(t.name, a);
			}
			
			a.push(t);
		}
	}
	
	private function popTypes(t:Null<Array<TypeParameter>>)
	{
		if (t != null) for (t in t) {
			var a = this.tparams.get(t.name);
			if (a != null)
			{
				a.remove(t);
			}
		}
	}
	
	private function lookupTParam(name:String):Null<TypeParameter>
	{
		var a = tparams.get(name);
		if (a != null)
		{
			return a[a.length - 1];
		} else {
			return null;
		}
	}
	
	private function typeExpressions(def:TDefinition):Void
	{
		this.current = def;
		
		//first let's set the type parameters inside our context
		pushParams(def);
		
		//now go through each field and start transforming expressions
		
		
		popParams(def);
	}
	
	private function mk(e:TExprExpr, t:TType, p:Pos)
	{
		return { expr : e, type : t, pos : p };
	}
	
	private function mk2(e:TExprExpr, t:TTypeT, p:Pos)
	{
		return { expr : e, type : mkt(t), pos : p };
	}
	
	private function mkt(t:TTypeT):TType
	{
		return { type : t, final : false, meta : null };
	}
	
	private function getPathExpr(e:Expr, arr:Array<String>):Bool
	{
		switch(e.expr)
		{
		case JIdent(v):
			arr.push(v);
			return true;
		case JField(e, f):
			if (getPathExpr(e, arr))
			{
				arr.push(f);
				return true;
			} else {
				return false;
			}
		default:
			return false;
		}
	}
	
	private function defToT(def:TDefinition, ?dynParams=true):TTypeT
	{
		return switch(def)
		{
		case TCDef(c):
			var p = null;
			if (!dynParams && c.types != null && c.types.length > 0)
			{
				p = c.types.map(function(c) return T(TTypeParam(c))).array();
			}
			TInst(c, p);
		case TEDef(e):
			TEnum(e);
		case TNotFound:
			TUnknown(null);
		}
	}
	
	private function follow(t:TTypeT):TTypeT
	{
		return switch(t)
		{
		case TLazy(ref):
			if (ref.ref == null) return t;
			follow(ref.ref);
		default: t;
		}
	}
	
	private function solveOverload(params:Array<TExpr>, fields:Array<TClassField>, ?types:Array<TypeParameter>, ?tparams:Array<TTypeT>):Null<{ cf:TClassField, types:Null<Array<TTypeT>> }>
	{
		var len = params.length;
		
		for (f in fields)
		{
			if (f.argsCount == -1 || f.argsCount == len)
			{
				var compatible = true;
				var ts = (f.types == null) ? null : [];
				for (i in 0...len)
				{
					var p = params[i].type;
					if (types != null && types.length != 0)
						p.type = applyParams(types, tparams, p.type);
					
					var op = f.args[i];
					if (op == null)
						if (f.argsCount == -1) 
							op = f.args[f.args.length - 1];
						else
							throw "assert";
					
					if (!unifies(p, op, f.types, ts))
					{
						compatible = false;
						break;
					}
				}
				
				if (compatible)
					return { cf:f, types:ts };
			}
		}
		
		return null;
	}
	
	private function mkStaticFieldAccess(def:TDefinition, callParams:Array<TExpr>, field:String, fields:Array<TClassField>, pos:Pos)
	{
		return if (callParams != null)
		{
			var cf = solveOverload(callParams, fields);
			if (cf == null) throw NoOverloadFound(defToT(def), field, true, callParams.map(function(p) return p.type.type), pos);
			
			var ret = applyParams(cf.cf.types, cf.types, cf.cf.args[0].type);
			mk2(TStaticCall(cf.cf, cf.types, callParams), ret, pos);
		} else {
			if (fields.length > 1 || fields[0].argsCount != -1) throw AccessFieldWithoutCalling(defToT(def), field, true, pos);
			mk(TStaticField(fields[0]), fields[0].type, pos);
		}
	}
	
	private function mkFieldAccess(e1:TExpr, callParams:Array<TExpr>, field:String, fields:Array<TClassField>, pos:Pos, ?types:Array<TypeParameter>, ?params:Array<TTypeT>)
	{
		return if (callParams != null)
		{
			var cf = solveOverload(callParams, fields, types, params);
			if (cf == null) throw NoOverloadFound(e1.type.type, field, false, callParams.map(function(p) return p.type.type), pos);
			
			var ret = applyParams(cf.cf.types, cf.types, cf.cf.args[0].type);
			mk2(TMemberCall(e1, cf.cf, cf.types, callParams), ret, pos);
		} else {
			if (fields.length > 1 || fields[0].argsCount != -1) throw AccessFieldWithoutCalling(e1.type.type, field, false, pos);
			mk(TClassField(e1, fields[0]), fields[0].type, pos);
		}
	}
	
	private function getDef(t:TTypeT):TDefinition
	{
		return switch(follow(t))
		{
		case TInst(c, _): TCDef(c);
		case TEnum(e): TEDef(e);
		case TBasic(_): throw "assert";
		default: TNotFound;
		}
	}
	
	private function mkMaybeFieldAccess(e1:TExpr, t:TTypeT, field:String, pos:Pos, ?callParams:Array<TExpr>):TExpr
	{
		switch(follow(t))
		{
		case TBasic( _ ): throw ErrorMessage("Basic types do not have fields!", pos);
		case TEnum( en ):
			var fields = en.fields.get(field);
			if (fields == null)
			{
				return mkMaybeFieldAccess(e1, ctx.tenum, field, pos, callParams);
			} else {
				return mkFieldAccess(e1, callParams, field, fields, pos);
			}
		case TInst( cl, params ):
			var fields = cl.fields.get(field);
			if (fields != null)
			{
				return mkFieldAccess(e1, callParams, field, fields, pos, cl.types, tparamsToType(params));
			} else {
				var super_t = cl.extend;
				if (super_t != null)
				{
					//TODO: needs to applyParams here
					return mkMaybeFieldAccess(e1, applyParams(cl.types, tparamsToType(params), super_t), field, pos, callParams);
				} else {
					throw UnboundField(t, field, false, pos);
				}
			}
		case TArray(t):
			if (field == "length" && callParams == null)
			{
				return mk2(TField(e1, field), ctx.tint, pos);
			} else {
				throw UnboundField(t, field, false, pos);
			}
		case TTypeParam(tp):
			//TODO use extends, super to be able to know which expr
			return mk2(TField(e1, field), TLazy( { ref:null } ), pos);
		case TUnknown(_), TLazy(_):
			return mk2(TField(e1, field), TLazy( { ref:null } ), pos);
		}
	}
	
	private function mkMaybeStaticField(e1:TExpr, field:String, pos:Pos, ?callParams:Array<TExpr>):TExpr
	{
		return switch(e1.expr)
		{
		case TParent(p):
			mkMaybeStaticField(p, field, pos, callParams);
		case TTypeExpr(def):
			switch(def)
			{
			case TCDef(c):
				var s = c.statics.get(field);
				if (s == null) throw UnboundField(e1.type.type, field, true, pos);
				mkStaticFieldAccess(def, callParams, field, s, pos);
			case TEDef(e):
				var c = e.constrs.get(field);
				if (c != null) {
					mk2(TEnumField(c), TEnum(e), pos);
				} else {
					var fields = e.statics.get(field);
					if (fields == null) throw UnboundField(e1.type.type, field, true, pos);
					mkStaticFieldAccess(def, callParams, field, fields, pos);
				}
			case TNotFound:
				if (callParams != null)
				{
					mk2(TField(e1, field), TUnknown(null), pos);
				} else {
					mk2(TCall(e1, field, callParams), TUnknown(null), pos);
				}
			}
		default: //call non-static field handler
			null;
		}
	}
	
	private function ttype(expr:Expr):TExpr
	{
		if (expr == null) return null;
		return switch(expr.expr)
		{
		case JConst( c ):
			switch(c)
			{
			case CLong( v ): mk2(TConst(TCLong(v)), TBasic(TLong), expr.pos);
			case CInt( v ): mk2(TConst(TCInt(v)), TBasic(TInt), expr.pos);
			case CFloat( f ): mk2(TConst(TCFloat(f)), TBasic(TFloat), expr.pos);
			case CSingle( f ): mk2(TConst(TCSingle(f)), TBasic(TSingle), expr.pos);
			case CString( s ): mk2(TConst(TCString(s)), ctx.tstring, expr.pos);
			}
			
		case JIdent( v ):
			switch(v)
			{
			case "null": mk2(TConst(TCNull), TLazy({ ref:null }), expr.pos);
			}
			var def = imported.get(v);
			if (def != null)
			{
				return mk2(TTypeExpr(def), ctx.tclass(defToT(def)), expr.pos);
			}
			var vr = lookupVar(v);
			if (vr == null)
				throw NotFoundVar(v, expr.pos);
			
			mk(TLocal(vr), vr.type, expr.pos);
		case JVars( vars ):
			var ret = [];
			for (vdecl in vars)
			{
				var v = ctx.allocVar(vdecl.name, this.t(vdecl.t));
				ret.push( { v : v, val : ttype(vdecl.val) } );
			}
			
			mk2(TVars(ret), ctx.tvoid, expr.pos);
		case JCast( to, expr ):
			var to = t(to);
			mk( TCast(to, ttype(expr)), to, expr.pos );
		case JParent( e ):
			var e = ttype(e);
			mk( TParent(e), e.type, expr.pos );
		case JBlock( el ):
			mk2( TBlock(el.map(ttype).array()), ctx.tvoid, expr.pos );
		case JSynchronized ( lock, el ):
			mk2( TSynchronized( ttype(lock), el.map(ttype).array() ), ctx.tvoid, expr.pos );
		case JField( e, f ):
			var arr = [];
			if (getPathExpr(e, arr))
			{
				//see if it's a type
				var t = lookupPath(arr);
				if (t != null)
				{
					return mk2(TTypeExpr(t), ctx.tclass(defToT(t)), expr.pos);
				} else {
					arr.push(f);
					var t = lookupPath(arr);
					if (t != null)
					{
						return mk2(TTypeExpr(t), ctx.tclass(defToT(t)), expr.pos);
					}
				}
			}
			
			var et = ttype(e);
			switch(et.type.type)
			{
			case TInst(c, p):
				if (c.name == "Class" && c.pack[0] == "java" && c.pack[1] == "lang")
				{
					///here
					//mkMaybeStaticField
				}
			default:
			}
			
			null;
			/*
			JBinop( op : String, e1 : Expr, e2 : Expr );
			JUnop( op : String, prefix : Bool, e : Expr );
			JCall( e : Expr, tparams:TParams, params : Array<Expr> );
			JIf( cond : Expr, e1 : Expr, ?e2 : Expr );
			JTernary( cond : Expr, e1 : Expr, ?e2 : Expr );
			JWhile( cond : Expr, e : Expr, doWhile : Bool, ?label:String );
			JFor( inits : Array<Expr>, conds : Array<Expr>, incrs : Array<Expr>, e : Expr, ?label:String );
			JForEach( t : T, name : String, inExpr : Expr, block : Expr, ?label:String );
			JBreak( ?label : String );
			JContinue( ?label : String );
			JReturn( ?e : Expr );
			JArray( e : Expr, index : Expr );
			JArrayDecl( t : T, lens : Null<Array<Expr>>, e : Null<Array<Expr>> );
			JNewAnon( def : { fields : Array<ClassField>, staticInit : Null<Expr>, instInit : Null<Expr> } );
			JNew( t : T, params : Array<Expr> );
			JThrow( e : Expr );
			JTry( e : Expr, catches : Array<{ name : String, t : T, e: Expr } >, finally : Expr );
			JSwitch( e : Expr, cases : Array<{ val : Expr, el : Array<Expr> }>, def : Null<Array<Expr>> );
			JComment( s : String, isBlock: Bool );
			JAssert( e : Expr, ?ifFalse : Expr );
			JInnerDecl( def : Definition );
			JInstanceOf( e : Expr, t : T );*/
		default:
			null;
		}
	}
	
	///////////////////////////////
	// HELPERS
	///////////////////////////////
	
	private function lookupPath( path : Array<String> ) : TDefinition
	{
		if (path.length != 1) //special case: lookup first for full path if not single path
		{
			var rpath = path.join(".");
			var f = fromFullPath(rpath);
			if (f != null)
				return f;
		} else {
			var path = "java.lang." + path[0];
			var f = fromFullPath(path);
			if (f != null)
				return f;
		}
		
		var p = path[0];
		var def = this.imported.get(p);
		if (def != null)
			return def;
		
		//if not found, search through all imports that either finish with the path or finish with '*'
		for (i in imports)
		{
			var lst = i[i.length - 1];
			if (lst == '*' || lst == p)
			{
				//try the whole path
				var wholePath = i.copy();
				i.pop(); i.push(p);
				
				var f = fromFullPath(i.join("."));
				if (f != null)
				{
					//if found, lookup now for the full path.
					//since type can be an inner declaration
					i.pop();
					for (p in path) i.push(p);
					var f = fromFullPath(i.join("."));
					if (f == null)
					{
						trace("Inner type not found " + i.join("."));
						return TNotFound;
					}
					
					return f;
				}
			}
		}
		
		return TNotFound;
	}
	
	private function t( tp : T ) : TType
	{
		var tt = typet(tp.t);
		
		return {
			final : tp.final,
			meta : null,
			type : tt
		};
	}
	
	private function typet( t : TPath ) : TTypeT
	{
		return switch(t)
		{
		case TArray(of):
			TTypeT.TArray( this.typet(of) );
		case TPath(path, params):
			if (path.length == 1)
			{
				switch(path[0])
				{
				case "byte":
					return TBasic(TByte);
				case "short":
					return TBasic(TShort);
				case "int":
					return TBasic(TInt);
				case "long":
					return TBasic(TLong);
				case "char":
					return TBasic(TChar);
				case "float":
					return TBasic(TSingle);
				case "double":
					return TBasic(TFloat);
				case "boolean":
					return TBasic(TBool);
				case "void":
					return TBasic(TVoid);
				default:
					//see if it's type parameter
					var tp = lookupTParam(path[0]);
					if (tp != null)
						return TTypeParam(tp);
				}
			}
			
			var def = lookupPath(path);
			switch(def)
			{
			case TCDef(c):
				TInst(c, t_tps(params));
			case TEDef(e):
				TEnum(e);
			case TNotFound:
				onTypeNotFound(path);
				TUnknown(t);
			}
		};
	}
	
	private function t_tps( tps : Null<Array<TArg>> ) : JavaTyped.TParams
	{
		if (tps == null || tps.length == 0) return null;
		var ret = [];
		for (t in tps)
			ret.push(t_tp(t));
		return ret;
	}
	
	private function t_tp( tp : TArg ) : TParam
	{
		return switch(tp)
		{
		case AType(t):
			TParam.T(this.typet(t.t));
		case AWildcard:
			TParam.TWildcard();
		case AWildcardExtends(t):
			TParam.TWildcard(this.typet(t.t));
		case AWildcardSuper(t):
			TParam.TWildcard(null, this.typet(t.t));
		}
	}
	
	private function tp( g : GenericDecl ) : TypeParameter
	{
		var ext = [];
		if (g.extend != null) for (e in g.extend)
			ext.push( this.t(e).type );
		return ctx.allocTypeParam(g.name, ext);
	}
	
	private function spath(pack:Array<String>, name:String)
	{
		return pack.join(".") + (pack.length > 0 ? "." : "") + name;
	}
	
	private function spos(p:Pos)
	{
		return p.file + " : " + p.min + "-" + p.max;
	}
	
	
}