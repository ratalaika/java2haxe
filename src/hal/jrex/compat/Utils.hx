package hal.jrex.compat;

/**
 * ...
 * @author waneck
 */

class Utils 
{

	public static inline function assert(expr:Bool, ?msg:String)
	{
#if debug
		if (!expr) throw (msg == null) ? "Assert failed" : msg;
#end
	}
	
}