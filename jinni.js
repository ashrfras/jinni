const createParser = require('./jparser');
const ErrorManager = require('./ErrorManager');

const fs = require('fs');
const path = require('path');

if (process.argv.length < 3) {
  console.error('يرجا ئعطائ ملف جني');
  process.exit(1);
}

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

const projectPath = path.resolve(path.dirname(mainFilePath));
const fileName = path.basename(mainFilePath, '.جني');
const outPath = path.join(projectPath, '__خام__');

// remove bin folder


// remove then create bin folder
try {
	fs.rmSync(outPath, { recursive: true });
} catch (err) {
} finally {
	fs.mkdirSync(outPath);
}

let code;
try {
	const data = fs.readFileSync(mainFilePath, 'utf8');
	code = data;
} catch (error) {
	console.error('فشلت قرائة الملف: ', error);
}

try {
	const parser = createParser();
	const result = parser.parse(code, {
		filePath: mainFilePath,
		projectPath: projectPath,
		outPath: outPath
	});
} catch (error) {
	let projectBasePath = path.dirname(projectPath);
	console.error("ملف: " + mainFilePath.replace(projectBasePath, ''));
	console.error(error);
}

ErrorManager.printAll(false);

if (ErrorManager.isBlocking) {
	console.error('خطئين فادحين، ترجا المراجعة');
}

// read from template.html
try {
	const data = fs.readFileSync('./template.html', 'utf8');
	code = data;
} catch (error) {
	console.error('فشلت قرائة الملف: ', error);
}

// create index.html
try {
	code = code.replace('%ئسملف%', fileName);
	fs.writeFileSync(path.join(projectPath, 'index.html'), code, { flag: 'w+' });
} catch (error) {
	console.error('فشلت الكتابة في الملف: ', error);
}