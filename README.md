# HttpServer

HttpServer is a simple HTTP server implementation for Lua. It allows you to create route handlers for different HTTP methods (GET, POST, PUT, DELETE, etc.) and serve static files. It also includes optional middleware for handling JSON and CORS.

## Features

- HTTP route handling
- Static file serving
- JSON parsing middleware
- CORS middleware

## Usage

First, require the HttpServer module:

```lua
require('http_server')
```

Create a new HttpServer instance:

```lua
Server = HttpServer.New()
```

Use the provided middleware for JSON parsing and CORS handling:

```lua
Server:use(HttpServer.json())
Server:use(HttpServer.cors())
```

Define routes for your API:

```lua
Server:get('/greeting', function(req, res)
  res.send('Hello world!')
end)
```

Start the server on a specific port:

```lua
Server:listen(9091)
```

## Example

This example demonstrates how to create a simple API with route handlers and middleware:

```lua
require('http_server')

API = HttpServer.New()

-- Apply JSON and CORS middleware
API:use(HttpServer.json())
API:use(HttpServer.cors())

-- Define a simple GET route
API:get('/', function(req, res)
  res.send('Hello World')
end)

-- Start the server on port 9091
API:listen(9091)
```

## CORS

To allow cross-origin requests, apply the CORS middleware:

```lua
MyServer:use(HttpServer.cors());
```

This will allow requests from all origins to all supported methods.

For endpoints that use the :all() route, you can specify the default list of permitted methods like so:

```lua
MyServer:use(HttpServer.cors({
  default_methods = {'GET','POST'}
}))
```

The default set is `GET`,`HEAD`,`PUT`,`PATCH`,`POST`, and `DELETE`.

*Note: do not include OPTIONS, as this is automatically included.*

## API

### HttpServer.New()

Creates a new HttpServer instance.

### HttpServer.json()

Returns a middleware function for JSON parsing.

### HttpServer.cors()

Returns a middleware function for handling CORS.

### HttpServer.Static(root)

Returns a middleware function for serving static files from the specified root directory.

### server:use(middleware)

Adds a middleware function to the server.

### server:listen(port)

Starts the server listening on the specified port.

### server:get(path, handler)

Adds a GET route to the server with the specified path and handler function.

### server:post(path, handler)

Adds a POST route to the server with the specified path and handler function.

### server:put(path, handler)

Adds a PUT route to the server with the specified path and handler function.

### server:delete(path, handler)

Adds a DELETE route to the server with the specified path and handler function.

### server:all(path, handler)

Adds a route for any HTTP verb to the server with the specified path and handler function.

## License

MIT License

Copyright (c) 2023 Locimation

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
