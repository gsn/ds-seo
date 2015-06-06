fs = require('fs')
path = require('path')
url = require('url')
request = require('request')
util = require('../util')
cache_manager = require('cache-manager')
elasticsearch = require('elasticsearch')
os = require('os')
myEsHost = "172.25.46.108:9200"

# cache spa to a local file
module.exports =
  init: ->
    @cache = cache_manager.caching(store: es_cache)
    return

  beforePhantomRequest: (req, res, next) ->
    parsed = url.parse(req.prerender.url, true)
    siteid = parsed.query.siteid
    host = parsed.host or parsed.hostname or ''
    if (host.indexOf('.gsn.io') < 0)
      res.send 404
      return

    if (siteid?)
      indexPath = path.join('' + siteid, 'index.html')
      sanitizedPath = parsed.pathname.replace(/[^a-zA-Z0-9]/gi, '_')
      sanitizedSearch = (parsed.search or '').replace(/[^a-zA-Z0-9]/gi, '_').replace('_cache_daily', '').replace("_siteid_#{siteid}", '').toLowerCase()
      cacheFile = {
        indexPath: indexPath
        myPath: indexPath.replace('/index.', sanitizedPath + '.')
        url: req.prerender.url  # store original url
        pathname: parsed.pathname
        search: (parsed.search or '').replace("siteid=#{siteid}&cache=daily", '').replace(/&$/g, '').replace(/^\?/g, '')
        siteid: siteid
        parsedUrl: parsed
        upath: "#{siteid}#{sanitizedPath}#{sanitizedSearch}".replace(/(_)+/g, '_').replace('_searchradius_', '').replace(/_$/g, '_')
        ip: req.headers['x-forwarded-for'] or req.connection.remoteAddress
      }
      req.prerender.cacheFile = cacheFile
      parsed = url.parse(req.prerender.url)
      newUrl = req.prerender.url.replace('.staging.', '.production.')
      if (newUrl.indexOf('storenbr') < 0 and newUrl.indexOf('storeid') < 0)
        newUrl = newUrl + "&sfs=true"
      req.prerender.url = newUrl

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
    msg = msg.replace(/\\n|\\t|\\r|\\f/g, '');  # remove all new line, tag, and invalid spacing
    msg = msg.replace(/\=\"\/\//gi, '="http://');  # convert all ="//" to ="http://"
    msg = msg.replace(/<head>[+\s\S]+<meta charset=\"utf-8\"/gi, '<head><meta charset="utf-8"');  # remove everything before charset utf-8
    msg = msg.replace(/<!--begin:analytics[+\s\S]+<!--end:analytics-->/gi, ''); # strip out analytics
    msg = msg.replace('{"ContentBaseUrl":', '{"dontUseProxy": true,"ContentBaseUrl":'); # force proxy
    return msg

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
    validContent = msg.indexOf('xstore.html') > 0
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

    if (validContent)
      payload =
        id: cacheFile.upath
        url: cacheFile.url
        ip: cacheFile.ip
        content: msg
        siteid: cacheFile.siteid
        pathname: cacheFile.pathname
        search: cacheFile.search
        server: os.hostname()

      @cache.set cacheFile.upath, payload, (err, result) ->
        if err
          console.error err

        next()
        return
    else
      next()

    return

es_cache =
  indexName: ->
    today = new Date()
    todayString = today.toISOString().split('T')[0]
    return "escache-spa" #-#{todayString}"
  get: (key, callback) ->
    self = @
    client = new (elasticsearch.Client)
      host: myEsHost
      #log: 'trace'

    client.get
      index: self.indexName()
      type: 'escache1'
      ignore_unavailable: true
      id: key
    , callback
    return
  set: (key, value, callback) ->
    self = @
    today = new Date()
    value.created = today.toISOString()
    value.createdts = today.getTime()
    client = new (elasticsearch.Client)
      host: myEsHost
      #log: 'trace'

    client.index
      index: self.indexName()
      type: 'escache1'
      id: key
      ignore_unavailable: true
      body: value
    , callback
    return