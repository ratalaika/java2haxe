package hal.java2hx.typed;
import hal.java2hx.Java;
import haxe.Int32;

/**
 * ...
 * @author waneck
 */

typedef Var = {
	var id : Int;
	var name : String;
	var t : T;
}

typedef TExpr = {
	expr : TExprExpr,
	t : T,
	pos : Pos
}

typedef T =
{
	final : Bool,
	meta : Metadata,
	type : TypeT
}

typedef TParams = Array<TypeT>;

typedef TypeParameter = {
	var id : Int;
	var name : String;
	var extend : Array<T>;
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

enum TypeT
{
	TBasic( basic : BasicType );
	TEnum( en : EnumDef, params : TParams );
	TInst( cl : ClassDef, params : TParams );
	TTypeParam( param : TypeParameter );
	TWildcard( ?ext : T, ?sup : T );
}

enum TConst
{
	TSuper;
	TThis;
	TString( s : String );
	TInt( i : Int32 );
	TFloat( v : String );
	TSingle( v : String );
}

enum TExprExpr 
{
	TConst( c : TConst );
	TLocal( v : Var );
	TVars( vars : Array<{ v : Var, val : Null<TExpr> }> );
	TParent( e : TExpr );
	TBlock( e : Array<TExpr> );
	TSynchronized ( lock : TExpr, block : Array<TExpr> );
	TField( e : TExpr, f : String );
	TBinop( op : String, e1 : TExpr, e2 : TExpr );
	TUnop( op : String, prefix : Bool, e : TExpr );
	TCall( e : TExpr, field:ClassField, tparams:TParams, params : Array<TExpr> );
	TTypeExpr( def : Definition );
	TIf( cond : TExpr, e1 : TExpr, ?e2 : TExpr );
	TTernary( cond : TExpr, e1 : TExpr, ?e2 : TExpr );
	TWhile( cond : TExpr, e : TExpr, doWhile : Bool, ?label:String );
	TFor( inits : Array<TExpr>, conds : Array<TExpr>, incrs : Array<TExpr>, e : TExpr, ?label:String );
	TForEach( v : Var, inExpr : TExpr, block : TExpr, ?label:String );
	TBreak( ?label : String );
	TContinue( ?label : String );
	TReturn( ?e : TExpr );
	TArray( e : TExpr, index : TExpr );
	TArrayDecl( t : T, lens : Null<Array<TExpr>>, e : Null<Array<TExpr>> );
	TNewAnon( def : { fields : Array<ClassField>, staticInit : Null<TExpr>, instInit : Null<TExpr> } );
	TNew( t : T, params : Array<TExpr> );
	TThrow( e : TExpr );
	TTry( e : TExpr, catches : Array<{ name : String, t : T, e: TExpr } >, finally : TExpr );
	TSwitch( e : TExpr, cases : Array<{ val : TExpr, el : Array<TExpr> }>, def : Null<Array<TExpr>> );
	TComment( s : String, isBlock: Bool );
	TAssert( e : TExpr, ?ifFalse : TExpr );
	TInnerDecl( def : Definition );
}