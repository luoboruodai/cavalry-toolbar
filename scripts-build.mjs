import { copyFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
const root = dirname(fileURLToPath(import.meta.url));
mkdirSync(join(root, 'dist'), { recursive: true });
for (const name of ['CavalryToolbar.js', 'CavalryQuickbarPanel.js']) {
  copyFileSync(join(root, 'src', name), join(root, 'dist', name));
}
mkdirSync(join(root, 'dist', 'CavalryToolbar_assets'), { recursive: true });
copyFileSync(join(root, 'native', 'windows', 'CavalryWheel.ps1'), join(root, 'dist', 'CavalryToolbar_assets', 'CavalryWheel.ps1'));
copyFileSync(join(root, 'native', 'macos', 'UIRelay.js'), join(root, 'dist', 'CavalryToolbar_assets', 'UIRelay.js'));
console.log('Product scripts and Windows helper ready; build the macOS helper with native/macos/build.sh.');
