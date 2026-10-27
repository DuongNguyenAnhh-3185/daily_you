const fs = require('fs');
const en = JSON.parse(fs.readFileSync('lib/l10n/intl_en.arb', 'utf8'));
const vi = JSON.parse(fs.readFileSync('lib/l10n/intl_vi.arb', 'utf8'));
const properNames = new Set(['videoTitle','appTitle','templateDefaultTimestampBody','formatDailyYouJson','formatDaybook','formatDaylio','formatDiarium','formatDiaro','formatMyBrain','formatOneShot','formatPixels','formatMarkdown','licenseGPLv3']);
const args = text => [...new Set([...text.matchAll(/\{(\w+)(?=[,}])/g)].map(m => m[1]))].sort().join(',');
const keys = Object.keys(en).filter(k => !k.startsWith('@'));
for (const key of keys) {
  if (typeof vi[key] !== 'string' || !vi[key].trim()) throw Error('Thiếu bản dịch: ' + key);
  if (args(en[key]) !== args(vi[key])) throw Error('Sai biến trong câu: ' + key);
  if (en[key] === vi[key] && !properNames.has(key)) throw Error('Còn nguyên tiếng Anh: ' + key);
  if (vi[key].includes('\uFFFD')) throw Error('Lỗi mã hóa UTF-8: ' + key);
}
console.log(`Đạt: ${keys.length}/${keys.length} mục tiếng Việt; đầy đủ biến; không có lỗi UTF-8.`);
