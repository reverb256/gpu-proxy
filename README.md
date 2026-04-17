# gpu-proxy

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Nix Flake](https://img.shields.io/badge/Nix-Flake-5277C3?logo=nixos&logoColor=white)](flake.nix)
[![Built with Nix](https://img.shields.io/badge/Built%20with-Nix-5277C3?logo=nixos)](https://nixos.org)


C++ Stratum mining proxy for CR29/Kryptex with TLS, pool failover, and multi-worker management. Version 2.0.0.

## Architecture

```
Miners (workers) ──TCP──▶ gpu-proxy:3334 ──TLS──▶ Mining Pool (Kryptex/CR29)
                              │
                              ├─ WorkerManager   Accepts miner connections, handles auth
                              ├─ PoolManager     Connects to pool with failover, submits shares
                              ├─ EventLoop       poll()-based I/O multiplexing
                              └─ Config          JSON config loading
```

### Components

| File | Purpose |
|------|---------|
| `src/main.cpp` | Entry point, signal handling, wires managers together |
| `src/config.{hpp,cpp}` | JSON config loading (pools, workers, ports) |
| `src/connection.{hpp,cpp}` | Non-blocking TCP + TLS connection (OpenSSL) |
| `src/event_loop.{hpp,cpp}` | `poll()`-based event loop with timeouts |
| `src/pool_manager.{hpp,cpp}` | Pool connection, Monero-style login, share submission, failover |
| `src/worker_manager.{hpp,cpp}` | Miner accept loop, subscribe/authorize/login, job broadcast |
| `src/stratum.{hpp,cpp}` | JSON-RPC message types, Stratum protocol parsing |
| `src/ssl_utils.{hpp,cpp}` | Blocking TLS helper (used for initial pool handshake) |

### Protocol Support

- **Monero Stratum**: `login`, `job`, `submit` methods (primary for CR29/Tari)
- **Bitcoin Stratum**: `mining.subscribe`, `mining.authorize`, `mining.notify`, `mining.submit` (compatibility)
- **TLS 1.2** to pool (configurable per-pool), plain TCP from workers

### Features

- Pool failover with priority ordering
- Automatic reconnect with exponential backoff (5 attempts per pool)
- Worker whitelist (empty = allow all)
- Non-blocking I/O with `poll()` — no threads beyond main
- JSON config file (path via `--config`)

## Build

### Nix (recommended)

```bash
nix build
./result/bin/gpu-proxy --config config.json
```

### Dev shell

```bash
nix develop
cmake -B build && cmake --build build
./build/gpu-proxy --config config.json
```

### CMake (manual)

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

Requires: C++17 compiler, OpenSSL, nlohmann_json.

## NixOS Module

Import the flake's NixOS module to run gpu-proxy as a systemd service:

```nix
{
  inputs.gpu-proxy.url = "path:/data/projects/own/gpu-proxy";

  outputs = { nixpkgs, gpu-proxy, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        gpu-proxy.nixosModules.default
        {
          services.gpu-proxy-cpp = {
            enable = true;
            listenPort = 3334;
            pools = [{
              name = "kryptex";
              url = "pool.kryptex.com:7777";
              wallet = "YOUR_WALLET";
              password = "x";
              tls = true;
              priority = 0;
            }];
          };
        }
      ];
    };
  };
}
```

The service runs with strict systemd sandboxing (DynamicUser, ProtectSystem, PrivateTmp, NoNewPrivileges).

## Config Format

```json
{
  "settings": {
    "listen_port": 3334,
    "api_port": 8083,
    "log_level": "INFO"
  },
  "pools": [
    {
      "name": "kryptex",
      "url": "pool.kryptex.com:7777",
      "wallet": "YOUR_WALLET",
      "password": "x",
      "tls": true,
      "priority": 0
    }
  ],
  "workers": []
}
```

## License

Proprietary — internal use only.
