express = require('express')
fs = require('fs')
path = require('path')
#compression = require('compression')
app = express()
port = 9800
basedir = path.join(__dirname, 'lib', 'plugins', 'public')

if !fs.existsSync(basedir)
  fs.mkdirSync basedir

#app.use compression()
app.use "*", (req, res) =>
  file = path.join(basedir, req.query.siteid, 'index.html')
  if fs.existsSync(file)
    console.log 'sending: %s', file.replace(__dirname, '')
    res.sendFile file

app.use express.static(basedir)
app.listen port, =>
  console.log "Express cache server listening on port %d in %s mode", port, app.settings.env
