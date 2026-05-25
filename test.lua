require("http_server")

-- Configuration ----------------------------------------------------------------

local PORT = 8082
local BASE = "http://127.0.0.1:" .. PORT

-- Test runner ------------------------------------------------------------------

local tests = {}
local results = {passed = 0, failed = 0}

local function check(name, cond, detail)
  if cond then
    print(string.format("[PASS] %s", name))
    results.passed = results.passed + 1
  else
    print(string.format("[FAIL] %s  |  %s", name, detail or ""))
    results.failed = results.failed + 1
  end
end

local function eq(label, expected, actual)
  check(label, expected == actual, ("expected %s, got %s"):format(tostring(expected), tostring(actual)))
end

local function add_test(name, fn)
  table.insert(tests, {name = name, fn = fn})
end

local function run_tests()
  local i = 0
  local function next()
    i = i + 1
    if i > #tests then
      print(string.format("\n=== Results: %d passed, %d failed ===", results.passed, results.failed))
      return
    end
    print(string.format("\n[%d/%d] %s", i, #tests, tests[i].name))
    tests[i].fn(next)
  end
  next()
end

-- Server setup

local app = HttpServer.New()

-- Global middleware: flag that it ran
app:use(
  "/",
  function(req, res)
    req.middlewareRan = true
  end
)

-- CORS middleware (adds Allow-Origin header; handles OPTIONS)
app:use("/", HttpServer.cors())

-- JSON body-parsing middleware
app:use("/", HttpServer.json())

-- Path-scoped middleware that intercepts and responds (tests early-exit)
app:use(
  "/protected",
  function(req, res)
    res.status(401).send("Unauthorized")
    return true
  end
)

-- Routes -----------------------------------------------------------------------

app:get(
  "/hello",
  function(req, res)
    res.send("Hello, World!")
  end
)

app:post(
  "/echo",
  function(req, res)
    res.send(req.body)
  end
)

app:put(
  "/resource",
  function(req, res)
    res.send(req.body)
  end
)

app:patch(
  "/resource",
  function(req, res)
    res.send("patched:" .. req.body)
  end
)

app:delete(
  "/resource",
  function(req, res)
    res.sendStatus(204)
  end
)

app:get(
  "/greet/:name",
  function(req, res)
    res.send("Hello, " .. req.params.name .. "!")
  end
)

app:get(
  "/greet/:first/:last",
  function(req, res)
    res.send(req.params.first .. " " .. req.params.last)
  end
)

app:get(
  "/search",
  function(req, res)
    res.send(req.query or "")
  end
)

app:post(
  "/json",
  function(req, res)
    if type(req.body) == "table" then
      res.send(tostring(req.body.key or "no-key"))
    else
      res.status(400).send("body not parsed")
    end
  end
)

app:get(
  "/teapot",
  function(req, res)
    res.status(418).send("I'm a teapot")
  end
)

app:get(
  "/custom-headers",
  function(req, res)
    res.set("X-Custom", "yes").send("ok")
  end
)

app:get(
  "/middleware-test",
  function(req, res)
    res.send(req.middlewareRan and "yes" or "no")
  end
)

-- Route that should be blocked by /protected middleware
app:get(
  "/protected/secret",
  function(req, res)
    res.send("secret")
  end
)

-- Responds to any HTTP verb
app:all(
  "/any",
  function(req, res)
    res.send(req.method)
  end
)

app:listen(PORT)
print("HTTP server listening on port " .. PORT)

-- Test cases  ------------------------------------------------------------------

-- 1: Basic GET
add_test(
  'GET /hello → 200 "Hello, World!"',
  function(next)
    HttpClient.Download(
      {
        Url = BASE .. "/hello",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("body", "Hello, World!", data)
          next()
        end
      }
    )
  end
)

-- 2: POST body echo
add_test(
  "POST /echo → echoes body",
  function(next)
    HttpClient.Upload(
      {
        Url = BASE .. "/echo",
        Method = "POST",
        Data = "ping",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("body", "ping", data)
          next()
        end
      }
    )
  end
)

-- 3: PUT body echo
add_test(
  "PUT /resource → echoes body",
  function(next)
    HttpClient.Upload(
      {
        Url = BASE .. "/resource",
        Method = "PUT",
        Data = "updated",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("body", "updated", data)
          next()
        end
      }
    )
  end
)

-- 4: PATCH body echo
add_test(
  "PATCH /resource → prefixed body",
  function(next)
    HttpClient.Upload(
      {
        Url = BASE .. "/resource",
        Method = "PATCH",
        Data = "fix",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("body", "patched:fix", data)
          next()
        end
      }
    )
  end
)

-- 5: DELETE → 204
add_test(
  "DELETE /resource → 204 No Content",
  function(next)
    HttpClient.Upload(
      {
        Url = BASE .. "/resource",
        Method = "DELETE",
        Data = "",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 204, code)
          next()
        end
      }
    )
  end
)

-- 6: Route param (single)
add_test(
  "GET /greet/:name → uses route param",
  function(next)
    HttpClient.Download(
      {
        Url = BASE .. "/greet/Alice",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("body", "Hello, Alice!", data)
          next()
        end
      }
    )
  end
)

-- 7: Route params (multiple)
add_test(
  "GET /greet/:first/:last → uses both route params",
  function(next)
    HttpClient.Download(
      {
        Url = BASE .. "/greet/John/Doe",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("body", "John Doe", data)
          next()
        end
      }
    )
  end
)

-- 8: Query string
add_test(
  "GET /search?q=hello → raw query string in req.query",
  function(next)
    HttpClient.Download(
      {
        Url = BASE .. "/search?q=hello",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("body", "q=hello", data)
          next()
        end
      }
    )
  end
)

-- 9: JSON middleware parses body when Content-Type matches
add_test(
  "POST /json + application/json → body decoded as table",
  function(next)
    HttpClient.Upload(
      {
        Url = BASE .. "/json",
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Data = '{"key":"value"}',
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("body", "value", data)
          next()
        end
      }
    )
  end
)

-- 10: JSON middleware skips when Content-Type absent
add_test(
  "POST /json without Content-Type → body not parsed",
  function(next)
    HttpClient.Upload(
      {
        Url = BASE .. "/json",
        Method = "POST",
        Data = '{"key":"value"}',
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 400, code)
          eq("body", "body not parsed", data)
          next()
        end
      }
    )
  end
)

-- 11: Custom status code
add_test(
  "GET /teapot → 418",
  function(next)
    HttpClient.Download(
      {
        Url = BASE .. "/teapot",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 418, code)
          next()
        end
      }
    )
  end
)

-- 12: Global middleware ran before route handler
add_test(
  "GET /middleware-test → global middleware ran",
  function(next)
    HttpClient.Download(
      {
        Url = BASE .. "/middleware-test",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("middleware flag", "yes", data)
          next()
        end
      }
    )
  end
)

-- 13: Path-scoped middleware intercepts before route handler
add_test(
  "GET /protected/secret → 401 intercepted by /protected middleware",
  function(next)
    HttpClient.Download(
      {
        Url = BASE .. "/protected/secret",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 401, code)
          eq("body", "Unauthorized", data)
          next()
        end
      }
    )
  end
)

-- 14: CORS OPTIONS preflight (HttpClient doesn't support OPTIONS; use raw TcpSocket)
add_test(
  "OPTIONS /hello → 204 CORS preflight",
  function(next)
    local sock = TcpSocket.New()
    sock.Connected = function()
      sock:Write("OPTIONS /hello HTTP/1.1\r\nHost: 127.0.0.1:" .. PORT .. "\r\nContent-Length: 0\r\n\r\n")
    end
    sock.Data = function()
      local data = sock:Read(sock.BufferLength)
      local code = tonumber(data:match("HTTP/%d%.%d (%d+)"))
      sock:Disconnect()
      eq("status", 204, code)
      next()
    end
    sock.Closed = function()
    end
    sock:Connect("127.0.0.1", PORT)
  end
)

-- 15: app:all matches GET
add_test(
  'GET /any → echoes verb "GET"',
  function(next)
    HttpClient.Download(
      {
        Url = BASE .. "/any",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("body", "GET", data)
          next()
        end
      }
    )
  end
)

-- 16: app:all matches POST
add_test(
  'POST /any → echoes verb "POST"',
  function(next)
    HttpClient.Upload(
      {
        Url = BASE .. "/any",
        Method = "POST",
        Data = "",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 200, code)
          eq("body", "POST", data)
          next()
        end
      }
    )
  end
)

-- 17: 404 for unknown route
add_test(
  "GET /nonexistent → 404 default handler",
  function(next)
    HttpClient.Download(
      {
        Url = BASE .. "/nonexistent",
        Timeout = 5,
        EventHandler = function(_, code, data, err)
          eq("status", 404, code)
          next()
        end
      }
    )
  end
)

-- Kick off after the server socket is ready ------------------------------------

Timer.CallAfter(run_tests, 0.5)
