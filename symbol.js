class Symbol {
	name;
	type;
	subType;
	members = {};
	isClass = false;
	
	constructor (s) {
		this.name = s.name;
		this.type = s.type;
		this.sybType = s.subType;
		this.members = s.members || {};
		this.isClass = s.isClass || false;
	}
	
	addMember (symb) {
		
	}
	
	checkMember (symb) {
		
	}
}

module.exports = Symbol;