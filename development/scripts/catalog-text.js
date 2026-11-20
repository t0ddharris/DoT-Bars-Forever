// One-time migration helper: extract addon-owned English UI strings to stable keys.
const fs = require('fs');
const path = require('path');
const lua = require('luaparse');
const root = path.resolve(__dirname, '../../DoTBarsForever');
if (fs.existsSync(path.join(root, 'Locale.lua'))) throw Error('Migration already applied; edit Locale.lua directly.');
const catalog = {};
const singles = new Set(['Close','Remove','Corruption','Target','Focus','Amethyst','Jade','Ember','Glacier','Gold']);
for (const name of ['Bars','Core','Options','Launcher','SpellTray']) {
  const file = path.join(root, name + '.lua');
  let source = fs.readFileSync(file, 'utf8');
  const ast = lua.parse(source, {luaVersion:'5.1', ranges:true, encodingMode:'pseudo-latin1'});
  const edits = [];
  function walk(node) {
    if (!node || typeof node !== 'object') return;
    if (node.type === 'StringLiteral') {
      const value = node.value;
      if (typeof value !== 'string' || value.includes('\\') || value.includes('|') || value === 'DoT Bars Forever' || value === 'DoT Bars Forever preview') return;
      if (!singles.has(value) && !/[A-Za-z]{2,}[ :.,]+[A-Za-z]{2,}/.test(value)) return;
      const key = value.toUpperCase().replace(/[^A-Z0-9]+/g,'_').replace(/^_|_$/g,'');
      if (catalog[key] && catalog[key] !== value) throw Error('Duplicate localization key: ' + key);
      catalog[key] = value;
      edits.push({start:node.range[0],end:node.range[1],text:'L.' + key});
      return;
    }
    for (const key of Object.keys(node)) if (key !== 'comments') {
      if (Array.isArray(node[key])) node[key].forEach(walk); else walk(node[key]);
    }
  }
  walk(ast);
  for (const edit of edits.sort((a,b)=>b.start-a.start)) source=source.slice(0,edit.start)+edit.text+source.slice(edit.end);
  source=source.replace('local addonName, ns = ...','local addonName, ns = ...\nlocal L = ns.L');
  fs.writeFileSync(file,source);
}
const lines=['local addonName, ns = ...','', '-- English fallback. Other locales intentionally use English until reviewed translations ship.', 'ns.L = {'];
for (const key of Object.keys(catalog).sort()) lines.push('    '+key+' = '+JSON.stringify(catalog[key])+',');
lines.push('}','');
fs.writeFileSync(path.join(root,'Locale.lua'),lines.join('\n'));
console.log('Cataloged '+Object.keys(catalog).length+' English messages.');
