// fengari can exit 0 after a Lua runtime error, so require an explicit PASS line.
const {spawnSync} = require('child_process');
const path = require('path');
const cli = path.join(__dirname, '..', 'node_modules', 'fengari-node-cli', 'src', 'lua-cli.js');
const r = spawnSync(process.execPath, [cli, path.join('tests', 'run.lua')], {cwd: path.join(__dirname, '..'), encoding: 'utf8'});
const out = (r.stdout || '') + (r.stderr || '');
process.stdout.write(out);
if (r.status !== 0 || !/^PASS: \d+ assertions/m.test(out) || /traceback|error/i.test(out)) {
  console.error('Lua test run failed (status ' + r.status + ').');
  process.exit(1);
}
