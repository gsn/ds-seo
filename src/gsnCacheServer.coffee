express = require('express')
fs = require('fs')
path = require('path')
compression = require('compression')
app = express()
port = 9800
basedir = path.join(__dirname, 'src', 'plugins', 'public')

if !fs.existsSync(basedir)
  fs.mkdirSync basedir

app.use compression()
app.use express.static(__dirname + '/src/plugins/public')
app.listen port
