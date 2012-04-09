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
	public var defs:Array<TDefinition>;
	
	public function new()
	{
		this.typed = new Hash();
	}
	
	public function allocVar(name:String, t:T):Var
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
	
	public function new(ctx)
	{
		this.ctx = ctx;
		this.imported = new Hash();
		this.contextVars = [];
		this.imports = [];
	}
	
	public dynamic function lookup(path:String):Null<Program>
	{
		throw "not implemented";
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
	
	private function processFirstPass(def:Program):TDefinition
	{
		var p = spath(def.pack, def.name);
		
		var t = ctx.typed.get(p);
		if (t != null)
			return t;
		
		switch(def.def)
		{
		case EDef(e):
			
		}
	}
	
	private function processEnum(def:Program, en:EnumDef):TEnumDef
	{
		var implement = [], orderedFields = [], orderedConstrs = [];
		//to avoid infinite recursion
		var ret = {
			pack : def.pack,
			meta : en.meta,
			kwds : en.kwds,
			name : en.name,
			implement : implement,
			
			orderedConstrs : orderedConstrs,
			constrs : new Hash(),
			
			orderedFields : orderedFields,
			staticInit : null,
			instInit : null,
			pos : en.pos
		};
		ctx.typed.set( spath(def.pack, en.name), ret );
		
		for (i in en.implement)
		{
			implement.push( t(i) );
		}
		
		for (c in en.constrs)
		{
			orderedConstrs.push( processEnumConstructor1(c) );
		}
		
		
		
	}
	
	private function processEnumConstructor1( e : EnumField ) : TEnumDef
	{
		var ret = {
			name : e.name,
			args : null,
			meta : e.meta,
			docs : null,
			pos : e.pos
		};
		
		untyped ret._rel = e;
		return ret;
	}
	
	private function t( t : T ) : TType
	{
		
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