class ErrorManager {
	static errorRegistry = [];
	static lineShift = {}; // we save line shifting over files
	static isBlocking = false; // is there a blocking error in our registry
	
	static ctx;
	static file;
	
	static setContext (ctx, file) {
		ErrorManager.ctx = ctx;
		ErrorManager.file = file;
	}
	
	static setFunc (func) {
		ErrorManager.func = func;
	}
	
	static hasErrors () {
		return ErrorManager.isBlocking;
	}
	
	static addShiftLine () {
		var shift = ErrorManager.lineShift[ErrorManager.file];
		if (shift) {
			ErrorManager.lineShift[ErrorManager.file] = shift+1;
		} else {
			ErrorManager.lineShift[ErrorManager.file] = 1;
		}
	}
	
	static error (msg) {
		ErrorManager.errorRegistry.push(
			new Error (Error.BLOCKING, ErrorManager.file, ErrorManager.func, ErrorManager.ctx?.first_line, msg, ErrorManager.ctx)
		);
		ErrorManager.isBlocking = true;
	}
	
	static errorProbable (msg, tag) {
		ErrorManager.errorRegistry.push(
			new Error (Error.PROBABLE, ErrorManager.file, ErrorManager.func, ErrorManager.ctx?.first_line, msg, ErrorManager.ctx, ErrorManager.tag)
		);
		ErrorManager.isBlocking = true;
	}
	
	static warning (msg) {
		ErrorManager.errorRegistry.push(
			new Error (Error.WARNING, ErrorManager.file, ErrorManager.func, ErrorManager.ctx.first_line, msg, ErrorManager.ctx)
		);
	}
	
	static printAll(exit = true) {
		ErrorManager.errorRegistry.forEach (er => {
			if (er.type != Error.WARNING) {
				er.print();
				console.log('====');
			}
		});
		if (exit) {
			console.log("نهاية الئجرائ");
			process.exit();
		}
	}
	
	static clearProbable (tag) {
		ErrorManager.errorRegistry = ErrorManager.errorRegistry.filter(er =>
			!(er.type == Error.PROBABLE && er.tag == tag)
		);
	}
}

class Error {
	static WARNING = 0;
	static BLOCKING = 1;
	static PROBABLE = 2;
	
	type;
	message;
	file;
	func;
	line;
	ctx;
	tag;
	
	constructor (type, file, func, line, msg, ctx, tag) {
		this.type = type;
		this.message = msg;
		this.file = file;
		this.func = func;
		this.line = line;
		this.ctx = ctx;
		this.tag = tag;
	}
	
	print () {
		//console.log(ErrorManager.lineShift[ErrorManager.file]);
		var line = this.line;// + (ErrorManager.lineShift[ErrorManager.file] || 0);
		if (this.type == Error.WARNING) {
			console.warn(
				'تحدير' + '\n'
				+ 'ملف: ' + this.file + '\n'
				+ 'في: ' + this.func + '\n'
				+ 'سطر: ' + line + '\n'
				+ this.message
			);
		} else { //if (this.type == Error.BLOCKING) {
			console.error(
				'خطئ ' + '\n'
				+ 'ملف: ' + this.file + '\n'
				+ 'في: ' + this.func + '\n'
				+ 'سطر: ' + line + '\n'
				+ this.message
			);
		}
	}
	
}

module.exports = ErrorManager;