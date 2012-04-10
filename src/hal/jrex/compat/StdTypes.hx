package hal.jrex.compat;

#if !(jvm || cs)
typedef Single = Float;
typedef Byte = Int;
typedef Short = Int;
#end

typedef Int64 = haxe.Int64;