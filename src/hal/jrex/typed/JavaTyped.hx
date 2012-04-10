package hal.jrex.typed;
import hal.jrex.Java;
import haxe.Int32;

/**
 * ...
 * @author waneck
 */

typedef TType =
{
	final : Bool,
	meta : Metadata,
	type : TTypeT
}
 
typedef Var = {
	var id : Int;
	var name : String;
	var t : TType;
}

typedef TExpr = {
	expr : TExprExpr,
	t : TType,
	pos : Pos
}

typedef TParams = Null<Array<TParam>>;

enum TParam
{
	T( t : TTypeT );
	TWildcard( ?ext : TTypeT, ?sup : TTypeT );
}

typedef TypeParameter = {
	var id : Int;
	var name : String;
	var extend : Null<Array<TType>>;
}

enum BasicType
{
	TByte;
	TShort;
	TInt;
	TLong;
	TChar;
	
	TSingle;
	TFloat;
	
	TBool;
	TVoid;
}

enum TTypeT
{
	TBasic( basic : BasicType );
	TEnum( en : TEnumDef, params : TParams );
	TInst( cl : TClassDef, params : TParams );
	TArray( t : TTypeT );
	TTypeParam( param : TypeParameter );
	TUnknown( t : TPath ); // when a type is not found
}

enum TConst
{
	TSuper;
	TThis;
	TString( s : String );
	TLong( v : String );
	TInt( i : Int32 );
	TFloat( v : String );
	TSingle( v : String );
}

typedef TFunction = {
	var args : Array<{ name : String, t : TType }>;
	var varArgs : Null<{ name : String, t : TType }>;
	var ret : TType;
	var throws:Array<TType>;
	var expr : Null<TExpr>;
	var pos : Pos;
}

enum TFieldKind
{
	TVar( val : Null<TExpr> );
	TFunction( func : TFunction );
}

typedef TClassField =
{
	var isMember : Bool;
	var isPrivate : Bool;
	var name : String;
	var meta : Metadata;
	var comments : String;
	var kwds : Array<String>;
	var kind : TFieldKind;
	var pos : Pos;
	var def : TDefinition;
	var docs : String;
	var isOverride : Bool;
	
	//for fast overload resolution
	var argsCount : Int; //-1 if variable or var-args
	var args : Null<Array<TType>>; //null if variable
}

typedef TBaseDef = {
	var pack : Array<String>;
	var meta : Metadata;
	var kwds : Array<String>;
	var name : String;
	var implement : Array<TType>;
	
	var ctors : Array<TClassField>;
	
	var orderedStatics : Array<TClassField>;
	var orderedFields : Array<TClassField>;
	var statics : Hash<Array<TClassField>>;
	var fields : Hash<Array<TClassField>>;
	
	var staticInit : Null<TExpr>;
	var instInit : Null<TExpr>;
	
	var pos : Pos;
}

typedef TClassDef = {
	> TBaseDef,
	var isInterface : Bool;
	var types : Array<TypeParameter>;
	var extend : Null<TType>;
}

typedef TEnumField = {
	var name : String;
	var args : Null<Array<TExpr>>;
	var meta : Metadata;
	var docs : String;
	var pos : Pos;
}

//we will offer by now limited support for enums
typedef TEnumDef = {
	> TBaseDef,
	
	var orderedConstrs : Array<TEnumField>;
	var constrs : Hash<TEnumField>;
	
}

enum TDefinition {
	TCDef( c : TClassDef );
	TEDef( e : TEnumDef );
	TNotFound;
}

enum TExprExpr 
{
	TConst( c : TConst );
	TLocal( v : Var );
	TVars( vars : Array<{ v : Var, val : Null<TExpr> }> );
	TCast( t : TType, expr : TExpr );
	TParent( e : TExpr );
	TBlock( e : Array<TExpr> );
	TSynchronized ( lock : TExpr, block : Array<TExpr> );
	TClassField( e : TExpr, f : TClassField );
	TStaticField( f : TClassField );
	TEnumField( f : TEnumField );
	TField( e : TExpr, f : String ); //for not found fields (maybe unavailable source code)
	TBinop( op : String, e1 : TExpr, e2 : TExpr );
	TUnop( op : String, prefix : Bool, e : TExpr );
	TMemberCall( e : TExpr, field : TClassField, tparams : TParams, params : Array<TExpr> );
	TStaticCall( field : TClassField, tparams : TParams, params : Array<TExpr> );
	TCall( e : TExpr, field : String, params : Array<TExpr> ); //for not found fields
	TTypeExpr( def : Definition ); //equivalent of MyClass / MyClass.class 
	TIf( cond : TExpr, e1 : TExpr, ?e2 : TExpr );
	TTernary( cond : TExpr, e1 : TExpr, ?e2 : TExpr );
	TWhile( cond : TExpr, e : TExpr, doWhile : Bool, ?label:String );
	TFor( inits : Array<TExpr>, conds : Array<TExpr>, incrs : Array<TExpr>, e : TExpr, ?label:String );
	TForEach( v : Var, inExpr : TExpr, block : TExpr, ?label:String );
	TBreak( ?label : String );
	TContinue( ?label : String );
	TReturn( ?e : TExpr );
	TArray( e : TExpr, index : TExpr );
	TArrayDecl( t : TType, lens : Null<Array<TExpr>>, e : Null<Array<TExpr>> );
	TNewAnon( def : { base : TClassDef, fields : Array<TClassField>, staticInit : Null<TExpr>, instInit : Null<TExpr>, captured : Array<Var> } );
	TNew( t : TType, params : Array<TExpr> );
	TThrow( e : TExpr );
	TTry( e : TExpr, catches : Array<{ v : Var, e: TExpr } >, finally : TExpr );
	TSwitch( e : TExpr, cases : Array<{ val : TExpr, el : Array<TExpr> }>, def : Null<Array<TExpr>> );
	TComment( s : String, isBlock: Bool );
	TAssert( e : TExpr, ?ifFalse : TExpr );
	TInnerDecl( def : TDefinition );
	TInstanceOf( e : Expr, t : TType );
}