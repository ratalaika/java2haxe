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
	
	public var typed:Hash<TDefinition>;
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
	
	public function new()
	{
		this.typed = new Hash();
		tbyte = TBasic(TByte); tshort = TBasic(TShort); tchar = TBasic(TChar); tsingle = TBasic(TSingle); tfloat = TBasic(TFloat);
		tlong = TBasic(TLong); tbool = TBasic(TBool); tvoid = TBasic(TVoid);
		
		tstring = null; //FIXME
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
	private var imported:Hash<TDefinition>;
	private var imports:Array< Array<String> >;
	private var contextVars:Array<Hash<Var>>;
	private var topLevel:TDefinition;
	private var children:Array<TDefinition>;
	private var tparams:Hash<Array<TypeParameter>>;
	
	private var current:Null<TDefinition>;
	
	public function new(ctx)
	{
		this.ctx = ctx;
		this.imported = new Hash();
		this.contextVars = [];
		this.imports = [];
		this.children = [];
		this.tparams = new Hash();
		
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
		contextVars.push(new Hash());
	}
	
	private function popBlock()
	{
		contextVars.pop();
	}
	
	private function unifies(from:TType, to:TType):Bool
	{
		//if (from.final && !to.final) return false;
		return false;
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
		
		if (ifrom == tlazy)
		{
			
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
			statics : new Hash(),
			fields : new Hash(),
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
			statics : new Hash(),
			fields : new Hash(),
			staticInit : null,
			instInit : null,
			pos : en.pos,
			
			orderedConstrs : [],
			constrs : new Hash(),
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
			
		case FVar(_,_):
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
					
				}
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