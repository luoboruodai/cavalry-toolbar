import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../src/CavalryToolbar.js', import.meta.url), 'utf8');
function mount(initial = null, files = ['/scripts/CavalryToolbar.js', '/scripts/Alpha.js', '/scripts/Beta.jsc'], script = source, options = {}) {
  const controls = { buttons: [], labels: [], draws: [], dropdowns: [], edits: [], containers: [], timers: [] };
  let clock = 1000;
  class ClockDate extends Date { static now() { return clock; } }
  const preferences = initial ? structuredClone(initial) : null;
  let saved = preferences;
  const calls = [], uiCalls = [], apiCalls = [], writes = [], folders = [];
  const methods = {
    setTitle() {}, setBackgroundColor(value) { this.background = value; }, setMargins() {},
    setSpaceBetween() {}, setFixedWidth(value) { this.width = value; }, setFixedHeight(value) { this.height = value; }, setFixedSize(width, height) { this.width = width; this.height = height; }, setMinimumWidth() {}, setMinimumHeight() {}, setDrawStroke() {},
    setCornerRounding(value) { this.radius = value; }, setToolTip(value) { this.tooltip = value; }, setRadius() {},
    setLayout(layout) { this.layout = layout; }, showAsPopover(x, y) { this.popover = { x, y }; }, close() { this.closed = true; }, setPreferredPopoverSide() {}, geometry() { return { x: 20, bottom: 40 }; }, add(...widgets) { this.children.push(...widgets); },
    addStretch() {}, addSpacing() {}, setSize(width, height) { this.width = width; this.height = height; }, setFontSize() {}, setPlaceholder() {},
    useHoverEvents(value) { this.hoverEvents = value; },
    setTextColor(value) { this.color = value; }, setEnabled(value) { this.enabled = value; },
    setHidden(value) { this.hidden = value; }, clear() { this.children = []; this.entries = []; },
    addEntry(value) { this.entries.push(value); }, setValue(value) { this.value = value; },
    getValue() { return this.value ?? 0; }, setText(value) { this.text = value; },
    getText() { return this.text || ''; }, clearPaths() { this.paths = []; },
    addPath(path, paint) { this.paths.push({ path, paint }); }, redraw() {},
  };
  function widget(text = '') { return Object.assign(Object.create(methods), { text, children: [], entries: [], paths: [] }); }
  const ui = {
    scriptLocation: '/scripts', ...methods, children: [],
    Button: function (name) { const item = widget(name); controls.buttons.push(item); return item; },
    Label: function (name) { const item = widget(name); controls.labels.push(item); return item; },
    Draw: function () { const item = widget(); controls.draws.push(item); return item; },
    DropDown: function () { const item = widget(); controls.dropdowns.push(item); return item; },
    LineEdit: function () { const item = widget(); controls.edits.push(item); return item; },
    HLayout: function () { return widget(); }, VLayout: function () { return widget(); },
    Container: function () { const item = widget(); controls.containers.push(item); return item; },
    show() { this.shown = true; }, setToolbar() { this.toolbar = true; }, runFileScript(path) { calls.push(path); uiCalls.push(path); },
    chooseFileToOpen() { throw new Error('This is not a Cavalry API'); },
  };
  const api = {
    hasPreferenceObject() { return saved !== null; }, getPreferenceObject() { return saved; },
    setPreferenceObject(_, state) { if (options.saveError) throw new Error('read-only preferences'); saved = structuredClone(state); },
    load(path) { calls.push(path); apiCalls.push(path); if (options.errorAfterRun) throw new Error('expected String, typeof=boolean'); return true; },
    presentOpenFile() { return options.openFile || '/external/Extra.js'; },
    presentSaveFile() { return options.saveFile || '/scripts/CavalryToolbar-Profiles.json'; },
    readFromFile(path) { if (typeof options.readFile === 'function') return options.readFile(path); throw new Error('file not found: ' + path); },
    makeFolder(path) { folders.push(path); return true; },
    writeToFile(path, content) { writes.push({ path, content }); return true; },
    listDirectoryPaths() { return files; }, isDirectory() { return false; },
    isFile(path) { return files.includes(path) || path === '/external/Extra.js'; },
  };
  api.Timer = function (callbacks) {
    this.callbacks = callbacks; this.active = false; this.ticks = 0;
    this.setInterval = value => { this.interval = value; };
    this.setRepeating = value => { this.repeating = value; };
    this.start = () => { this.active = true; };
    this.stop = () => { this.active = false; };
    this.isActive = () => this.active;
    controls.timers.push(this);
  };
  if (options.noTimer) delete api.Timer;
  if (options.noHasPreference) delete api.hasPreferenceObject;
  class Path {
    constructor() { this.ops = []; }
    moveTo(...args) { this.ops.push(['moveTo', ...args]); }
    lineTo(...args) { this.ops.push(['lineTo', ...args]); }
    close() { this.ops.push(['close']); }
    addText(...args) { this.ops.push(['text', ...args]); }
    addEllipse(...args) { this.ops.push(['ellipse', ...args]); }
    toObject() { return { ops: this.ops }; }
  }
  vm.runInNewContext(script, { ui, api, cavalry: { Path }, console, Math, Date: ClockDate }, { filename: 'CavalryToolbar.js' });
  const byButton = text => controls.buttons.find(b => b.text === text);
  const byLabel = text => controls.labels.find(b => b.text.includes(text));
  return { ui, controls, byButton, byLabel, calls, uiCalls, apiCalls, writes, folders, saved: () => saved,
    advance(ms) { clock += ms; for (const timer of controls.timers) if (timer.active) { timer.ticks++; timer.callbacks.onTimeout(); } },
  };
}

test('native window renders twelve slots and a twelve-sector donut', () => {
  const app = mount();
  assert.equal(app.ui.shown, true);
  assert.equal(app.controls.draws[0].paths.length, 39); // 12 wedges + per-character arc labels + hub/state
  assert.ok(app.byButton('01   ＋  未绑定'));
  assert.ok(app.byButton('Alpha  · JS'));
  assert.ok(app.byButton('Beta  · JSC'));
  assert.equal(app.byButton('运行选中脚本').enabled, false);
});

test('configuration controls share the same size, radius, and surface rhythm', () => {
  const app = mount();
  const slot = app.byButton('01   ＋  未绑定');
  assert.equal(slot.height, 30); assert.equal(slot.width, 226); assert.equal(slot.radius, 6);
  assert.equal(app.byButton('清空选中槽位').width, 226);
  assert.equal(app.byButton('运行选中脚本').height, 30);
  assert.equal(app.byButton('绑定到选中快捷位 →').width, 276);
  assert.equal(app.byButton('绑定到选中快捷位 →').height, 30);
  const dropdowns = app.controls.buttons.filter(b => b.isSelectField);
  assert.deepEqual(dropdowns.map(d => [d.width, d.height]), [[180, 30], [276, 30]]);
  assert.equal(dropdowns[0].radius, 6); assert.equal(dropdowns[1].radius, 6);
  const fields = app.controls.edits;
  assert.equal(fields[0].height, 30); assert.equal(fields[1].height, 30);
  assert.equal(fields[0].background, '#262b34'); assert.equal(fields[1].background, '#262b34');
  assert.equal(fields[0].radius, 6); assert.equal(fields[1].radius, 6);
  const chip = app.byButton('Alpha  · JS');
  assert.equal(chip.width, 135); assert.equal(chip.height, 30); assert.equal(chip.radius, 6);
});

test('styled select fields preserve profile and run-mode callbacks', () => {
  const app = mount();
  const profile = app.controls.buttons.find(b => b.isSelectField && b.width === 180);
  const mode = app.controls.buttons.find(b => b.isSelectField && b.width === 276);
  assert.ok(profile && mode);
  profile.onClick();
  const options = app.controls.buttons.filter(b => b.text === '工作台');
  assert.ok(options.length > 0);
  options[0].onClick();
  assert.equal(profile.getValue(), 0);
  mode.onClick();
  const uiOption = app.controls.buttons.find(b => b.text === 'UI 面板  /  runFileScript');
  assert.ok(uiOption); uiOption.onClick();
  assert.equal(mode.getValue(), 1);
  app.byButton('Alpha  · JS').onClick();
  app.byButton('绑定到选中快捷位 →').onClick();
  assert.equal(app.saved().profiles[0].modes[0], 'ui');
});

test('bind then launch, preserve profile state, and refuse missing scripts', () => {
  const app = mount();
  app.byButton('Alpha  · JS').onClick();
  app.byButton('绑定到选中快捷位 →').onClick();
  assert.equal(app.saved().profiles[0].slots[0], '@scripts/Alpha.js');
  assert.equal(app.byButton('运行选中脚本').enabled, true);
  app.byButton('运行选中脚本').onClick();
  assert.deepEqual(app.calls, ['/scripts/Alpha.js']);
  assert.deepEqual(app.apiCalls, ['/scripts/Alpha.js']);
  const restored = mount(app.saved());
  assert.equal(restored.byButton('01   Alpha').enabled, undefined);
  restored.controls.draws[0].onMouseRelease({ x: 155, y: 262 }, 'left');
  assert.deepEqual(restored.calls, []); // editor preview must never launch while arranging
  restored.byButton('运行选中脚本').onClick();
  assert.deepEqual(restored.calls, ['/scripts/Alpha.js']);
  const stale = mount(app.saved(), ['/scripts/CavalryToolbar.js']);
  stale.byButton('运行选中脚本').onClick();
  assert.deepEqual(stale.calls, []);
  assert.match(stale.byLabel('脚本已移动').text, /重新绑定/);
});

test('profile creation and deletion keep the remaining profile intact', () => {
  const app = mount();
  app.controls.edits[0].setText('Motion');
  app.byButton('＋ 新建').onClick();
  assert.equal(app.saved().active, 1);
  assert.equal(app.saved().profiles[1].name, 'Motion');
  app.byButton('删除配置').onClick();
  assert.equal(app.saved().profiles.length, 2);
  app.byButton('确认删除').onClick();
  assert.equal(app.saved().profiles.length, 1);
  assert.equal(app.saved().profiles[0].name, '工作台');
});

test('manual import adds an external file to the catalogue without executing it', () => {
  const app = mount();
  app.byButton('＋ 添加').onClick();
  assert.ok(app.byButton('Extra  · JS'));
  assert.deepEqual(app.calls, []);
  assert.equal(app.saved().custom[0], '/external/Extra.js');
});


test('portable @scripts paths resolve against the host Scripts root', () => {
  const state = { version: 1, active: 0, custom: [], profiles: [
    { name: 'Portable', slots: ['@scripts/Alpha.js', ...Array(11).fill('')], modes: Array(12).fill('script') },
  ] };
  const editor = mount(state, ['/scripts/Alpha.js'], source);
  assert.ok(editor.byButton('01   Alpha'));
  editor.byButton('运行选中脚本').onClick();
  assert.deepEqual(editor.apiCalls, ['/scripts/Alpha.js']);
});

test('UI-panel mode uses isolated UI-script launcher', () => {
  const app = mount();
  app.byButton('Alpha  · JS').onClick();
  app.controls.buttons.find(b => b.isSelectField && b.width === 276).setValue(1);
  app.byButton('绑定到选中快捷位 →').onClick();
  assert.equal(app.saved().profiles[0].modes[0], 'ui');
  app.byButton('运行选中脚本').onClick();
  assert.deepEqual(app.uiCalls, ['/scripts/Alpha.js']);
  assert.deepEqual(app.apiCalls, []);
});


test('removing a manually imported script requires clearing its slot first', () => {
  const app = mount();
  app.byButton('＋ 添加').onClick();
  app.byButton('绑定到选中快捷位 →').onClick();
  app.byButton('移出').onClick();
  assert.equal(app.saved().custom.length, 1);
  app.byButton('清空选中槽位').onClick();
  app.byButton('移出').onClick();
  assert.equal(app.saved().custom.length, 0);
  assert.equal(app.saved().profiles[0].slots[0], '');
});


test('2.7 boolean-result warning does not falsely claim the script never ran', () => {
  const state = { version: 1, active: 0, custom: [], profiles: [
    { name: 'Test', slots: ['/scripts/Alpha.js', ...Array(11).fill('')], modes: Array(12).fill('script') },
  ] };
  const editor = mount(state, ['/scripts/Alpha.js'], source, { errorAfterRun: true });
  editor.byButton('运行选中脚本').onClick();
  assert.deepEqual(editor.apiCalls, ['/scripts/Alpha.js']);
  assert.match(editor.byLabel('脚本已触发').text, /布尔返回值/);
});

test('Windows-style configured paths are normalised before display and launch', () => {
  const state = { version: 1, active: 0, custom: [], profiles: [
    { name: 'Test', slots: ['C:\\Users\\test\\Cavalry\\Sample.JS', ...Array(11).fill('')] },
  ] };
  const app = mount(state, ['C:/Users/test/Cavalry/Sample.JS']);
  assert.ok(app.byButton('01   Sample'));
  app.byButton('运行选中脚本').onClick();
  assert.deepEqual(app.apiCalls, ['C:/Users/test/Cavalry/Sample.JS']);
});


test('UI-panel mode preserves Windows-style .jsc paths in editor and Quickbar', () => {
  const state = { version: 1, active: 0, custom: [], profiles: [
    { name: 'JSC', slots: ['C:\\Tools\\Panel.jsc', ...Array(11).fill('')], modes: ['ui', ...Array(11).fill('script')] },
  ] };
  const editor = mount(state, ['C:/Tools/Panel.jsc'], source);
  editor.byButton('运行选中脚本').onClick();
  assert.deepEqual(editor.uiCalls, ['C:/Tools/Panel.jsc']);
});

test('JSC launches are reported as host-dependent instead of falsely confirmed', () => {
  const state = { version: 1, active: 0, custom: [], profiles: [
    { name: 'JSC', slots: ['/scripts/Panel.jsc', ...Array(11).fill('')], modes: Array(12).fill('script') },
  ] };
  const editor = mount(state, ['/scripts/Panel.jsc'], source);
  editor.byButton('运行选中脚本').onClick();
  assert.match(editor.byLabel('.jsc').text, /无法确认/);
});

test('search transitions between zero and many results without hiding or recreating rows', () => {
  const app = mount();
  const search = app.controls.edits[1];
  const rows = app.controls.buttons.filter(b => b.text === 'Alpha  · JS' || b.text === 'Beta  · JSC');
  search.setText('no-match'); search.onValueChanged();
  assert.equal(rows[0].hidden, undefined);
  assert.equal(rows[0].enabled, false);
  search.setText(''); search.onValueChanged();
  assert.ok(app.byButton('Alpha  · JS'));
  assert.equal(rows[0].enabled, true);
});


test('a failed preference write remains visible instead of a false saved claim', () => {
  const app = mount(null, ['/scripts/Alpha.js'], source, { saveError: true });
  app.byButton('Alpha  · JS').onClick();
  app.byButton('绑定到选中快捷位 →').onClick();
  assert.equal(app.saved(), null);
  assert.ok(app.byButton('01   Alpha'));
  assert.match(app.byLabel('设置未保存').text, /read-only preferences/);
});

test('older preference API without hasPreferenceObject still reads saved profiles', () => {
  const state = { version: 1, active: 0, custom: [], profiles: [
    { name: 'Legacy', slots: ['/scripts/Alpha.js', ...Array(11).fill('')] },
  ] };
  const editor = mount(state, ['/scripts/Alpha.js'], source, { noHasPreference: true });
  assert.ok(editor.byButton('01   Alpha'));
});



test('legacy JavaScript runtimes without fill or Number.isInteger remain usable', () => {
  const legacyPrefix = 'Array.prototype.fill = undefined; Number.isInteger = undefined;\n';
  const state = { version: 1, active: 0, custom: [], profiles: [
    { name: 'Legacy JS', slots: ['/scripts/Alpha.js', ...Array(11).fill('')], modes: Array(12).fill('script') },
  ] };
  const editor = mount(state, ['/scripts/Alpha.js'], legacyPrefix + source);
  assert.ok(editor.byButton('01   Alpha'));
  editor.byButton('运行选中脚本').onClick();
  assert.deepEqual(editor.apiCalls, ['/scripts/Alpha.js']);
});

test('newer profile formats stay read-only instead of being overwritten', () => {
  const state = { version: 2, active: 0, custom: [], profiles: [{ name: 'Future', slots: ['/scripts/Alpha.js'] }] };
  const editor = mount(state, ['/scripts/Alpha.js'], source);
  editor.byButton('Alpha  · JS').onClick();
  editor.byButton('绑定到选中快捷位 →').onClick();
  editor.byButton('清空选中槽位').onClick();
  assert.deepEqual(editor.saved(), state);
  assert.match(editor.byLabel('较新的配置格式').text, /只读/);

});

test('malformed or older persisted configs remain read-only', () => {
  for (const state of [
    { version: 1, active: 0, custom: [], profiles: [null] },
    { version: 0, active: 0, custom: [], profiles: [{ name: 'Old', slots: ['/scripts/Alpha.js'] }] },
  ]) {
    const editor = mount(state, ['/scripts/Alpha.js'], source);
    editor.byButton('Alpha  · JS').onClick();
    editor.byButton('绑定到选中快捷位 →').onClick();
    assert.deepEqual(editor.saved(), state);
    assert.match(editor.byLabel('只读').text, /只读/);

  }
});

test('stale slot paths are visible and cannot be launched', () => {
  const state = { version: 1, active: 0, custom: [], profiles: [
    { name: 'Test', slots: ['/scripts/Missing.js', ...Array(11).fill('')], modes: Array(12).fill('script') },
  ] };
  const app = mount(state, ['/scripts/CavalryToolbar.js']);
  const stale = app.controls.buttons.find(button => button.text.includes('失效'));
  assert.ok(stale);
  assert.equal(app.byButton('运行选中脚本').enabled, false);
});

test('profile export writes a portable JSON snapshot without executing scripts', () => {
  const state = { version: 1, active: 0, custom: [], profiles: [
    { name: 'Portable', slots: ['@scripts/Alpha.js', ...Array(11).fill('')], modes: Array(12).fill('script') },
  ] };
  const app = mount(state, ['/scripts/Alpha.js']);
  app.byButton('导出配置').onClick();
  const exportWrite = app.writes.find((entry) => /\.json$/i.test(entry.path));
  assert.ok(exportWrite);
  const payload = JSON.parse(exportWrite.content);
  assert.equal(payload.format, 'com.cavalrytoolbar.profile-export');
  assert.equal(payload.state.profiles[0].slots[0], '@scripts/Alpha.js');
  assert.deepEqual(app.calls, []);
});

test('profile import validates JSON and persists portable aliases', () => {
  const imported = { format: 'com.cavalrytoolbar.profile-export', version: 1, state: {
    version: 1, active: 0, custom: [], profiles: [
      { name: 'Imported', slots: ['@scripts/Beta.jsc', ...Array(11).fill('')], modes: Array(12).fill('script') },
    ]
  } };
  const app = mount(null, ['/scripts/Beta.jsc'], source, {
    openFile: '/scripts/CavalryToolbar-Profiles.json',
    readFile() { return JSON.stringify(imported); },
  });
  app.byButton('导入配置').onClick();
  assert.equal(app.saved().profiles[0].name, 'Imported');
  assert.equal(app.saved().profiles[0].slots[0], '@scripts/Beta.jsc');
  assert.ok(app.byButton('01   Beta'));
});

test('malformed profile import leaves the existing state untouched', () => {
  const state = { version: 1, active: 0, custom: [], profiles: [{ name: 'Keep', slots: Array(12).fill('') }] };
  const app = mount(state, ['/scripts/Alpha.js'], source, {
    openFile: '/scripts/bad.json',
    readFile() { return JSON.stringify({ format: 'com.cavalrytoolbar.profile-export', version: 1, state: { version: 1, profiles: [null] } }); },
  });
  app.byButton('导入配置').onClick();
  assert.equal(app.saved().profiles[0].name, 'Keep');
  assert.match(app.byLabel('配置导入失败').text, /只读|损坏/);
});

test('shortcut launcher embeds a portable fallback for hosts without preference reads', () => {
  const app = mount(null, ['/scripts/Alpha.js']);
  app.byButton('Alpha  · JS').onClick();
  app.byButton('绑定到选中快捷位 →').onClick();
  app.byButton('同步快捷键').onClick();
  const launched = [];
  const result = vm.runInNewContext(app.writes[0].content, {
    api: { load(path) { launched.push(path); } },
    ui: {}, console,
  });
  assert.equal(result, 'finished');
  assert.match(app.writes[0].content, /fallbackAbsolutePath/);
  assert.deepEqual(launched, ['/scripts/Alpha.js']);

  const emptyStateRuntime = [];
  const emptyStateResult = vm.runInNewContext(app.writes[0].content, {
    api: {
      hasPreferenceObject() { return true; },
      getPreferenceObject() { return { version: 1, active: 0, profiles: [{ slots: [''] }] }; },
      load(path) { emptyStateRuntime.push(path); },
    },
    ui: {}, console,
  });
  assert.equal(emptyStateResult, 'finished');
  assert.deepEqual(emptyStateRuntime, ['/scripts/Alpha.js']);
});

test('shortcut sync generates twelve stable launcher scripts without hard-coding target paths', () => {
  const app = mount();
  app.byButton('同步快捷键').onClick();
  assert.equal(app.folders[0], '/scripts/CavalryToolbar_Launchers');
  assert.equal(app.writes.length, 12);
  assert.equal(app.writes[0].path, '/scripts/CavalryToolbar_Launchers/CavalryToolbar_Slot01.js');
  assert.match(app.writes[0].content, /com\.cavalrytoolbar\.quickbar\.v1/);
  assert.match(app.writes[0].content, /var slot = 0/);
  assert.match(app.writes[0].content, /launcher slot 1 entered/);
  assert.match(app.writes[0].content, /hasPreferenceObject/);
  assert.match(app.writes[0].content, /return "finished"/);
  assert.doesNotMatch(app.writes[0].content, /Number\.isInteger/);
  assert.doesNotMatch(app.writes[0].content, /Alpha\.js|Beta\.jsc/);

  let readCount = 0;
  const unavailable = vm.runInNewContext(app.writes[0].content, {
    api: {
      hasPreferenceObject() { return false; },
      getPreferenceObject() { readCount++; throw new Error('should not read'); },
    },
    ui: {}, console,
  });
  assert.equal(unavailable, 'unavailable');
  assert.equal(readCount, 0);

  const dynamicState = { version: 1, active: 0, custom: [], profiles: [
    { name: 'Dynamic', slots: ['@scripts/Alpha.js', ...Array(11).fill('')], modes: Array(12).fill('script') },
  ] };
  const dynamicApp = mount(dynamicState, ['/scripts/Alpha.js', '/scripts/Beta.js']);
  dynamicApp.byButton('同步快捷键').onClick();
  const dynamicRuntime = [];
  const dynamicResult = vm.runInNewContext(dynamicApp.writes[0].content, {
    api: {
      hasPreferenceObject() { return true; },
      getPreferenceObject() { return { version: 1, active: 0, profiles: [{ slots: ['@scripts/Beta.js'] }] }; },
      load(path) { dynamicRuntime.push(path); },
    },
    ui: { scriptLocation: '/scripts' }, console,
  });
  assert.equal(dynamicResult, 'finished');
  assert.deepEqual(dynamicRuntime, ['/scripts/Beta.js']);
});


function ringPoint(index) {
  const angle = Math.PI / 2 - Math.PI * 2 / 12 * (index + 0.5);
  return { x: 155 + Math.cos(angle) * 108, y: 155 + Math.sin(angle) * 108 };
}
function arrangedState(reducedMotion = false) {
  return { version: 1, active: 0, custom: [], reducedMotion, profiles: [
    { name: 'Arrange', slots: ['/scripts/Alpha.js', '/scripts/Beta.jsc', ...Array(10).fill('')],
      modes: ['ui', 'script', ...Array(10).fill('script')] },
  ] };
}

test('Filee-style preview selects on click without executing any bound script', () => {
  const app = mount(arrangedState());
  const ring = app.controls.draws[0];
  ring.onMousePress(ringPoint(1), 'left');
  ring.onMouseRelease(ringPoint(1), 'left');
  ring.onMouseRelease(ringPoint(0), 'right');
  assert.deepEqual(app.calls, []);
  assert.match(app.byLabel('SLOT 02').text, /Beta/);
});

test('dragging between ring slots exchanges paths and modes without execution', () => {
  const app = mount(arrangedState());
  const ring = app.controls.draws[0];
  ring.onMousePress(ringPoint(0), 'left');
  ring.onMouseMove(ringPoint(1));
  ring.onMouseRelease(ringPoint(1), 'left');
  assert.deepEqual(app.saved().profiles[0].slots.slice(0, 2), ['/scripts/Beta.jsc', '/scripts/Alpha.js']);
  assert.deepEqual(app.saved().profiles[0].modes.slice(0, 2), ['script', 'ui']);
  assert.deepEqual(app.calls, []);
});

test('dragging out, leaving the frame, or moving below threshold never changes a profile', () => {
  for (const cancel of ['outside', 'leave', 'short']) {
    const initial = arrangedState(); const app = mount(initial); const ring = app.controls.draws[0];
    ring.onMousePress(ringPoint(0), 'left');
    if (cancel === 'short') {
      const p = ringPoint(0); ring.onMouseMove({ x: p.x + 2, y: p.y + 2 }); ring.onMouseRelease(p, 'left');
    } else {
      ring.onMouseMove(ringPoint(1));
      if (cancel === 'leave') app.controls.containers.find(c => c.onMouseLeave).onMouseLeave();
      ring.onMouseRelease(cancel === 'outside' ? { x: 0, y: 0 } : ringPoint(1), 'left');
    }
    assert.deepEqual(app.saved(), initial);
    assert.deepEqual(app.calls, []);
  }
});

test('failed drag persistence rolls back both the path and execution mode', () => {
  const state = arrangedState(); const app = mount(state, undefined, source, { saveError: true });
  const ring = app.controls.draws[0];
  ring.onMousePress(ringPoint(0), 'left'); ring.onMouseMove(ringPoint(1)); ring.onMouseRelease(ringPoint(1), 'left');
  assert.deepEqual(app.saved(), state);
  app.byButton('02   Beta').onClick(); app.byButton('运行选中脚本').onClick();
  assert.deepEqual(app.apiCalls, ['/scripts/Beta.jsc']);
  assert.deepEqual(app.uiCalls, []);
});

test('double-click binds the selected library script and never starts it', () => {
  const app = mount(); app.byButton('Alpha  · JS').onClick();
  app.controls.draws[0].onMouseDoubleClick(ringPoint(3), 'left');
  assert.equal(app.saved().profiles[0].slots[3], '@scripts/Alpha.js');
  assert.deepEqual(app.calls, []);
});

test('hover motion is interruptible, finite, and stopped on window close', () => {
  const app = mount(); const ring = app.controls.draws[0];
  const firstPoint = () => ring.paths[0].path.ops[0].slice(1);
  const rest = firstPoint(); ring.onMouseMove(ringPoint(0));
  assert.equal(app.controls.timers.length, 1);
  app.advance(80); assert.notDeepEqual(firstPoint(), rest);
  const mid = firstPoint(); ring.onMouseMove(ringPoint(1));
  assert.deepEqual(firstPoint(), mid); // retarget does not jump back to rest
  app.advance(160); assert.equal(app.controls.timers[0].active, false);
  ring.onMouseMove(ringPoint(0)); assert.equal(app.controls.timers[0].active, true);
  app.ui.onClose(); assert.equal(app.controls.timers[0].active, false);
});

test('press feedback returns to the hover rest state without delaying editor actions', () => {
  const app = mount(); const ring = app.controls.draws[0];
  const firstPoint = () => ring.paths[0].path.ops[0].slice(1);
  ring.onMouseMove(ringPoint(0)); app.advance(160);
  const hoverRest = firstPoint();
  ring.onMousePress(ringPoint(0), 'left'); app.advance(60);
  assert.notDeepEqual(firstPoint(), hoverRest); // pressed sector recedes from its hover lift
  ring.onMouseRelease(ringPoint(0), 'left'); app.advance(120);
  assert.deepEqual(firstPoint(), hoverRest);
  assert.equal(app.controls.timers[0].active, false);
  assert.deepEqual(app.calls, []); // preview feedback never runs a script
});

test('hover fill interpolates continuously instead of switching at a threshold', () => {
  const app = mount(); const ring = app.controls.draws[0];
  const restColor = ring.paths[0].paint.color;
  ring.onMouseMove(ringPoint(0)); app.advance(80);
  const middleColor = ring.paths[0].paint.color;
  assert.notEqual(middleColor, restColor);
  assert.notEqual(middleColor, '#078430');
  app.advance(80);
  assert.equal(ring.paths[0].paint.color, '#078430');
  assert.equal(app.controls.timers[0].active, false);
});

test('successful swap pulses the hub once and repeated swaps do not restart it', () => {
  const app = mount(arrangedState()); const ring = app.controls.draws[0];
  const hubRadius = () => ring.paths.find(p => p.path.ops[0][0] === 'ellipse').path.ops[0][3];
  ring.onMousePress(ringPoint(0), 'left'); ring.onMouseRelease(ringPoint(1), 'left');
  assert.deepEqual(app.saved().profiles[0].slots.slice(0, 2), ['/scripts/Beta.jsc', '/scripts/Alpha.js']);
  assert.equal(app.controls.timers[0].active, true);
  app.advance(80);
  assert.ok(Math.abs(hubRadius() - 67.84) < 0.000001); // 64 × 1.06 at the confirmation peak
  ring.onMousePress(ringPoint(1), 'left'); ring.onMouseRelease(ringPoint(0), 'left');
  app.advance(80);
  assert.equal(hubRadius(), 64); // second swap did not restart the pulse
  app.advance(120); // the independent press-release channel also reaches rest
  assert.equal(app.controls.timers[0].active, false);
  assert.deepEqual(app.saved().profiles[0].slots.slice(0, 2), ['/scripts/Alpha.js', '/scripts/Beta.jsc']);
  assert.deepEqual(app.calls, []);
});

test('successful swaps stay static when reduced motion or no Timer is required', () => {
  for (const [state, options] of [[arrangedState(true), {}], [arrangedState(), { noTimer: true }]]) {
    const app = mount(state, undefined, source, options); const ring = app.controls.draws[0];
    ring.onMousePress(ringPoint(0), 'left'); ring.onMouseRelease(ringPoint(1), 'left');
    app.advance(80);
    const hub = ring.paths.find(p => p.path.ops[0][0] === 'ellipse').path.ops[0];
    assert.equal(hub[3], 64);
    assert.equal(app.controls.timers.length, 0);
    assert.deepEqual(app.saved().profiles[0].slots.slice(0, 2), ['/scripts/Beta.jsc', '/scripts/Alpha.js']);
  }
});

test('reduced motion and hosts without Timer retain static feedback with no timers', () => {
  for (const [state, options] of [[arrangedState(true), {}], [arrangedState(), { noTimer: true }]]) {
    const app = mount(state, undefined, source, options); const ring = app.controls.draws[0];
    const rest = ring.paths[0].path.ops[0].slice(1);
    ring.onMouseMove(ringPoint(0));
    assert.deepEqual(ring.paths[0].path.ops[0].slice(1), rest);
    assert.equal(app.controls.timers.length, 0);
    assert.deepEqual(app.calls, []);
  }
});


test('coalesced native drag with no mouse-move event still exchanges on release', () => {
  const app = mount(arrangedState()); const ring = app.controls.draws[0];
  ring.onMousePress(ringPoint(0), 'left'); ring.onMouseRelease(ringPoint(1), 'left');
  assert.deepEqual(app.saved().profiles[0].slots.slice(0, 2), ['/scripts/Beta.jsc', '/scripts/Alpha.js']);
  assert.deepEqual(app.saved().profiles[0].modes.slice(0, 2), ['script', 'ui']);
  assert.deepEqual(app.calls, []);
});


test('importing reduced-motion config updates the control and schedules no animation', () => {
  const incoming = arrangedState(true);
  const app = mount(null, undefined, source, { readFile: () => JSON.stringify(incoming) });
  app.byButton('导入配置').onClick();
  assert.ok(app.byButton('动效：关'));
  app.controls.draws[0].onMouseMove(ringPoint(0));
  assert.equal(app.controls.timers.length, 0);
});

test('slot hub remains readable while vector text uses a readable Unicode fallback', () => {
  const state = { version: 1, active: 0, custom: [], profiles: [{ name: '工作台',
    slots: ['/scripts/动画测试.js', ...Array(11).fill('')], modes: Array(12).fill('script') }] };
  const app = mount(state, ['/scripts/动画测试.js']);
  assert.ok(app.byButton('01   动画测试'));
  const text = app.controls.draws[0].paths.flatMap(p => p.path.ops.filter(op => op[0] === 'text').map(op => op[1])).join('');
  assert.ok(text.includes('01'));
  assert.ok(text.includes('JS'));
  assert.ok(!/[\u4e00-\u9fff]/.test(text));
});


test('editor preserves its real UI context when evaluating only its installed wheel entry', () => {
  const reads = [];
  const app = mount(null, undefined, source, { readFile(path) {
    reads.push(path);
    return 'ui.runFileScript("/scripts/Panel.js"); "finished";';
  } });
  app.byButton('呼出轮盘').onClick();
  assert.deepEqual(reads, ['/scripts/CavalryQuickbarPanel.js']);
  assert.deepEqual(app.uiCalls, ['/scripts/Panel.js']);
  assert.deepEqual(app.apiCalls, []);
  assert.equal(app.saved(), null);
});

test('unreadable wheel entry reports an actionable error and never loads a substitute', () => {
  const app = mount(); app.byButton('呼出轮盘').onClick();
  assert.match(app.byLabel('轮盘启动失败').text, /file not found/);
  assert.deepEqual(app.calls, []);
});
