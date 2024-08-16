const fs = require('fs');
const Path = require('path');
const ErrorManager = require('./ErrorManager');
const Scope = require('./Scope');
const Symbol = require('./Symbol');

class ImportManager {
	static importedScopes = [];
	static openScopes = []; // currently open files
	static toReparse = []; // files with circular dependancy to reparse
	
	static projectPath;
	static outputPath;
	
	static setContext (ctx) {
		ImportManager.projectPath = ctx.projectPath;
		ImportManager.outputPath = ctx.outPath;
	}
	
	// imp is import path
	// fromFilePath is path of file from which import occuring
	static addImport (imp, fromFilePath) {
		// check if currently open => circular dependancy
		// don't parse an already open file
		// just return the symbol as منوع
		// and show warning message
		
		// is this an automatically imported file?
		var impname = imp.split('.');
		impname = impname[impname.length-1];
		var isAutoImport = imp == 'ئساسية.بدائي' || (imp.includes('ئساسية') && Symbol.AUTOIMPORTS.includes(impname))
			
		var openScope = ImportManager.openScopes.find((s) => s.name == imp);
		if (openScope) {
			ErrorManager.warning("ئيراد دائري ل '" + imp + "' من '" + fromFilePath + "'");
			var impname = imp.split('.');
			impname = impname[impname.length-1];
			var scope = new Scope();
			scope.add(new Symbol(impname, Symbol.getSystemType('منوع')));
			var myImp = '/' + imp.replaceAll('.', '/') + '.جني';
			ImportManager.toReparse.push({
				whenEnd: myImp,
				reparse: fromFilePath,
				name: imp
			});
			if (!isAutoImport) {
				ImportManager.openScopes.pop();
			}
			return scope;
		}
		
		// check if already imported
		var importedScope = ImportManager.importedScopes.find((s) => s.name == imp);
		if (importedScope) {
			//!isAutoImport && ImportManager.openScopes.pop();
			return importedScope.scope;
		}
		
		if (ImportManager.isUrlImport(imp)) {
			// remove " and '
			imp = imp.replace(/\"/g, '').replace(/\'/g, '');
			if (!imp.startsWith('//')) {
				// string import should start with '//' 
				ErrorManager.error("ئيراد عنونت لا يبدئ ب //");
			}
			// string imports are not added to importedScopes
			// since no symbols are declared
			
		} else {
			// register this a open scope
			// but only if not in auto imports, those don't cause circular dependancy conflicts
			
			if (!isAutoImport) {
				ImportManager.openScopes.push({
					name: imp
				});
			}
		
			// this is not a string, this is not a URL import
			var myFileImp = ImportManager.getImportInfo(imp);
			
			if (myFileImp.exists) {
				if (myFileImp.path == fromFilePath) {
					ErrorManager.warning('تم تجاهل ئيراد لنفس الملف الحالي');
					if (!isAutoImport) {
						ImportManager.openScopes.pop();
					}
					return
				}
				var scope = {
					name: imp,
					scope: ImportManager.processImport(myFileImp.path, fromFilePath)
				}
				// don't add this file to importedScopes if marked to reparse
				// bc files with circular dependancy are to be reparsed again
				//var toreparse = ImportManager.toReparse.find((elem => elem.reparse == fromFilePath));
				ImportManager.importedScopes.push(scope);
				
				if (!isAutoImport) {
					ImportManager.openScopes.pop(); // remove this file from currently open imports list
				}
				
				// if reparsewhen this means this file has caused circular depandency
				// we need to reparse the other dependant file
				
				var reparseWhen = ImportManager.toReparse.find((elem => fromFilePath.includes(elem.whenEnd)));
				if (reparseWhen) {
					ImportManager.toReparse = ImportManager.toReparse.filter((elem => fromFilePath.includes(elem.reparse)));				
					var myimp = reparseWhen.reparse.replaceAll('/', '.').replaceAll('.جني', '');
					var reparseScope = ImportManager.importedScopes.find(elem => myimp.includes(elem.name));
					var myFileImp = ImportManager.getImportInfo(reparseScope.name);
					reparseScope.scope = ImportManager.processImport(myFileImp.path, fromFilePath);
				}
				
				return scope.scope;
			} else {
				// import is not found locally, search and download from library
				// and then continue just like local like: مكون.بتشدبي
				// TODO: downloadFromLibrary();
				myFileImp = ImportManager.getImportInfo(`مكون.${imp}`);
				if (myFileImp.exists) {
					// we have successfully downloaded component from library
					var scope = {
						name: imp,
						scope: ImportManager.processImport(myFileImp.path, fromFilePath)
					}

					if (! ImportManager.toReparse.includes(fromFilePath)) {
						ImportManager.importedScopes.push(scope);
					}
					
					if (!isAutoImport) {
						ImportManager.openScopes.pop();
					}
					return scope.scope;
				} else {
					if (!isAutoImport) {
						ImportManager.openScopes.pop();
					}
					ErrorManager.error("تعدر ئيجاد الوحدة '" +  imp + "'");
				}
			}
		}
	}
	
	static getImportInfo (impPath) {	
		// imports can be relative to project path to current file
		// if not, they are relative to the compiler executable
		var projectBase = ImportManager.projectPath;
		var compilerBase = __dirname;
		
		// look in the current project path
		var ret = ImportManager._getImportInfo(impPath, projectBase);
		if (!ret.exists) {
			// look in the compiler exec path
			ret = ImportManager._getImportInfo(impPath, compilerBase);
		}
		
		return ret;
	}
	
	static _getImportInfo (impPath, basePath) {		
		var splitted = impPath.split('.');
		var name = splitted[splitted.length-1]; // last part is filename
		// ئساسية.عنصر becomes ئساسية/عنصر
		var myImport = impPath.replaceAll('.', '/');
		
		// try to find like /projectPath/ئساسية.جني
		var filePath1 = Path.join(basePath, myImport + '.جني');
		// or find like /projectPath/ئساسية/ئساسية.جني
		var filePath2 = Path.join(basePath, myImport, name + '.جني');
		
		try {
			fs.statSync(filePath1);
			return {
				exists: true,
				path: filePath1,
				relativePath: '.' + filePath1.replace(basePath, '')
			}
		} catch (err) {}
		
		try {
			fs.statSync(filePath2);
			return {
				exists: true,
				path: filePath2,
				relativePath: '.' + filePath2.replace(basePath, '')
			}
		} catch (err) {}

		return {
			exists: false
		}
	}
	
	static processImport(importPath, fromFilePath) {
		//var fileBase = Path.dirname(fromFilePath);
		//var importPath = Path.join(ImportManager.projectPath, relativeImportPath);
		
		var scope = ImportManager.readAndParseFile(importPath);
		if (!scope) {
			ErrorManager.printAll(); // this exits process
		}
		return scope;
	}
	
	// read and parse and imported file
	static readAndParseFile(filePath) {
		filePath = Path.resolve(filePath);
		var fileContent;
		try {
			fileContent = fs.readFileSync(filePath, 'utf8');
		} catch (e) {
			ErrorManager.error("تعدر ئيراد الوحدة: " + filePath);
		}
		const createParser = require('./jparser');
		const parser = createParser();
		
		try {
			const scope = parser.parse(fileContent, {
				filePath: filePath,
				projectPath: ImportManager.projectPath,
				outPath: ImportManager.outputPath
			});
			// returns a scope object containing global symbols of
			// the imported files
			return scope;
		} catch (e) {
			// parsing failed
			console.log(e);
			ErrorManager.printAll();
		}
	}
	
	static isUrlImport (s) {
		return s.startsWith('"') || s.startsWith("'");
	}
	
}

module.exports = ImportManager;