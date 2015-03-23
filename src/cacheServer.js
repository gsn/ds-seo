var express = require('express')
var fs = require('fs')
var path = require('path')
var compression = require('compression')
var app = express()
var port = 9800

var basedir = path.join(__dirname, 'src', 'plugins', 'public')
if (!fs.existsSync(basedir))
  fs.mkdirSync(basedir);

app.use(compression())

app.use(express.static(__dirname + '/src/plugins/public'));
/*
app.get("*", function (req, res) {
   // can still be accessed from something.com/myapp
   var myfile = path.join(basedir, req.query.siteid, 'index.html');
   if (fs.existsSync(myfile)) {
     res.sendFile(myfile);
   }
   else {
     res.sendStatus(404);
   }
});
*/
app.listen(port);
