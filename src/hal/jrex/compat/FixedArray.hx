package hal.jrex.compat;

/**
 * ...
 * @author waneck
 */

typedef FixedArray<T> =
#if flash9
	flash.Vector<T>;
#elseif jvm
	jvm.NativeArray<T>;
#elseif cs
	cs.NativeArray<T>;
#else
	Array<T>;
#end

class FixedArrayExt
{
	public static inline function alloc<T>(size:Int):FixedArray<T>
	{
#if flash9
		var vec = new flash.Vector();
		vec.length = size;
		vec.fixed = true;
		return vec;
#elseif jvm
		return new jvm.NativeArray(size);
#elseif cs
		return new cs.NativeArray(size);
#else
		var arr = [];
		arr[size-1] = null;
		
		return arr;
#end
	}
	
	public static inline function len(arr:FixedArray<T>):Int
	{
		return arr.length;
	}
	
	public static inline function get<T>(arr:FixedArray<T>, idx:Int):T
	{
		return arr[idx];
	}
	
	public static inline function set<T>(arr:FixedArray<T>, idx:Int, val:T):T
	{
		return arr[idx] = val;
	}
}
