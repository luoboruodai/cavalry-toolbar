// Manual Cavalry-host fixture for a blank scene; no scene or composition APIs.
// Bind as an ordinary script, run once, then inspect the marker in the OS temp folder.
var smokePath = api.getTempFolder().replace(/\\/g, '/').replace(/\/$/, '') + '/CavalryToolbarSmoke-v01.txt';
api.writeToFile(smokePath, 'CAVALRY_TOOLBAR_SMOKE_OK', true);
'finished';
