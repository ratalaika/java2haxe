package hal.jrex.converter;
import hal.jrex.Java;
import haxe.ds.StringMap;
import haxe.ds.StringMap;
import haxe.ds.StringMap;
import haxe.ds.StringMap;
import haxe.ds.StringMap;
import haxe.ds.StringMap;
import haxe.ds.StringMap;
import haxe.ds.StringMap;
import haxe.ds.StringMap;
import haxe.ds.StringMap;
import haxe.io.Input;
import sys.FileSystem;
import sys.io.File;

/**
 * ...
 * @author waneck
 */

enum ImportedDef
{
	TypeParameter;
	Module(p:Program);
	Submodule(p:Program, innerClasses:Array<String>, def:Definition);
	NotFound; //don't waste time looking for modules
}

class Normalizer
{
	private var modules:StringMap<Program>;
	private var packs:StringMap<Array<Program>>;
	//private var types:StringMap<Definition>;
	
	private var definitionStack:Array<StringMap<ImportedDef>>;
	
	public function new() 
	{
		this.modules = new StringMap();
		this.packs = new StringMap();
		//this.types = new StringMap();
		
		this.definitionStack = [new StringMap()];
	}
	
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
					for (d in m.defs)
						normalize(d);
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
	
	function normalize(d:Definition)
	{
		
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
						var p = i.path;
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