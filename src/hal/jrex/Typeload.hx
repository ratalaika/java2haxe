package hal.jrex;
import hal.jrex.Java;
import haxe.ds.StringMap;
import haxe.io.Input;
import sys.FileSystem;
import sys.io.File;

/**
 * ...
 * @author waneck
 */

enum Identifier
{
	Classpath(paths:Array<String>);
	Def(d:Definition);
}

class Typeload 
{
	private var modules:StringMap<Definition>;
	private var classpaths:Array<String>;
	private var globalIdentifiers:StringMap<Identifier>;
	
	private var parser:Parser;
	
	public function new() 
	{
		this.modules = new StringMap();
		this.classpaths = [];
		this.globalIdentifiers = new StringMap();
		
		this.parser = new Parser();
	}
	
	private function getFile(path:String):Null<Input>
	{
		if (FileSystem.exists(path))
			return File.read(path, false);
		return null;
	}
	
	private function readDir(path:String):Array<String>
	{
		return FileSystem.readDirectory(path);
	}
	
	public function lookupModule(m:Array<String>)
	{
		
	}
	
	public function allModules():Iterator<String>
	{
		return modules.keys();
	}
	
	public function getModule(m:String, normalize:Bool=false)
	{
		
	}
}