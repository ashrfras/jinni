const createParser = require('./jparser');

const fs = require('fs');
const path = require('path');

if (process.argv.length < 3) {
  console.error('يرجا ئعطائ ملف جني');
  process.exit(1);
}

const mainFilePath = path.resolve(process.argv[2]);
const projectPath = path.resolve(path.dirname(mainFilePath));
const fileName = path.basename(mainFilePath, '.جني');
const outPath = path.join(projectPath, '__خام__');

// remove bin folder
fs.rmSync(outPath, { recursive: true });

// create bin folder
try {
	fs.mkdirSync(outPath);
} catch (err) {}

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



return;
(async function() {
	try {
		await fs.promises.mkdir(outPath);
	} catch (err) {}
  
	let code;
	try {
		const data = await fs.promises.readFile(mainFilePath, 'utf8');
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
	} catch (e) {
		let projectBasePath = path.dirname(projectPath);
		console.error("ملف: " + mainFilePath.replace(projectBasePath, ''));
		console.error(e.message);
	}
})();

return

// unused code

fs.readdir(projectPath, async (err, files) => {
  if (err) {
    console.error('فشلت قرائة المجلد:', err);
    return;
  }

  // create out dir
  try {
    await fs.promises.mkdir(outPath);
  } catch (err) {}

  files.forEach(async (file) => {
    const filePath = path.join(projectPath, file);
    const stats = await fs.promises.stat(filePath);

    if (stats.isFile()) {
      const outFilePath = path.join(outPath, file.replace('.جني', '.js'));
      fs.readFile(filePath, 'utf8', async (err, data) => {
        if (err) {
          console.error('فشلت قرائة الملف:', err);
          return;
        }

        const code = data;
        try {
          const result = parser.parse(code);
          await fs.promises.writeFile(outFilePath, result, { flag: 'w+' });
        } catch (e) {
          console.error("ملف: " + file);
          console.error(e.message);
        }
      });
    } else {
      if (file != '__خام__') {
        // is directory
        const outdir = path.join(outPath, file);
        try {
         await fs.promises.mkdir(outdir);
        } catch (err) {}
          }
    }
  }); // foreach file
}); // readdir
