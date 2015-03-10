



FastangoCursor = (cursorUrl, parser, body) ->
  try body = JSON.parse body catch e
    body = code : 500

  if body.code is 201
    _result =    body.result
    _more   = !! body.hasMore
    _count  =    body.count
    _id     =    body.id
    _idx    =    0

  console.log '- - - - -'
  # console.log _result
  console.log "more #{_more}"
  console.log "count #{_count}"
  console.log "id #{_id}"
  console.log '- - - - -'

  {
    _all: (cb) ->
      @_more (status) =>
        return cb status if status isnt 200 or ! _more
        @_all cb

    _more: (cb) ->
      return cb 200 if ! _more

      parser.put cursorUrl+_id, null, (status, headers, data) ->
          # console.log "put result #{status} #{status.constructor} #{headers} #{data}"
          return cb status if status isnt 200

          try data = JSON.parse data catch then return cb 500
          # console.log "parsed data"

          _result.push.apply _result, data.result
          # console.log "pushed applyed"

          _more = data.hasMore
          # console.log "set more & cb"
          cb status

    all : (cb) ->
      @_all (status) ->
        _idx = _result.length
        try cb status, _result

    next : (cb) ->

    hasNext : () -> _more || _index < _result.length
  }




fastango = (parser, currentDb, cb) ->
  obj =
    _db:  () -> currentDb
    _use: (newDb, cb) -> fastango parser, newDb, cb

    _queryUrl:       "/_db/#{currentDb}/_api/cursor"
    _transactionUrl: "/_db/#{currentDb}/_api/transaction"
    _postCollection: "/_db/#{currentDb}/_api/collection"

    _query: (q, bindVars, opts, cb) ->
      if typeof bindVars is 'function'
        cb       = bindVars
        bindVars = undefined
      if typeof opts is 'function'
        cb   = opts
        opts = undefined

      data =
        query     : q
        bindVars  : bindVars                || undefined
        batchSize : opts and opts.batchSize || undefined
        ttl       : opts and opts.ttl       || undefined
        count     : opts and opts.count     || false
        options :
          fullCount         : opts and opts.fullCount      || false
          maxPlans          : opts and opts.maxPlans       || undefined
          'optimizer.rules' : opts and opts.optimizerRules || undefined
      parser.post this._queryUrl, new Buffer(JSON.stringify(data), 'utf8'), (status, headers, body) =>
        console.log status
        console.log headers
        console.log body
        console.log 'cb cursor'
        cb status, FastangoCursor "#{@_queryUrl}/", parser, body


    _transaction: (opts, func, cb) ->
      console.log 'fastango _transaction'
      body = 
        action:      String func
        collections: opts.collections || {}
        waitForSync: opts.waitForSync || undefined
        lockTimeout: opts.lockTimeout || undefined
        params     : opts.params      || undefined

      console.log 'fastango post transaction'
      try parser.post @_transactionUrl, new Buffer(JSON.stringify(body), 'utf8'), cb catch e
        console.log e


    _createDocumentCollection: (name, options, cb) ->
      if typeof options is 'function'
        cb      = options
        options = {}
      options.name = name
      parser.post @_postCollection, new Buffer(JSON.stringify(options), 'utf8'), (status, headers, body) ->
        if 200 is status
          setupCollection name
        cb status, headers, body

  # obj

  setupCollection = (colName) ->
      obj[colName] = urls:{}
      obj[colName].urls['GET_DOC']      = "/_db/#{currentDb}/_api/document/#{colName}/"
      obj[colName].urls['POST_DOC']     = "/_db/#{currentDb}/_api/document?collection=#{colName}"
      obj[colName].urls['TRUNCATE_COL'] = "/_db/#{currentDb}/_api/collection/#{colName}/truncate"
      obj[colName].urls['DELETE_COL']   = "/_db/#{currentDb}/_api/collection/#{colName}"
      obj[colName].urls['DOC_COUNT']    = "/_db/#{currentDb}/_api/collection/#{colName}/count"

      ###
          DOCUMENT OPERATIONS
      ###
      obj[colName].save = (str, cb) ->
        parser.post this.urls['POST_DOC'], new Buffer(str, 'utf8'), cb

      obj[colName].head = (_key, cb) -> cb 501

      obj[colName].document = (_key, cb) ->
        parser.get this.urls['GET_DOC']+_key, cb

      obj[colName].update  = (_key, str, cb) -> cb 501

      obj[colName].replace = (_key, cb) -> cb 501

      obj[colName].delete  = (_key, cb) -> cb 501

      obj[colName].all     = (cb) -> cb 501

      obj[colName].count = (cb) ->
        parser.get this.urls['DOC_COUNT'], cb

      ###
          COLLECTION OPERATIONS
      ###
      obj[colName].truncate = (cb) ->
        parser.put this.urls['TRUNCATE_COL'], null, cb

      obj[colName].drop = (cb) ->
        parser.delete this.urls['DELETE_COL'], (status, headers, body) ->
          if 200 is status
            obj[colName] = null
            delete obj[colName]
            console.log 'delete col because status is 200'
          cb status, headers, body

      obj[colName].load = (cb)   -> cb 501

      obj[colName].unload = (cb) -> cb 501



  parser.get "/_db/#{currentDb}/_api/collection?excludeSystem=true", (status, headers, body) ->
    collections = JSON.parse body
    try
      setupCollection col.name for col in collections.collections
    catch e
      console.log e




    try cb status, obj
  return obj









module.exports = fastango







