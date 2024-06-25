/* lexical grammar */
%lex

%{
	var line_number = 1; // Track line numbers
%}

%%

/* [^\S\r\n]+ skip whitespace but not newline */

\s+													/* skip whitespace */
"#"[^\n]*											/* skip comments */
\n													{ line_number++; return 'NEWLINE' }

\([\n\r\s]*\<(?:[^)\\]|\\[\s\S])*\>[\n\r\s]*\)		return 'JNX'

"ئدا"												return 'IF'
"وئلا"												return 'ELSE'
"تم"												return 'END'
"صحيح"												return 'TRUE'
"خطئ"												return 'FALSE'
"عدم"												return 'NULL'
"دع"												return 'DEF'
"ئعلن"												return 'DECL'
"=="												return 'EQ'
"لا="												return 'NEQ'
"<="												return 'LTE'
">="												return 'GTE'
"<"													return 'LT'
">"													return 'GT'
"وو "												return 'AND'
"ئو "												return 'OR'
"+"													return '+'
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
	//const _parser = require('./jparser');
	const globalSymb = { name: 'العام', type: 'العام', members: {} };
	var importPath;
	var result;
	var mustImp = ["كائن", "منطق", "نص", "مصفوفة"]; // automatic imports
	
	
	function createParser (yy) {
		const parser = new Parser();
		// read .env file
		const mainFilePath = process.argv[2];
		const projectPath = path.dirname(mainFilePath);
		const envpath = path.join(projectPath, "/.سياق");
		var scope = {
			'سياق': {name: 'سياق', type: 'سياق', members: {} },
			'العام': globalSymb
		};
		if (!yy) { // no yy, means new parser without context
			var env = "";
			try {
				env = fs.readFileSync(envpath, 'utf8');
			} catch (e) {}
			try {
				env = JSON.parse('{' + env.replaceAll('\n', ',') + '}');
			} catch (e) {
				throw new Error('علا .سياق ئن يكون بصيغة: "متغير": "قيمة"');
			}
			for (var key in env) {
				if (env[key] == "") { 
					// empty context vars are considered nulls
					env[key] = null;
				}
				scope["سياق"].members[key] = {name: key, type: "نص", members: {}}
			}
		}
		parser.yy = {
			scopeStack: yy ? yy.scopeStack : [scope], // symbol table
			selfStack: yy ? yy.selfStack : [], // holder stack for current SELF object symbol
			functionStack: yy ? yy.functionStack : [], // holder stack for current function
			mysuper: '', // super holder if current function inherits
			myshortcut: '', // shortcut holder if current function shortcuts another
			isawait: false, // if current function contains await, TODO: unused, remove it
			env: JSON.stringify(env) // environment variables (سياق)
		}
		
		parser.originalParse = parser.parse;
		parser.parse = function (input, ctx) {
			// do not add global imports on inlineparses
			input = (ctx.inlineParse ? '' : globalImport(ctx.filePath)) + input;
			return parser.originalParse(input, ctx);
		}
		
		return parser;
	}
%}

%{
	// override default error handler
    parser.parseError = function (str, hash) {
		let errorMessage = "خطئ نحوي سطر: " + hash?.loc?.first_line;
		errorMessage += "\nلم يتوقع: '" + hash.text + "'";
		errorMessage += "\n" + str;
        throw new Error(errorMessage);
    }
%}

%{
	// symbol table logic
	
	function enterScope(yy) {
		yy.scopeStack.push({});
	}
	
	function exitScope(yy) {
		yy.scopeStack.pop();
	}
	
	function declareSymbol(yy, ctx, name, type, members = {}, isClass = false) {
		var currentScope = yy.scopeStack[yy.scopeStack.length-1];
		if (currentScope[name]) {
			throw new Error("ال" + type + " '" + name + "' معررف مسبقا.");
		}
		// isClass is false by default
		// a function becomes class when having: has, super, extends, shortcut?
		if (name != type) {
			// this is a variable of type
			var smb = checkSymbol(yy, type, ctx);
			members = smb.members;
		}
		currentScope[name] = { name: name, type: type, members: members, isClass: isClass };
		return currentScope[name];
	}
	
	function checkSymbol(yy, name, ctx) {
		if (['مجهول', 'فارغ', 'كائن', 'منوع', 'عدم'].includes(name)) {
			return { type: name, name: name }
		}
		for (var i=yy.scopeStack.length-1; i >=0; i--) {
			if (yy.scopeStack[i][name]) {
				return yy.scopeStack[i][name];
			}
		}
		console.log(ctx);
		throw new Error("سطر: " + ctx?.first_line + "\n" + "الئسم '" + name + "' غير معروف.");
	}
	
	function declareMember(yy, object, member, ctx) {
		let name = object.name || object;		
		let symb = checkSymbol(yy, name, ctx);
		if (symb.members[member]) {
			throw new Error("الئسم '" + member + "' معررف مسبقا في الكائن " + name + "'.");
		}
		checkSymbol(yy, member.type, ctx);
		symb.members[member.name] = { name: member.name, type: member.type, members: (member.members || {}) };
		return symb.members[member.name];
	}
	
	function checkMember(yy, object, member, ctx) {
		let name = object.name || object;
		var symb;
		if (object.type && object.type == 'كائن') {
			symb = object; // when its an object literal, we don't check type symbol, we only check variable members
		} else {
			symb = checkSymbol(yy, name, ctx); // check symbol of base object
		}
		if (symb.type && ['مجهول', 'منوع'].includes(symb.type)) {
			// غض الطرف عن النوعين مجهول ومنوع
			return {type: symb.type, name: member};
		}
		if (!symb.members[member]) {
			if (name == 'العام') {
				throw new Error("سطر: " + ctx?.first_line + "\n" + "الئسم '" + member + "' غير معروف.");
			} else {
				throw new Error("سطر: " + ctx?.first_line + "\n" + "الئسم '" + member + "' غير معروف في الكائن " + name + " <" + symb.type + ">.");
			}
		}
		return symb.members[member];
	}
%}


%{
	// imports logic
	
	// unused function TO REMOVE
	function checkImportFile(s) {
		var splited = s.split('/');
		var lastPart = splited[splited.length-1];
		if (!lastPart.includes('.')) {
			// no extension add default
			return s + '/' + lastPart + '.جني';
		}
		return s;
	}
	
	function importExists(s, context) {
		// find a file like ./name.js
		// or like /name/name.js
		//var myFileImport = myImport.replace('.', '/') + '.js';
		var splitted = s.split('.');
		var name = splitted[splitted.length-1]; // last part is file name
		var myImport = s.replace('.', '/');
		
		//imports are relative to project path not current file
		//var fileBase = path.dirname(context.filePath);
		var fileBase = context.projectPath;
		
		var filePath1 = path.join(fileBase, myImport + '.جني');
		var filePath2 = path.join(fileBase, myImport, name + '.جني');

		try {
			fs.statSync(filePath1);
			return {
				exists: true,
				path: filePath1,
				relativePath: '.' + filePath1.replace(context.projectPath, '')
				//relativePath: './' + myImport + '.جني'
			}
		} catch (err) {}
		try {		
			fs.statSync(filePath2);
			return {
				exists: true,
				path: filePath2,
				relativePath: '.' + filePath2.replace(context.projectPath, '')
				//relativePath: './' + path.join(myImport, name + '.جني')
			}
		} catch (err) {}
		return {
			exists: false
		}
	}
	
	function processImport(yy, meta, context, importString, importSpecifier) {
		var fileBase = path.dirname(context.filePath);
		var importPath = path.join(context.projectPath, importString);
		var scope = readAndParseFile(importPath, context);
		if (!scope) {
			process.exit();
		}
		if (importSpecifier.find == "all") {
			var mysymb = declareSymbol(yy, null, importSpecifier.add, importSpecifier.add);
			for (const key in scope) {
				var symb = scope[key];
				declareMember(yy, mysymb, symb, meta);
			}
		} else {
			importSpecifier.find.forEach((find) => {
				var symb = scope[find];
				if (!symb) {
					throw new Error ("الئسم " + find + " غير معروف في الوحدة '" + importString + "'")
				}
				declareSymbol(yy, null, symb.name, symb.type, symb.members, symb.isClass);
			});	
		}
	}

    // Function to read and parse imported file
    function readAndParseFile(filePath, context) {
		filePath = path.resolve(filePath);
		let fileContent;
		try {
			fileContent = fs.readFileSync(filePath, 'utf8');
		} catch (e) {
			let projectBasePath = path.dirname(context.projectPath);
			throw new Error("تعدر ئيراد الوحدة: " + filePath);
		}
		fileContent = fileContent; // + globalImport(filePath);
		try {
			const createParser = require('./jparser');
			_parser = createParser();
			const symTable = _parser.parse(fileContent, {
				filePath: filePath,
				projectPath: path.resolve(context.projectPath),
				outPath: context.outPath
			});
			return symTable;
			//console.log(symTable);
			//symbolTable = { ...symbolTable, ...symTable }
			//await fs.promises.writeFile(outFilePath, result, { flag: 'w+' });
		} catch (e) {
			let projectBasePath = path.dirname(context.projectPath);
			console.error("ملف: " + filePath.replace(projectBasePath, ''));
			console.error(e);
			return null;
		}
    }
	
	function inlineParse(s, context, yy) {
		if (!s.endsWith('؛')) {
			s += '؛';
		}
		const createParser = require('./jparser');
		_parser = createParser(yy);
		const result = _parser.parse(s, {
			inlineParse: true,
			projectPath: path.resolve(context.projectPath),
			outPath: context.outPath
		});
		return result;
	}
	
	function isUrlImport(s) {
		//return s.startsWith('//');
		return s.startsWith('"') || s.startsWith("'");
	}
	
	function isRelativeImport(s) {
		return s.startsWith('.');
	}
	
	function isAbsoluteImport(s) {
		return !s.startsWith('/') && !s.startsWith('//') && !s.startsWith('.')
	}
	
	function globalImport(filePath) {
		let filname = path.basename(filePath, '.جني');
		if (!mustImp.includes(filname) && filname != 'بدائي') {
			return "ئورد " + mustImp.join('، ') + " من ئساسية.بدائي؛";
		} else {
			return "";
		}
	}
%}

%{
	// JNX logic
	
	let htmtags = "رئس:head,جسم:body,قسم:div,ميطا:meta,عنوان:title,حيز:span,رابط:a,تدييل:footer,ترويس:header,صورة:img"
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
	function startup() {
		return "globalThis.العام=globalThis;";
		//return "Object.defineProperty(globalThis)"
	}
	
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
%left EQ NEQ LT LTE GT GTE
%left AND OR
%left IN
%right '='
%right NOT
%right AWAIT
%right IF

%%

////
program
    : statement_list EOF {
		var globalvars = "";
		if ($1.includes('مدخل')) { // TODO: improve madkhal checking
			globalvars = "globalThis['سياق'] = " + yy.env;
		}
		result = globalvars + $1.filter(Boolean).join(';');
		if (context.inlineParse) {
			return result;
		}
		let fileName = context.filePath.replace(context.projectPath, '.').replace('.جني', '.js');
		fileName = fileName.replaceAll('/', '.').replace('..', '/');
		let outFilePath = path.join(context.outPath, fileName);
		fs.writeFile(outFilePath, result, { flag: 'w+' }, (err) => {
			if (err) {
				console.log('فشل حفض الملف: ' + outFilePath);
			}
		});
		// get global scope
		var glob = yy.scopeStack.pop();
		// remove env from it
		delete glob["سياق"];
		return glob; // return global scope
    }
	| EOF /* empty */
    ;
////


////
statement_list
    : statement { $$ = [$1]; }
    | statement_list statement { $1.push($2); $$ = $1; }
    ;
statement
    : import_statement semic_or_nl { $$ = $1; }
	| function_def { $$ = $1; }
	| super_call semic_or_nl { $$ = $1; }
	| shortcuts_call semic_or_nl { $$ = ''; }
	| has_statement semic_or_nl { $$ = $1; }
	| var_declaration semic_or_nl { $$ = $1; }
	| say_statement semic_or_nl { $$ = $1; }
	| return_statement semic_or_nl { $$ = $1; }
	| while_statement { $$ = $1; }
    | for_in_statement { $$ = $1; }
	| if_statement { $$ = $1; }
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
		
		//var myImport = $4.replace(/\"/g, '').replace(/\'/g, '');
		if (isUrlImport($4)) {
			var imp = $4.replace(/\"/g, '').replace(/\'/g, ''); // remove " and '
			// path should start with '//' 
			// then consider specifier as مجهول and add symbol
			if (!imp.startsWith('//')) {
				throw new Error("ئيراد عنونت لا يبدئ ب //");
			}
			if ($2.find == 'all') {
				declareSymbol(yy, @1, $2.add, 'مجهول');
			}else {
				$2.add.forEach((add) => {
					declareSymbol(yy, @1, add, 'مجهول');
				});
			}
			if (imp == '//') {
				// nonfunctional import just for the parser
				$$ = "";
			} else {
				$$ = 'import ' + $2.value + ' from "' + imp + '";'; 
			}
		} else {
			// import is not a string
			var myFileImport = importExists($4, context);

			if (myFileImport.exists) {
				// local import, build path and parse file
				processImport(yy, @2, context, myFileImport.relativePath, $2);
			} else {
				// unfound locally, download from library
				// and continue just like local
				// addDownloadFromLibrary();
				myFileImport = importExists('مكون.' + $4, context);
				if (myFileImport.exists) {
					processImport(yy, @2, context, myFileImport.relativePath, $2);
				} else {
					throw new Error("تعدر ئيجاد الوحدة '" +  $4 + "'")
				}
			}
			var imp = myFileImport.relativePath.replaceAll('/', '.').replace('.جني', '.js').replace('..', './');
			var exp = $2.value;
			if (exp.includes('* as ')) {
				exp = '{' + exp.replace('* as ', '') + '}';
			}
			$$ = 'import ' + $2.value + ' from "' + imp + '";export ' + exp;
		}
	}
/*
    | IMPORT import_path {
		importPath = path.join(context.projectPath, $2.replace(/\"/g, ''));
		importPath = path.resolve(importPath);
		var scope = readAndParseFile(importPath, context)
		$$ = 'import ' + $2; 
	}
*/
    ;
import_specifier
    : import_list {
		$$ = {
			find: $1.split(', '),
			add: $1.split(', '),
			value: '{' + $1 + '}'
		}			
	}
    | IDENTIFIER AS IDENTIFIER { 
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
function_def
	: function_decl function_ret body_block {
		var selfSymb = yy.selfStack.pop();
		var funcSymb = yy.functionStack.pop();
		
		if ($3.includes('this.')) {
			// we used this keyword, so self is a class
			selfSymb.isClass = true;
		}
		
		var extendStr = '';
		if (yy.mysuper != '') { // this class inherits
			extendStr = ' extends ' + yy.mysuper,
            yy.mysuper = '';
        }
		
		if (!selfSymb.isClass && (funcSymb.type != $2.type)) {
			throw new Error("سطر: " + @1.first_line + "\n" + "نوع الئرجاع غير متوافق في الوضيفة '" + funcSymb.name + " <" + funcSymb.type + ">'");
		}
		
		if ($1.funcname == 'مدخل') { // self exec main function
			$$ = '(function ' + $1.funcname + $1.params + $3 + ')()'; 
		} else if (yy.myshortcut != '') { // this is a shortcut
			$$ = $1.exportStr + 'const ' + $1.funcname + '=' + yy.myshortcut + ';'
				+ $1.funcname + '.prototype || (' + $1.funcname + '.prototype = {});'
				+ $3.slice(1,-1); // remove first and last { }
			yy.myshortcut = '';
		} else if (selfSymb.isClass) { // this is a class
			// we should not have a return
			if ($2.type) {
				throw new Error("سطر: " + @1.first_line + "\n" + "لا يجب تحديد نوع ئرجاع لصنف.");
			}
			$$ = $1.exportStr + 'class ' + $1.funcname + extendStr + '{constructor' + $1.params + $3 + '}';
		} else { // this is a function
			var asyncStr = funcSymb.isawait ? 'async ' : '';
			$$ = $1.exportStr + asyncStr + 'function ' + $1.funcname + $1.params + $3;
		}
	}
	| subfunc_decl function_ret body_block {
		var funcSymb = yy.functionStack.pop();
		if (funcSymb.type != $2.type) {
			throw new Error("سطر: " + @1.first_line + "\n" + "نوع الئرجاع غير متوافق في الوضيفة '" + funcSymb.name + " <" + funcSymb.type + ">'");
		}
		if (yy.myshortcut != '') {
			var result = $1.objname + '.prototype.' + $1.funcname + '=' + $1.objname + '.prototype.' + yy.myshortcut + ';';
			result += $1.objname + '.' + $1.funcname + '=' + $1.objname + '.' + yy.myshortcut + ';';
			$$ = result;
			yy.myshortcut = '';
		} else {
			var asyncStr = funcSymb.isawait ? 'async ' : '';
			$$ = $1.objname + '.prototype.' + $1.funcname + '=' + $1.objname + '.' + $1.funcname + '=' + asyncStr + 'function' + $1.value + $3;
		}
	}
	;
	
function_ret
	: '=>' type_decl {
		// $2 = { type, subtype }
		$$ = {
			type: $2.type,
			subtype: $2.subtype
		}
	}
	| /* empty */ {
		$$ = {
			type: null
		}
	}
	;
function_decl
	: function_decl_name function_decl_params {
		$$ = {
			funcname: $1.funcname,
			exportStr: $1.isExport ? 'export ' : '',
			params: $2,
			value: $1.value + $2 // TODO unused
		}
	}
	;
function_decl_name
	: DECL IDENTIFIER {
		var mySymb = declareSymbol(yy, @1, $2, $2);
		yy.selfStack.push(mySymb);
		yy.functionStack.push(mySymb);
		enterScope(yy);
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
		var mySymb = checkSymbol(yy, $2, @1);
		yy.selfStack.push(mySymb);
		enterScope(yy);
		var mySymb2 = declareMember(yy, mySymb, { name: $4, type: 'عدم' });
		yy.functionStack.push(mySymb2);
		$$ = {
			funcname: $4,
			objname: $2
			//value: $2 + '.prototype.' + $4 + '=' + $2 + '.' + $4 + '=' + async + 'function'
		}
	}
	;
param_list
    : /* empty */ { $$ = ''; }
    | IDENTIFIER {
		declareSymbol(yy, @1, $1, 'منوع');
		$$ = $1; 
	}
	| IDENTIFIER type_decl {
		declareSymbol(yy, @1, $2.type, $1);
		$$ = $2;
	}
    | param_list '،' IDENTIFIER  {
		declareSymbol(yy, @1, $3, 'منوع');
		$$ = $1 + ',' + $3; 
	}
	| param_list '،' IDENTIFIER type_decl {
		declareSymbol(yy, @1, $4.type, $3);
		$$ = $1 + ',' + $4;
	}
    ;
////


////
body_block
	: ':' statement_list END {
		exitScope(yy);
		$$ = '{' + $2.filter(Boolean).join(';') + '}';
	}
	| ':' /* empty */ END {
		exitScope(yy);
		$$ = '{}';
	}
	;
////


////
super_call
    : SUPER IDENTIFIER '(' arg_list ')' {
		var superSymb = checkSymbol(yy, $2, @2);
        yy.mysuper = $2;
		// copy super members to self members
		var selfSymb = yy.selfStack[yy.selfStack.length-1];
		for (var key in superSymb.members) {
			selfSymb.members[key] = superSymb.members[key]
		}
		selfSymb.isClass = true;
		//$$ = 'Reflect.construct(' + $2 + ', [' + $4 + '], new.target || ' + selfSymb.name + ')';
		//$$ = 'super(' + $4 + ')';
        //$$ = $2 + '.call(this' + ($4 ? ', ' + $4 : '') + ')';
		// if this class already shortcuts, then don't call super()
		if (yy.myshortcut != '') {
			$$ = '';
		}else {
			$$ = 'super(' + $4 + ')';
		}
    }
    ;
////


////
shortcuts_call
	: SHORTCUTS shortcuts_specifier {
		var selfSymb = yy.selfStack[yy.selfStack.length-1];
		var funcSymb = yy.functionStack[yy.functionStack.length-1];
		yy.myshortcut = $2.identifier;
		if (selfSymb.name == funcSymb.name) { // we are in an object
			var superSymb = checkSymbol(yy, $2.identifier, @2);
			selfSymb.myshortcut = $2.identifier;
			// TODO: for now we grant that when a func shortcuts then its a class
			selfSymb.isClass = true;
			// copy origi members to self members if we are in a class
			for (var key in superSymb.members) {
				selfSymb.members[key] = superSymb.members[key]
			}
		} else { // we are in a subfunction
			// if there is no AS TYPE then error
			if (!$2.astype) {
				throw new Error("سطر: " + @1.first_line + "\n" + "يلزم تحديد نوع الئختصار في الوضيفة '" + funcSymb.name + "' ");
			}
			var superSymb;
			if (!selfSymb.myshortcut) {
				// parent not shortcuting
				superSymb = checkMember(yy, selfSymb, $2.identifier, @1);
			} else {
				// parent have a shortcut
				superSymb = checkMember(yy, selfSymb.myshortcut, $2, @1);
			}
			// function type is the one specified in AS TYPE
			funcSymb.type = $2.astype;
		}
	}
	;
shortcuts_specifier
	: IDENTIFIER {
		$$ = {
			identifier: $1
		}
	}
	| IDENTIFIER AS IDENTIFIER {
		$$ = {
			identifier: $1,
			astype: $3
		}
	}
	;
////


////
has_statement
	: HAS has_list {
		var selfSymb = yy.selfStack[yy.selfStack.length-1];
		selfSymb.isClass = true;
		var names = $2.split(',');
		var result = '';
		var thisStr = 'this';
		if (yy.myshortcut != '') {
			thisStr = selfSymb.name + '.prototype';
		}
		names.forEach((param) => {
			param = param.split(' ');
			var name = param[1] || param[0];
			var type = param.length > 1 ? param[0] : 'منوع';
			declareMember(yy, selfSymb, {name: name, type: type}, @1);
			// declare setters & getters
			var setter = 'خد' + name;
			var getter = 'رد' + name;
			//declareMember(yy, selfSymb, {name: setter, type: 'مجهول'}, @1);
			//declareMember(yy, selfSymb, {name: getter, type: 'مجهول'}, @1);
			result += `Object.defineProperty(${selfSymb.name}.prototype, '${name}', {get: function() {return this.${getter}()}, set: function(value) {this.${setter}(value)} });`;
			result += `${thisStr}.${setter} = function (value) { this._${name} = value; };`;
			result += `${thisStr}.${getter} = function () { return this._${name}; };`;
		});
		$$ = result;
	}
	;
has_list
    : /* empty */ { $$ = ''; }
	| IDENTIFIER IDENTIFIER {
		$$ = $1 + ' ' + $2;
	}
	| IDENTIFIER {
		//declareSymbol(yy, @1, $1, 'مجهول');
		$$ = $1; 
	}
	| has_list '،' IDENTIFIER IDENTIFIER {
		$$ = $1 + ',' + $3 + ' ' + $4;
	}
    | has_list '،' IDENTIFIER  {
		//declareSymbol(yy, @1, $3, 'مجهول');
		$$ = $1 + ',' + $3; 
	}
    ;
////


////
var_declaration
    : DEF IDENTIFIER {
		// دع ب
		declareSymbol(yy, @1, $2, 'منوع');
        $$ = 'let ' + $2; 
    }
    | DEF IDENTIFIER '=' expression {
		// دع ب = 4
		declareSymbol(yy, @1, $2, $4.type);
        $$ = 'let ' + $2 + ' = ' + $4.value;
    }
	| DEF IDENTIFIER IDENTIFIER {
		// دع عدد ب
		declareSymbol(yy, @1, $3, $2);
		$$ = 'let ' + $3;
	}
	| DEF IDENTIFIER IDENTIFIER '=' expression {
		// دع عدد ب = 4
		if ($2 != $4.type) {
			// type mismatch
			throw new Error("سطر: " + @1.first_line + "\n" + "محاولة ئسناد '" + $4.type + "' ئلا '" + $2 + "'");
		}
		declareSymbol(yy, @1, $3, $2);
		$$ = 'let ' + $2 + ' = ' + $4.value;
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
return_statement
    : RETURN expression {
		var funcSymb = yy.functionStack[yy.functionStack.length-1];
		funcSymb.type = $2.type;
		$$ = 'return ' + $2.value; 
	}
    | RETURN {
		var funcSymb = yy.functionStack[yy.functionStack.length-1];
		funcSymb.type = "عدم";
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
		enterScope(yy);
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
		enterScope(yy);
		declareSymbol(yy, @1, $2, $4.type);
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
		enterScope(yy);
		$$ = 'if (' + $2.value + ')';
	}
	;
	
elif_clauses
	: elif_head noend_block { $$ = $1 + $2 }
	| elif_clauses elif_head noend_block { $$ = $2 + $3 }
	;
	
elif_head
	: ELSE IF expression {
		enterScope(yy);
		$$ = 'else if (' + $3.value + ')';
	}
	;
	
noend_block
	: ':' statement_list {
		exitScope(yy);
		$$ = '{' + $2.filter(Boolean).join(';') + '}';
	}
	;
	
else_clause
	: else_head noend_block { $$ = $1 + $2 }
	;
	
else_head
	: ELSE {
		enterScope(yy);
		$$ = 'else';
	}
	;
////


//// expressions ////

////
assignment
    : IDENTIFIER '=' expression {
		var mySymb = checkSymbol(yy, $1, @1);
		if (mySymb.type != 'منوع' && (mySymb.type != $3.type)) {
			// type mismatch
			throw new Error("سطر: " + @1.first_line + "\n" + "محاولة ئسناد '" + '<' + $3.type + ">' ئلا '" + mySymb.name + ' <' + mySymb.type + ">'");
		}
		if ($3.symb && $3.symb.type == 'كائن') {
			// expression is an object literal
			// add members to identifier's symbol
			mySymb.members = $3.symb.members;
			// mySymb.type = $3.symb.type;
		}
		$$ = {
			type: mySymb.type,
			value: $1 + '=' + $3.value
		}
	}
    | member_access '=' expression {
		if ($1.symb) {
			if ($1.symb.type != 'منوع' && ($1.symb.type != $3.type)) {
				throw new Error("سطر: " + @1.first_line + "\n" + "محاولة ئسناد '" + '<' + $3.type + ">' ئلا '" + $1.symb.name + ' <' + $1.symb.type + ">'");
			}
			if ($3.symb && $3.symb.type == 'كائن') {
				// expression is an object literal
				// add members to the assigned symbol
				$1.symb.members = $3.symb.members;
			}

			// $1.symb.type = $3.type
		}
		$$ = {
			type: $3.type,
			value: $1.value + '=' + $3.value
		}
	}
    | array_access '=' expression {
		$$ = {
			type: $3.type,
			value: $1.value + '=' + $3.value
		}
	}
    ;
////


////
arithmetic
	// type of arithmetic is same as first operand
    : expression '+' expression {
		$$ = {
			type: $1.type,
			value: $1.value + ' + ' + $3.value 
		}
	}
    | expression '-' expression { 
		$$ = {
			type: $1.type,
			value: $1.value  + ' - ' + $3.value 
		}
	}
    | expression '×' expression { 
		$$ = {
			type: $1.type,
			value: $1.value  + ' * ' + $3.value 
		}
	}
    | expression '÷' expression { 
		$$ = {
			type: $1.type,
			value: $1.value  + ' / ' + $3.value 
		}
	}
    ;
////


////
comparison
    : expression EQ expression {
		$$ = {
			type: 'منطق',
			value: $1.value + ' == ' + $3.value 
		}
	}
    | expression NEQ expression { 
		$$ = {
			type: 'منطق',
			value: $1.value + ' != ' + $3.value 
		}
	}
    | expression LT expression { 
		$$ = {
			type: 'منطق',
			value: $1.value + ' < ' + $3.value
		}
	}
    | expression LTE expression { 
		$$ = {
			type: 'منطق',
			value: $1.value  + ' <= ' + $3.value
		}
	}
    | expression GT expression { 
		$$ = {
			type: 'منطق',
			value: $1.value + ' > ' + $3.value
		}
	}
    | expression GTE expression { 
		$$ = {
			type: 'منطق',
			value: $1.value + ' >= ' + $3.value
		}
	}
    ;
////


////
logical
	: expression AND expression {
		$$ = {
			type: 'منطق',
			value: $1.value + ' && ' + $3.value
		}
	}
	| expression OR expression {
		$$ = {
			type: 'منطق',
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
			type: 'مجهول',
			value: $3.value + ' ? ' + $1.value + ' : ' + $5.value
		}
    }
    ;
////


////
function_call
    : IDENTIFIER '(' arg_list ')' {
		var symb = checkSymbol(yy, $1, @1);
		// check if class or function
		var newStr = symb.isClass ? 'new ' : '';
		$$ = {
			symb: symb,
			type: symb.type,
			value: newStr + $1 + '(' + $3 + ')'
		}
	}
    | member_access '(' arg_list ')' {
		// TODO: check if member_access is a function
		// TODO: maybe add isFunction to symbolTable
		$$ = {
			symb: $1.symb,
			type: $1.type,
			value: $1.value + '(' + $3 + ')'
		}
	}
	| array_access '(' arg_list ')' {
		$$ = {
			type: $1.type,
			value: $1.value + '(' + $3 + ')'
		}
	}
    ;
arg_list // no type property for arg_list
    : /* empty */ { $$ = ''; }
    | expression { 
		$$ = $1.value; 
	}
    | arg_list '،' expression { 
		$$ = $1 + ', ' + $3.value
	}
    ;
////


////
await_expr
    : AWAIT expression {
		var funcSymb = yy.functionStack[yy.functionStack.length-1];
		funcSymb.isawait = true;
        $$ = {
			type: $2.type,
			value: 'await ' + $2.value
		}
    }
    ;
////


//// TODO unused remove
new_expr
	: NEW function_call {
		$$ = {
			type: $2.type,
			value: 'new ' + $2.value
		}
	}
	;
////
	
	
////
member_access
    : IDENTIFIER '.' IDENTIFIER {
		var type = checkSymbol(yy, $1, @1).type;
		var symb = checkMember(yy, $1, $3, @3);
		type = symb.type;
		$$ = {
			symb: symb,
			type, 
			value: $1 + '.' + $3 
		}
	}
    | function_call '.' IDENTIFIER {
		var type = $1.type;
		var symb = checkMember(yy, type, $3, @3);
		type = symb.type;
		$$ = {
			symb: symb,
			type, 
			value: $1.value + '.' + $3 
		}; 
	}
    | member_access '.' IDENTIFIER {
		//var type = $1.type;
		var symb = $1.symb;
		var symb2;
		if (symb.type == 'كائن') {
			// for object literals, we take symb name as member base
			symb2 = checkMember(yy, symb, $3, @3);
		} else {
			// for other variables, we take their symb type as member base
			symb2 = checkMember(yy, symb.type, $3, @3);
		}
		var type = symb2.type;
		$$ = {
			symb: symb2,
			type, 
			value: $1.value + '.' + $3 
		};
	}
	| array_access '.' IDENTIFIER {
		$$ = {
			symb: null, // TODO: may cause problems
			type: $1.type,
			value: $1.value + '.' + $3
		};
	}
    | SELF '.' IDENTIFIER {
		var selfSymb = yy.selfStack[yy.selfStack.length-1];
		var symb = checkMember(yy, selfSymb, $3, @3);
		var type = symb.type;
		$$ = {
			symb,
			type,
			value: 'this.' + $3
		}
	}
    ;
////
	
	
////
array_access
	: IDENTIFIER '[' expression ']' {
		var symb = checkSymbol(yy, $1, @1);
		if (!['مصفوفة', 'منوع', 'كائن'].includes(symb.type)) {
			throw new Error("سطر: " + @1.first_line + "\n" + "تعدر ولوج عنصر مصفوفة من '" + symb.name + " <" + symb.type + ">'");
		}
		$$ = {
			type: symb.subtype || 'مجهول', //'مجهول', // we don't currently check types of array elements
			value: $1 + '[' + $3.value + ']'
		}
	}
	| SELF '[' expression ']' {
		$$ = {
			type: 'مجهول',
			value: 'this[' + $3.value + ']'
		}
	}
    | member_access '[' expression ']' {
		var symb = $1.symb;
		if (!['مصفوفة', 'منوع', 'كائن'].includes(symb.type)) {
			throw new Error("سطر: " + @1.first_line + "\n" + "تعدر ولوج عنصر مصفوفة من '" + symb.name + " <" + symb.type + ">'");
		}
		$$ = {
			type: symb.subtype || 'مجهول', // we don't currently check types of array elements
			value: $1.value + '[' + $3.value + ']'
		}
	}
    ;
////


////
object_literal
    : '{' property_list '}' {
		var symbs = $2.symb; // these are symbols of object properties
		var members = {};
		symbs.forEach((sy) => {
			members[sy.name] = sy;
		});
		var symb = { name: '', type: 'كائن', members };
		$$ = {
			type: symb.type,
			symb: symb,
			value: '{' + $2.value + '}'
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
		//declareMember(currentAssign, { name: $1, type: $3.type }, @1);	
		var symb = { name: $1, type: $3.type, members: {} }
		$$ = {
			symb: symb,
			value: $1 + ': ' + $3.value
		}
	}
    | STRING ':' expression {
		//declareMember(currentAssign, { name: $1, type: $3.type }, @1);
		var symb = { name: $1, type: $3.type, members: {} }
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
		throw new Error("سطر: " + @1.first_line + "\n" + "حدد نوع المصفوفة");
		$$ = "";
	}
	| AS IDENTIFIER {
		var symb = checkSymbol(yy, $2, @1);
		$$ = {
			type: symb.type,
			value: []
		}
	}
	| expression {
        $$ = {
			type: $1.type,
			value: [ $1.value ]
		}
    }
    | array_elements '،' expression {
        $1.value.push($3.value);
		if ($1.type != $3.type) {
			throw new Error("سطر: " + @1.first_line + "\n" + "نوعين غير متجانسين في المصفوفة.");
		}
        $$ = {
			type: $1.type,
			value: $1.value
		}
    }
    ;
////


////
type_decl
	: IDENTFIER {
		$$ = {
			type: $1
		}
	}
	| IDENTIFIER '[' IDENTIFIER ']' {
		$$ = {
			type: $1,
			subtype: $3
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
		$$ = {
			type: 'منطق',
			value: '!' + $2.value
		}
	}
    ;
////


////
in_expression
	: expression IN expression {
		$$ = {
			type: 'منطق',
			value: $1.value + ' in ' + $3.value
		}
	}
	;
////


////
expression
    : assignment {
		$$ = {
			type: $1.type,
			value: $1.value
		}
	}
	| arithmetic {
		$$ = {
			type: $1.type,
			value: $1.value
		}
	}
    | comparison {
		$$ = {
			type: $1.type,
			value: $1.value
		} 
	}
	| logical {
		$$ = {
			type: $1.type,
			value: $1.value
		}
	}
	| ternary { 
		$$ = {
			type: $1.type,
			value: $1.value
		} 
	}
    | function_call {
		$$ = { 
			type: $1.type, 
			value: $1.value 
		}; 
	}
    | await_expr {
		// could've done $$=$1 but that's confusing
		$$ = {
			type: $1.type,
			value: $1.value
		}
	}
/* TODO: remove this, no new keyword
	| new_expr {
		$$ = {
			type: $1.type,
			value: $1.value
		}
	}
*/
	| member_access {
		$$ = {
			symb: $1.symb,
			type: $1.type,
			value: $1.value
		}
	}
    | array_access {
		$$ = { 
			type: $1.type, 
			value: $1.value
		} 
	}
    | object_literal {
		$$ = {
			symb: $1.symb,
			type: $1.type, 
			value: $1.value
		}; 
	}
	| spread_operator {
		$$ = {
			type: 'مجهول',
			value: $1
		}
	}
	| '[' array_elements ']' {
		$$ = {
			type: 'مصفوفة',
			subtype: $2.type,
			value: '[' + $2.value.join(', ') + ']'
		}
	}
    | logical_negation {
		$$ = { 
			type: $1.type, // منطق 
			value: $1.value 
		}; 
	}
	| '(' expression ')' {
		$$ = {
			symb: $2.symb,
			type: $2.type,
			value: '(' + $2.value + ')'
		};
	}
	| in_expression {
		$$ = {
			type: 'منطق',
			value: $1.value
		}
	}
    | IDENTIFIER {
		var symb = checkSymbol(yy, $1, @1);
		$$ = {
			symb: symb,
			type: symb.type, 
			value: $1
		}; 
	}
    | NUMBER {
		$$ = {
			type: 'عدد',
			value: toEnDigit($1)
		}
	}
    | TRUE {
		$$ = {
			type: 'منطق', 
			value: 'true'
		}; 
	}
    | FALSE {
		$$ = {
			type: 'منطق', 
			value: 'false'
		}; 
	}
    | NULL {
		$$ = {
			type: 'عدم', 
			value: 'null'
		}; 
	}
    | STRING {
		//inlineParse($2.replace('<x-', '<'), context, yy)
		const regex = /{(.*?)}/g;
		var match;
		
		while ((match = regex.exec($1)) !== null) {
			let s = match[1];
			if (s != '') {
				inlineParse(s, context, yy);
			}
		}
		$$ = {
			type: 'نص',
			value: $1.replaceAll('"', '`').replaceAll('{', '${')
		}
	}
    | SELF {
		$$ = {
			type: yy.selfStack[yy.selfStack.length-1].type,
			value: 'this'
		}			
	}
    | JNX {
		var result = $1.replace('(', '').replace(')', '') // تعويض القوسين بعلامات ئقتباس
					.replaceAll('\t','') // حدف الفراغين
					.replace(/(\r\n|\n|\r)/gm,''); // حدف رجعات السطر
					//.replaceAll('{', '${'); // تعويض متغيرين القالب
		result = processJNX(result, context, yy);
		$$ = {
			type: 'نص',
			value: result
		}
	}
    ;

%%

module.exports = createParser;