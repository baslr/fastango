// Generated by CoffeeScript 1.9.1
(function() {
  var Parser, ParserV2, net;

  net = require('net');


  /*
  
  V2
   */

  ParserV2 = (function() {
    function ParserV2(ip, port) {
      this.ip = ip;
      this.port = port;
      console.log(this.ip, this.port);
      this.queue = [];
      this.connected = false;
      this.reconnecting = false;
    }

    ParserV2.prototype.reconnect = function() {
      if (this.reconnecting) {
        return;
      }
      this.reconnecting = true;
      console.log('parser reconnect');
      this.socket = net.connect(this.port, this.ip);
      this.socket.on('connect', (function(_this) {
        return function() {
          console.log('socket connect');
          _this.remain = new Buffer(0);
          _this.parseHead = true;
          _this.headers = {};
          _this.error = null;
          _this.connected = true;
          _this.reconnecting = false;
          if (_this.queue.length) {
            return _this.handleQueue();
          }
        };
      })(this));
      this.socket.on('error', (function(_this) {
        return function(e) {
          _this.error = e;
          _this.connected = false;
          return console.log('socket error', e);
        };
      })(this));
      this.socket.on('end', (function(_this) {
        return function() {
          _this.connected = false;
          return console.log('socket end');
        };
      })(this));
      this.socket.on('close', (function(_this) {
        return function() {
          _this.connected = false;
          console.log('socket close');
          if (_this.queue.length === 0) {
            return;
          }
          return _this.reconnect();
        };
      })(this));
      return this.socket.on('data', (function(_this) {
        return function(data) {
          _this.remain = Buffer.concat([_this.remain, data]);
          return _this.parseData();
        };
      })(this));
    };

    ParserV2.prototype.parseData = function() {
      var contentLength, e, h, head, header, heads, i, index, len, pack, string;
      while (true) {
        try {
          index = 0;
          if (this.parseHead) {
            index = 10;
            string = this.remain.slice(0, 10).toString('ascii');
            while (this.remain[index]) {
              string += String.fromCharCode(this.remain[index++]);
              if (-1 < string.search('\r\n\r\n$')) {
                this.parseHead = false;
                break;
              }
            }
            if (this.parseHead) {
              return;
            }
            heads = string.slice(0, -4).split('\r\n');
            head = heads.shift();
            this.statusCode = Number(head.slice(9, 12));
            for (i = 0, len = heads.length; i < len; i++) {
              header = heads[i];
              h = header.split(': ');
              this.headers[h[0].toLowerCase()] = h[1].toLowerCase();
            }
          }
          if (index > 0) {
            this.remain = this.remain.slice(index);
          }
          contentLength = Number(this.headers['content-length']);
          if (this.remain.length < contentLength) {
            return;
          }
          this.parseHead = true;
          pack = this.remain.slice(0, contentLength);
          this.remain = this.remain.slice(contentLength);
          try {
            this.queue.shift().pop()(this.statusCode, this.headers, pack);
          } catch (_error) {}
          this.headers = {};
          if (0 === this.remain.length) {
            return;
          }
        } catch (_error) {
          e = _error;
          console.log("PARSE ERROR:");
          console.log(e);
          console.log(this.remain);
          console.log(index);
          console.log(head);
        }
      }
    };

    ParserV2.prototype.handleQueue = function() {
      var entry, i, len, ref, results;
      if (!this.connected) {
        return this.reconnect();
      }
      ref = this.queue;
      results = [];
      for (i = 0, len = ref.length; i < len; i++) {
        entry = ref[i];
        this[entry[0]].apply(this, entry);
        if (this.error) {
          break;
        } else {
          results.push(void 0);
        }
      }
      return results;
    };


    /*
        GET
     */

    ParserV2.prototype.get = function(url, cb) {
      this.queue.push(['_get', url, cb]);
      if (!this.connected) {
        return this.reconnect();
      }
      return this._get(0, url);
    };

    ParserV2.prototype._get = function(_, url) {
      return this.socket.write("GET " + url + " HTTP/1.1\r\n\r\n", 'ascii');
    };


    /*
        POST
     */

    ParserV2.prototype.post = function(url, buf, cb) {
      this.queue.push(['_post', 'POST', url, buf, cb]);
      if (!this.connected) {
        return this.reconnect();
      }
      return this._post(0, 'POST', url, buf);
    };

    ParserV2.prototype._post = function(_, method, url, buf) {
      return this._writeRequest('POST ', url, buf);
    };


    /*
        PUT
     */

    ParserV2.prototype.put = function(url, buf, cb) {
      this.queue.push(['_put', url, buf, cb]);
      if (!this.connected) {
        return this.reconnect();
      }
      return this._put(0, url, buf);
    };

    ParserV2.prototype._put = function(_, url, buf) {
      if (buf) {
        this.socket.write("PUT " + url + " HTTP/1.1\r\nContent-Type: application/json\r\ncontent-length: " + buf.length + "\r\n\r\n");
        return this.socket.write(buf, 'binary');
      } else {
        return this.socket.write("PUT " + url + " HTTP/1.1\r\n\r\n", 'ascii');
      }
    };


    /*
        DELETE
     */

    ParserV2.prototype["delete"] = function(url, cb) {
      this.queue.push(['_delete', url, cb]);
      if (!this.connected) {
        return this.reconnect();
      }
      return this._delete(0, url);
    };

    ParserV2.prototype._delete = function(_, url) {
      return this.socket.write("DELETE " + url + " HTTP/1.1\r\n\r\n", 'ascii');
    };


    /*
        PATCH
     */

    ParserV2.prototype.patch = function(url, buf, cb) {
      this.queue.push(['_patch', url, buf, cb]);
      if (!this.connected) {
        return this.reconnect();
      }
      return this._patch(0, url, buf);
    };

    ParserV2.prototype._patch = function(_, url, buf) {
      return this._writeRequest('PATCH ', url, buf);
    };

    ParserV2.prototype._writeRequest = function(method, url, buf) {
      this.socket.write(method);
      this.socket.write(url);
      this.socket.write(" HTTP/1.1\r\ncontent-type: application/json\r\ncontent-length: ");
      this.socket.write(buf.length + "\r\n\r\n");
      return this.socket.write(buf, 'binary');
    };

    return ParserV2;

  })();


  /*
        with strings
   */


  /*
  
      WITH buffer head parsers by finding the binary \r\n\r\n
   */

  Parser = (function() {
    function Parser(ip, port) {
      this.ip = ip;
      this.port = port;
      console.log(this.ip, this.port);
      this.remain = new Buffer(0);
      this.parseHead = true;
      this.cb = [];
      this.headers = {};
      this.connected = false;
      this.socket = net.connect(this.port, this.ip, (function(_this) {
        return function() {
          _this.connected = true;
          return console.log('parser connected');
        };
      })(this));
      this.socket.on('error', function(e) {
        return console.log('socketerror', e);
      });
      this.socket.on('data', (function(_this) {
        return function(data) {
          _this.remain = Buffer.concat([_this.remain, data]);
          return _this.parseData();
        };
      })(this));
    }

    Parser.prototype.parseData = function() {
      var e, h, head, header, heads, i, index, len, pack, string;
      while (true) {
        try {
          index = 0;
          if (this.parseHead) {
            string = '';
            while (this.remain[index]) {
              string += String.fromCharCode(this.remain[index++]);
              if (-1 < string.search('\r\n\r\n$')) {
                this.parseHead = false;
                break;
              }
            }
            if (this.parseHead) {
              return;
            }
            heads = string.slice(0, -4).split('\r\n');
            head = heads.shift();
            this.statusCode = Number(head.slice(9, 12));
            for (i = 0, len = heads.length; i < len; i++) {
              header = heads[i];
              h = header.split(': ');
              this.headers[h[0].toLowerCase()] = h[1].toLowerCase();
            }
          }
          if (index > 0) {
            this.remain = this.remain.slice(index);
          }
          if (this.remain.length < Number(this.headers['content-length'])) {
            return;
          }
          this.parseHead = true;
          pack = this.remain.slice(0, Number(this.headers['content-length']));
          this.remain = this.remain.slice(Number(this.headers['content-length']));
          this.cb.shift()(this.statusCode, this.headers, pack);
          this.headers = {};
        } catch (_error) {
          e = _error;
          console.log(e);
          console.log(this.remain);
          console.log(index);
          console.log(head);
        }
      }
    };

    Parser.prototype.get = function(url, cb) {
      if (!this.connected) {
        return console.log('parser not connected');
      }
      this.cb.push(cb);
      return this.socket.write("GET " + url + " HTTP/1.1\r\n\r\n", 'binary');
    };

    Parser.prototype.post = function(url, buf, cb) {
      if (!this.connected) {
        return;
      }
      this.cb.push(cb);
      this.socket.write("POST " + url + " HTTP/1.1\r\nContent-Type: application/json\r\ncontent-length: " + buf.length + "\r\n\r\n");
      this.socket.write(buf, 'binary');
      return console.log('wrote:', buf.toString('hex'));
    };

    return Parser;

  })();

  module.exports = ParserV2;

}).call(this);
