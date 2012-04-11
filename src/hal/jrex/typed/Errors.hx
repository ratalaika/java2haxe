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
	UnboundField(def:TDefinition, field:String, isStatic:Bool, pos:Pos);
	NoOverloadFound(def:TDefinition, field:String, isStatic:Bool, types:Iterable<TTypeT>, pos:Pos);
	AccessFieldWithoutCalling(def:TDefinition, field:String, isStatic:Bool, pos:Pos);
}