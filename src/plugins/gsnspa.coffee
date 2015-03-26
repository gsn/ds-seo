fs = require('fs')
path = require('path')
url = require('url')
request = require('request')
util = require('../util')

# cache spa to a local file
module.exports =
  init: ->
    @CACHE_HOST = process.env.CACHE_HOST or 'localhost:9800'
    @CACHE_DIR = process.env.CACHE_DIR or __dirname + '/public'
    if (!fs.existsSync(@CACHE_DIR))
      fs.mkdir @CACHE_DIR, (err) =>
        # do nothing

    return

  beforePhantomRequest: (req, res, next) ->
    parsed = url.parse(req.prerender.url, true)
    siteid = parsed.query.siteid
    host = parsed.host or parsed.hostname or ''
    if (host.indexOf('.gsn.io') < 0)
      res.send 404
      return

    if (siteid?)
      indexPath = path.join(@CACHE_DIR, '' + siteid, 'index.html')
      cacheFile = {
        indexPath: indexPath
        path: indexPath.replace('/index.', parsed.pathname + '.')
        url: req.prerender.url  # store original url
        pathname: parsed.pathname
        cache: parsed.query.cache
        siteid: siteid
        parsedUrl: parsed
      }
      req.prerender.cacheFile = cacheFile

      # make sure index page is cache before calling localhost
      @cacheIndexPage req
      if (@sendFile(res, cacheFile.path))
        return

      parsed = url.parse(req.prerender.url)
      req.prerender.url = 'http://' + @CACHE_HOST + '/' + siteid + '/' + parsed.search + '&selectFirstStore=true&gourl=' + parsed.pathname

      next()
    else
      res.send 404

    return

  sendFile: (res, filePath) ->
    if (fs.existsSync(filePath))
      stat = fs.statSync(filePath)

      if (stat.ctime.getDate() != (new Date()).getDate())
        fs.unlinkSync filePath
        return false

      res.writeHead(200, {
          'Content-Type': 'text/html',
          'Content-Length': stat.size
      })

      # stream the data to client
      readFile = fs.createReadStream(filePath)
      readFile.on("data", (data) =>
        if (!res.write(data))
          readFile.pause()
      )

      res.on("drain", () =>
        readFile.resume()
      )

      readFile.on("end", () =>
        res.end()
      )

      return true

    return false

  cleanHtml: (msg) ->
    msg = msg.replace(/\\n|\\t|\\r|\\f/g, '');
    msg = msg.replace(/\=\"\/\//gi, '="http://');
    msg = msg.replace(/<!--endhead-->[+\s\S]+<body/gi, '</head><body');
    msg = msg.replace(/<!--begin:analytics[+\s\S]+<!--begin:analytics-->/gi, '');
    msg = msg.replace(/<!--begin:analytics[+\s\S]+<!--end:analytics-->/gi, '');
    msg = msg.replace(/<div.+hidden ng-scope.+alt\=\"tracking\s+pixel\"><\/div>/gi, '');
    msg = msg.replace('{"ContentBaseUrl":', '{"dontUseProxy": true,"ContentBaseUrl":');
    msg = msg.replace(/<!--\s+google\s+map[+\s\S]+<\/body>/gi, '<script src="//maps.googleapis.com/maps/api/js?v=3.exp&sensor=false&libraries=geometry"></script></body>');
    return msg

  cacheIndexPage: (req) ->
    cacheFile = req.prerender.cacheFile
    shouldWrite = !fs.existsSync(cacheFile.indexPath)
    parsed = cacheFile.parsedUrl
    if (cacheFile.exists)
      stat = fs.statSync(cacheFile.indexPath)

      # if file exists and not current, overwrite file
      shouldWrite = stat.ctime.getDate() != (new Date()).getDate()

    else if (!fs.existsSync(path.dirname(cacheFile.indexPath)))
      fs.mkdirSync(path.dirname(cacheFile.indexPath))

    cacheFile.shouldWrite = shouldWrite or parsed.query.forcerefresh
    if (cacheFile.shouldWrite)
      util.log 'index caching: ' + parsed.protocol + '//' + parsed.host
      request(parsed.protocol + '//' + parsed.host, (error, response, body) ->
        if (error)
          return

        msg = cleanHtml body
        if (cacheFile.shouldWrite)
          if (fs.existsSync(cacheFile.indexPath))
            fs.unlinkSync cacheFile.indexPath

          fs.writeFileSync(cacheFile.indexPath, msg)
      )
    return

  removeScriptTags: (msg) ->
    matches = msg.match(/<script(?:.*?)>(?:[\S\s]*?)<\/script>/gi)
    i = 0
    while matches and i < matches.length
      if matches[i].indexOf('application/ld+json') == -1
        msg = msg.replace(matches[i], '')
      i++
    return msg

  beforeSend: (req, res, next) ->
    if !req.prerender.documentHTML
      return next()

    # clean up content before write
    msg = req.prerender.documentHTML.toString()
    msg = @cleanHtml msg
    msg = @removeScriptTags msg

    # shrinking the file
    msg = msg.replace(/\n|\t|\f|\r/g, '');
    msg = msg.replace(/<!--.*?-->/g, '');
    msg = msg.replace(/( data-[^=]*=")([^"])*(")/gi, '');
    msg = msg.replace(/(\>\s+\<)+/g, '\>\n\<');
    msg = msg.replace(/\s+/g, ' ');
    msg = msg.replace(/></g, '>\r\n<');

    req.prerender.documentHTML = msg

    cacheFile = req.prerender.cacheFile
    # if url contain cache, then cache it
    if (cacheFile.cache)
      fs.writeFileSync(cacheFile.path, msg)

    next()
    return