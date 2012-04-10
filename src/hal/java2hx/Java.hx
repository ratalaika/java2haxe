/*
 * Copyright (c) 2008-2011, Nicolas Cannasse
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   - Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   - Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
package hal.java2hx;

typedef Pos = {
	file:String,
	min:Int,
	max:Int
}

enum Const {
	CLong( v : String );
	CInt( v : String );
	CFloat( f : String );
	CSingle( f : String );
	CString( s : String );
}

typedef Expr = { expr : ExprExpr, pos: Pos };

enum ExprExpr 
{
	JConst( c : Const );
	JIdent( v : String );
	JVars( vars : Array<{ name : String, t : T, val : Null<Expr> }> );
	JCast( to : T, expr : Expr );
	JParent( e : Expr );
	JBlock( e : Array<Expr> );
	JSynchronized ( lock : Expr, e : Array<Expr> );
	JField( e : Expr, f : String );
	JBinop( op : String, e1 : Expr, e2 : Expr );
	JUnop( op : String, prefix : Bool, e : Expr );
	JCall( e : Expr, tparams:TParams, params : Array<Expr> );
	JIf( cond : Expr, e1 : Expr, ?e2 : Expr );
	JTernary( cond : Expr, e1 : Expr, ?e2 : Expr );
	JWhile( cond : Expr, e : Expr, doWhile : Bool, ?label:String );
	JFor( inits : Array<Expr>, conds : Array<Expr>, incrs : Array<Expr>, e : Expr, ?label:String );
	JForEach( t : T, name : String, inExpr : Expr, block : Expr, ?label:String );
	JBreak( ?label : String );
	JContinue( ?label : String );
	JReturn( ?e : Expr );
	JArray( e : Expr, index : Expr );
	JArrayDecl( t : T, lens : Null<Array<Expr>>, e : Null<Array<Expr>> );
	JNewAnon( def : { fields : Array<ClassField>, staticInit : Null<Expr>, instInit : Null<Expr> } );
	JNew( t : T, params : Array<Expr> );
	JThrow( e : Expr );
	JTry( e : Expr, catches : Array<{ name : String, t : T, e: Expr } >, finally : Expr );
	JSwitch( e : Expr, cases : Array<{ val : Expr, el : Array<Expr> }>, def : Null<Array<Expr>> );
	JComment( s : String, isBlock: Bool );
	JAssert( e : Expr, ?ifFalse : Expr );
	JInnerDecl( def : Definition );
	JInstanceOf( e : Expr, t : T );
}

typedef T = {
	final:Bool, t:TPath
}

enum TPath {
	TPath( p : Array<String>, params : TParams);
	TArray( of : TPath );
}

enum TArg {
	AType( t : T );
	AWildcard;
	AWildcardExtends( t : T );
	AWildcardSuper( t : T );
}

typedef TParams = Null<Array<TArg>>;

typedef GenericDecl = {
	name : String,
	extend : Null<Array<T>>
}

enum FieldKind {
	FVar( t : T, val : Null<Expr> );
	FFun( f : Function );
	FComment;
}

typedef Function = {
	var args : Array<{ name : String, t : T }>;
	var varArgs : Null<{ name : String, t : T }>;
	var ret : T;
	var throws:Array<T>;
	var expr : Null<Expr>;
	var pos : Pos;
}

typedef Metadata = Array<{ name : String, args : Array<{ name : String, val : Expr }>, pos : Pos }>;

typedef ClassField = {
	var meta : Metadata;
	var comments : Array<Expr>;
	var kwds : Array<String>;
	var name : String;
	var kind : FieldKind;
	var pos : Pos;
}

typedef EnumField = {
	var name : String;
	var args : Null<Array<Expr>>;
	var meta : Metadata;
	var pos : Pos;
}

typedef EnumDef = {
	var meta : Metadata;
	var kwds : Array<String>;
	var name : String;
	var implement : Array<T>;
	var childDefs : Array<Definition>;
	
	var constrs : Array<EnumField>;
	var fields : Array<ClassField>;
	var staticInit : Expr;
	var instInit : Expr;
	var pos : Pos;
}

typedef ClassDef = {
	var meta : Metadata;
	var kwds : Array<String>;
	var isInterface : Bool;
	var types : Array<GenericDecl>;
	var name : String;
	var implement : Array<T>;
	var extend : Null<T>;
	var childDefs : Array<Definition>;
	
	var fields : Array<ClassField>;
	var staticInit : Expr;
	var instInit : Expr;
	var pos : Pos;
}

enum Definition {
	CDef( c : ClassDef );
	EDef( e : EnumDef );
}

typedef Program = {
	var header : Array<Expr>; // will hold only comments
	var pack : Array<String>;
	var imports : Array<Array<String>>;
	var name : String;
	var def : Definition;
}