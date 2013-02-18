package hal.jrex.typed;
import hal.jrex.Java;
import hal.jrex.typed.JavaTyped;

/**
 * ...
 * @author waneck
 */

enum TyperError
{
	NotFoundVar(v:String, pos:Pos);
	UnboundField(def:TTypeT, field:String, isStatic:Bool, pos:Pos);
	NoOverloadFound(def:TTypeT, field:String, isStatic:Bool, types:Iterable<TTypeT>, pos:Pos);
	AccessFieldWithoutCalling(def:TTypeT, field:String, isStatic:Bool, pos:Pos);
	ErrorMessage(msg:String, pos:Pos);
}