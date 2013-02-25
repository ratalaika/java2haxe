package hal.jrex.converter;
import hal.jrex.Java;
import haxe.io.Output;
import haxe.ds.StringMap;

using Lambda;
/**
 * ...
 * @author waneck
 */

class HaxeExtern
{
	private var out:Output;
	private var program:Program;
	private var indent:Array<String>;
	private var iereg:EReg;
	private var sereg:EReg;
	private var opts:StringMap<Bool>;
	private var since:Bool;
	private var typeParamsStack:Array<Array<String>>;

	public function new(out:Output, opts)
	{
		this.iereg = ~/^( +)/mg;
		this.sereg = ~/@since[^\.]+\.([\d]+)/;
		this.indent = [];
		this.out = out;
		this.opts = opts;

		this.since = opts.exists('parse-since');
		typeParamsStack = [];
	}

	public function lookupTypeParam(s:String)
	{
		for(tp in typeParamsStack)
		{
			for(t in tp)
			{
				if (s == t)
					return true;
			}
		}

		return false;
	}

	private function beginIndent()
	{
		indent.push('\t');
	}

	private function endIndent()
	{
		indent.pop();
	}

	private function nl()
	{
		out.writeString('\n' + indent.join(""));
	}

	public function convertModule(p:Program)
	{
		this.program = p;
		if (p.pack.length != 0)
		{
			out.writeString("package " + p.pack.join(".") + ";\n");
		}

		for (def in p.defs)
			definition(def, []);
	}

	private function definition(d:Definition, defStack:Array<String>)
	{
		switch(d)
		{
		case EDef(e): convertEnum(e, defStack);
		case CDef(c):
			if (c.types != null)
				typeParamsStack.push(c.types.map(function(t) return t.name));
			convertClass(c, defStack);
			if (c.types != null)
				typeParamsStack.pop();
		}
	}

	private inline function w(s:String)
	{
		out.writeString(s);
	}

	private function isHxKeyword(s:String):Bool
	{
		return switch(s)
		{
			case "callback", "cast", "extern", "function", "in", "typedef", "using", "var", "untyped", "inline":
				true;
			default: false;
		}
	}

	private function convertClass(c:ClassDef, defStack:Array<String>)
	{
		//don't compile private or internal
		var isPrivate = false;
		if (c.kwds.has("private") || (!c.kwds.has("protected") && !c.kwds.has("public")))
			isPrivate = true;

		var require = null;
		if (c.comments != null)
		{
			for (c in c.comments)
			{
				switch(c.expr)
				{
				case JComment(c, true) if (sereg.match(c)):
					var since = sereg.matched(1);
					require = "@:require(java" +(since.substr(0,1)) + ") ";
				default:
				}
			}
			for (c in c.comments) expr(c);
		}
		if (since && require != null) w(require);

		if (defStack.length > 0)
			w("@:native('" + program.pack.concat(defStack).join("$") + "$" + c.name + "') ");

		if (isPrivate)
			w('@:internal ');
		if (c.isInterface)
			w('extern interface ');
		else
			w('extern class ');
		w((defStack.length > 0 ? defStack.join("_") + "_" + c.name : c.name));

		if (c.types.length > 0)
			w('<' + c.types.map(function(g) return g.name).join(", ") + '>');

		c.extend = c.extend.filter(function(v) switch(v.t) {
			case TPath(p, _): if (p[0] == "java" && p[1] == "lang" && p[2] == "object") return false; return true;
			default: return true;
		}).array();

		if (c.extend.length > 0)
			w(' extends ' + c.extend.map(t).join(" extends "));
		if (c.implement.length > 0)
			w(' implements ' + c.implement.map(t).join(' implements '));

		nl();
		w('{');
		beginIndent();
		nl();

		for (f in c.fields)
		{
			//don't compile private or internal
			if (!c.isInterface && (f.kwds.has("private") || (!f.kwds.has("protected") && !f.kwds.has("public"))))
				continue;
			if (c.isInterface && f.kwds.has("static"))
				continue;

			if (f.types != null)
				typeParamsStack.push(f.types.map(function(t) return t.name));
			var require = null;
			if (f.comments != null)
			{
				for (c in f.comments)
				{
					switch(c.expr)
					{
					case JComment(c, true) if (sereg.match(c)):
						var since = sereg.matched(1);
						require = "@:require(java" +(since.substr(0,1)) + ") ";
					default:
					}
				}
				for (c in f.comments) expr(c);
			}

			switch(f.kind)
			{
			case FVar(vt, _):
				var isFinal = vt.final || f.kwds.remove("final");
				var isStatic = f.kwds.remove('static');

				f.kwds.remove('public');
				var access = f.kwds.remove('protected') ? 'private ' : 'public ';

				if (since && require != null) w(require);

				if (f.name.charCodeAt(0) == '%'.code)
				{
					w("@:native('" + f.name.substr(1) + "') ");
				} else if (isHxKeyword(f.name)) {
					if (!isStatic)
						w("//");
					else
						w("@:native('" + f.name + "') ");
				}
				for (k in f.kwds)
					w("@:" + k +" ");

				w(access);
				if (isStatic)
					w('static ');
				w('var '); w(id(f.name));
				if (isFinal)
					w('(default, null)');
				w(' : '); w(t(vt)); w(';'); nl(); nl();
			case FFun(fn):
				var access = f.kwds.remove('protected') ? 'private ' : 'public ';
				var isStatic = f.kwds.remove('static');
				f.kwds.remove('public');
				if (since && require != null) w(require);
				if (f.name.charCodeAt(0) == '%'.code)
				{
					w("@:native('" + f.name.substr(1) + "') ");
				} else if (isHxKeyword(f.name)) {
					if (!isStatic)
						w("//");
					else
						w("@:native('" + f.name + "') ");
				}

				w("@:overload "); //necessary

				//for (tw in fn.throws)
					//w("@:throws('" + t(tw) + "') ");
				for (k in f.kwds)
					w("@:" + k +" ");
				if (!isStatic && f.meta != null && f.meta.exists(function(f) return f.name == "Override"))
					w("override ");
				w(access);
				if (isStatic) w("static ");
				w('function ');
				if (f.name == c.name)
					w("new");
				else
					w(id(f.name));

				if (f.types != null && f.types.length > 0)
					w("<" + f.types.map(generic).join(", ") + ">");
				w("(");
				var first = true;
				for (a in fn.args)
				{
					if (first)
						first = false;
					else
						w(", ");
					w(id(a.name));
					w(" : ");
					w(t(a.t));
				}

				if (fn.varArgs != null)
				{
					if (!first) w(", ");
					w(id(fn.varArgs.name));
					w(" : ");
					w(t({ final : fn.varArgs.t.final, t : TArray(fn.varArgs.t.t) }));
				}
				w(") : ");
				w(t(fn.ret));
				w(";"); nl(); nl();
			}
			if (f.types != null)
				typeParamsStack.pop();
		}

		endIndent();
		nl();
		w('}');
		nl();

		defStack.push(c.name);
		for (d in c.childDefs)
		{
			switch(d)
			{
				case CDef(_):
					definition(d, defStack);
				default: definition(d, defStack);
			}
		}
		defStack.pop();
	}

	private function t(t:T):String
	{
		return tpath(t.t);
	}

	private function tpath(t:TPath):String
	{
		return switch(t)
		{
			case TPath(["int"], []): "Int";
			case TPath(["byte"], []): "java.StdTypes.Int8";
			case TPath(["char"], []): "java.StdTypes.Char16";
			case TPath(["double"], []): "Float";
			case TPath(["float"], []): "Single";
			case TPath(["long"], []): "haxe.Int64";
			case TPath(["short"], []): "java.StdTypes.Int16";
			case TPath(["boolean"], []): "Bool";
			case TPath(["void"], []): "Void";

			case TPath(["java", "lang", "Integer"], [] ): "Null<Int>";
			case TPath(["java", "lang", "Double"], [] ): "Null<Float>";
			case TPath(["java", "lang", "Single"], [] ): "Null<Single>";
			case TPath(["java", "lang", "Boolean"], [] ): "Null<Bool>";
			case TPath(["java", "lang", "Byte"], [] ): "Null<java.StdTypes.Int8>";
			case TPath(["java", "lang", "Character"], [] ): "Null<java.StdTypes.Char16>";
			case TPath(["java", "lang", "Short"], [] ): "Null<java.StdTypes.Int16>";
			case TPath(["java", "lang", "Long"], [] ): "Null<haxe.Int64>";

			case TPath(["java", "lang", "Object"], [] ): "Dynamic";
			case TPath(["java", "lang", "String"], [] ): "String";
			case TPath(["java", "lang", "Class"], params ): "Class<" + params.map(targ).join(", ") + ">";

			//case TPath(["java", "lang", ", params):
			case TPath([p], []) if (p.charCodeAt(0) == '*'.code):
				var p = p.substr(1);
				if (lookupTypeParam(p))
				{
					p;
				} else {
					"Dynamic";
				}
			case TPath(p, params) if (params == null || params.length == 0):
				p.join(".");
			case TPath(p, params):
				p.join(".") + "<" + params.map(targ).join(", ") + ">";
			case TArray(tp):
				"java.NativeArray<" + tpath(tp) + ">";
		}
	}

	private function targ(t:TArg):String
	{
		return switch(t)
		{
			case AType(tp), AWildcardExtends(tp), AWildcardSuper(tp): this.t(tp);
			default: "Dynamic";
		}
	}

	private function id(s:String):String
	{
		if (isHxKeyword(s))
		{
			return "_" + s;
		}
		//TODO include haxe keywords
		return StringTools.replace(s, "%", "_");
	}

	private function generic(gd:GenericDecl):String
	{
		if (gd.extend == null)
			return gd.name;
		return gd.name + " : " + gd.extend.map(t).join(", ");
	}

	private function convertEnum(e:EnumDef, defStack:Array<String>)
	{
		var require = null;
		if (e.comments != null)
		{
			for (c in e.comments)
			{
				switch(c.expr)
				{
				case JComment(c, true) if (sereg.match(c)):
					var since = sereg.matched(1);
					require = "@:require(java" +(since.substr(0,1)) + ") ";
				default:
				}
			}
			for (c in e.comments) expr(c);
		}
		if (since && require != null) w(require);

		if (defStack.length > 0)
			w("@:native('" + program.pack.concat(defStack).join("$") + "$" + e.name + "') ");

		if (e.kwds.has("private") || e.kwds.has("protected"))
			w('private');
		w('extern enum ' + (defStack.length > 0 ? defStack.join("_") + "_" + e.name : e.name));
		nl();
		w('{');
		beginIndent();
		nl();
		for ( ctor in e.constrs )
		{
			if (ctor.comments != null)
			{
				for (c in ctor.comments)
					expr(c);
			}

			w(ctor.name);
			w(';');
			nl();
		}
		endIndent();
		nl();
		w('}');
		nl();
		nl();

		defStack.push(e.name);
		for (d in e.childDefs)
			definition(d, defStack);
		defStack.pop();
	}

	private function expr(e:Expr)
	{
		switch(e.expr)
		{
			case JConst(c):
				switch(c)
				{
					case CLong( v ): out.writeString(v);
					case CInt( v ): out.writeString(v);
					case CFloat( f ): out.writeString(f);
					case CSingle( f ): out.writeString(f);
					case CString( s ): out.writeString(s);
				}
			case JComment(s, isBlock):
				if (isBlock)
				{
					var tabs = indent.join("");
					s = iereg.replace(s, tabs);
					out.writeString(s);
					nl();
				} else {
					out.writeString("//");
					out.writeString(s);
					out.writeString("\n");
				}
			default: //do nothing
		}
	}

}
