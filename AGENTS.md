# GPU Proxy

## What
C++ Stratum mining proxy (v2.0.0). Bridges miners to pools with TLS, failover, worker management.

## Stack
- C++17, CMake 3.15+, OpenSSL, nlohmann_json
- Nix flake build + NixOS systemd module
- No external dependencies beyond OpenSSL and nlohmann_json

## Build
```bash
nix build                    # flake build
nix develop                  # dev shell with cmake/gcc/gdb
cmake -B build && cmake --build build  # manual
```

## Structure
```
├── CMakeLists.txt       Build definition
├── main.cpp             Placeholder (real entry: src/main.cpp)
├── src/
│   ├── main.cpp         Entry point, signal handler
│   ├── config.*         JSON config loading
│   ├── connection.*     Non-blocking TCP + TLS (OpenSSL)
│   ├── event_loop.*     poll()-based I/O multiplexing
│   ├── pool_manager.*   Pool connection, login, failover
│   ├── worker_manager.* Miner accept, auth, job broadcast
│   ├── stratum.*        JSON-RPC / Stratum protocol types
│   └── ssl_utils.*      Blocking TLS helper
├── nix/module.nix       NixOS systemd module
└── flake.nix            Nix flake (package + module + devShell)
```

## Key Decisions
- Root `main.cpp` is a placeholder returning 0. Real entry is `src/main.cpp` (listed in CMakeLists.txt).
- `ssl_utils.*` is a blocking TLS helper. The async path uses `connection.*` with non-blocking OpenSSL.
- Dual protocol support: Monero Stratum (login/job/submit) and Bitcoin Stratum (subscribe/authorize/notify).
- Pool connections use TLS 1.2 (pinned, for Kryptex compatibility). Worker connections are plain TCP.

## NixOS Integration
- `nix/module.nix` exports `services.gpu-proxy-cpp` with declarative pool/worker config
- Runs as sandboxed systemd service (DynamicUser, strict filesystem protection)
- Config generated from NixOS options → JSON file → passed via `--config`

## Origin
Extracted from `/etc/nixos/modules/mining/gpu-proxy-cpp/` and `gpu-proxy-cpp.nix` in the nixos-config repo.
