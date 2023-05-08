-- [[ CONSTANTS ]] --

HttpServer = (function()

  local HTTP_METHODS = {
    'CHECKOUT',
    'COPY',
    'DELETE',
    'GET',
    'HEAD',
    'LOCK',
    'MERGE',
    'MKACTIVITY',
    'MKCOL',
    'MOVE',
    'M-SEARCH',
    'NOTIFY',
    'OPTIONS',
    'PATCH',
    'POST',
    'PURGE',
    'PUT',
    'REPORT',
    'SEARCH',
    'SUBSCRIBE',
    'TRACE',
    'UNLOCK',
    'UNSUBSCRIBE'
  };
  
  local HTTP_CODES = {
    [100] = 'Continue',
    [101] = 'Switching Protocols',
    [102] = 'Processing',
    [200] = 'OK',
    [201] = 'Created',
    [202] = 'Accepted',
    [203] = 'Non-Authoritative Information',
    [204] = 'No Content',
    [205] = 'Reset Content',
    [206] = 'Partial Content',
    [207] = 'Multi-Status',
    [208] = 'Already Reported',
    [226] = 'IM Used',
    [300] = 'Multiple Choices',
    [301] = 'Moved Permanently',
    [302] = 'Found',
    [303] = 'See Other',
    [304] = 'Not Modified',
    [305] = 'Use Proxy',
    [306] = 'Reserved',
    [307] = 'Temporary Redirect',
    [308] = 'Permanent Redirect',
    [400] = 'Bad Request',
    [401] = 'Unauthorized',
    [402] = 'Payment Required',
    [403] = 'Forbidden',
    [404] = 'Not Found',
    [405] = 'Method Not Allowed',
    [406] = 'Not Acceptable',
    [407] = 'Proxy Authentication Required',
    [408] = 'Request Timeout',
    [409] = 'Conflict',
    [410] = 'Gone',
    [411] = 'Length Required',
    [412] = 'Precondition Failed',
    [413] = 'Request Entity Too Large',
    [414] = 'Request-URI Too Long',
    [415] = 'Unsupported Media Type',
    [416] = 'Requested Range Not Satisfiable',
    [417] = 'Expectation Failed',
    [422] = 'Unprocessable Entity',
    [423] = 'Locked',
    [424] = 'Failed Dependency',
    [425] = 'Unassigned',
    [426] = 'Upgrade Required',
    [427] = 'Unassigned',
    [428] = 'Precondition Required',
    [429] = 'Too Many Requests',
    [430] = 'Unassigned',
    [431] = 'Request Header Fields Too Large',
    [500] = 'Internal Server Error',
    [501] = 'Not Implemented',
    [502] = 'Bad Gateway',
    [503] = 'Service Unavailable',
    [504] = 'Gateway Timeout',
    [505] = 'HTTP Version Not Supported',
    [506] = 'Variant Also Negotiates (Experimental)',
    [507] = 'Insufficient Storage',
    [508] = 'Loop Detected',
    [509] = 'Unassigned',
    [510] = 'Not Extended',
    [511] = 'Network Authentication Required'
  };

  local Base64 = (function()
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
    -- encoding
    return {
      encode = function(data)
        return ((data:gsub('.', function(x) 
          local r,b='',x:byte()
          for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
          return r;
        end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
          if (#x < 6) then return '' end
          local c=0
          for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
          return b:sub(c+1,c+1)
        end)..({ '', '==', '=' })[#data%3+1])
      end,

    -- decoding
      decode = function(data)
        data = string.gsub(data, '[^'..b..'=]', '')
        return (data:gsub('.', function(x)
          if (x == '=') then return '' end
          local r,f='',(b:find(x)-1)
          for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
          return r;
        end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
          if (#x ~= 8) then return '' end
          local c=0
          for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
          return string.char(c)
        end))
      end
    };
  end)();

  local Server = {
    _server = TcpSocketServer.New(),
    _routes = {},
    _middleware = {}
  }

  local function respond(sock, code, body, options)
    options = options or {};

    if(body == nil) then
      -- do nothing
    elseif(type(body) == 'table') then
      body = require('rapidjson').encode(body);
    elseif(type(body) ~= 'string') then
      body = tostring(body);
    end;

    local headers = options.headers or {};
    local headerString = '';

    if(not headers.Connection) then
      headerString = headerString .. 'Connection: close\r\n';
    else
      options.keepalive = true;
    end;

    if(body ~= nil) then
      headerString = headerString .. ('Content-Length: %d\r\n'):format(#body);
    end;

    for k,v in pairs(options.headers or {}) do
      headerString = headerString .. ("%s: %s\r\n"):format(k,v);
    end;

    sock:Write(
      ('HTTP/1.1 %d %s\r\n%s\r\n%s'):format(
        code, HTTP_CODES[code], headerString, (body ~= nil) and body or ''
      )
    )
    if(not options.keepalive) then Timer.CallAfter(function() sock:Disconnect(); end, 1); end; -- workaround for non-blocking write
  end;

  local function defaultHandler(req, res)
    res.sendStatus(404);
  end;

  local HttpResponse = {
    New = function(obj)
      return setmetatable({
        socket = obj.socket,
        headers = {},
        statusCode = obj.statusCode or 200
      },{
        __index = function(t,k)
          if(k == 'status') then
            return function(code)
              t.statusCode = code;
              return t;
            end
          elseif(k == 'send') then
            return function(body)
              respond(t.socket, t.statusCode, body, {headers = t.headers});
              return t;
            end
          elseif(k == 'set') then
            return function(k,v)
              t.headers[k] = v;
            end
          elseif(k == 'sendStatus') then
            return function(code)
              t.status(code);
              t.send(HTTP_CODES[code]);
              return t;
            end;
          end
        end
      })
    end
  }

  local HttpRequest = {
    New = function(obj)
      return setmetatable(obj, {
        
      })
    end;
  }

  local WebSocket = {
    New = function(req, res, callback)

      if(not(req.headers['upgrade'] and req.headers['upgrade'][1] == 'websocket')) then
        res.sendStatus(400);
        return;
      end;

      if(not(req.headers['sec-websocket-version'] and req.headers['sec-websocket-version'][1])) then
        res.sendStatus(400);
        return;
      end;

      if(not(req.headers['sec-websocket-key'] and req.headers['sec-websocket-key'][1] ~= '')) then
        res.sendStatus(400);
        return;
      end;

      local client_key = req.headers['sec-websocket-key'][1];
      local response_key = Crypto.Digest('sha1', client_key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11");
      local response_b64 = Base64.encode(response_key);

      print('WEBSOCKET (v' .. req.headers['sec-websocket-version'][1] .. ')');

      res.headers['Upgrade'] = 'websocket';
      res.headers['Connection'] = 'Upgrade';
      res.headers['Sec-WebSocket-Accept'] = response_b64;
      res.status(101).send()
      
      local socket = rawget(res, 'socket');
      socket.Data = function()
        print('wsdata', socket:Read(1024));
      end;

      local function frameData(data)
        local packet = bitstring.pack('1:int 3:int 4:int 1:int 7:int', 1, 0, 0x01, 0, #data);
        packet = packet .. data;
        return packet;
      end;

      local wsObject = setmetatable({}, {
        __newindex = function(t,k,v)
          if(k == 'Closed') then
            if(type(v) ~= 'function') then
              error('Property "Closed" expects function, ' .. type(v) .. ' was given.');
            end;
            socket.Closed = v;
          end;
        end,
        __index = function(t,k)
          if(k == 'Write') then
            return function(self,str)
              socket:Write(frameData(str));
            end
          elseif(k == 'IsConnected') then
            return socket.IsConnected;
          else
            error('Property "' .. k .. ' does not exist on WebSocket.');
          end;
        end
      });

      callback(wsObject);

    end
  }

  Server._server.EventHandler = function(Sock)

    print('CONNECTION');
    Sock.EventHandler = print;

    Sock.Data = function()

      local function read()
        while(Sock:Search('\r\n') == 1) do Sock:Read(2); end;
        return Sock:ReadLine(TcpSocket.EOL.Custom, '\r\n\r\n');
      end;
      for line in read do
        local verb, resource, proto, headerString = line:match('^(%u+) ([^ ]+) HTTP/(%d%.%d)\r\n(.*)');

        -- Parse headers
        local headers = {};
        while(#headerString > 0) do

          local k,v;
          k,v,headerString = headerString:match('^([^:]+):[\t ]?([^\r\n]+)(.*)');
          if(not k) then return respond(Sock, 400); end;

          if(headerString:sub(1,2) == '\r\n') then headerString = headerString:sub(3); end;

          k = k:lower();
          if(headers[k]) then
            table.insert(headers[k], v);
          else
            headers[k] = {v};
          end;

        end;

        -- Host header must be present for HTTP 1.1
        if(proto == '1.1' and not headers['host']) then
          respond(Sock, 400);
        end;

        -- Host header must only be present once for HTTP 1.1
        if(proto == '1.1' and #headers['host'] ~= 1) then
          respond(Sock, 400);
        end;

        -- Apply host header if resource is not HTTP URI
        local host = resource:match('^http://([^/]+)');
        if(not host) then host = headers['host'][1]; end;

        -- Check for transfer encoding
        if(headers['transfer-encoding']) then
          Sock:Disconnect();
          error('TODO: implement transfer-encoding.');
        end;

        -- Check for request body
        local body;
        if(headers['content-length']) then
          local expectedBodyLength = tonumber(headers['content-length'][1]);
          if(not expectedBodyLength) then return respond(Sock, 400); end;
          if(Sock.BufferLength < expectedBodyLength) then
            error('TODO: implement state machine. Received: ' .. Sock.BufferLength .. ', expect ' .. expectedBodyLength);
          end;
          body = Sock:Read(expectedBodyLength);
        end;

        local request = HttpRequest.New({
          method = verb,
          path = resource,
          headers = headers,
          body = body
        });

        local response = HttpResponse.New({
          socket = Sock
        });

        for _,middleware in ipairs(Server._middleware) do
          if(request.path:match('^' .. middleware.path)) then
            local handled = middleware.fn(request, response);
            if(handled) then return; end;
          end;
        end;

        -- print(verb, host, resource, proto, (body and #body), require('rapidjson').encode(headers));

        for fn, handler in pairs(Server._routes) do
          local params = fn(request);
          if(params) then
            request.params = params;
            local ok, err = pcall(handler, request, response);
            if(not ok) then
              response.status(500).send(err);
              print('SERVER ERROR: ' .. err);
            end;
            return;
          end;
        end;

        defaultHandler(request, response);

      end;

    end;

  end;

  local function contains(t, v)
    for _,c in pairs(t) do
      if(c == v) then return true; end;
    end;
    return false;
  end;

  local function addRoute(server, route, verb, handler)
    local matchFn = function(req)

      -- Match method
      if(verb ~= 'all'
        and req.method:lower() ~= verb
        and req.method:upper() ~= 'OPTIONS'
      ) then return; end;

      -- Match parameters
      local paramNames = {};
      local matchPattern = route:gsub('/:([^/+]+)', function(paramName)
        table.insert(paramNames, paramName);
        return '/([^/+]+)'
      end);

      matchPattern = '^'..matchPattern..'/?$'; -- match whole string

      local values = {req.path:match(matchPattern)};
      if(not values[1]) then return; end;
      local params = {};
      for i,k in ipairs(paramNames) do
        params[k] = values[i];
      end;

      if(req.method:upper() == 'OPTIONS') then
        return verb:upper();
      else
        return params;
      end;

    end;
    server._routes[matchFn] = handler;
  end;

  local function addMiddleware(path, fn)
    assert(type(path) == 'string', 'Middleware path must be a string.');
    assert(type(fn) == 'function', 'Middleware function must be a function.');
    table.insert(Server._middleware, {path = path, fn = fn});
  end;

  return {
    STATUS_CODE = HTTP_CODES,
    METHOD = HTTP_METHODS,
    New = function()
      return setmetatable(Server, {
        __index = function(t, k)

          -- New route for HTTP verb
          if(k:lower() == k and contains(HTTP_METHODS, k:upper())) then
            return function(server, route, handler)
              addRoute(server, route, k, handler);
            end;
          end;

          -- New route for any HTTP verb
          if(k == 'all') then
            return function(server, route, handler)
              addRoute(server, route, 'all', handler);
            end;
          end;

          if(k == 'listen') then
            return function(server, port)
              server._server:Listen(port);
            end;
          end;

          if(k == 'ws') then
            return function(server, route, handler)
              if(type(handler) ~= 'function') then
                error('Expected "function" argument, got ' .. type(handler));
              end;
              addRoute(server, route, 'get', function(req, res)
                WebSocket.New(req, res, handler);
              end)
            end;
          end;

          if(k == 'use') then
            return function(server, ...)
              local args = {...};
              if(#args == 1) then
                addMiddleware('/', args[1]);
              else
                addMiddleware(args[1], args[2]);
              end;
            end;
          end;

        end;
      })
    end,
    json = function()
      return function(req, res)
        if(req.headers['content-type'] and req.headers['content-type'][1] == 'application/json') then
          req.body = require('rapidjson').decode(req.body);
        end;
      end;
    end,
    cors = function(config)
      config = config or {};

      config.default_methods = config.default_methods
        or {'GET','HEAD','PUT','PATCH','POST','DELETE'};

      return function(req, res)

        if(req.method ~= 'OPTIONS') then
          res.set('Access-Control-Allow-Origin', '*');
          return;
        end;

        for fn in pairs(Server._routes) do
          local method = fn(req);
          if(method == 'all') then method = table.concat(config.default_methods, ', '); end;
          if(method) then
            res.set('Access-Control-Allow-Origin', '*');
            res.set('Access-Control-Allow-Methods', 'OPTIONS, ' .. method);
            res.sendStatus(204);
            return true;
          end;
        end;

      end;
    end,
    Static = function(root)
      if(root:match('^/')) then root = root:sub(2); end;
      return function(req, res)
        local fh = io.open(root .. req.path, 'r');
        if(not fh) then return; end;
        local data = fh:read('*all');
        fh:close();
        res.send(data);
        return true; -- handled
      end
    end;
  };

end)();