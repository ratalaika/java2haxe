package hal.jrex.converter;
import hal.jrex.Java;
import haxe.ds.StringMap;
import haxe.io.Input;
import neko.vm.Module;
import sys.FileSystem;
import sys.io.File;
using Lambda;

/**
 * ...
 * @author waneck
 */

enum ImportedDef
{
	TypeParameter;
	Module(p:Program);
	Submodule(p:Program, innerClasses:Array<String>, def:Definition);
}

class Normalizer
{
	private var modules:StringMap<Program>;
	private var packs:StringMap<Array<Program>>;
	private var cur:Program;
	//private var types:StringMap<Definition>;

	private var definitionStack:Array<StringMap<ImportedDef>>;
	private var superType:Map<ClassDef, { d: Definition, p : Array<TArg> }>;

	public function new()
	{
		this.modules = new StringMap();
		this.packs = new StringMap();
		this.superType = new Map();
		//this.types = new StringMap();

		this.definitionStack = [new StringMap()];
	}
	
	/*
	function applyParams(types:Array<GenericDecl>, params:Array<TArg>, t:TPath):TPath
	{
		if (types.length == 0)
			return t;
		
		return switch(t)
		{
		case TArray(tp):
			TArray(applyParams(types, params, tp));
		case TPath([p], []):
			var i = 0;
			for (t in types)
			{
				if (t.name == p)
					return params
				i++;
			}
		}
	}
	*/

	public function addModule(p:Program):Void
	{
		var path = p.pack.concat([p.name]);
		var pack = p.pack.join(".");
		var g = packs.get(pack);
		if (g == null)
		{
			g = [];
			packs.set(pack, g);
		}

		g.push(p);
		modules.set(path.join("."), p);

		if (pack == "java.lang")
		{
			//special definition stack
			definitionStack[0].set(p.name, Module(p));
		}
	}

	public function allModules():Iterator<String>
	{
		return modules.keys();
	}

	public function getNormalizedModule(path:String):Null<Program>
	{
		var m = modules.get(path);
		if (m == null)
			return null;
		
		if (untyped m.norm == true)
		{
			return m;
		}
		
		untyped m.norm = true;
			
		//add all modules in same package level to the definition stack
		var ds = new StringMap();
		definitionStack.push(ds);
		for (md in packs.get(m.pack.join(".")))
		{
			ds.set(md.name, Module(md));
		}

		{
			ds = new StringMap();
			definitionStack.push(ds);
			//add imports
			addImports(m, ds);

			{
				ds = new StringMap();
				definitionStack.push(ds);
				//add all child modules to the definition stack
				for (d in m.defs)
				{
					if (getDef(d).name != m.name)
						ds.set(getDef(d).name, Submodule(m, [], d));
					addChildDefs(m, ds, d, []);
				}

				//MAIN LOOP
				{
					var old = this.cur;
					this.cur = m;
					for (d in m.defs)
						normalize(d);
					this.cur = old;
				}

				//pop child modules
				definitionStack.pop();
			}

			//pop imports
			definitionStack.pop();
		}

		//pop package level modules
		definitionStack.pop();

		return m;
	}

	function normalizeField(f:ClassField)
	{
		if (f.kwds.has("private") || !(f.kwds.has('public') || f.kwds.has('protected')))
			return;
		if (f.types != null && f.types.length > 0)
		{
			var ds = new StringMap();
			definitionStack.push(ds);
			for (t in f.types)
				ds.set(t.name, TypeParameter);
		}
		switch(f.kind)
		{
		case FVar(t, _): normalizeType(t);
		case FFun(f):
			for (arg in f.args) normalizeType(arg.t);
			normalizeType(f.ret);
			if (f.varArgs != null)
				normalizeType(f.varArgs.t);
		}

		if (f.types != null && f.types.length > 0)
		{
			definitionStack.pop();
		}
	}
	
	function fieldSig(f:ClassField)
	{
		return switch(f.kind)
		{
		case FFun(fn):
			tToString(fn.ret.t) + " " + f.name + "(" + fn.args.map(function(a) return tToString(a.t.t)) + ")";
		default: null;
		}
	}
	
	function tToString(t:TPath)
	{
		return switch(t)
		{
		case TArray(t): tToString(t) + "[";
		case TPath(p, _): p.join(".");
		}
	}

	function normalize(d:Definition)
	{
		switch(d)
		{
		case CDef(c):
			if (c.kwds.has("private") || !(c.kwds.has('public') || c.kwds.has('protected')))
				return;
			//add another definitionStack for the type parameters
			var ds = new StringMap();
			definitionStack.push(ds);
			for (tp in c.types)
			{
				ds.set(tp.name, TypeParameter);
			}

			{
				//go through all fields' definition and normalizeType()
				for (f in c.fields)
				{
					normalizeField(f);
				}
				
				//check overrides
				if (!c.isInterface) 
				{
					var funs = c.fields
						.filter(function(f) return switch(f.kind) { case FFun(_): true; default: false; } );
					var funSig = funs.map(fieldSig);
					
					var d = d;
					while (d != null)
					{
						switch(d)
						{
						case CDef(c):
							var ext = superType.get(c);
							if (ext == null)
							{
								if (c.extend[0] != null) switch(c.extend[0].t)
								{
								case TPath(["java", "lang", "Object"], []):
								case TPath(p, params):
									var d2 = lookupPath(p, params);
									if (d2 != null)
									{
										//make sure it's normalized
										var m = getNormalizedModule( d2.m.pack.join(".") + "." + d2.m.name );
										if (m == null) throw "assert";
										
										ext = { d : d2.d, p : params };
										superType.set(c, ext);
									}
								default: throw "assert";
								}
							}
							
							if (ext != null)
							{
								switch(ext.d)
								{
								case CDef(c):
									//for each of our functions
									var i = 0;
									for (f in funs)
									{
										var sig = funSig[i++];
										//look for fields of the exact same signature:
										for (field in c.fields)
										{
											if (sig == fieldSig(field))
											{
												if (f.meta == null)
													f.meta = [];
												f.meta.push( { name:"Override", args:null, pos: f.pos } );
											}
										}
									}
									
									d = ext.d;
								default: throw "assert";
								}
								
							} else {
								d = null;
							}
							
							
						default: throw "assert";
						}
					}
				}
				
				for (i in c.implement)
					normalizeType(i);
				for (e in c.extend)
					normalizeType(e);
			}

			definitionStack.pop();
			
		case EDef(_): //no need of any normalization for haxe
		}

	}

	function normalizeType(t:T)
	{
		if (untyped t.norm == true)
			return;

		t.t = nt(t.t);
		untyped t.norm = true;
	}
	
	function lookupPath(p:Array<String>, params:Array<TArg>):Null<{ m:Program, d:Definition, ic : Array<String> }>
	{
		//look for exact match
		var m = modules.get(p.join("."));
		if (m != null)
		{
			for (d in m.defs)
			{
				if (getDef(d).name == p[p.length - 1])
					return { m : m, d: d, ic : null };
			}
			throw "assert " + p + ", " + params + " , \n" + m;
		} else {
			//look in stack for matches
			for (i in 1...(definitionStack.length+1))
			{
				var def = definitionStack[definitionStack.length - i];
				var imp = def.get(p[0]);
				if (imp != null)
				{
					switch(imp)
					{
					case TypeParameter:
						if (p.length > 1 || params.length != 0) throw "assert";
						return null; //no change
					case Module(m):
						var innerStack = p.slice(1);
						var d = getDefinitionFromModule(m, innerStack);
						
						if (d == null)
						{
							trace("WARNING: Module " + m.pack.join(".") + "." + m.name + " found for type " + p.join(".") + ", but no matching submodule was found");
							return null;
						}

						return { m : m, d: d, ic : innerStack };
					case Submodule(m, innerClasses, def):
						if (p.length > 1)
						{
							var innerStack = innerClasses.concat(p.slice(1));
							var d = getDefinitionFromModule(m, innerStack);
							if (d == null)
							{
								trace("WARNING: Module " + m.pack.join(".") + "." + m.name + " found for type " + p.join(".") + ", but no matching submodule was found for stack " + innerStack.join('.'));
								return null;
							}
							
							return { m : m, d: def, ic : innerStack };
						} else {
							return { m : m, d: def, ic : innerClasses };
						}
					}
				}
			}

			//if still not found, look for modules in order
			var cp = "";
			for (i in 0...p.length)
			{
				if (cp != "") cp += ".";
				cp += p[i];

				var m = modules.get(cp);
				if (m != null)
				{
					var innerStack = p.slice(i);
					var d = getDefinitionFromModule(m, innerStack);
					if (d == null)
					{
						trace("WARNING: Module " + m.pack.join(".") + "." + m.name + " found for type " + p.join(".") + ", but no matching submodule was found");
						return null;
					}
					
					return { m : m, d : d, ic : innerStack };
				}
			}

			trace("WARNING: Path " + p.join(".") + " not found");
			return null;
		}
	}

	function nt(t:TPath):TPath
	{
		return switch(t)
		{
		case TArray(t):
			TArray(nt(t));
		case
		TPath(["int"], []),
		TPath(["byte"], []),
		TPath(["char"], []),
		TPath(["double"], []),
		TPath(["float"], []),
		TPath(["long"], []),
		TPath(["short"], []),
		TPath(["boolean"], []),
		TPath(["void"], []): t;

		case TPath(p, params):
			var t = lookupPath(p, params);
			if (t == null)
			{
				return TPath(p, params.map(na));
			}
			
			return mkTPath(t.m, t.d, t.ic, params);
		}
	}

	function mkTPath(root:Program, def:Definition, innerStack:Array<String>, params:Array<TArg>):TPath
	{
		var path = null;
		if (root == this.cur)
		{
			path = [];
			if (innerStack == null || innerStack.length == 0)
				path.push(root.name);
		} else {
			path = root.pack.copy();
			path.push(root.name);
		}

		if (innerStack != null && innerStack.length > 0)
			path.push([root.name].concat(innerStack).join("_"));

		switch(def)
		{
		case CDef(c):
			if (params == null || params.length == 0 && c.types.length > 0)
			{
				params = c.types.map(function(gd) return AWildcard);
			}
		default:
		}

		return TPath(path, params);
	}

	function na(a:TArg)
	{
		return switch(a)
		{
		case AType(t):
			AType({ t : nt(t.t), final: t.final });
		default: a; //wildcards == Dynamic in Haxe
		}
	}

	function addImports(m:Program, ds:StringMap<ImportedDef>)
	{
		//add imports
		for (i in m.imports)
		{
			if (!i.isStatic)
			{
				if (i.path[i.path.length - 1] == "*")
				{
					i.path.pop();
					//add whole package
					var pack = packs.get(i.path.join("."));
					i.path.push("*");
					if (pack == null)
					{
						trace("WARNING: No package ' " + i.path.join(".") + " ' found");
						continue;
					}

					for (md in pack)
					{
						ds.set(md.name, Module(md));
					}
				} else {
					//we might have a direct module referenced, or a submodule
					var m = modules.get(i.path.join("."));
					if (m == null)
					{
						//submodule is referenced
						var p = i.path.copy();
						var diffpath = [];
						while (m == null && p.length > 0)
						{
							diffpath.push(p.pop());
							m = modules.get(p.join("."));
						}
						if (m == null)
						{
							trace("WARNING: couldn't find any fitting module for import " + i.path.join("."));
							continue;
						}

						diffpath.reverse();
						var def = getDefinitionFromModule(m, diffpath);
						if (def == null)
						{
							trace("WARNING: couldn't find any fitting definition for import " + i.path.join(".") + " and module " + m.pack.join(".") + "." + m.name);
							continue;
						}

						ds.set(getDef(def).name, Submodule(m, diffpath, def));
					} else {
						ds.set(m.name, Module(m));
					}
				}
			}
		}
	}

	private function addChildDefs(module:Program, ds:StringMap<ImportedDef>, def:Definition, innerStack:Array<String>)
	{
		var d = getDef(def);
		if (innerStack.length > 0)
		{
			ds.set(d.name, Submodule(module, innerStack, def));
		}

		innerStack.push(d.name);
		for (c in d.childDefs)
			addChildDefs(module, ds, c, innerStack);
		innerStack.pop();
	}

	static function getDefinitionFromModule(m:Program, path:Array<String>):Null<Definition>
	{
		var cur = m.defs;
		if (path.length == 0) return cur[0];
		for (p in cur)
			if (getDef(p).name == m.name && path[0] != m.name)
				cur = getDef(p).childDefs;

		var i = 0;
		for (p in path)
		{
			i++;
			var found = false;
			for (c in cur)
			{
				if (found) break;
				var d = getDef(c);
				if (d.name == p)
				{
					if (i == path.length)
						return c;
					cur = d.childDefs;
					found = true;
				}
			}
			if (!found) return null;
		}

		trace(m);
		trace(m.name);
		trace(path);
		throw "assert";
	}

	static function getDef(d:Definition):{ name:String, childDefs:Array<Definition> }
	{
		return switch(d)
		{
		case CDef(c): return c;
		case EDef(c): return c;
		}
	}
}
