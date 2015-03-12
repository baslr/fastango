net = require 'net'

###

V2

###


class ParserV2
  constructor: (@ip, @port) ->
    console.log @ip, @port

    @queue        = []
    @connected    = false
    @reconnecting = false


  reconnect: () ->
    return if @reconnecting
    @reconnecting = true
    console.log 'parser reconnect'

    @socket = net.connect @port, @ip

    @socket.on 'connect', () =>
      console.log 'socket connect'

      @remain       = new Buffer 0
      @parseHead    = true
      @headers      = {}

      @error        = null
      @connected    = true
      @reconnecting = false
      @handleQueue() if @queue.length

    @socket.on 'error', (e) =>
      @error     = e
      @connected = false
      console.log 'socket error', e # close socket

    @socket.on 'end', () =>
      @connected = false
      console.log 'socket end'

    @socket.on 'close', () =>
      @connected = false
      console.log 'socket close'
      return if @queue.length is 0
      @reconnect()

    @socket.on 'data', (data) =>
      # console.log data.toString()
      # console.log "on data: add #{data.length} to #{@remain.length}"
      # @remain += data.toString 'utf8'
      @remain = Buffer.concat [@remain, data]
      # console.log "new data length is #{@remain.length}"
      @parseData()





  parseData: () ->
    # console.log "parseData()"
    # console.log '- - - -'
    # console.log 'cblength:', @cb.length, 'remaining:', @remain.length
    # console.dir @remain.toString()
    # console.log '- - - -'
    while true
      try
        index = 0
        if @parseHead
          index = 10
          # console.log "parse header"
          string = @remain.slice(0, 10).toString 'ascii'
          while @remain[index]
            string += String.fromCharCode @remain[index++]
            if -1 < string.search '\r\n\r\n$' # break on header end
              # console.log 'found header end', index
              @parseHead = false
              break
          return if @parseHead

          # return if -1 is (index = @remain.indexOf '\r\n\r\n')
          # @parseHead = false

          heads = string.slice(0, -4).split '\r\n'
          head  = heads.shift()
          @statusCode = Number head.slice 9,12

          for header in heads
            h = header.split(': ')
            @headers[h[0].toLowerCase()] = h[1].toLowerCase()
        # fi

        @remain       = @remain.slice index if index > 0
        contentLength = Number @headers['content-length']

        if @remain.length < contentLength
          # console.log 'have to return no more data', @remain.length, Number @headers['content-length']
          return

        # console.log 'done'

        @parseHead = true
        pack    = @remain.slice 0, contentLength
        @remain = @remain.slice    contentLength

        # console.log 'do callback, remain is:', @remain.length
        # console.log 'get:', pack.toString 'utf8'
        try @queue.shift().pop() @statusCode, @headers, pack
        @headers = {}
        return if 0 is @remain.length
      catch e
        console.log "PARSE ERROR:"
        console.log e
        console.log @remain
        console.log index
        console.log head


  handleQueue: () ->
    return @reconnect() if ! @connected

    for entry in @queue
      @[entry[0]].apply this, entry
      break if @error


  ###
      GET
  ###
  get: (url, cb) ->
    @queue.push ['_get', url, cb]
    return @reconnect() if ! @connected
    @_get 0, url
  
  _get: (_, url) ->
    @socket.write "GET #{url} HTTP/1.1\r\n\r\n", 'ascii'


  ###
      POST
  ###
  post: (url, buf, cb) ->
    @queue.push ['_post', 'POST', url, buf, cb]    
    return @reconnect() if ! @connected
    @_post 0, 'POST', url, buf

  _post: (_, method, url, buf) ->
    @_writeRequest 'POST ', url, buf


  ###
      PUT
  ###
  put: (url, buf, cb) ->
    @queue.push ['_put', url, buf, cb]
    return @reconnect() if ! @connected
    @_put 0, url, buf

  _put: (_, url, buf) ->
    if buf
      @socket.write "PUT #{url} HTTP/1.1\r\nContent-Type: application/json\r\ncontent-length: #{buf.length}\r\n\r\n"
      @socket.write  buf, 'binary'
    else
      @socket.write "PUT #{url} HTTP/1.1\r\n\r\n", 'ascii'


  ###
      DELETE
  ###
  delete: (url, cb) ->
    @queue.push ['_delete', url, cb]
    return @reconnect() if ! @connected
    @_delete 0, url

  _delete: (_, url) ->
    @socket.write "DELETE #{url} HTTP/1.1\r\n\r\n", 'ascii'

  ###
      PATCH
  ###
  patch: (url, buf, cb) ->
    @queue.push ['_patch', url, buf, cb]
    return @reconnect() if ! @connected
    @_patch 0, url, buf

  _patch: (_, url, buf) ->
    @_writeRequest 'PATCH ', url, buf






  _writeRequest: (method, url, buf) ->
    @socket.write method # 'POST '
    @socket.write url
    @socket.write " HTTP/1.1\r\ncontent-type: application/json\r\ncontent-length: "
    @socket.write "#{buf.length}\r\n\r\n"
    @socket.write  buf, 'binary'


###
      with strings
###
# class ParserV2
#   constructor: (@ip, @port) ->
#     console.log @ip, @port
#     @remain    = ''
#     @parseHead = true

#     @cb      = []
#     @headers = {}


#     @connected = false

#     @socket = net.connect @port, @ip, () =>
#       @connected = true
#       console.log 'parser connected'

#     @socket.on 'error', (e) -> console.log 'socketerror', e

#     @socket.on 'data', (data) =>
#       # console.log data.toString()
#       # console.log "on data: add #{data.length} to #{@remain.length}"
#       @remain += data.toString 'utf8'

#       # console.log "new data length is #{@remain.length}"
#       @parseData()

#   parseData: () ->
#     # console.log "parseData()"
#     # console.log '- - - -'
#     # console.log 'cblength:', @cb.length, 'remaining:', @remain.length
#     # console.log @remain.toString()
#     # console.log '- - - -'
#     while true
#       try
#         index = 0
#         if @parseHead
#           # console.log "parse header"
#           return if -1 is (index = @remain.indexOf '\r\n\r\n')
#           @parseHead = false

#           heads = @remain.slice(0, index).split '\r\n'
#           head  = heads.shift()
#           @statusCode = Number head.slice 9,12

#           for header in heads
#             h = header.split(': ')
#             @headers[h[0].toLowerCase()] = h[1].toLowerCase()
#         # fi

#           @remain = @remain.slice index + 4 # if index > 0

#         contentLength = Number @headers['content-length']


#         if new Buffer(@remain, 'utf8').length < contentLength
#           # console.log 'have to return no more data', @remain.length, Number @headers['content-length']
#           return

#         # console.log 'done'

#         @parseHead = true
#         pack    = @remain.slice 0, contentLength
#         @remain = @remain.slice    contentLength

#         #console.log 'do callback, remain is:', @remain.length
#         # console.log 'get:', pack.toString 'utf8'
#         try @cb.shift() @statusCode, @headers, pack
#         @headers = {}
#         return if 0 is @remain.length
#       catch e
#         console.log "PARSE ERROR:"
#         console.log e
#         console.log @remain
#         console.log index
#         console.log head



#   get: (url, cb) ->
#     return console.log 'parser not connected' if ! @connected
#     @cb.push cb
#     # console.log "accept get: cb.length is #{@cb.length}"
#     @socket.write "GET #{url} HTTP/1.1\r\n\r\n", 'binary'

#   _writeRequest: (method, url, buf) ->
#     @socket.write method # 'POST '
#     @socket.write url
#     @socket.write " HTTP/1.1\r\nContent-Type: application/json\r\ncontent-length: "
#     @socket.write "#{buf.length}\r\n\r\n"
#     @socket.write  buf, 'binary'


#   post: (url, buf, cb) ->
#     return if ! @connected
#     @_writeRequest 'POST ', url, buf
#     @cb.push cb
#     # console.log "accept post: cb.length is #{@cb.length}"
#     # console.log 'wrote:', buf.toString 'hex'

#   put: (url, buf, cb) ->
#     return if ! @connected

#     @socket.write 'PUT '
#     @socket.write url
#     @socket.write " HTTP/1.1\r\n\r\n"

#     if buf
#       @socket.write 'Content-Type: application/json\r\ncontent-length: '
#       @socket.write "#{buf.length}\r\n\r\n"
#       @socket.write  buf, 'binary'

#     @cb.push cb
#     # console.log "put: #{url}"




###

    WITH buffer head parsers by finding the binary \r\n\r\n

###
# class ParserV2
#   constructor: (@ip, @port) ->
#     console.log @ip, @port
#     @remain    = new Buffer 0 # ''
#     @parseHead = true

#     @cb      = []
#     @headers = {}


#     @connected = false

#     @socket = net.connect @port, @ip, () =>
#       @connected = true
#       console.log 'parser connected'

#     @socket.on 'error', (e) -> console.log 'socketerror', e

#     @socket.on 'data', (data) =>
#       # console.log data.toString()
#       # console.log "on data: add #{data.length} to #{@remain.length}"
#       # @remain += data.toString 'utf8'
#       @remain = Buffer.concat [@remain, data]

#       # console.dir @remain.toString()
#       # console.log "new data length is #{@remain.length}"
#       @parseData()

#   parseData: () ->
#     # console.log "parseData()"
#     # console.log '- - - -'
#     # console.log 'cblength:', @cb.length, 'remaining:', @remain.length
#     # console.dir @remain.toString()
#     # console.log '- - - -'
#     while true
#       try
#         index = 0
#         if @parseHead
#           index = 0
#           # console.log "parse header"
#           # string = @remain.slice(0, 100).toString 'ascii'
#           while @remain[index]
#             continue if 0x0d isnt @remain[index++] # check for \r

#             if @remain[index+2] is 0x0a and @remain[index] is 0x0a and @remain[index+1] is 0x0d # last \n, first \n, 2nd \r
#               string     = @remain.slice(0, index-1).toString('ascii')
#               @parseHead = false
#               @remain    = @remain.slice index+3
#               break
#             else
#               index += 3

#             # string += String.fromCharCode @remain[index++]
#             # if -1 < string.search '\r\n\r\n$' # break on header end
#             #   # console.log 'found header end', index
#             #   @parseHead = false
#             #   break
#           return if @parseHead

#           # return if -1 is (index = @remain.indexOf '\r\n\r\n')
#           # @parseHead = false

#           heads = string.split '\r\n'
#           head  = heads.shift()
#           @statusCode = Number head.slice 9,12

#           for header in heads
#             h = header.split(': ')
#             @headers[h[0].toLowerCase()] = h[1].toLowerCase()
#         # fi

#         # @remain       = @remain.slice index if index > 0
#         contentLength = Number @headers['content-length']

#         if @remain.length < contentLength
#           # console.log 'have to return no more data', @remain.length, Number @headers['content-length']
#           return

#         # console.log 'done'

#         @parseHead = true
#         pack    = @remain.slice 0, contentLength
#         @remain = @remain.slice    contentLength

#         # console.log 'do callback, remain is:', @remain.length
#         # console.log 'get:', pack.toString 'utf8'
#         try @cb.shift() @statusCode, @headers, pack
#         @headers = {}
#         return if 0 is @remain.length
#       catch e
#         console.log "PARSE ERROR:"
#         console.log e
#         console.log @remain
#         console.log index
#         console.log head



#   get: (url, cb) ->
#     return console.log 'parser not connected' if ! @connected
#     @cb.push cb
#     # console.log "accept get: cb.length is #{@cb.length}"
#     @socket.write "GET #{url} HTTP/1.1\r\n\r\n", 'binary'

#   _writeRequest: (method, url, buf) ->
#     @socket.write method # 'POST '
#     @socket.write url
#     @socket.write " HTTP/1.1\r\nContent-Type: application/json\r\ncontent-length: "
#     @socket.write "#{buf.length}\r\n\r\n"
#     @socket.write  buf, 'binary'


#   post: (url, buf, cb) ->
#     return if ! @connected
#     @_writeRequest 'POST ', url, buf
#     @cb.push cb
#     # console.log "accept post: cb.length is #{@cb.length}"
#     # console.log 'wrote:', buf.toString 'hex'

#   put: (url, buf, cb) ->
#     return if ! @connected

#     @socket.write 'PUT '
#     @socket.write url
#     @socket.write " HTTP/1.1\r\n\r\n"

#     if buf
#       @socket.write 'Content-Type: application/json\r\ncontent-length: '
#       @socket.write "#{buf.length}\r\n\r\n"
#       @socket.write  buf, 'binary'

#     @cb.push cb
#     # console.log "put: #{url}"















class Parser
  constructor: (@ip, @port) ->
    console.log @ip, @port
    @remain    = new Buffer 0
    @parseHead = true

    @cb      = []
    @headers = {}


    @connected = false

    @socket = net.connect @port, @ip, () =>
      @connected = true
      console.log 'parser connected'

    @socket.on 'error', (e) -> console.log 'socketerror', e

    @socket.on 'data', (data) =>
      # console.log data.toString()
      # console.log "on data: add #{data.length} to #{@remain.length}"
      @remain = Buffer.concat [@remain, data]
      @parseData()

  parseData: () ->
    # console.log '- - - -'
    # console.log 'cblength:', @cb.length, 'remaining:', @remain.length
    # console.log @remain.toString()
    # console.log '- - - -'
    while true
      try
        index  = 0
        if @parseHead
          string = ''
          while @remain[index]
            string += String.fromCharCode @remain[index++]
            if -1 < string.search '\r\n\r\n$' # break on header end
              # console.log 'found header end'
              @parseHead = false
              break
          return if @parseHead

          heads = string.slice(0, -4).split '\r\n'
          head  = heads.shift()
          @statusCode = Number head.slice 9,12
          # console.log "head is: #{head}"

          for header in heads
            h = header.split(': ')
            @headers[h[0].toLowerCase()] = h[1].toLowerCase()
        # fi

        @remain = @remain.slice index if index > 0 # slice only when we have something to slice

        if @remain.length < Number @headers['content-length']
          #console.log 'have to return no more data', @remain.length, Number @headers['content-length']
          return

        @parseHead = true
        pack    = @remain.slice 0, Number @headers['content-length']
        @remain = @remain.slice    Number @headers['content-length']

        #console.log 'do callback, remain is:', @remain.length
        # console.log 'get:', pack.toString 'utf8'
        @cb.shift() @statusCode, @headers, pack
        @headers = {}
      catch e
        console.log e
        console.log @remain
        console.log index
        console.log head



  get: (url, cb) ->
    return console.log 'parser not connected' if ! @connected
    @cb.push cb
    # console.log "accept get: cb.length is #{@cb.length}"
    @socket.write "GET #{url} HTTP/1.1\r\n\r\n", 'binary'

  post: (url, buf, cb) ->
    return if ! @connected
    @cb.push cb
    # console.log "accept post: cb.length is #{@cb.length}"
    @socket.write "POST #{url} HTTP/1.1\r\nContent-Type: application/json\r\ncontent-length: #{buf.length}\r\n\r\n"
    @socket.write  buf, 'binary'
    console.log 'wrote:', buf.toString 'hex'

module.exports = ParserV2









# net = require 'net'

# ###

# V2

# ###

























# class Parser
#   constructor: (@ip, @port) ->
#     console.log @ip, @port
#     @remain    = new Buffer 0
#     @parseHead = true

#     @cb      = []
#     @headers = {}


#     @connected = false

#     @socket = net.connect @port, @ip, () =>
#       @connected = true
#       console.log 'parser connected'

#     @socket.on 'error', (e) -> console.log 'socketerror', e

#     @socket.on 'data', (data) =>
#       # console.log data.toString()
#       # console.log "on data: add #{data.length} to #{@remain.length}"
#       @remain = Buffer.concat [@remain, data]
#       @parseData()

#   parseData: () ->
#     # console.log '- - - -'
#     # console.log 'cblength:', @cb.length, 'remaining:', @remain.length
#     # console.log @remain.toString()
#     # console.log '- - - -'
#     while true
#       try
#         index  = 0
#         if @parseHead
#           string = ''
#           while @remain[index]
#             string += String.fromCharCode @remain[index++]
#             if -1 < string.search '\r\n\r\n$' # break on header end
#               # console.log 'found header end'
#               @parseHead = false
#               break
#           return if @parseHead

#           heads = string.slice(0, -4).split '\r\n'
#           head  = heads.shift()
#           @statusCode = Number head.slice 9,12
#           # console.log "head is: #{head}"

#           for header in heads
#             h = header.split(': ')
#             @headers[h[0].toLowerCase()] = h[1].toLowerCase()
#         # fi

#         @remain = @remain.slice index if index > 0 # slice only when we have something to slice

#         if @remain.length < Number @headers['content-length']
#           #console.log 'have to return no more data', @remain.length, Number @headers['content-length']
#           return

#         @parseHead = true
#         pack    = @remain.slice 0, Number @headers['content-length']
#         @remain = @remain.slice    Number @headers['content-length']

#         #console.log 'do callback, remain is:', @remain.length
#         # console.log 'get:', pack.toString 'utf8'
#         @cb.shift() @statusCode, @headers, pack
#         @headers = {}
#       catch e
#         console.log e
#         console.log @remain
#         console.log index
#         console.log head



#   get: (url, cb) ->
#     return console.log 'parser not connected' if ! @connected
#     @cb.push cb
#     # console.log "accept get: cb.length is #{@cb.length}"
#     @socket.write "GET #{url} HTTP/1.1\r\n\r\n", 'binary'

#   post: (url, buf, cb) ->
#     return if ! @connected
#     @cb.push cb
#     # console.log "accept post: cb.length is #{@cb.length}"
#     @socket.write "POST #{url} HTTP/1.1\r\nContent-Type: application/json\r\ncontent-length: #{buf.length}\r\n\r\n"
#     @socket.write  buf, 'binary'
#     console.log 'wrote:', buf.toString 'hex'

# module.exports = ParserV2

























