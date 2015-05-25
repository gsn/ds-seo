fs = require('fs')
path = require('path')
url = require('url')
request = require('request')
util = require('../util')
cache_manager = require('cache-manager')
elasticsearch = require('elasticsearch')
myEsHost = "172.25.46.108:9200"

# cache spa to a local file
module.exports =
  init: ->
    @cache = cache_manager.caching(store: es_cache)
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
      sanitizedPath = parsed.pathname.replace(/[^a-zA-Z0-9]/gi, '_')
      sanitizedSearch = (parsed.search or '').replace(/[^a-zA-Z0-9]/gi, '_').replace('_cache_daily', '').replace("_siteid_#{siteid}", '')
      cacheFile = {
        indexPath: indexPath
        myPath: indexPath.replace('/index.', sanitizedPath + '.')
        url: req.prerender.url  # store original url
        pathname: parsed.pathname
        cache: parsed.query.cache
        siteid: siteid
        parsedUrl: parsed
        upath: "#{siteid}#{sanitizedPath}#{sanitizedSearch}".replace(/(_)+/g, '_')
        ip: req.headers['x-forwarded-for'] or req.connection.remoteAddress
      }
      req.prerender.cacheFile = cacheFile

      # make sure index page is cache before calling localhost
      @cacheIndexPage req, =>
        parsed = url.parse(req.prerender.url)
        req.prerender.url = 'http://' + @CACHE_HOST + parsed.pathname + parsed.search + '&selectFirstStore=true'

        @cache.get cacheFile.upath, (err, result) ->
          if err
            console.error err
          if !err and result?._source
            console.log 'cache hit'
            return res.send(200, result._source.content)
          next()
          return
    else
      res.send 404

    return

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

  cacheIndexPage: (req, next) ->
    cacheFile = req.prerender.cacheFile
    shouldWrite = !fs.existsSync(cacheFile.indexPath)
    parsed = cacheFile.parsedUrl
    self = @
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
          return next()

        msg = self.cleanHtml body
        if (cacheFile.shouldWrite)
          if (fs.existsSync(cacheFile.indexPath))
            fs.unlinkSync cacheFile.indexPath

          fs.writeFileSync(cacheFile.indexPath, msg)
        next()
      )
    else
      next()
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

    cacheFile = req.prerender.cacheFile;
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

    @cache.set cacheFile.upath, { id: cacheFile.upath, url: cacheFile.url, ip: cacheFile.ip, content: msg, siteid: cacheFile.siteid, pathname: cacheFile.pathname }, (err, result) ->
      if err
        console.error err
      return

    next()
    return

es_cache = 
  indexName: ->
    today = new Date()
    todayString = today.toISOString().split('T')[0]
    return "escache-#{todayString}"
  get: (key, callback) ->
    self = @
    client = new (elasticsearch.Client)
      host: myEsHost
      #log: 'trace'

    client.get
      index: self.indexName()
      type: 'escache1'
      id: key
    , callback
    return
  set: (key, value, callback) ->
    self = @
    today = new Date()
    value.created = today.toISOString()
    client = new (elasticsearch.Client)
      host: myEsHost
      #log: 'trace'

    client.index
      index: self.indexName()
      type: 'escache1'
      id: key
      body: value
    , callback
    return