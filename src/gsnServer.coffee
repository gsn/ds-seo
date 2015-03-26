prerender = require './lib'

cp = require('child_process')
spawn = cp.spawn
grep = spawn('node', [ 'gsnCacheServer.js' ], stdio: [
  0
  'pipe'
])

server = prerender(
  workers: process.env.PHANTOM_CLUSTER_NUM_WORKERS or 4
  iterations: process.env.PHANTOM_WORKER_ITERATIONS or 10
  phantomBasePort: process.env.PHANTOM_CLUSTER_BASE_PORT or 12300
  messageTimeout: process.env.PHANTOM_CLUSTER_MESSAGE_TIMEOUT)

server.use prerender.gsnspa()
server.start()
