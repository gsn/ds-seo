require('./run/prerender');
var cp = require('child_process');
var spawn = cp.spawn,
    grep  = spawn('node', ['cacheServer.js'], {
    stdio: [0, 'pipe']
});
