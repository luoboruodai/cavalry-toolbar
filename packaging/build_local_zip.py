"""Build a local script bundle; it neither installs nor publishes anything."""
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
out = root / 'dist' / 'CavalryToolbar-v0.1-script-bundle.zip'
entries = {
    'Scripts/CavalryToolbar.js': root / 'dist' / 'CavalryToolbar.js',
    'Scripts/CavalryQuickbarPanel.js': root / 'dist' / 'CavalryQuickbarPanel.js',
    'validation/QuickbarSmoke.js': root / 'tests' / 'host' / 'QuickbarSmoke.js',
    'validation/HostCompatibilityProbe.js': root / 'tests' / 'host' / 'HostCompatibilityProbe.js',
    'INSTALL-WINDOWS.txt': root / 'packaging' / 'INSTALL-WINDOWS.txt',
}
assets = root / 'dist' / 'CavalryToolbar_assets'
for relative in [
    'CavalryWheel.ps1',
    'CavalryWheel.app/Contents/Info.plist',
    'CavalryWheel.app/Contents/MacOS/CavalryWheel',
    'CavalryWheel.app/Contents/Resources/UIRelay.js',
    'CavalryWheel.app/Contents/_CodeSignature/CodeResources',
]:
    source = assets / relative
    if not source.is_file():
        raise SystemExit(f'Missing native helper input: {source}')
    entries['Scripts/CavalryToolbar_assets/' + relative] = source
with ZipFile(out, 'w', compression=ZIP_DEFLATED, compresslevel=9) as archive:
    for name, source in sorted(entries.items()):
        info = ZipInfo(name, (2026, 10, 18, 0, 0, 0))
        info.compress_type = ZIP_DEFLATED
        info.external_attr = (0o755 if name.endswith("/MacOS/CavalryWheel") else 0o644) << 16
        archive.writestr(info, source.read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)
with ZipFile(out) as archive:
    assert archive.testzip() is None
    assert archive.namelist() == sorted(entries)
    for name, source in entries.items():
        assert archive.read(name) == source.read_bytes()
print(f'{out} ({out.stat().st_size} bytes; {len(entries)} entries verified)')
