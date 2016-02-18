fs            = require('fs')
path          = require('path')
url           = require('url')
request       = require('request')
util          = require('../util')
cache_manager = require('cache-manager')
s3            = new (require('aws-sdk')).S3({params:{Bucket: 'digitalstore-cache'},region: 'us-west-2'})
os            = require('os')

# cache spa to s3
module.exports =
  init: ->
    @cache = cache_manager.caching(store: my_cache)
    return

  beforePhantomRequest: (req, res, next) ->
    if (req.prerender.url is 'healthcheck')
      return res.send(200, 'ok')
  
    validHosts = /(gsn|brick)+/gmi
    parsed = url.parse(req.prerender.url, true)
    siteid = parsed.query.siteid
    host = parsed.host or parsed.hostname or ''
    if !validHosts.test(host)
      # console.log(host)
      # console.log('hi')
      res.send 404
      return

    if (siteid?)
      # console.log('hi2')
      indexPath = path.join('' + siteid, 'index.html')
      sanitizedPath = parsed.pathname.replace(/[^a-zA-Z0-9]/gi, '_')
      sanitizedSearch = (parsed.search or '').replace(/[^a-zA-Z0-9]/gi, '_').replace('_cache_daily', '').replace("_siteid_#{siteid}", '').toLowerCase()
      cacheFile =
        indexPath: indexPath
        myPath: indexPath.replace('/index.', sanitizedPath + '.')
        url: req.prerender.url  # store original url
        pathname: parsed.pathname
        search: (parsed.search or '').replace("siteid=#{siteid}&cache=daily", '').replace(/&$/g, '').replace(/^\?/g, '')
        siteid: siteid
        parsedUrl: parsed
        upath: "#{siteid}#{sanitizedPath}#{sanitizedSearch}".replace(/(_)+/g, '_').replace('_searchradius_', '').replace(/_$/g, '_')
        ip: req.headers['x-forwarded-for'] or req.connection.remoteAddress
      
      req.prerender.cacheFile = cacheFile
      parsed = url.parse(req.prerender.url)
      newUrl = req.prerender.url
      req.prerender.url = newUrl

      # proceed next if no cache
      if parsed.search.indexOf("cache=") < 0
        next()
      else 
        @cache.get cacheFile.upath, (err, result) ->
          if err
            console.error err
            next()
            return

          data = result.Body
          rst = JSON.parse(data)
          return res.send(200, rst.content)
    else
      res.send 404

    return

  cleanHtml: (msg) ->
    msg = msg.replace(/\\n|\\t|\\r|\\f/g, '')  # remove all new line, tag, and invalid spacing
    msg = msg.replace(/\=\"\/\//gi, '="http://')  # convert all ="//" to ="http://"
    msg = msg.replace(/<head>[+\s\S]+<meta charset=\"utf-8\"/gi, '<head><meta charset="utf-8"')  # remove everything before charset utf-8
    msg = msg.replace(/<!--begin:analytics[+\s\S]+<!--end:analytics-->/gi, '') # strip out analytics
    msg = msg.replace('{"ContentBaseUrl":', '{"dontUseProxy": true,"ContentBaseUrl":') # force proxy
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

    cacheFile = req.prerender.cacheFile

    # clean up content before write
    msg = req.prerender.documentHTML.toString()
    validContent = msg.indexOf('xstore.html') > 0

    msg = @cleanHtml msg
    msg = @removeScriptTags msg

    # shrinking the file
    msg = msg.replace(/\n|\t|\f|\r/g, '')
    msg = msg.replace(/<!--.*?-->/g, '')
    msg = msg.replace(/( data-[^=]*=")([^"])*(")/gi, '')
    msg = msg.replace(/(\>\s+\<)+/g, '\>\n\<')
    msg = msg.replace(/\s+/g, ' ')
    msg = msg.replace(/></g, '>\r\n<')

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

      @cache.set cacheFile.upath, JSON.stringify(payload, null, 2), (err, result) ->
        if err
          console.error err

        next()
        return
    else
      next()

    return

my_cache =
  indexDate: (days)->
    date = new Date()
    date.setDate(date.getDate() + days)
    dateString = date.toISOString().split('T')[0].replace(/\D+/gi, '')
    return dateString

  get: (key, callback) ->
    self = @
    try
      key = "-ds-seo/#{self.indexDate(0)}/#{key}.json"
      # console.log "get #{key}"
      s3.getObject({
          Key: key
      }, callback)
    catch e
      callback(e)

  set: (key, value, callback) ->
    self = @
    # note: do not store in reduce_redundancy or 
    # object won't come back as json  
    try
      # store duplicate to next day so it's available 24 hours
      s3.putObject({
          Key: "-ds-seo/#{self.indexDate(1)}/#{key}.json"
          ContentType: 'application/json;charset=UTF-8'
          Body: value
      }, (err) ->
        if err
          console.error err
      )

      # store for current date
      request = s3.putObject({
          Key: "-ds-seo/#{self.indexDate(0)}/#{key}.json"
          ContentType: 'application/json;charset=UTF-8'
          Body: value
      }, callback)
    catch e
      callback(e)

    if (!callback)
      request.send()
