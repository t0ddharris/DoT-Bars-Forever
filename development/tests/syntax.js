const fs = require('fs');
const path = require('path');
const lua = require('luaparse');
const dir = path.join(__dirname, '..', '..', 'DoTBarsForever');
for (const file of fs.readdirSync(dir).filter(f => f.endsWith('.lua'))) {
  lua.parse(fs.readFileSync(path.join(dir, file), 'utf8'), {luaVersion: '5.1'});
  console.log('Lua 5.1 syntax: ' + file);
}
