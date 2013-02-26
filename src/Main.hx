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
import haxe.ds.StringMap;

/**
 * ...
 * @author waneck
 */

class Main
{

	var norm:Normalizer;
	var opts:StringMap<Bool>;

	function new(opts)
	{
		this.norm = new Normalizer();
		this.opts = opts;
	}

	static function main()
	{
		var args = Sys.args();
		var len = args.length;
		var paths = [];
		var outPath = null;
		var opts = new StringMap(), arg = 1;
		if (args[0] != 'externs') error("invalid build method '" + args[0] + "' did you mean externs?");
		while(arg < len)
		{
			switch(args[arg++])
			{
				case '-i', '--include':
					paths.push(args[arg++]);
				case '-o', '--out':
					if (outPath == null)
							outPath = args[arg++];
					else
						error("Multiple out paths");
				case '--opt':
					var a = args[arg++];
					switch(a)
					{
						case 'parse-since', 'verbose': opts.set(a, true);
						default: error("Unknown optional: " + a);
					}
				default: error("Unknown argument : " + args[arg-1]);
			}
		}
		if (paths.length == 0) error("There must be an output defined");
		if (outPath == null) error("The output path must be defined");

		var m = new Main(opts);
		for(path in paths)
			recurse(path, m);

		m.log("==== starting generation ====");
		outPath += '/';
		for (md in m.norm.allModules())
		{
			m.log(" Generating " + md);
			var md = m.norm.getNormalizedModule(md);
			var cur = [];
			for (p in md.pack)
			{
				cur.push(p);
				if (!FileSystem.exists(outPath + cur.join("/")))
					FileSystem.createDirectory(outPath + cur.join("/"));
			}
			var f = File.write(outPath + md.pack.join("/") + "/" + md.name + ".hx");
			var e = new HaxeExtern(f, opts);
			e.convertModule(md);
			f.close();
		}
	}

	static function print(v:String)
	{
		Sys.println(v);
	}

	static function argError()
	{
		print("Usage: neko jrex externs [-i|--include path/to/sources, -i|--include path/to/sources, ...] [-o|--out path/to/target/folder] [--opt option1, --opt option2...]");
		print("\t<-i, --include> : adds a java folder/class to be included");
		print("\t<-o, --out> : target folder");
		print("\t<--opt> : option set");
		print("\tavailable options:");
		print("\t\tparse-since : parse @since tags and add @:require(javaX)");
		print("");
		print("Example: neko jrex externs -i javastd -o haxe-java --opt parse-since");
		Sys.exit(-1);
	}

	static function error(s:String)
	{
		print("error: " + s);
		argError();
	}

	function log(v:String)
	{
		if (opts.exists("verbose")) print(v);
	}

	static function recurse(path, m:Main)
	{
		m.log("Checking path : " + path);
		var files = if (FileSystem.isDirectory(path)) {
			FileSystem.readDirectory(path);
		} else {
			var ret = [haxe.io.Path.withoutDirectory(path)];
			path = haxe.io.Path.directory(path);
			ret;
		};
		for (file in files)
		{
			var fpath = path + "/" + file;
			if (FileSystem.isDirectory(fpath))
			{
				recurse(fpath, m);
				continue;
			}

			if (file.charCodeAt(0) < 'A'.code || file.charCodeAt(0) > 'Z'.code || !StringTools.endsWith(file.toLowerCase(), '.java'))
				continue;

			m.log(" - parsing file " + fpath);

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

			m.norm.addModule(p);
		}
	}
}
