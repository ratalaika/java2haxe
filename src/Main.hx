package ;

import hal.jrex.Parser;
import hal.jrex.Typeload;
import hal.jrex.converter.HaxeExtern;
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
#if !display
		//var p = new Parser().parseString(Test1.x, "file.java");
		//var p = new Parser().parseString('package java.lang; public class Test { public String toString(); }', "file.java");
		var p = new Parser().parse(File.read('../example/classes/java/lang/Object.java', false), 'Object.java');
		
		var out = File.write('Test.hx');
		var he = new HaxeExtern(out);
		he.convertModule(p);
		out.close();
		switch(p.def)
		{
			case CDef(c):
				for (f in c.fields)
					trace(f);
			default:
		}
	}
#end
}