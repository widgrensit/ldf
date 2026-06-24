# ldf

Erlang/OTP service for managing listener information and converting messages to ETSI XML formats. Built on Nova.

## Stack
- Erlang/OTP, Nova framework, Cowboy
- PostgreSQL via pgo
- ETSI 103120 and ETSI 103707 JSON-to-XML conversion

## Build & run
```bash
rebar3 compile
rebar3 shell              # Dev with config/sys.config
rebar3 run                # fmt --write && shell
rebar3 release            # Production release
```

## Test & quality
```bash
rebar3 fmt                # erlfmt
rebar3 dialyzer           # Static analysis
rebar3 xref               # Cross-reference checks
```

## Configuration
- Port: 8095
- DB: PostgreSQL (host: db, port: 5432, database: ldf)
- Chatli service: http://chatli:8090/v1

## API routes
- `POST /li` — create listener
- `GET /li` — list listeners
- `DELETE /li/:liid` — delete listener
- `POST /receiver` — create message
- `GET /receiver` — get messages (supports ETSI 103120/103707 conversion)
- `POST /history` — submit history
- `GET /message/:messageid` — get specific message
- `/www/admin`, `/www/receiver`, `/www/history` — web UIs

## Structure
- `src/ldf_srv.erl` — main gen_server (add/remove listeners, history)
- `src/ldf_db.erl` — database layer
- `src/ldf_router.erl` — route definitions
- `src/etsi103120.erl` — ETSI 103120 JSON-to-XML conversion
- `src/etsi103707.erl` — ETSI 103707 JSON-to-XML conversion
- `src/controllers/` — HTTP handlers (li, receiver, message)
- `priv/assets/` — static web assets
