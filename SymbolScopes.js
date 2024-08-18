const fs = require('fs');
const path = require('path');

const ErrorManager = require('./ErrorManager');
const Symbol = require('./Symbol');
const Scope = require('./Scope');

class SymbolScopes {
	scopeStack; // as Scope
	
	// this takes a fileName, an returns an autoimport code to add to it
	static autoImportText(fileName) {
		if (!Symbol.isAutoImport(fileName) && fileName != 'بدائي') {
			return "ئورد " + Symbol.AUTOIMPORTS.join('، ') + " من ئساسية.بدائي؛";
		} else {
			return "";
		}
	}
	
	constructor () {
		this.scopeStack = [];
		this.enter(); // first scope
	}

	enter () {
		return this.scopeStack.push(new Scope());
	}
	
	exit () {
		return this.scopeStack.pop();
	}
	
	getCurrent () {
		return this.scopeStack[this.scopeStack.length - 1];
	}
	
	// create a symbol without declaring it
	// or scope checking it
	// use this to create a symbol, never use new Symbol by your own
	createSymbol (name, type, isArray = false, subType = null) {
		var mySymb = new Symbol(name);
		if (!type) {
			type = name;
		}
		if (subType) {
			mySymb.subTypeSymbol = this.getSymbByName(subType);
		}
		if (type == 'فارغ') {
			mySymb.typeSymbol = Symbol.SYSTEMTYPES['فارغ']
		}else if (name != type) {
			// this is a variable
			// check it's type symbol
			var smb = this.getSymbByName(type);
			// variables get there type's members
			mySymb.members = smb.members;
			mySymb.typeSymbol = smb;
			mySymb.isArray = isArray;
		}
		return mySymb;
	}
	
	// like createSymbol() above but takes symbol arguments not type names
	createSymbolS (name, typeSymbol, isArray, subTypeSymbol = null) {
		var mySymb = new Symbol(name);
		mySymb.subTypeSymbol = subTypeSymbol;

		mySymb.members = typeSymbol.members;
		mySymb.isArray = isArray;
		mySymb.typeSymbol = typeSymbol;
	}
	
	declareSymbol (name, type, isArray = false, subType = null) {
		// declare symb in the current scope
		var scope = this.getCurrent();
		if (scope.containsByName(name)) {
			ErrorManager.error("الئسم '" + name + "' معرف مسبقا في هدا المجال");
		}
		if (!type) {
			type = name;
		}
		var mySymb = this.createSymbol(name, type, isArray, subType);
		return scope.add(mySymb);
	}
	
	// Adds a symbol to the current scope
	addSymbol (smb) {
		var scope = this.getCurrent();
		if (scope.containsByName(smb.name)) {
			ErrorManager.error("الئسم '" + smb.name + "' معرف مسبقا في هدا المجال");
		}
		return scope.add(smb);
	}
	
	checkSymb (symb) {
		// check symb in the current scope and it's parents
		return checkByName(symb.name);
	}
	
	getSymbByName (symbName) {
		// check symb in the current scope and it's parent given it's name
		if (Symbol.isSystemType(symbName)) {
			return Symbol.getSystemType(symbName);
		}
		for (var i=this.scopeStack.length-1; i >= 0; i--) {
			var scope = this.scopeStack[i];
			var mySymb = scope.containsByName(symbName);
			if (mySymb) {
				return mySymb;
			}
		}
		ErrorManager.error("الئسم '" + symbName + "' غير معروف");
	}
	
	
}

module.exports = SymbolScopes;