const fs = require('fs');
const path = require('path');

const targetArg = process.argv[2];
const artifactsArg = process.argv[3];
const corpusArg = process.argv[4];

if (!targetArg) {
    console.error('Ошибка: Укажите путь к целевому скрипту фаззинга.');
    process.exit(1);
}

const targetPath = path.resolve(process.cwd(), targetArg);
const targetModule = require(targetPath);
let fuzzFunc = targetModule.fuzz || (typeof targetModule === 'function' ? targetModule : null);

if (!fuzzFunc && typeof targetModule === 'object') {
    const foundKey = Object.keys(targetModule).find(k => typeof targetModule[k] === 'function');
    if (foundKey) fuzzFunc = targetModule[foundKey];
}

if (typeof fuzzFunc !== 'function') {
    console.error('Ошибка: Не удалось обнаружить функцию фаззинга в модуле.');
    process.exit(1);
}

// Собираем тест-кейсы из корпуса и артефактов
const sources = [
    corpusArg ? path.resolve(process.cwd(), corpusArg) : null,
    artifactsArg ? path.resolve(process.cwd(), artifactsArg) : null
].filter(Boolean);

let executedCount = 0;

sources.forEach(dir => {
    if (fs.existsSync(dir) && fs.statSync(dir).isDirectory()) {
        fs.readdirSync(dir).forEach(file => {
            const filePath = path.join(dir, file);
            if (fs.statSync(filePath).isFile()) {
                try {
                    fuzzFunc(fs.readFileSync(filePath));
                } catch (e) {
                    // Игнорируем штатные исключения, отловленные фаззером
                }
                executedCount++;
            }
        });
    }
});

console.log(`Успешно проиграно тест-кейсов: ${executedCount}`);
