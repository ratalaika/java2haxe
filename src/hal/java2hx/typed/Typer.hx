package hal.java2hx.typed;
import hal.java2hx.Java;
import hal.java2hx.typed.JavaTyped;
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
}

class Typer 
{
	private var ctx:TyperContext;
	private var imported:Hash<TDefinition>;
	private var imports:Array< Array<String> >;
	private var contextVars:Array<Hash<Var>>;
	private var topLevel:TDefinition;
	private var children:Array<TDefinition>;
	
	public function new(ctx)
	{
		this.ctx = ctx;
		this.imported = new Hash();
		this.contextVars = [];
		this.imports = [];
		this.children = [];
		
		ctx.typersLeft.push(this);
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
		return false;
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
	
	private function t( t : T ) : TType
	{
		return null;
	}
	
	private function tp( g : GenericDecl ) : TypeParameter
	{
		return null;
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