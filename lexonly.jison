/* lexical grammar */
%lex

%%
								
[ \t\v\f\r\n]										return 'WHITESPACE'
"#"[^\n]*											return 'COMMENT'

\([\n\r\s]*\<(?:[^)\\]|\\.|\\[\s\S])*\>[\n\r\s]*\)	return 'STRING'


"ئدا"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"وئلا"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"تم"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"صحيح"(?![a-zA-Z0-9_\u0621-\u0669])					return 'OPERATOR'
"خطئ"(?![a-zA-Z0-9_\u0621-\u0669])					return 'OPERATOR'
"عدم"(?![a-zA-Z0-9_\u0621-\u0669])					return 'OPERATOR'
"دع"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"ئعلن"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"دالة"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"وعد"(?![a-zA-Z0-9_\u0621-\u0669])					return 'OPERATOR'
"بنية"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"تعداد"(?![a-zA-Z0-9_\u0621-\u0669])				return 'KEYWORD'
"=="												return 'SYMBOL'
"لا="												return 'SYMBOL'
"<="												return 'SYMBOL'
">="												return 'SYMBOL'
"<"													return 'SYMBOL'
">"													return 'SYMBOL'
"وو"(?![a-zA-Z0-9_\u0621-\u0669])					return 'SYMBOL'
"ئو"(?![a-zA-Z0-9_\u0621-\u0669])					return 'SYMBOL'
"+"													return 'SYMBOL'
"-"													return 'SYMBOL'
"×"													return 'SYMBOL'
"÷"													return 'SYMBOL'
"%"													return 'SYMBOL'
"("													return 'SYMBOL'
")"													return 'SYMBOL'
"["													return 'SYMBOL'
"]"													return 'SYMBOL'
"{"													return 'SYMBOL'
"}"													return 'SYMBOL'
":"													return 'SYMBOL'
"؛"													return 'SYMBOL'
"،"													return 'SYMBOL'
"..."												return 'SYMBOL'
"."													return 'SYMBOL'
"="													return 'SYMBOL'
"؟"													return 'SYMBOL'
"ئرجع"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"هدا"												return 'KEYWORD'
"يمدد"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"يختصر"(?![a-zA-Z0-9_\u0621-\u0669])				return 'KEYWORD'
"يملك"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"لكل"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"في"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"طالما"(?![a-zA-Z0-9_\u0621-\u0669])				return 'KEYWORD'
"قل"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"ئشطب"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"ئورد"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"ك"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"من"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"الكل"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"ريتما"(?![a-zA-Z0-9_\u0621-\u0669])				return 'KEYWORD'
"ليس"(?![a-zA-Z0-9_\u0621-\u0669])       			return 'OPERATOR'
"حاول"(?![a-zA-Z0-9_\u0621-\u0669])					return 'KEYWORD'
"ئستدرك"(?![a-zA-Z0-9_\u0621-\u0669])				return 'KEYWORD'

\"(?:[^"\\]|\\[\s\S])*\"							return 'STRING' // Double quoted string
\'[^'\n]*\'											return 'STRING' // Single quoted string

[\u0660-\u0669]+(\.[\u0660-\u0669]+)?   			return 'NUMBER'  // Eastern Arabic numerals
[a-zA-Z_\u0621-\u064A][a-zA-Z0-9_\u0621-\u0669]*	return 'IDENTIFIER'
\d+(\.\d+)?\b              							return 'NUMBER' // Western Arabic numerals


<<EOF>>												return 'EOF'
.													return 'UNKNOWN'
/lex

%token KEYWORD SYMBOL OPERATOR NUMBER STRING IDENTIFIER COMMENT WHITESPACE UNKNOWN
%start program
%%

program
	:
	;
	
%%


