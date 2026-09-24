# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

# all the mock replies below answer the fixed key "dGhlIHNhbXBsZSBub25jZQ=="
# whose accept value is "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=" (RFC 6455 section 1.3)

no_long_string();

run_tests();

__DATA__

=== TEST 1: a well formed handshake response is accepted
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==" })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
\r
"
--- response_body
connected
--- no_error_log
[error]



=== TEST 2: a wrong Sec-WebSocket-Accept is rejected
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==" })
            if not ok then
                ngx.say("failed to connect: ", err)
                ngx.say("fatal: ", wb.fatal)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: 0000000000000000000000000000=\r
\r
"
--- response_body
failed to connect: failed websocket handshake: invalid "Sec-WebSocket-Accept" response header
fatal: true
--- no_error_log
[error]



=== TEST 3: a missing Sec-WebSocket-Accept is rejected
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==" })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
\r
"
--- response_body
failed to connect: failed websocket handshake: missing "Sec-WebSocket-Accept" response header
--- no_error_log
[error]



=== TEST 4: a non-websocket Upgrade is rejected
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==" })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: h2c\r
Connection: Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
\r
"
--- response_body
failed to connect: failed websocket handshake: invalid "Upgrade" response header
--- no_error_log
[error]



=== TEST 5: a Connection header without the upgrade token is rejected
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==" })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: close\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
\r
"
--- response_body
failed to connect: failed websocket handshake: invalid "Connection" response header
--- no_error_log
[error]



=== TEST 6: the upgrade token is found in a Connection token list
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==" })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: WebSocket\r
Connection: keep-alive, Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
\r
"
--- response_body
connected
--- no_error_log
[error]



=== TEST 7: a subprotocol that was never offered is rejected
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==" })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
Sec-WebSocket-Protocol: json\r
\r
"
--- response_body
failed to connect: failed websocket handshake: invalid "Sec-WebSocket-Protocol" response header
--- no_error_log
[error]



=== TEST 8: an offered subprotocol is accepted
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==",
                                         protocols = { "xml", "json" } })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
Sec-WebSocket-Protocol: json\r
\r
"
--- response_body
connected
--- no_error_log
[error]



=== TEST 9: an extension that was never offered is rejected
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==" })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
Sec-WebSocket-Extensions: permessage-deflate\r
\r
"
--- response_body
failed to connect: failed websocket handshake: unexpected "Sec-WebSocket-Extensions" response header
--- no_error_log
[error]



=== TEST 10: a real handshake still succeeds
--- http_config eval: $::HttpConfig
--- config
    location = /ws {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end

            local data, typ = wb:recv_frame()
            wb:send_text(data .. " [" .. typ .. "]")
        }
    }

    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            wb:send_text("hello")

            local data, typ, err = wb:recv_frame()
            if not data then
                ngx.say("failed to receive frame: ", err)
                return
            end

            ngx.say("received: ", data, " (", typ, ")")
            wb:close()
        }
    }
--- request
GET /t
--- response_body
received: hello [text] (text)
--- no_error_log
[error]



=== TEST 11: trailing whitespace in the response headers is tolerated
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==" })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket \r
Connection: Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=  \r
\r
"
--- response_body
connected
--- no_error_log
[error]



=== TEST 12: a subprotocol differing only in case is rejected
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==",
                                         protocols = { "json" } })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
Sec-WebSocket-Protocol: JSON\r
\r
"
--- response_body
failed to connect: failed websocket handshake: invalid "Sec-WebSocket-Protocol" response header
--- no_error_log
[error]



=== TEST 13: a subprotocol list passed as a single string is honoured
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local ok, err = wb:connect("ws://127.0.0.1:7986/",
                                       { key = "dGhlIHNhbXBsZSBub25jZQ==",
                                         protocols = "xml, json" })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
        }
    }
--- request
GET /t
--- tcp_listen: 7986
--- tcp_reply eval
"HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
Sec-WebSocket-Protocol: json\r
\r
"
--- response_body
connected
--- no_error_log
[error]



=== TEST 14: the server selects one of several offered subprotocols
--- http_config eval: $::HttpConfig
--- config
    location = /ws {
        content_by_lua_block {
            local server = require "resty.websocket.server"
            local wb, err = server:new()
            if not wb then
                ngx.log(ngx.ERR, "failed to new websocket: ", err)
                return ngx.exit(444)
            end
            wb:recv_frame()
        }
    }

    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local uri = "ws://127.0.0.1:" .. ngx.var.server_port .. "/ws"
            local ok, err = wb:connect(uri, { protocols = { "xml", "json" } })
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("selected: ", wb:get_resp_headers().sec_websocket_protocol)
            wb:close()
        }
    }
--- request
GET /t
--- response_body
selected: xml
--- no_error_log
[error]
