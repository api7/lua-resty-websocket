### dev:          Install runtime dependencies locally
.PHONY: dev
dev:
	luarocks install rockspec/api7-lua-resty-websocket-master-0.rockspec --only-deps --local

### test:         Run the test suite
.PHONY: test
test:
	PATH="$(PWD)/work/nginx/sbin:$$PATH" prove -I. -r t/

### help:         Show Makefile rules
.PHONY: help
help:
	@echo Makefile rules:
	@echo
	@grep -E '^### [-A-Za-z0-9_]+:' Makefile | sed 's/###/   /'
