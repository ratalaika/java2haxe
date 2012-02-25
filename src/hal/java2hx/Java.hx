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
	CInt( v : String );
	CFloat( f : String );
	CString( s : String );
}

#if J2HX_PARSE_POS 
typedef Expr = { expr : ExprExpr, pos: Pos };

enum ExprExpr 
#else
enum Expr
#end
{
	JConst( c : Const );
	JIdent( v : String );
	JVars( vars : Array<{ name : String, t : T, val : Null<Expr> }> );
	JParent( e : Expr );
	JBlock( e : Array<Expr> );
	JField( e : Expr, f : String );
	JBinop( op : String, e1 : Expr, e2 : Expr );
	JUnop( op : String, prefix : Bool, e : Expr );
	JCall( e : Expr, tparams:TParams, params : Array<Expr> );
	JIf( cond : Expr, e1 : Expr, ?e2 : Expr );
	JTernary( cond : Expr, e1 : Expr, ?e2 : Expr );
	JWhile( cond : Expr, e : Expr, doWhile : Bool );
	JFor( inits : Array<Expr>, conds : Array<Expr>, incrs : Array<Expr>, e : Expr );
	JForEach( t : T, name : String, inExpr : Expr, block : Expr );
	JBreak( ?label : String );
	JContinue;
	JFunction( f : Function, name : Null<String> );
	JReturn( ?e : Expr );
	JArray( e : Expr, index : Expr );
	JArrayDecl( e : Array<Expr> );
	JNew( t : T, params : Array<Expr>, anonClass:Null<ClassDef> );
	JThrow( e : Expr );
	JTry( e : Expr, catches : Array<{ name : String, t : Null<T>, e : Expr }> );
	JSwitch( e : Expr, cases : Array<{ val : Expr, el : Array<Expr> }>, def : Null<Array<Expr>> );
	JLabel( name : String );
	JComment( s : String, isBlock: Bool );
}

enum T {
	TArray( of : T );
	TPath( p : Array<String>, params : TParams);
	TComplex( e : Expr );
}

enum TGeneric {
	GType( t : T );
	GWildcard( ?tExtends : T );
}

typedef TParams = Null<Array<TGeneric>>;

enum FieldKind {
	FVar( t : T, val : Null<Expr> );
	FFun( f : Function );
	FComment;
}

typedef Function = {
	var args : Array<{ name : String, t : T }>;
	var varArgs : Null<String>;
	var ret : T;
	var expr : Null<Expr>;
}

typedef Metadata = Array<{ name : String, args : Array<{ name : String, val : Expr }> }>;

typedef ClassField = {
	var meta : Metadata;
	var comments : Array<Expr>;
	var kwds : Array<String>;
	var name : String;
	var kind : FieldKind;
}

typedef EnumDef = {
	var meta : Metadata;
	var kwds : Array<String>;
	var name : String;
	var fields : Array<String>;
	var funcs : Array<ClassField>;
}

typedef ClassDef = {
	var meta : Metadata;
	var kwds : Array<String>;
	var isInterface : Bool;
	var name : String;
	var fields : Array<ClassField>;
	var implement : Array<T>;
	var extend : Null<T>;
	var inits : Array<Expr>;
	var staticInits : Array<Expr>;
}

typedef FunctionDef = {
	var meta : Metadata;
	var kwds : Array<String>;
	var name : String;
	var f : Function;
}

typedef NamespaceDef = {
	var meta : Metadata;
	var kwds : Array<String>;
	var name : String;
	var value : String;
}

enum Definition {
	CDef( c : ClassDef );
	FDef( f : FunctionDef );
	NDef( n : NamespaceDef );
}

typedef Program = {
	var header : Array<Expr>; // will hold only comments
	var pack : Array<String>;
	var imports : Array<Array<String>>;
	var defs : Array<Definition>;
}