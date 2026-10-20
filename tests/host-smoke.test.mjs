import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('./host/QuickbarSmoke.js', import.meta.url), 'utf8');
const probeSource = readFileSync(new URL('./host/HostCompatibilityProbe.js', import.meta.url), 'utf8');
for (const [platform, temp, expected] of [
  ['macOS', '/tmp/', '/tmp/CavalryToolbarSmoke-v01.txt'],
  ['Windows', 'C:\\Users\\tester\\AppData\\Local\\Temp\\', 'C:/Users/tester/AppData/Local/Temp/CavalryToolbarSmoke-v01.txt'],
]) {
  test(`${platform} fixture writes only a temp marker and returns a string`, () => {
    const writes = [];
    const api = {
      getTempFolder() { return temp; },
      writeToFile(...args) { writes.push(args); return true; },
    };
    const result = vm.runInNewContext(source, { api });
    assert.equal(result, 'finished');
    assert.deepEqual(writes, [[expected, 'CAVALRY_TOOLBAR_SMOKE_OK', true]]);
  });
}


for (const [platform, temp, expected] of [
  ['macOS', '/tmp/', '/tmp/CavalryToolbarHostProbe-v01.json'],
  ['Windows', 'C:\\Users\\tester\\AppData\\Local\\Temp\\', 'C:/Users/tester/AppData/Local/Temp/CavalryToolbarHostProbe-v01.json'],
]) {
  test(`${platform} host compatibility probe is scene-neutral`, () => {
    const writes = [];
    const api = {
      getTempFolder() { return temp; },
      hasPreferenceObject() { return true; },
      getPreferenceObject() { return {}; },
      setPreferenceObject() {},
      load() {},
      encryptFile() {},
      presentOpenFile() { return ''; },
      presentSaveFile() { return ''; },
      readFromFile() { return ''; },
      listDirectoryPaths() {},
      toNativeFilePath(value) { return value; },
      writeToFile(...args) { writes.push(args); return true; },
    };
    const ui = { scriptLocation: temp, runFileScript() {} };
    const result = vm.runInNewContext(probeSource, { api, ui, JSON, console });
    assert.equal(result, 'finished');
    assert.equal(writes.length, 1);
    assert.equal(writes[0][0], expected);
    const report = JSON.parse(writes[0][1]);
    assert.equal(report.probe, 'CavalryToolbarHostProbe');
    assert.equal(report.version, 1);
    assert.equal(report.hasLoad, true);
    assert.equal(report.hasEncryptFile, true);
    assert.equal(report.hasRunFileScript, true);
    assert.equal(report.hasPresentOpenFile, true);
    assert.equal(report.hasPresentSaveFile, true);
    assert.equal(report.hasReadFromFile, true);
  });
}
