package ;

import hal.jrex.converter.Normalizer;
import hal.jrex.Parser;
import hal.jrex.converter.HaxeExtern;
import haxe.io.BytesOutput;
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
	static var norm:Normalizer = new Normalizer();
	static function main()
	{

		//var p = new Parser().parseString(Test1.x, "file.java");
		//var p = new Parser().parseString('package java.lang; public class Test { public String toString(); }', "file.java");
		var path = "../example/classes/java";
		//var path = "../example/classes/java/awt/font";

		recurse(path);

		for (m in norm.allModules())
		{
			trace(" ++++ " + m);
			var m = norm.getNormalizedModule(m);
			var cur = [];
			for (p in m.pack)
			{
				cur.push(p);
				if (!FileSystem.exists("out/" + cur.join("/")))
					FileSystem.createDirectory("out/" + cur.join("/"));
			}
			var f = File.write("out/" + m.pack.join("/") + "/" + m.name + ".hx");
			var e = new HaxeExtern(f);
			e.convertModule(m);
			f.close();
		}
	}

	static function recurse(path)
	{
		trace(path);
		for (file in FileSystem.readDirectory(path))
		{
			var fpath = path + "/" + file;
			if (FileSystem.isDirectory(fpath))
			{
				recurse(fpath);
				continue;
			}

			if (file.charCodeAt(0) < 'A'.code || file.charCodeAt(0) > 'Z'.code || !StringTools.endsWith(file.toLowerCase(), '.java'))
				continue;

			trace("=== " + fpath);

			var r = null;
			try
			{
				r = File.read(fpath, false);
			}
			catch (e:Dynamic)
			{
				trace(e);
				continue;
			}
			var p = new Parser(true).parse(r, fpath);
			r.close();

			norm.addModule(p);

			//var out = File.write(Path.withoutExtension(file) + ".hx");
			//var out = new BytesOutput();
			//var he = new HaxeExtern(out);
			//he.convertModule(p);
			//out.close();
		}
	}
}
