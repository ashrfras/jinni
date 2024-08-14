const ErrorManager = require('./ErrorManager');

class Symbol {
	// Automatically import these types in every source
	static AUTOIMPORTS = ['عدد', 'نوعبنية', 'منطق', 'نصية', 'مصفوفة', 'نوعتعداد'];
	
	// system types known by the compiler
	static SYSTEMTYPES = {
		'مجهول': new Symbol('مجهول'),
		'فارغ': new Symbol('فارغ'),
		'منوع': new Symbol('منوع'),
		'عدم': new Symbol('عدم'),
		'دالة': new Symbol('دالة')
	};
	
	// generic permissive types
	static GENERICTYPES = {
		'مجهول': Symbol.SYSTEMTYPES['مجهول'],
		'منوع': Symbol.SYSTEMTYPES['منوع'],
		'عدم': Symbol.SYSTEMTYPES['عدم']
	}
	
	name;
	typeSymbol;
	subType; // unused	
	isClass; // bad but legacy
	isStruct; // bad but legacy
	isEnum; // bad but legacy
	mySuper; // if this is an inheriting class
	myShortcut; // if this is a shortcut symbol
	isAwait; // if function contains await
	isArray; // is this an array
	superSymbol; // symbol of super class if this class inherits
	members = [];
	args = []; // func argument symbols
	allowed = []; // allowed values for enums
	isLiteral = false; // is this a literal value
	
	
	constructor (name, typeSymbol = null, isArray = false, isClass = false) {
		this.name = name;
		this.typeSymbol = typeSymbol || this;
		//this.members = [];
		this.isClass = isClass;
		this.mySuper = '';
		this.myShortcut = '';
		this.isArray = isArray;
	}
	
	static isSystemType(symbName) {
		return Boolean(Symbol.SYSTEMTYPES[symbName]);
	}
	
	static isGenericType(symbName) {
		return Boolean(Symbol.GENERICTYPES[symbName]);
	}
	
	static isAutoImport(symbName) {
		return Boolean(Symbol.AUTOIMPORTS.includes(symbName));
	}
	
	static getSystemType(symbName) {
		var smb = Symbol.SYSTEMTYPES[symbName];
		return smb;
	}
	
	duplicate (typeSymb) {
		return new Symbol(
			this.name,
			typeSymb || this.typeSymbol,
			this.isArray,
			this.members,
			this.mySuper,
			this.myShortcut,
			this.isAwait,
			this.superSymbol,
			this.isStruct,
			this.isLiteral,
			this.isEnum
		);
	}
	
	hasParent () {
		return this.mySuper != '';
	}
	
	isShortcut () {
		return this.myShortcut != '';
	}
	
	isVariable () {
		return this.name != this.typeSymbol.name;
	}
	
	isIterable () {
		return ['مصفوفة', 'منوع', 'نوعبنية', 'نوعتعداد', 'مجهول'].includes(this.typeSymbol.name) || this.isArray;
	}
	
	isNull () {
		return this.typeSymbol.name == 'عدم';
	}
	
	isGeneric () {
		return Symbol.isGenericType(this.typeSymbol.name);
	}
	
	isSystem () {
		return Symbol.isSystemType(this.typeSymbol.name);
	}
	
	isAny () {
		return this.typeSymbol.name == 'منوع';
	}
	
	// sameTypeAs
	canBeAssignedTo (symb, printerror = true) {
		var assignFrom = this;
		var assignTo = symb;
		
		if (assignTo.isAny() || assignFrom.isAny()) {
			return true;
		}
		
		if (assignTo.isGeneric()) {
			return true;
		}
		if (assignFrom.isNull()) {
			return true;
		}
		
		if (assignFrom.isArray != assignTo.isArray) {
			return false;
		}
		
		// if we assign literal struct (from) to structType (to), check members
		// all members in the literal struct (from) chould exist and affects to (to) members
		// it is ok to have some missing members in the (from) struct
		if (assignTo.typeSymbol.isStruct && assignFrom.typeIs('نوعبنية')) {
			var canbe = true;
			// نوعبنية نب = {}
			// structType st (assignTo) = { ... } (assignFrom)
			// affecting struct literal to struct
			// check members
			assignFrom.members.forEach((fromMemb) => {
				// toMemb is the one in the left hand side: st variable
				// fromMemb is the one in the right hand side: {}
				var toMemb = assignTo.typeSymbol.checkMember(fromMemb.name);
				// check if the assigned (fromMember) exist and assignable to toMemb
				if (!fromMemb.canBeAssignedTo(toMemb)) {
					if (printerror) {
						ErrorManager.error("محاولة ئسناد " + fromMemb.toString() + " ئلا " + toMemb.toString());
					}
					canbe = false;
				}
			});
			return canbe;
		}
		
		// enumType et = "value"
		if (assignTo.isEnum && assignFrom.typeIs('نصية')) {
			// are we assigning a literal string?
			if (assignFrom.isLiteral) { // yes, check it
				if (!assignTo.allowed.includes(assignFrom.name)) {
					ErrorManager.error("القيمة '" + assignFrom.name + "' ليست ضمن التعداد " + assignTo.toEnumString());
					return false;
				} else {
					return true;
				}
			} else { // no, warning
				ErrorManager.warning("ئستخدام متغير كقيمة للتعداد '" + assignTo.name + "' تم تجاهل الفحص");
				return true;
			}
		}
		
		//if (this.typeIs('_بنية') && symb.typeSymbol.isStruct) return true;
		return (assignFrom.typeSymbol.name == assignTo.typeSymbol.name);
	}
	
	getTypeName () {
		return this.typeSymbol.name;
	}
	
	typeIs (name) {
		return this.typeSymbol.name == name;
	}
	
	typeIsNot (name) {
		return !this.typeIs(name);
	}
	
	addMember (memberSymb) {
		var memb = this.getMemberWithInfo(memberSymb);
		// if isinherited allow overwriting
		if (memb.symb && !memb.isInherited) {
			ErrorManager.error("الئسم '" + memberSymb.name + "' معرف مسبقا في الكائن " + this.toString());
		}
		if (memb.symb && memb.isInherited) {
			var i = this.members.indexOf(memb.symb);
			this.members[i] = memberSymb;
		}
		if (!memb.symb) {
			this.members.push(memberSymb);
		}
		return memberSymb;
	}
	
	// we may pass member funcArgs array to allow function overloading
	checkMember (memberName) {
		if (Symbol.isGenericType(this.typeSymbol.name)) {
			// generic types are not member checked
			return new Symbol(memberName, Symbol.SYSTEMTYPES['مجهول']);
		}
		let memberSymb = this.getMemberName(memberName);
		if (!memberSymb) {
			ErrorManager.error("الئسم '" + memberName + "' غير معروف في الكائن " + this.toString());
		}
		return memberSymb;
	}
	
	copyMembersTo(symb) {
		this.members.forEach((mm) => {
			symb.addMember(mm);
		});
	}
	
	// like getMember but returns if inherited or not
	getMemberWithInfo (symb) {
		var symbName = symb.name
		var mem = this.members.filter((m) => m.name == symbName);
		var isInherited = false;
		if (mem.length > 1) {
			// name has overloading, not supported yet
			ErrorManager.warning("وجود ئحتمالين متعددين للئسم " + symbName);
			mem = mem[0];
		} else if (mem.length < 1) { // unfound in this, check parents
			if (this.superSymbol) {
				mem = this.superSymbol.getMemberName(symbName);
				isInherited = true;
			} else {
				mem = null;
			}
		} else {
			mem = mem[0];
		}
		return {
			symb: mem,
			isInherited
		}
	}
	
	getMemberName (symbName) {
		var mem = this.members.filter((m) => m.name == symbName);
		if (mem.length > 1) {
			// name has overloading, not supported yet
			ErrorManager.warning("وجود ئحتمالين متعددين للئسم " + symbName);
			mem = mem[0];
		} else if (mem.length < 1) { // unfound in this, check parents
			if (this.superSymbol) {
				mem = this.superSymbol.getMemberName(symbName);
			} else {
				mem = null;
			}
		} else {
			mem = mem[0];
		}
		return mem;
	}
	
	getMember (symb) {
		return this.getMemberName(symb.name);
	}
	
	// check function arguments against a given list of symbols
	checkArgs (symbs) {
		var requiredParams = this.args.filter(a => !a.init);
		
		// given params should be same length or bigger then of required params
		if (requiredParams.length > symbs.length) {
			ErrorManager.error("عدد معطيين قليل في " + this.toFuncString() + " توقع " + requiredParams.length + " وجد " + symbs.length);
			return;
		}
		
		// given params should be equal or less than param length
		if (this.args.length < symbs.length) {
			ErrorManager.error("عدد معطيين كتير في " + this.toFuncString() + " توقع " + this.args.length + " وجد " + symbs.length);
			return;
		}
		
		// if at least one given arg has name specified then this is a named arg check
		var isNamedArgs = symbs.some(item => item.name != null);
		
		if (isNamedArgs) {
			// if a mixture of named and unammed, error
			if (symbs.some(item => item.name == null)) {
				ErrorManager.error("تمرير مزيج من المعطيين المسمين والموضعيين");
				return;
			}
			return this.checkNamedArgs (symbs);
		} else {
			return this.checkPositionalArgs (symbs);
		}
	}
	
	checkNamedArgs (symbs) {
		var outputValues = [];

		for (var i=0; i<this.args.length; i++) {
			var mySymb = this.args[i];
			var thatSymb = symbs.find(s => s.name == mySymb.symb.name);
			if (!thatSymb) {
				if (!mySymb.init) { // required param
					ErrorManager.error("لم يتم تمرير المعطا الئجباري " + mySymb.symb.toString() + " في " + this.toFuncString());
					break;
				} else { // optional param
					outputValues.push('undefined');
				}
			} else { // we have that param given
				if (!thatSymb.symb.canBeAssignedTo(mySymb.symb)) {
					ErrorManager.error("المعطا المسما " + thatSymb.name + ' (' + thatSymb.symb.toString() + ")" +
					" غير متوافق. يتوقع " + mySymb.symb.toTypeString() + " في " + this.toFuncString() 
					);
					break;
				}
				outputValues.push(thatSymb.value);
			}
		}
		// if still other params in the input symns, then error
		if (outputValues.filter(o => o != 'undefined').length != symbs.length) {
			ErrorManager.error("معطيين ئضافيين غير صالحين في " + this.toFuncString());
		}
		return outputValues;
	}
	
	checkPositionalArgs (symbs) {
		var outputValues = [];
		
		for (var i=0; i<this.args.length; i++) {
			var myArg = this.args[i];
			var thatArg = symbs[i] ? symbs[i].symb : null;
			if (!thatArg) {
				if (!myArg.init) { // arg is required
					ErrorManager.error("لم يتم تمرير المعطا الئجباري " + myArg.symb.toString());
					break;
				} else { // arg is optional
					continue;
				}
			}
			if (!thatArg.canBeAssignedTo(myArg.symb)) {
				ErrorManager.error("المعطا الموضعي " + thatArg.toString() +
					" غير متوافق. يتوقع " + myArg.symb.toTypeString() + " في " + this.toFuncString() 
				);
				break;
			}
			outputValues.push(symbs[i].value);
		}
		return outputValues;
	}
	
	toString () {
		if (this.isClass || Symbol.isSystemType(this.name) || this.isLiteral) {
			return "'" + this.name + "'";
		} else {
			return ("'" + 
				(this.name != '' ? this.name + ' ك ' : '') + 
				this.typeSymbol.name +
				(this.isArray ? '[]' : '') +
			"'");
		} 
	}
	
	toTypeString () {
		return "'" + this.getTypeName() +
			(this.isArray ? "[]" : "") +
			"'";
	}
	
	toFuncString () { // add arguments later
		return "'" + this.name + " (" +
			this.args.map(item => item.symb.toTypeString()).join('، ') +
			")'";
	}
	
	toEnumString () {
		return "'" + this.name + " [" +
			this.allowed.join('، ') +
		"]";
	}
}

module.exports = Symbol;