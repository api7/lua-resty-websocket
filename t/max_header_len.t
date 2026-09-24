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

# a valid handshake response for the fixed key used below, padded past the
# 8192 byte default limit
our $BigReply = "HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
X-Padding: " . ("a" x 9000) . "\r
\r
";

our $SmallReply = "HTTP/1.1 101 Switching Protocols\r
Upgrade: websocket\r
Connection: Upgrade\r
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r
\r
";

# never terminated by CRLFCRLF: the client must stop reading at the limit
our $UnterminatedReply = "HTTP/1.1 101 Switching Protocols\r
X-Padding: " . ("a" x 9000);

no_long_string();

run_tests();

__DATA__

=== TEST 1: oversized response headers are refused by default
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local uri = "ws://127.0.0.1:7986/"
            local ok, err = wb:connect(uri,
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
--- tcp_reply eval: $::BigReply
--- response_body
failed to connect: failed to receive response header: response headers too large (limit: 8192 bytes)
--- no_error_log
[error]



=== TEST 2: max_header_len = 0 restores the unbounded read
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new{ max_header_len = 0 }

            local uri = "ws://127.0.0.1:7986/"
            local ok, err = wb:connect(uri,
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
--- tcp_reply eval: $::BigReply
--- response_body
connected
--- no_error_log
[error]



=== TEST 3: a smaller limit refuses a response that would otherwise fit
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new{ max_header_len = 32 }

            local uri = "ws://127.0.0.1:7986/"
            local ok, err = wb:connect(uri,
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
--- tcp_reply eval: $::SmallReply
--- response_body
failed to connect: failed to receive response header: response headers too large (limit: 32 bytes)
--- no_error_log
[error]



=== TEST 4: a header block that is never terminated is refused
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"
            local wb = client:new()

            local uri = "ws://127.0.0.1:7986/"
            local ok, err = wb:connect(uri,
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
--- tcp_reply eval: $::UnterminatedReply
--- response_body
failed to connect: failed to receive response header: response headers too large (limit: 8192 bytes)
--- no_error_log
[error]



=== TEST 5: new() rejects a bad max_header_len
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local client = require "resty.websocket.client"

            local wb, err = client:new{ max_header_len = -1 }
            ngx.say("negative: ", wb, ", ", err)

            wb, err = client:new{ max_header_len = "8192" }
            ngx.say("string: ", wb, ", ", err)
        }
    }
--- request
GET /t
--- response_body
negative: nil, max_header_len must be a non-negative number
string: nil, max_header_len must be a non-negative number
--- no_error_log
[error]



=== TEST 6: a real handshake still succeeds under the default limit
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
            local ok, err = wb:connect(uri)
            if not ok then
                ngx.say("failed to connect: ", err)
                return
            end

            ngx.say("connected")
            wb:close()
        }
    }
--- request
GET /t
--- response_body
connected
--- no_error_log
[error]
