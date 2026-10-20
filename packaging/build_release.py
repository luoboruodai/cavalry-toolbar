"""Build and byte-verify the public macOS and Windows installation archives."""
from hashlib import sha256
from pathlib import Path
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
version = (root / 'VERSION').read_text().strip()
out = root / 'dist' / 'release'
out.mkdir(parents=True, exist_ok=True)

common = {
    'Scripts/CavalryToolbar.js': root / 'dist' / 'CavalryToolbar.js',
    'Scripts/CavalryQuickbarPanel.js': root / 'dist' / 'CavalryQuickbarPanel.js',
    'validation/QuickbarSmoke.js': root / 'tests' / 'host' / 'QuickbarSmoke.js',
    'validation/HostCompatibilityProbe.js': root / 'tests' / 'host' / 'HostCompatibilityProbe.js',
    'INSTALL.md': root / 'docs' / 'INSTALL.md',
    'INSTALL.zh-CN.md': root / 'docs' / 'INSTALL.zh-CN.md',
    'LICENSE': root / 'LICENSE',
}
mac = dict(common)
app = root / 'dist' / 'CavalryToolbar_assets' / 'CavalryWheel.app'
for source in sorted(app.rglob('*')):
    if source.is_file():
        mac['Scripts/CavalryToolbar_assets/CavalryWheel.app/' + source.relative_to(app).as_posix()] = source
windows = dict(common)
windows['Scripts/CavalryToolbar_assets/CavalryWheel.ps1'] = root / 'dist' / 'CavalryToolbar_assets' / 'CavalryWheel.ps1'
windows['Scripts/CavalryToolbar_assets/UIRelay.js'] = root / 'dist' / 'CavalryToolbar_assets' / 'UIRelay.js'
archives = {
    f'CavalryToolbar-v{version}-macOS-universal.zip': mac,
    f'CavalryToolbar-v{version}-Windows-x64.zip': windows,
}
for name, entries in archives.items():
    for member, source in entries.items():
        if not source.is_file():
            raise SystemExit(f'Missing release input: {source}')
    destination = out / name
    with ZipFile(destination, 'w', compression=ZIP_DEFLATED, compresslevel=9) as archive:
        for member, source in sorted(entries.items()):
            info = ZipInfo(member, (2026, 10, 20, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            info.external_attr = (0o755 if member.endswith('/MacOS/CavalryWheel') else 0o644) << 16
            archive.writestr(info, source.read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)
    with ZipFile(destination) as archive:
        assert archive.testzip() is None
        assert archive.namelist() == sorted(entries)
        for member, source in entries.items():
            assert archive.read(member) == source.read_bytes()
    print(f'{destination.name}: {destination.stat().st_size} bytes; {len(entries)} members verified')
checksums = out / 'SHA256SUMS.txt'
checksums.write_text(''.join(f'{sha256((out / name).read_bytes()).hexdigest()}  {name}\n' for name in sorted(archives)))
print(checksums)
