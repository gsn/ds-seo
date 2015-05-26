prerender = require './lib'
cp        = require('child_process')
cluster   = require('cluster')
path      = require('path')

server = prerender(
  workers: process.env.PHANTOM_CLUSTER_NUM_WORKERS or 4
  iterations: process.env.PHANTOM_WORKER_ITERATIONS or 10
  phantomBasePort: process.env.PHANTOM_CLUSTER_BASE_PORT or 12300
  messageTimeout: process.env.PHANTOM_CLUSTER_MESSAGE_TIMEOUT)

server.use prerender.gsnspa()
server.start()

if cluster.isMaster
  cp.fork path.join(__dirname, 'gsnCacheServer.js')
