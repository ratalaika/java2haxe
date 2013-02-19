package ;

import hal.jrex.Parser;
import hal.jrex.Typeload;
import hal.jrex.converter.HaxeExtern;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
//import hal.jrex.typed.Typer;
import neko.Lib;

/**
 * ...
 * @author waneck
 */

class Main 
{
	static function main()
	{
		//var p = new Parser().parseString(Test1.x, "file.java");
		//var p = new Parser().parseString('package java.lang; public class Test { public String toString(); }', "file.java");
		var path = "../example/classes/java/lang";
		
		for (file in FileSystem.readDirectory(path))
		{
			var fpath = path + "/" + file;
			if (file.charCodeAt(0) < 'A'.code || file.charCodeAt(0) > 'Z'.code || !StringTools.endsWith(file.toLowerCase(), '.java'))
				continue;
			
			trace("=== " + file);
			var p = new Parser(true).parse(File.read(fpath, false), fpath);
			
			var out = File.write(Path.withoutExtension(file) + ".hx");
			var he = new HaxeExtern(out);
			he.convertModule(p);
			out.close();
		}
	}
}