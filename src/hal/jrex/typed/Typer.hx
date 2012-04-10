package hal.jrex.typed;
import hal.jrex.Java;
import hal.jrex.typed.JavaTyped;
import haxe.Log;
import haxe.PosInfos;

/**
 * ...
 * @author waneck
 */

class TyperContext
{
	public static var ids:Int = 0;
	
	public var typed:Hash<TDefinition>;
	public var typersLeft:Array<Typer>;
	
	public function new()
	{
		this.typed = new Hash();
	}
	
	public function allocVar(name:String, t:TType):Var
	{
		return {
			id : ids++,
			name : name,
			t : t
		};
	}
	
	public function allocTypeParam(name:String, extend:Array<TType>)
	{
		return {
			id : ids++,
			name : name,
			extend : extend
		};
	}
}

class Typer 
{
	private var ctx:TyperContext;
	private var imported:Hash<TDefinition>;
	private var imports:Array< Array<String> >;
	private var contextVars:Array<Hash<Var>>;
	private var topLevel:TDefinition;
	private var children:Array<TDefinition>;
	private var tparams:Hash<TypeParameter>;
	
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
	
	private function unifiesT(from:TTypeT, to:TTypeT, ?types:Array<TypeParameter>, ?inferredT:Array<TTypeT>):Bool
	{
		var ifrom = Type.enumIndex(from);
		var ito = Type.enumIndex(to);
		
		if (ifrom != ito)
		{
			//it could be:
			//a box operation, an unbox operation
			//a type parameter 
			
			if (ifrom == 0 && (ito == 1 || ito == 5)) //box operation
			{
				var pathTo = getPath(to);
				return pathTo == "java.lang.Object" || pathTo == "java.lang." + getBasicName(getBasic(from));
			}
		}
		
		switch(to)
		{
		case TBasic(t):
			switch(t)
			{
			case TLong, TInt, TChar, TShort, TByte:
			
			default:
			}
		default:
		}
		
		return false;
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
		
		this.imports = prog.imports;
		
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
			types.push( tp( t ) );
		}
		
		ret.extend = t( c.extend );
		
		for (i in c.implement)
		{
			implement.push( t(i) );
		}
		
		for (c in c.fields)
		{
			processClassField1(par, c, cast ret);
		}
		
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
					var tp = tparams.get(path[0]);
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
			ext.push( this.t(e) );
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