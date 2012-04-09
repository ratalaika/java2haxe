package hal.java2hx.compat;

#if !(jvm || cs)
typedef Single = Float;
typedef Byte = Int;
typedef Short = Int;
#end