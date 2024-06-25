const Symbole = require('./symbol');

class SymbolScopes {
	scopeStack;
	
	constructor (yy) {
		this.scopeStack = yy.scopeStack;
	}

	enter () {
		return this.scopeStack.push({});
	}
	
	exit () {
		return this.scopeStack.pop();
	}
	
	declare (symb) {
		// declare symb in the current scope
	}
	
	check (symb) {
		// check symb in the current scope and it's parents
	}
	
}