/* lexical grammar */
%lex

%%

//[^\n]+ //skip whitespace but not newline

// ErrorManager.addShiftLine()
								
[ \t\v\f\r\n]+										/* skip whitespace */
\n													{ return false }
"#"[^\n]*											/* skip comments */


\([\n\r\s]*\<(?:[^)\\]|\\[\s\S])*\>[\n\r\s]*\)		return 'JNX'

"ئدا"												return 'IF'
"وئلا"												return 'ELSE'
"تم"												return 'END'
"صحيح"												return 'TRUE'
"خطئ"												return 'FALSE'
"عدم"												return 'NULL'
"دع"												return 'DEF'
"ئعلن"												return 'DECL'
"دالة"												return 'DALA'
"بنية"												return 'STRUCT'
"تعداد"												return 'ENUM'
"=="												return 'EQ'
"لا="												return 'NEQ'
"<="												return 'LTE'
">="												return 'GTE'
"<"													return 'LT'
">"													return 'GT'
"وو "												return 'AND'
"ئو "												return 'OR'
"+"													return '+'
"->"												return 'RETURNS'
"-"													return '-'
"×"													return '×'
"÷"													return '÷'
"%"													return '%'
"("													return '('
")"													return ')'
"["													return '['
"]"													return ']'
"{"													return '{'
"}"													return '}'
":"													return ':'
"؛"													return '؛'
"،"													return '،'
"..."												return 'SPREAD'
"."													return '.'
"="													return '='
"؟"													return '؟'
"ئرجع "												return 'RETURN'
"هدا"												return 'SELF'
"يمدد "												return 'SUPER'
"يختصر "											return 'SHORTCUTS'
"يملك "												return 'HAS'
"لكل "												return 'FOR'
"في "												return 'IN'
"طالما "											return 'WHILE'
"قل "												return 'SAY'
"ئورد "												return 'IMPORT'
"ك "												return 'AS'
"ئنشئ "												return 'NEW'
"من "												return 'FROM'
"الكل "												return 'ALL'
"ريتما "											return 'AWAIT'
"ليس "       										return 'NOT'

\"(?:[^"\\]|\\[\s\S])*\"							return 'STRING' // Double quoted string
\'[^'\n]*\'											return 'STRING' // Single quoted string

[\u0660-\u0669]+(\.[\u0660-\u0669]+)?   			return 'NUMBER'  // Eastern Arabic numerals
[a-zA-Z_\u0621-\u064A][a-zA-Z0-9_\u0621-\u0669]*	return 'IDENTIFIER'
\d+(\.\d+)?\b              							return 'NUMBER' // Western Arabic numerals


<<EOF>>												return 'EOF'
.													return 'UNKNOWN'

/lex

%{
    const fs = require('fs');
    const path = require('path');
	const SymbolScopes = require('./SymbolScopes');
	const ErrorManager = require('./ErrorManager');
	const ImportManager = require('./ImportManager');
	const Symbol = require('./Symbol');
	
	function createParser (yy) {
		const parser = new Parser();
		
		// .env file's path
		var mainFilePath = path.resolve(process.argv[2]);

		// given path can be a file named مدخل.جني
		// or a folder in which case we add file مدخل.جني
		if (!mainFilePath.endsWith('مدخل.جني')) {
			if (mainFilePath.endsWith('.جني')) {
				console.error('قم بتحديد ملف بئسم مدخل.جني');
				process.exit();
			}
			mainFilePath = path.join(mainFilePath, 'مدخل.جني');
		}
		
		const projectPath = path.dirname(mainFilePath);
		//const envpath = path.join(projectPath, "/.سياق");
		
		// Either pass symbolScopes object (for inline parsing)
		// Or make a new one
		const symbolScopes = yy ? yy.symbolScopes : new SymbolScopes(); //envpath);
		
		// I use yy to pass variables to the newly created parser
		parser.yy = {
			symbolScopes: symbolScopes, // symbol table
			selfStack: yy ? yy.selfStack : [], // holder stack for current SELF object symbol
			funcStack: yy ? yy.funcStack: [] // holder stack for current function symbol		
		}
		
		parser.originalParse = parser.parse;
		parser.parse = function (input, ctx) {
			// here we add global imports to the input source code
			// do not add global imports on inlineparses
			var fileName = path.basename(ctx.filePath, '.جني');
			input = ( ctx.inlineParse ? '' : SymbolScopes.autoImportText(fileName) ) + input;
			try {
				var result = parser.originalParse(input, ctx);
				return result;
			} catch (e) {
				// exception while parsing, lets show errors
				console.log(e);
				ErrorManager.printAll();
			}
		}
		
		return parser;
	}
	
	// override default error handler
	parser.parseError = function (str, hash) {
		ErrorManager.error(
			"لم يتوقع: '" + hash.text + "'" + '\n' + str
		);
		ErrorManager.printAll();
	}
	
	function inlineParse(s, context, yy) {
		if (!s.endsWith('؛')) {
			s += '؛';
		}
		const createParser = require('./jparser');
		const _parser = createParser(yy);
		try {
			const scope = _parser.parse(s, {
				inlineParse: true,
				filePath: context.filePath,
				projectPath: path.resolve(context.projectPath),
				outPath: context.outPath
			});
			return scope;
		} catch (e) {
			console.log(e);
			ErrorManager.printAll();
		}
	}
%}

%{
	// JNX logic
	
	let htmtags = "رئس:head,جسم:body,قسم:div,ميطا:meta,عنوان:title,حيز:span,رابط:a,تدييل:footer,ترويس:header,صورة:img,ئدخال:input"
		.replaceAll(":", '":"').replaceAll(',', '","');
	let htmatts = "مصدر:src,ئصل:rel,عنونت:href,لئجل:for,معرف:id,ستنب:placeholder,معطل:disabled,مطلوب:required,مختار:checked,محدد:selected,ئسم:name,قيمة:value,محتوا:content,صنف:class,طول:height,عرض:width"
		.replaceAll(":", '":"').replaceAll(',', '","');
		
	function processJNX(src, context, yy) {
		// tags
		var tags = JSON.parse('{"' + htmtags + '"}');
		for (var tag in tags) {
			var rg = RegExp(`(?<=[\\<\\/])${tag}(?=[\\s\\>])` ,'g');
			src = src.replace(rg, tags[tag]);
		}
		// add x- to arabic tags
		src = src.replace(RegExp('(?<=(\\<|\\<\\/))([^\x2F-\x7F]*)(?=[\\s\\>])', 'g'), 'x-$2');
		// attrs
		var attrs = JSON.parse('{"' + htmatts + '"}');
		for (var att in attrs) {
			var rg = RegExp(`(?<=\\<((?!x-)[\\s\\S])*\\s+)${att}(?=[\\s]*=)`, 'g');
			src = src.replace(rg, attrs[att]);
		}
		src = processJNXControl(src, context, yy);
		src = src.replaceAll('{', '${');
		return src;
	}
	
	function replaceWithX(s) {
		return s.replace(RegExp('(?<=(\\<|\\<\\/))([^\x2F-\x7F]*)(?=[\\s\\>])', 'g'), 'x-$2');
	}
	
	function processJNXControl(s, context, yy) {
		var rg = RegExp('(<\\s*x-تكرار\\s*لكل\\s*\\=\\s*\\")([^\\"]*)(\\"\\s*في\\s*\\=\\s*\\")([^\\"]*)(\\"\\s*\\>)(((?!(\\<\\s*\\/\\s*x-تكرار\\s*\\>))[\\s\\S])*)(\\<\\s*\\/\\s*x-تكرار\\s*\\>)', 'g');
		while (s != (s = s.replace(rg, "` + $4.map($2 => { return `$6` }).join('') + `"))) {}
		var rgCond = RegExp('(\\< *x-شرط *\\>)(((?!(\\< *\\/ *x-شرط *\\>))[\\s\\S])*)(\< *\\/ *x-شرط *\\>)', 'g');
		var rgWhen = RegExp('(\\< *x-عند * تحقق *= *\\")([^\\"]*)(\\" *\\>)(((?!(\\< *\\/ *x-عند *\\>))[\\s\\S])*)(\\< *\\/ *x-عند *\\>)', 'g');
		var rgElse = RegExp('(\\< *x-عند * غيره *\\>)(((?!(\\< *\\/ *x-عند *\\>))[\\s\\S])*)(\\< *\\/ *x-عند *\\>)', 'g');
		while (s != (
			s = s.replace(rgCond, "` + ($2 '') + `").
				replace(rgWhen, function ($0, $1, $2, $3, $4) {
					var result = inlineParse($2.replace('<x-', '<'), context, yy) + " ? `" + $4 + "` :";
					return result;
				}).replace(rgElse, "`$2` +")
		)) {}
		return '`' + s + '`';
	}
%}

%{
	// Utils
    function toEnDigit(s) {
		return s.replace(/[\u0660-\u0669]/g,
            function(a) { return a.charCodeAt(0) & 0xf }
        )
    }
%}


/* parser grammar */
%start program

%parse-param context

%left SPREAD
%left '+' '-'
%left '×' '÷'
%nonassoc EQ NEQ LT LTE GT GTE
%left OR
%left AND
%left IN
%right '='
%right NOT
%right AWAIT
%right IF

%left SPREAD
%left '+' '-'
%left '×' '÷'
%left EQ NEQ LT LTE GT GTE
%left AND
%left OR
%right '='
%right IN
%right NOT
%right AWAIT
%right IF

%%

////
program
    : declstatement_list EOF {
		ErrorManager.setContext(@1, context.filePath);
		var result = $1.filter(Boolean).join(';');
		if (context.inlineParse) {
			return result;
		}
		let fileName = context.filePath.replace(context.projectPath, '.').replace('.جني', '.js');
		fileName = fileName.replace(__dirname, '.');
		fileName = fileName.replaceAll('/', '.').replace('..', '/');
		
		// make sure not to repeat last two names: ئساسية.ئساسية.جني becomes ئساسية.جني
		var nameArr = fileName.split('.');
		var lastName = nameArr[nameArr.length - 2];
		var lastLastName = nameArr[nameArr.length - 3];
		if (lastLastName) {
			if (lastName == lastLastName.replace('/', '')) {
				fileName = fileName.replace(lastName + '.', '');
			}
		}
		
		let outFilePath = path.join(context.outPath, fileName);
		
		fs.writeFile(outFilePath, result, { flag: 'w+' }, (err) => {
			if (err) {
				throw new Error('فشل حفض الملف: ' + outFilePath);
			}
		});	
		// get global scope
		var glob = yy.symbolScopes.exit();
		return glob; // return global scope
    }
	| EOF /* empty */
    ;
////


////
declstatement_list
	: declstatement { $$ = [$1]; }
	| declstatement_list declstatement { $1.push($2); $$ = $1; }
	;
declstatement
	: import_statement semic_or_nl { $$ = $1; }
	| function_def { $$ = $1; }
	| var_def semic_or_nl { $$ = $1; }
	| struct_def { $$ = $1; }
	| expression semic_or_nl { $$ = $1.value; }
	;
////


////
statement_list
    : statement { $$ = [$1]; }
    | statement_list statement { $1.push($2); $$ = $1; }
    ;
statement
    : super_call semic_or_nl { $$ = $1; }
	| shortcuts_call semic_or_nl { $$ = ''; }
	| has_statement semic_or_nl { $$ = $1; }
	| var_declaration semic_or_nl { $$ = $1; }
	| say_statement semic_or_nl { $$ = $1; }
	| return_statement semic_or_nl { $$ = $1; }
	| while_statement { $$ = $1; }
    | for_in_statement { $$ = $1; }
	| if_statement { $$ = $1; }
	| assignment semic_or_nl { $$ = $1.value; }
	| expression semic_or_nl { $$ = $1.value; }
    | error { $$ = ''; }
    ;
semic_or_nl
    : '؛'
    ;
////


//// statements ////

////
import_statement
	: IMPORT import_specifier FROM import_path {
		ErrorManager.setContext(@1, context.filePath);
		ImportManager.setContext(context);
		
		var importSpecifier = $2;	
		var scope = ImportManager.addImport($4, context.filePath);
		
		if (importSpecifier.find == 'all') {
			var mySymb;
			if (!scope) { // string import
				mySymb = yy.symbolScopes.declareSymbol(importSpecifier.add);
			} else {
				mySymb = yy.symbolScopes.declareSymbol(importSpecifier.add);
				scope.copyToSymbol(mySymb);
			}
		} else {
			if (!scope) { // string import
				importSpecifier.add.forEach((add) => {
					yy.symbolScopes.declareSymbol(add, 'مجهول');
				});
			} else {
				importSpecifier.find.forEach((find) => {
					var symb = scope.getSymbolByName(find);
					if (!symb) {
						ErrorManager.error("الئسم " + find + " غير معروف في الوحدة '" + $4 + "'");
					}
					// TODO REVIEW symb.name = sym.add
					yy.symbolScopes.addSymbol(symb);
				});
			}
		}
		
		if (!scope) { // this is a string import
			var imp = $4.replace(/\"/g, '').replace(/\'/g, ''); // remove " and '
			if (imp == '//') {
				// nonfunctional import just for the parser
				$$ = "";
			} else {
				$$ = 'import ' + $2.value + ' from "' + imp + '";'; 
			}
		} else {
			var imp = './' + $4 + '.js';
			var exp = $2.value;
			if (exp.includes('* as ')) {
				exp = '{' + exp.replace('* as ', '') + '}';
			}
			$$ = 'import ' + $2.value + ' from "' + imp + '";export ' + exp;
		}
	}
	| IMPORT import_list {
		ErrorManager.setContext(@1, context.filePath);
		ImportManager.setContext(context);
		var importNames = $2.split(', ');
		var result = '';
		importNames.forEach (impName => {
			var scope = ImportManager.addImport(impName, context.filePath);
			var symb = scope.getSymbolByName(impName);
			if (!symb) {
				ErrorManager.error("الئسم " + impName + " غير معروف في الوحدة '" + impName + "'");
			}
			// TODO REVIEW symb.name = sym.add
			yy.symbolScopes.addSymbol(symb);
			var imp = './' + impName + '.js';
			var exp = impName;
			var sep = result == '' ? '' : ';';
			result += sep + 'import {' + impName + '} from "' + imp + '";export {' + exp + '}';
		});
		$$ = result;
	}
	;
import_specifier
    : import_list {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			find: $1.split(', '),
			add: $1.split(', '),
			value: '{' + $1 + '}'
		}			
	}
    | IDENTIFIER AS IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			find: [$1],
			add: [$3],
			value: '{' + $1.replace('مفترض', 'default') + ' as ' + $3 + '}'
		}
	}
/* TODO: support AS in imports
	| ALL {
		$$ = {
			find: 'all',
			add: 'العام',
			value: '* as العام' 
		}
	}
*/
    | ALL AS IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			find: "all",
			add: $3,
			value: '* as ' + $3
		}
	}
    ;
import_list
    : IDENTIFIER { $$ = $1; }
    | import_list '،' IDENTIFIER {
		$$ = $1 + ', ' + $3
	}
    ;
import_path
	: IDENTIFIER { $$ = $1; }
	| import_path '.' IDENTIFIER {
		$$ = $1 + '.' + $3
	}
	| STRING { $$ = $1; }
	;
////


////
var_def
	: DECL IDENTIFIER '.' IDENTIFIER AS type_decl {
		ErrorManager.setContext(@1, context.filePath);
		var mySymb = yy.symbolScopes.getSymbByName($2);
		var mySymb2 = yy.symbolScopes.createSymbol($4, $6.type, $6.isArray);
		mySymb.addMember(mySymb2);
		$$ = $2 + '.' + $4 + ' = null';
	}
	| DECL IDENTIFIER '.' IDENTIFIER '=' expression {
		ErrorManager.setContext(@1, context.filePath);
		var mySymb = yy.symbolScopes.getSymbByName($2);
		var mySymb2 = yy.symbolScopes.createSymbol($4, 'منوع', $6.symb.isArray);
		mySymb.addMember(mySymb2);
		$$ = $2 + '.' + $4 + ' = ' + $6.value;
	}
	| DECL IDENTIFIER '.' IDENTIFIER AS type_decl '=' expression {
		ErrorManager.setContext(@1, context.filePath);
		var mySymb = yy.symbolScopes.getSymbByName($2);
		var mySymb2 = yy.symbolScopes.createSymbol($4, $6.type, $6.isArray);
		if (! $8.symb.canBeAssignedTo(mySymb2) ) {
			// type mismatch
			ErrorManager.error("محاولة ئسناد " + $8.symb.toString() + " ئلا " + mySymb2.toTypeString());
		}
		mySymb.addMember(mySymb2);
		$$ = $2 + '.' + $4 + ' = ' + $8.value;
	}
	;
////


////
struct_def
	: DECL struct_decl struct_body {
		var funcSymb = yy.funcStack.pop(); // exit struct scope
		yy.symbolScopes.exit();
		$$ = 'export const ' + $2 + ' = {}'; // no output
	}
	;
struct_decl
	: STRUCT IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		var mySymb = yy.symbolScopes.declareSymbol($2, null, false, false);
		mySymb.isStruct = true; // bad but legacy
		yy.funcStack.push(mySymb);
		yy.symbolScopes.enter();
		$$ = $2;
	}
	;
struct_body
	: ':' has_list END {
		ErrorManager.setContext(@1, context.filePath);
		var funcSymb = yy.funcStack[yy.funcStack.length-1]; // current struct symbol
		var symbols = $2; // $2 has_list is an array of symbols
		symbols.forEach((symb) => {
			funcSymb.addMember(symb);
		});
	}
	;
////


//// support disactivated for now
enum_def
	: DECL enum_decl enum_body {
		var funcSymb = yy.funcStack.pop(); // exit enum scope
		yy.symbolScopes.exit();
		$$ = ''; // no output
	}
	;
enum_decl
	: ENUM IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		var mySymb = yy.symbolScopes.declareSymbol($2, null, false, false);
		mySymb.isEnum = true; // bad but legacy
		yy.funcStack.push(mySymb);
		yy.symbolScopes.enter();
	}
	;
enum_body
	: ':' enum_list END {
		ErrorManager.setContext(@1, context.filePath);
		var funcSymb = yy.funcStack[yy.funcStack.length-1]; // current enum symbol
		var enums = $2; // $2 enum_list is an array of {symb, value}
		enums.forEach((enu) => {
			funcSymb.addMember(enu.symb);
		});
	}
	;
enum_list
	: enum_elem {
		$$ = [$1]
	}
	| enum_list '،' enum_elem {
		$1.push($3);
		if ($3.value == null) {
			$3.value = $1.length
		}
		$$ = $1;
	}
	;
enum_elem
	: IDENTIFIER {
		$$ = {
			symb: yy.symbolScopes.createSymbol($1, 'عدد'),
			value: null
		}
	}
	| IDENTIFIER '=' expression {
		$$ = {
			symb: yy.symbolScopes.createSymbol($1, $3.symb.getTypeName()),
			value: $3.value
		}
	}
	;
////


////
function_def
	: function_decl function_ret body_block {
		ErrorManager.setContext(@1, context.filePath);
		
		var function_decl = $1;
		var function_ret = $2;
		var body_block = $3;
		
		var selfSymb = yy.selfStack.pop();
		var funcSymb = yy.funcStack.pop();
		
		if (body_block.includes('this.')) {
			// we used this keyword, so self is a class
			selfSymb.isClass = true;
			selfSymb.typeSymbol = selfSymb;
		}
		
		var extendStr = '';
		if (funcSymb.hasParent()) {
			extendStr = ' extends ' + funcSymb.mySuper;
		}
		
		if (!selfSymb.isClass && !function_ret.symb.canBeAssignedTo(funcSymb)) {
			ErrorManager.error("نوع الئرجاع غير متوافق مع الوضيفة '" + funcSymb.toString() + "'");
		}
		
		if (function_decl.funcname == 'مدخل') { // self exec main function
			$$ = '(function ' + function_decl.funcname + function_decl.params + body_block + ')()'; 
		} else if (funcSymb.isShortcut()) { // this is a shortcut
			$$ = function_decl.exportStr + 'const ' + function_decl.funcname + '=' + funcSymb.myShortcut + ';'
				+ function_decl.funcname + '.prototype || (' + function_decl.funcname + '.prototype = {});'
				+ body_block.slice(1,-1); // remove first and last { }
		} else if (selfSymb.isClass) { // this is a class
			// we should not have a return
			if (funcSymb.typeIsNot(funcSymb.name)) {
				ErrorManager.error("لا يجب تحديد نوع ئرجاع لصنف <" + funcSymb.getTypeName() + ">");
			}
			$$ = function_decl.exportStr + 'class ' + function_decl.funcname + extendStr + '{constructor' + function_decl.params + body_block + '}';
		} else { // this is a function
			var asyncStr = funcSymb.isAwait ? 'async ' : '';
			$$ = function_decl.exportStr + asyncStr + 'function ' + function_decl.funcname + function_decl.params + body_block;
		}
	}
	| subfunc_decl function_ret body_block {
		ErrorManager.setContext(@1, context.filePath);
		
		var function_decl = $1;
		var function_ret = $2;
		var body_block = $3;
		
		var funcSymb = yy.funcStack.pop();
		
		/* unecessary check, to remove
		if (!funcSymb.sameTypeAs(function_ret.symb)) {
			ErrorManager.error("نوع الئرجاع " + function_ret.symb.toString() + " غير متوافق مع الوضيفة " + funcSymb.toString());
		}
		*/
		
		// dealing with setters and getters (DISABLED FOR NOW)
		/*
		var setterCode = '';
		var getterCode = '';
		if (function_decl.funcname.startsWith('رد')) {
			// getter function
			getterCode = `Object.defineProperty(${function_decl.objname}.prototype,'${function_decl.funcname}',{get: function() {return this.${function_decl.funcname}();},configurable:true});`;
		}
		if (function_decl.funcname.startsWith('خد')) {
			// setter function
			setterCode = `Object.defineProperty(${function_decl.objname}.prototype,'${function_decl.funcname}',{set: function (value) {this.${function_decl.funcname}(value);},configurable:true});`;
		}
		*/
		
		if (funcSymb.isShortcut()) {
			var result = function_decl.objname + '.prototype.' + function_decl.funcname + '=' + function_decl.objname + '.prototype.' + funcSymb.myShortcut + ';';
			result += function_decl.objname + '.' + function_decl.funcname + '=' + function_decl.objname + '.' + funcSymb.myShortcut + ';';
			$$ = result;
		} else {
			var asyncStr = funcSymb.isAwait ? 'async ' : '';
			$$ = function_decl.objname + '.prototype.' + function_decl.funcname + '=' + function_decl.objname + '.' + function_decl.funcname + '=' + asyncStr + 'function' + function_decl.value + body_block;
		}
	}
	;
	
function_ret
	: AS type_decl {
		ErrorManager.setContext(@1, context.filePath);
		// $2 = { type, subtype }
		var funcSymb = yy.funcStack[yy.funcStack.length-1];
		funcSymb.typeSymbol = yy.symbolScopes.getSymbByName($2.type);
		funcSymb.isArray = $2.isArray;
		$$ = {
			symb: funcSymb//.typeSymbol
		}
	}
	| /* empty */ {
		$$ = {
			symb: Symbol.SYSTEMTYPES['فارغ']
		}
	}
	;
function_decl
	: function_decl_name function_decl_params {
		$$ = {
			funcname: $1.funcname,
			exportStr: $1.isExport ? 'export ' : '',
			params: $2
		}
	}
	;
function_decl_name
	: DECL IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		ErrorManager.setFunc($2);
		var mySymb = yy.symbolScopes.declareSymbol($2, 'فارغ');
		
		yy.selfStack.push(mySymb);
		yy.funcStack.push(mySymb);
		yy.symbolScopes.enter();	
		
		$$ = {
			funcname: $2,
			isExport: !$2.startsWith('_'),
		}
	}
	;
function_decl_params
	: '(' param_list ')' {
		$$ = '(' + $2 + ')';
	}
	;
	
subfunc_decl
	: subfunc_decl_name function_decl_params {
		$$ = {
			funcname: $1.funcname,
			objname: $1.objname,
			value: $2
		}
	}
	;
subfunc_decl_name
	: DECL IDENTIFIER '.' IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		ErrorManager.setFunc($2 + '.' + $4);
		var mySymb = yy.symbolScopes.getSymbByName($2);
		yy.selfStack.push(mySymb);
		yy.symbolScopes.enter();
		var mySymb2 = yy.symbolScopes.createSymbol($4, 'فارغ');
		mySymb.addMember(mySymb2);
		yy.funcStack.push(mySymb2);
		$$ = {
			funcname: $4,
			objname: $2
			//value: $2 + '.prototype.' + $4 + '=' + $2 + '.' + $4 + '=' + async + 'function'
		}
	}
	;
param_list
	: /* empty */ { $$ = ''; }
	| param {
		ErrorManager.setContext(@1, context.filePath);
		$$ = $1;
	}
	| param_list '،' param {
		ErrorManager.setContext(@1, context.filePath);
		$$ = $1 + ',' + $3;
	}
	;
param
	: param_def {
		var funcSymb = yy.funcStack[yy.funcStack.length-1];
		funcSymb.args.push({
			symb: $1.symb,
			init: $1.init
		});
		$$ = $1.value;
	}
	| DALA IDENTIFIER is_param_opt dala_params function_ret  {
		var funcSymb = yy.funcStack[yy.funcStack.length-1];
		var symb = yy.symbolScopes.declareSymbol($2, 'دالة');
		funcSymb.args.push({
			symb: symb,
			init: $3
		});
		$$ = $2;
	}
	| STRUCT IDENTIFIER is_param_opt '{' has_list '}' {
		var funcSymb = yy.funcStack[yy.funcStack.length-1];
		var symb = yy.symbolScopes.declareSymbol($2, null, false, false);
		symb.isStruct = true; // bad but legacy
		funcSymb.args.push({
			symb: symb,
			init: $3
		});
		// $5 has_list is an array of symbols
		var symbols = $5;
		symbols.forEach((s) => {
			symb.addMember(s);
		});
		$$ = $2;
	}
	;
is_param_opt
	: {
		/* empty */
		$$ = false;
	}
	| '؟' {
		$$ = true;
	}
	;
dala_params
	: '(' dala_param_types ')' {
		$$ = "";
	}
	;
dala_param_types
	: /* empty */ {
		$$ = "";
	}
	| type_decl {
		yy.symbolScopes.getSymbByName($1.type);
		$$ = "";
	}
	| dala_param_types '،' type_decl {
		yy.symbolScopes.getSymbByName($3.type);
		$$ = "";
	}
	;
////


////
body_block
	: ':' statement_list END {
		ErrorManager.setContext(@1, context.filePath);
		yy.symbolScopes.exit();
		$$ = '{' + $2.filter(Boolean).join(';') + '}';
	}
	| ':' /* empty */ END {
		ErrorManager.setContext(@1, context.filePath);
		yy.symbolScopes.exit();
		$$ = '{}';
	}
	;
////


////
super_call
    : SUPER IDENTIFIER '(' arg_list ')' {
		ErrorManager.setContext(@1, context.filePath);
		var superSymb = yy.symbolScopes.getSymbByName($2);
		var selfSymb = yy.selfStack[yy.selfStack.length-1];
		selfSymb.mySuper = $2;
		
		// check args
		var paramValues = superSymb.checkArgs($4);

		// copy super members to self members
		// superSymb.copyMembersTo(selfSymb);
		selfSymb.superSymbol = superSymb;
		selfSymb.isClass = true;
		selfSymb.typeSymbol = selfSymb; // change type to itself

		// if this class already shortcuts, then don't call super()
		if (selfSymb.isShortcut()) {
			$$ = '';
		} else {
			$$ = 'super(' + $4 + ')';
		}
    }
    ;
////


////
shortcuts_call
	: SHORTCUTS IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		var selfSymb = yy.selfStack[yy.selfStack.length-1];
		var funcSymb = yy.funcStack[yy.funcStack.length-1];
		funcSymb.myShortcut = $2;
		if (selfSymb.name == funcSymb.name) { // we are in a class
			selfSymb.myShortcut = $2;
			var superSymb = yy.symbolScopes.getSymbByName($2);
			// TODO: for now we grant that when a func shortcuts then its a class
			selfSymb.isClass = true;
			selfSymb.typeSymbol = selfSymb; // change type to itself
			// if already have members, this means we used a has or extends before shortcuts > error
			if (selfSymb.members.length) {
				ErrorManager.error('يجب ئن تكون صيغة يختصر كئول سطر في المجموعة');
			}
			// copy origi members to self members if we are in a class
			superSymb.copyMembersTo(selfSymb);
		} else { // we are in a subfunction
			if (!selfSymb.isShortcut()) {
				// parent not shortcuting
				selfSymb.checkMember($2);
			} else {
				// parent have a shortcut
				var superSymb = yy.symbolScopes.getSymbByName(selfSymb.myShortcut);
				superSymb.checkMember($2);
			}
		}
	}
	;
////



////
has_statement
	: HAS has_list {
		ErrorManager.setContext(@1, context.filePath);
		var selfSymb = yy.selfStack[yy.selfStack.length-1];
		selfSymb.isClass = true; // has keyword makes this a class
		selfSymb.typeSymbol = selfSymb; // change type to itself
		
		var thisStr = 'this';
		if (selfSymb.isShortcut()) {
			thisStr = selfSymb.name + '.prototype';
		}
		var result = ''; // will contain setter, getter output for the property
		
		// $2 has_list is an array of symbols
		var symbols = $2;
		symbols.forEach((symb) => {
			selfSymb.addMember(symb);
			if (symb.isShortcut()) {
				// declare setters & getters
				var name = symb.myShortcut;
				var getterCode = `return this.${name}`;
				var setterCode = `this.${name} = value;`;
				result += `Object.defineProperty(${selfSymb.name}.prototype, '${symb.name}', {get: function() {${getterCode}}, set: function(value) {${setterCode}} });`;
			}
		});
		$$ = result;
	}
	;
has_list
	: /* empty */ { 
		$$ = []; 
	}
	| has_list_elements {
		$$ = $1;
	}
	;
has_list_elements
	: has_list_element {
		$$ = [$1];
	}
	| has_list_elements '،' has_list_element {
		$1.push($3);
		$$ = $1;
	}
	;
has_list_element
	: param_decl {
		$$ = $1.symb
	}
	| param_decl SHORTCUTS IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		var selfSymb = yy.selfStack[yy.selfStack.length-1];
		if (!selfSymb.isShortcut()) {
			// parent not shortcuting
			selfSymb.checkMember($3);
		} else {
			// parent have a shortcut
			var superSymb = yy.symbolScopes.getSymbByName(selfSymb.myShortcut);
			superSymb.checkMember($3);
		}
		$1.symb.myShortcut = $3;
		$$ = $1.symb;
	}
	;

	
////
param_def
	: param_decl {
		$$ = {
			symb: $1.symb,
			value: $1.value,
			init: $1.init
		}
	}
	| param_decl param_init {
		var paramSymb = $1.symb;
		var initSymb = $2.symb;
		if (!initSymb.canBeAssignedTo(paramSymb)) {
			ErrorManager.error("محاولة ئسناد " + initSymb.toString() + " ئلا " + paramSymb.toTypeString());
		}
		$$ = {
			symb: paramSymb,
			value: $1.value + '=' + $2.value,
			init: true
		}
	}
	;
param_decl
	: IDENTIFIER is_param_opt {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			symb: yy.symbolScopes.declareSymbol($1, 'منوع'),
			value: $1,
			init: $2
		}
	}
	| IDENTIFIER IDENTIFIER is_param_opt {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			symb: yy.symbolScopes.declareSymbol($2, $1),
			value: $2,
			init: $3
		}
	}
	| IDENTIFIER '[' ']' IDENTIFIER is_param_opt {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			symb: yy.symbolScopes.declareSymbol($4, $1, true /*isArray*/),
			value: $4,
			init: $5
		}
	}
	| ENUM IDENTIFIER is_param_opt '[' identifier_list ']' {
		ErrorManager.setContext(@1, context.filePath);
		var symb = yy.symbolScopes.declareSymbol($2, 'نوعتعداد');
		symb.isEnum = true; // bad but legacy
		symb.allowed = $5;
		$$ = {
			symb: symb,
			value: $2,
			init: $3
		}
	}
	;
param_init
	: '=' expression {
		$$ = $2;
	}
	;
identifier_list
	: IDENTIFIER {
		$$ = [$1]
	}
	| identifier_list '،' IDENTIFIER {
		$1.push($3);
		$$ = $1
	}
	;
////


////
var_declaration
    : DEF IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		// دع ب
		yy.symbolScopes.declareSymbol($2, 'منوع');
        $$ = 'let ' + $2; 
    }
    | DEF IDENTIFIER '=' expression {
		ErrorManager.setContext(@1, context.filePath);
		// دع ب = 4
		var mySymb = yy.symbolScopes.declareSymbol($2, 'منوع', $4.symb.isArray);
		if ($4.symb.typeIs('نوعبنية')) {
			// mySymb is generic add struct memebers to it
			mySymb.members = $4.symb.members;
		}
        $$ = 'let ' + $2 + ' = ' + $4.value;
    }
	| IDENTIFIER IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		// عدد ب
		yy.symbolScopes.declareSymbol($2, $1);
		$$ = 'let ' + $2;
	}
	| IDENTIFIER '[' ']' IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		// عدد[] ب
		yy.symbolScopes.declareSymbol($4, $1, true);
		$$ = 'let ' + $4;
	}
	| IDENTIFIER IDENTIFIER '=' expression {
		ErrorManager.setContext(@1, context.filePath);
		// عدد ب = 4
		var mySymb = yy.symbolScopes.declareSymbol($2, $1);
		if (!$4.symb.canBeAssignedTo(mySymb)) {
			// type mismatch
			ErrorManager.error("محاولة ئسناد '" + $4.symb.toString() + "' ئلا '" + $1 + "'");
		}
		
		if ($4.symb.typeIs('نوعبنية')) {
			// expression is an object literal
			if (!mySymb.typeSymbol.isStruct) {
				// mySymb is generic add struct memebers to it
				mySymb.members = $4.symb.members;
			}
		}
		
		$$ = 'let ' + $2 + ' = ' + $4.value;
	}
	| IDENTIFIER '[' ']' IDENTIFIER '=' expression {
		ErrorManager.setContext(@1, context.filePath);
		// عدد ب = 4
		if (!Symbol.isGenericType($1) && $6.symb.typeIsNot($1)) {
			// type mismatch
			ErrorManager.error("محاولة ئسناد '" + $6.symb.toString() + "' ئلا '" + $1 + "'");
		}
		yy.symbolScopes.declareSymbol($4, $1, true);
		$$ = 'let ' + $4 + ' = ' + $6.value;
	}
    ;
////


////
say_statement
    : SAY expression {
        //$$ = $1 + '(' + $2.value + ')';
		$$ = 'console.log(' + $2.value + ')';
    }
    ;
////


////
wtype_expr
	: WTYPE expression {
		$$ = {
			symb: yy.symbolScopes.createSymbol('', 'نصية'),
			value: $2.getTypeName()
		}
	}
	;
////


////
return_statement
    : RETURN expression {
		ErrorManager.setContext(@1, context.filePath);
		var funcSymb = yy.funcStack[yy.funcStack.length-1];
		if (funcSymb.typeIs('فارغ')) {
			ErrorManager.warning("ئستخدام ئرجاع في وضيفة فارغة، سيتم التحويل ئلا منوع");
			// convert function return type to منوع
			funcSymb.typeSymbol = Symbol.SYSTEMTYPES['منوع'];
		}
		
		if (!$2.symb.canBeAssignedTo(funcSymb)) {
			ErrorManager.error("نوع الئرجاع " + $2.symb.toString() + " غير متوافق مع الوضيفة " + funcSymb.toString());
		}
		if ($2.symb.typeIs('نوعبنية')) {
			// expression is an object literal
			if (!funcSymb.typeSymbol.isStruct) {
				// funcSymb is generic add struct memebers to it
				funcSymb.members = $2.symb.members;
			}
		}
		$$ = 'return ' + $2.value; 
	}
    | RETURN {
		ErrorManager.setContext(@1, context.filePath);
		var funcSymb = yy.funcStack[yy.funcStack.length-1];
		if (funcSymb.typeIsNot('فارغ')) {
			ErrorManager.error("نوع الئرجاع غير متوافق مع الوضيفة " + funcSymb.toString());
		}
		$$ = 'return'; 
	}
    ;
////


////
while_statement
	: while_head body_block {
		$$ = $1 + $2;
	}
	;
while_head
	: WHILE expression { 
		yy.symbolScopes.enter();
		$$ = 'while (' + $2.value + ')';
	}
	;
////


////
for_in_statement
	: for_in_head body_block {
		$$ = $1 + $2;
	}
	;
for_in_head
	: FOR IDENTIFIER IN expression {
		ErrorManager.setContext(@1, context.filePath);
		yy.symbolScopes.enter();
		yy.symbolScopes.declareSymbol($2, $4.symb.typeSymbol.name);
		// TOREVIEW
		//if ($4.type == 'مصفوفة') {
			$$ = 'for (var ' + $2 + ' of ' + $4.value + ')';
		//} else {
			//$$ = 'for (var ' + $2 + ' in ' + $4.value + ')';
		//}
	}
	;
////


////
if_statement
	: if_head noend_block elif_clauses else_clause END {
		$$ = $1 + $2 + $3 + $4;
	}
	| if_head noend_block elif_clauses END {
		$$ = $1 + $2 + $3;
	}
	| if_head noend_block else_clause END {
		$$ = $1 + $2 + $3;
	}
	| if_head noend_block END {
		$$ = $1 + $2;
	}
	;
	
if_head
	: IF expression {
		yy.symbolScopes.enter();
		$$ = 'if (' + $2.value + ')';
	}
	;
	
elif_clauses
	: elif_head noend_block { $$ = $1 + $2 }
	| elif_clauses elif_head noend_block { $$ = $2 + $3 }
	;
	
elif_head
	: ELSE IF expression {
		ErrorManager.setContext(@1, context.filePath);
		yy.symbolScopes.enter();
		$$ = 'else if (' + $3.value + ')';
	}
	;
	
noend_block
	: ':' statement_list {
		ErrorManager.setContext(@1, context.filePath);
		yy.symbolScopes.exit();
		$$ = '{' + $2.filter(Boolean).join(';') + '}';
	}
	;
	
else_clause
	: else_head noend_block { $$ = $1 + $2 }
	;
	
else_head
	: ELSE {
		yy.symbolScopes.enter();
		$$ = 'else';
	}
	;
////


//// expressions ////

////
assignment
    : IDENTIFIER '=' expression {
		ErrorManager.setContext(@1, context.filePath);
		var mySymb = yy.symbolScopes.getSymbByName($1);
		if (!$3.symb.canBeAssignedTo(mySymb)) {
			// type mismatch
			ErrorManager.error("محاولة ئسناد " + $3.symb.toString() + " ئلا " + mySymb.toString());
		}
		if ($3.symb.typeIs('نوعبنية')) {
			// expression is an object literal
			if (!mySymb.typeSymbol.isStruct) {
				// mySymb is generic add struct memebers to it
				mySymb.members = $3.symb.members;
			}
		}
		$$ = {
			symb: mySymb,
			value: $1 + '=' + $3.value
		}
	}
    | member_access '=' expression {
		ErrorManager.setContext(@1, context.filePath);
		if ($1.symb) {
			var mySymb = $1.symb;
			if (!$3.symb.canBeAssignedTo(mySymb)) {
				ErrorManager.error("محاولة ئسناد " + $3.symb.toString() + " ئلا " + $1.symb.toString());
			}
			if ($3.symb.typeIs('نوعبنية')) {
				// expression is an object literal
				if (!mySymb.typeSymbol.isStruct) {
					// mySymb is generic add struct memebers to it
					mySymb.members = $3.symb.members;
				}
			}
		}
		$$ = {
			symb: $3.symb,
			value: $1.value + '=' + $3.value
		}
	}
    | array_access '=' expression {
		$$ = {
			symb: $3.symb,
			value: $1.value + '=' + $3.value
		}
	}
    ;
////


////
arithmetic
	// type of arithmetic is same as first operand
	// TODO, types should be the same, check it
    : expression '+' expression {
		$$ = {
			symb: $1.symb,
			value: $1.value + ' + ' + $3.value 
		}
	}
    | expression '-' expression { 
		$$ = {
			symb: $1.symb,
			value: $1.value  + ' - ' + $3.value 
		}
	}
    | expression '×' expression { 
		$$ = {
			symb: $1.symb,
			value: $1.value  + ' * ' + $3.value 
		}
	}
    | expression '÷' expression { 
		$$ = {
			symb: $1.symb,
			value: $1.value  + ' / ' + $3.value 
		}
	}
    ;
////


////
comparison
    : expression EQ expression {
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'),
			value: $1.value + ' == ' + $3.value 
		}
	}
    | expression NEQ expression { 
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'),
			value: $1.value + ' != ' + $3.value 
		}
	}
    | expression LT expression { 
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'),
			value: $1.value + ' < ' + $3.value
		}
	}
    | expression LTE expression { 
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'),
			value: $1.value  + ' <= ' + $3.value
		}
	}
    | expression GT expression { 
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'),
			value: $1.value + ' > ' + $3.value
		}
	}
    | expression GTE expression { 
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'),
			value: $1.value + ' >= ' + $3.value
		}
	}
    ;
////


////
logical
	: expression AND expression {
		//if (!$3.symb.canBeAssignedTo($1.symb, /*printerror*/ false)) {
		if ($1.symb.getTypeName() != $3.symb.getTypeName()) {
			ErrorManager.error("عملية وو بين معاملان غير متوافقان " + $1.symb.toTypeString() + '،' + $3.symb.toTypeString());
		}
		$$ = {
			symb: $1.symb,
			value: $1.value + ' && ' + $3.value
		}
	}
	| expression OR expression {
		//if (!$3.symb.canBeAssignedTo($1.symb, /*printerror*/ false)) {
		if ($1.symb.getTypeName() != $3.symb.getTypeName()) {
			ErrorManager.error("عملية ئو بين معاملان غير متوافقان " + $1.symb.toTypeString() + '،' + $3.symb.toTypeString());
		}
		$$ = {
			symb: $1.symb,
			value: $1.value + ' || ' + $3.value
		}
	}
	;
////

	
////
ternary
    : expression IF expression ELSE expression {
		// TODO: add probable type $1 or $5
		// for now type checking will be ignored for ternary
        $$ = {
			symb: Symbol.SYSTEMTYPES['مجهول'],
			value: $3.value + ' ? ' + $1.value + ' : ' + $5.value
		}
    }
    ;
////


////
function_call
    : IDENTIFIER '(' arg_list ')' {
		ErrorManager.setContext(@1, context.filePath);
		var symb = yy.symbolScopes.getSymbByName($1);
		// check args
		var paramValues = symb.checkArgs($3);
		// check if class or function
		var newStr = symb.isClass ? 'new ' : '';
		$$ = {
			symb: symb,
			value: newStr + $1 + '(' + paramValues.join(', ') + ')'
		}
	}
    | member_access '(' arg_list ')' {
		var symb = $1.symb;
		// check args
		var paramValues = symb.checkArgs($3);
		$$ = {
			symb: symb,
			value: $1.value + '(' + paramValues.join(', ') + ')'
		}
	}
	| array_access '(' arg_list ')' {
		ErrorManager.setContext(@1, context.filePath);
		ErrorManager.warning("تجاهل فحص المعطيين لئستدعائ وضيفة من مصفوفة");
		$$ = {
			symb: $1.symb,
			value: $1.value + '(' + $3.map(item => item.value).join(', ') + ')'
		}
	}
	| '(' expression ')' '.' IDENTIFIER '(' arg_list ')' {
		ErrorManager.setContext(@1, context.filePath);
		var symb = $2.symb.typeSymbol.checkMember($5);
		// check args
		var paramValues = symb.checkArgs($7);
		// check if class or function
		// var newStr = symb.isClass ? 'new ' : '';
		$$ = {
			symb: symb,
			value: '(' + $2.value + ').' + $5 + '(' + paramValues.join(', ') + ')'
		}
	}
    ;
arg_list
	: /* empty */ { $$ = []; }
	| func_arg {
		$$ = [{
			symb: $1.symb,
			value: $1.value,
			name: $1.name
		}]
	}
	| arg_list '،' func_arg {
		$1.push({
			symb: $3.symb,
			value: $3.value,
			name: $3.name
		})
		$$ = $1;
	}
	;
func_arg
	: expression {
		$$ = {
			symb: $1.symb,
			value: $1.value,
			name: null,
		}
	}
	| lambda_expr {
		$$ = {
			symb: $1.symb,
			value: $1.value,
			name: null
		}
	}
	| IDENTIFIER ':' expression {
		$$ = {
			symb: $3.symb,
			value: $3.value,
			name: $1
		}
	}
	| IDENTIFIER ':' lambda_expr {
		$$ = {
			symb: $3.symb,
			value: $3.value,
			name: $1
		}
	}
	;
////


////
lambda_expr
	: declare_dala function_decl_params ':' expression {
		yy.symbolScopes.exit();
		$$ = {
			symb: $4.symb,
			value: $2 + "=>" + $4.value
		}
	}
	;
declare_dala
	: DALA {
		yy.symbolScopes.enter();
	}
	;
////


////
await_expr
    : AWAIT expression {
		ErrorManager.setContext(@1, context.filePath);
		var funcSymb = yy.funcStack[yy.funcStack.length-1];
		funcSymb.isAwait = true;
        $$ = {
			symb: $2.symb,
			value: 'await ' + $2.value
		}
    }
    ;
////
	

////
member_access
    : IDENTIFIER '.' IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		var symb = yy.symbolScopes.getSymbByName($1);
		var memberSymb = symb.checkMember($3);	
		$$ = {
			symb: memberSymb,
			value: $1 + '.' + $3 
		}
	}
    | function_call '.' IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		var symb = $1.symb.typeSymbol;
		var memberSymb = symb.checkMember($3);
		$$ = {
			symb: memberSymb,
			value: $1.value + '.' + $3 
		}; 
	}
    | member_access '.' IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		//var type = $1.type;
		var symb = $1.symb;
		var memberSymb;
		if (symb.typeIs('نوعبنية')) {
			// for object literals, we take symb name as member base
			memberSymb = symb.checkMember($3);
		} else {
			// for other variables, we take their symb type as member base
			//var typeSymb = yy.symbolScopes.getSymbByName(symb.type);
			var typeSymb = symb.typeSymbol;
			memberSymb = typeSymb.checkMember($3);
		}
		$$ = {
			symb: memberSymb,
			value: $1.value + '.' + $3 
		};
	}
	| array_access '.' IDENTIFIER {
		$$ = {
			symb: $1.symb,
			value: $1.value + '.' + $3
		};
	}
    | SELF '.' IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		var selfSymb = yy.selfStack[yy.selfStack.length-1];
		var symb = selfSymb.checkMember($3);
		$$ = {
			symb,
			value: 'this.' + $3
		}
	}
	;
/*
	| '(' expression ')' '.' IDENTIFIER {
		ErrorManager.setContext(@1, context.filePath);
		var symb = $2.symb;
		var memberSymb;
		if (symb.typeIs('نوعبنية')) {
			// for object literals, we take symb name as member base
			memberSymb = symb.checkMember($5);
		} else {
			// for other variables, we take their symb type as member base
			//var typeSymb = yy.symbolScopes.getSymbByName(symb.type);
			var typeSymb = symb.typeSymbol;
			memberSymb = typeSymb.checkMember($5);
		}
		$$ = {
			symb: memberSymb,
			value: $2.value + '.' + $5 
		};
	}
*/
////
	
	
////
array_access
	: IDENTIFIER '[' expression ']' {
		ErrorManager.setContext(@1, context.filePath);
		var symb = yy.symbolScopes.getSymbByName($1);
		if (!symb.isIterable()) {
			ErrorManager.error("تعدر ولوج عنصر مصفوفة من " + symb.toString());
		}
		var unknownType = Symbol.SYSTEMTYPES['مجهول'];
		$$ = {
			symb: symb.isArray ? symb.typeSymbol : unknownType,
			value: $1 + '[' + $3.value + ']'
		}
	}
	| SELF '[' expression ']' {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			symb: Symbol.SYSTEMTYPES['مجهول'],
			value: 'this[' + $3.value + ']'
		}
	}
    | member_access '[' expression ']' {
		ErrorManager.setContext(@1, context.filePath);
		var symb = $1.symb;
		if (!symb.isIterable()) {
			ErrorManager.error("تعدر ولوج عنصر مصفوفة من " + symb.toString());
		}
		var unknownType = Symbol.SYSTEMTYPES['مجهول'];
		$$ = {
			// type: symb.subtype, // || 'مجهول'
			//yy.symbolScopes.getSymbByName(symb.subType),
			symb: symb.isArray ? symb.typeSymbol : unknownType, 
			value: $1.value + '[' + $3.value + ']'
		}
	}
    ;
////


////
object_literal
    : '{' property_list '}' {
		ErrorManager.setContext(@1, context.filePath);
		var symbs = $2.symb; // these are symbols of object properties
		var symb = new Symbol('', yy.symbolScopes.getSymbByName('نوعبنية'));

		symbs.forEach((sy) => {
			symb.addMember(sy);
		});
		
		$$ = {
			symb: symb,
			value: '{' + $2.value + '}'
		}
	}
	| '{' /* empty */ '}' {
		ErrorManager.setContext(@1, context.filePath);
		var symb = new Symbol('');
		symb.typeSymbol = new Symbol('', yy.symbolScopes.getSymbByName('نوعبنية'));
		$$ = {
			symb: symb,
			value: '{}'
		}
	}
    ;	
property_list
    : property { 
		$$ = {
			symb: [$1.symb],
			value: $1.value 
		}
	}
    | property_list '،' property {
		$$ = {
			symb: $1.symb.concat($3.symb),
			value: $1.value + ', ' + $3.value
		}
	}
    ;
property
    : IDENTIFIER ':' expression {
		ErrorManager.setContext(@1, context.filePath);
		var symb = yy.symbolScopes.createSymbol($1);
		symb.typeSymbol = $3.symb.typeSymbol;
		$$ = {
			symb: symb,
			value: $1 + ': ' + $3.value
		}
	}
    | STRING ':' expression {
		ErrorManager.setContext(@1, context.filePath);
		var symb = yy.symbolScopes.createSymbol($1);
		symb.typeSymbol = $3.symb.typeSymbol;
		$$ = {
			symb: symb,
			value: $1 + ': ' + $3.value
		}
	}
    ;
////


////
array_elements
    : /* empty */ {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منوع'),
			value: []
		}
		//ErrorManager.error("حدد نوع المصفوفة");
		//$$ = "";
	}
	| expression {
        $$ = {
			symb: $1.symb,
			value: [ $1.value ]
		}
    }
    | array_elements '،' expression {
		ErrorManager.setContext(@1, context.filePath);
        $1.value.push($3.value);
		if (!$3.symb.canBeAssignedTo($1.symb)) {
			ErrorManager.error("نوعين غير متجانسين في المصفوفة");
		}
        $$ = {
			symb: $1.symb,
			value: $1.value
		}
    }
    ;
////


////
type_decl
	: IDENTIFIER {
		$$ = {
			type: $1,
			isArray: false
		}
	}
	| IDENTIFIER '[' ']' {
		$$ = {
			type: $1,
			isArray: true
		}
	}
	;
////


////
spread_operator
	: SPREAD expression {
		$$ = '...' + $2.value;
	}
	;
////


////
logical_negation
    : NOT expression {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'),
			value: '!' + $2.value
		}
	}
    ;
////


////
in_expression
	: expression IN expression {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'),
			value: $1.value + ' in ' + $3.value
		}
	}
	;
////


////
type_casting
	: AS type_decl {
		ErrorManager.setContext(@1, context.filePath);
		var symb = yy.symbolScopes.getSymbByName($2.type);
		// $2.isArray
		$$ = {
			symb: symb,
			isArray: $2.isArray
		}
	}
	;
////


////
parenthesis_expr
	: '(' expression ')' {
		$$ = {
			symb: $2.symb,
			value: '(' + $2.value + ')'
		};
	}
	;
////


////
expression
    : logical {
		$$ = {
			symb: $1.symb,
			value: $1.value
		}
	}	
	| arithmetic {
		$$ = {
			symb: $1.symb,
			value: $1.value
		}
	}
    | comparison {
		$$ = {
			symb: $1.symb,
			value: $1.value
		} 
	}
	| ternary { 
		$$ = {
			symb: $1.symb,
			value: $1.value
		} 
	}
    | function_call {
		$$ = { 
			symb: $1.symb, 
			value: $1.value 
		}; 
	}
	| function_call type_casting {
		// function_call
		var symb = $1.symb.duplicate($2.symb);
		symb.isArray = $2.isArray;
		$$ = {
			symb: symb,
			value: $1.value
		};
	}
    | await_expr {
		// could've done $$=$1 but that's confusing
		$$ = {
			symb: $1.symb,
			value: $1.value
		}
	}
	| member_access {
		$$ = {
			symb: $1.symb,
			value: $1.value
		}
	}
	| member_access type_casting {
		// member_access
		var symb = $1.symb.duplicate($2.symb);
		symb.isArray = $2.isArray;
		$$ = {
			symb: symb,
			value: $1.value
		}
	}
    | array_access {
		$$ = { 
			symb: $1.symb, 
			value: $1.value
		} 
	}
	| array_access type_casting {
		var symb = $1.symb.duplicate($2.symb);
		symb.isArray = $2.isArray;
		$$ = {
			symb: symb,
			value: $1.value
		}
	}
    | object_literal {
		$$ = {
			symb: $1.symb,
			value: $1.value
		}; 
	}
	| spread_operator {
		$$ = {
			symb: Symbol.SYSTEMTYPES['مجهول'],
			value: $1
		}
	}
	| '[' array_elements ']' {
		ErrorManager.setContext(@1, context.filePath);
		var elemTypeSymb = $2.symb.typeSymbol;
		var symb = yy.symbolScopes.createSymbol('', elemTypeSymb.name, true /*isArray*/);
		$$ = {
			symb: symb,
			value: '[' + $2.value.join(', ') + ']'
		}
	}
	| '[' array_elements ']' type_casting {
		ErrorManager.setContext(@1, context.filePath);
		var elemTypeSymb = $2.symb.typeSymbol;
		var symb = yy.symbolScopes.createSymbol('', $4.symb.name, true /*isArray*/);
		$$ = {
			symb: symb,
			value: '[' + $2.value.join(', ') + ']'
		}
	}
    | logical_negation {
		$$ = { 
			symb: $1.symb, // منطق 
			value: $1.value 
		}; 
	}
	| parenthesis_expr {
		$$ = {
			symb: $1.symb,
			value: '(' + $1.value + ')'
		};
	}
	| '(' expression ')' type_casting {
		var symb = $2.symb.duplicate($4.symb);
		symb.isArray = $4.isArray;
		$$ = {
			symb: symb,
			value: '(' + $2.value + ')'
		}
	}
	| in_expression {
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'),
			value: $1.value
		}
	}
    | IDENTIFIER {
		var symb = yy.symbolScopes.getSymbByName($1);
		$$ = {
			symb: symb,
			value: $1
		}; 
	}
	| IDENTIFIER type_casting {
		var symb = yy.symbolScopes.getSymbByName($1);
		var mySymb = symb.duplicate($2.symb);
		mySymb.isArray = $2.isArray;
		$$ = {
			symb: mySymb,
			value: $1
		}; 
	}
    | NUMBER {
		$$ = {
			symb: yy.symbolScopes.getSymbByName('عدد'),
			value: toEnDigit($1)
		}
	}
    | TRUE {
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'), 
			value: 'true'
		}; 
	}
    | FALSE {
		$$ = {
			symb: yy.symbolScopes.getSymbByName('منطق'),
			value: 'false'
		}; 
	}
    | NULL {
		$$ = {
			symb: Symbol.SYSTEMTYPES['عدم'],
			value: 'null'
		}; 
	}
    | STRING {
		ErrorManager.setContext(@1, context.filePath);
		//inlineParse($2.replace('<x-', '<'), context, yy)
		const regex = /{(.*?)}/g;
		var match;
		
		while ((match = regex.exec($1)) !== null) {
			let s = match[1];
			if (s != '') {
				inlineParse(s, context, yy);
			}
		}
		var val = $1.replaceAll('"', '').replaceAll("'", "");
		var symb = yy.symbolScopes.createSymbol(val, 'نصية');
		symb.isLiteral = true;
		$$ = {
			symb: symb,
			value: $1.replaceAll('"', '`').replaceAll('{', '${')
		}
	}
    | SELF {
		ErrorManager.setContext(@1, context.filePath);
		$$ = {
			symb: yy.selfStack[yy.selfStack.length-1],
			value: 'this'
		}			
	}
	| SELF type_casting {
		ErrorManager.setContext(@1, context.filePath);
		var symb = yy.selfStack[yy.selfStack.length-1];
		var mySymb = symb.duplicate($2.symb);
		mySymb.isArray = $2.isArray;
		$$ = {
			symb: mySymb,
			value: 'this'
		}; 
	}
    | JNX {
		ErrorManager.setContext(@1, context.filePath);
		var result = $1.replace('(', '').replace(')', '') // تعويض القوسين بعلامات ئقتباس
					.replaceAll('\t','') // حدف الفراغين
					.replace(/(\r\n|\n|\r)/gm,''); // حدف رجعات السطر
					//.replaceAll('{', '${'); // تعويض متغيرين القالب
		result = processJNX(result, context, yy);
		$$ = {
			symb: yy.symbolScopes.getSymbByName('نصية'),
			value: result
		}
	}
    ;

%%

module.exports = createParser;