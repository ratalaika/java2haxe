package ;

import hal.jrex.Parser;
import hal.jrex.typed.Typer;
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
		var p = new Parser().parseString('package java.lang; public class Test { public String toString(); }', "file.java");
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