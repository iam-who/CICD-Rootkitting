# Security & Safety

This repository is an **intentionally vulnerable lab**. It reproduces a real
build-time supply-chain attack so engineers can learn to detect and prevent it.
Treat the compromised artifacts as malware.

## Authorized use only

Use this only on machines you own or are explicitly authorized to test. Do not
deploy the artifacts it produces, and do not point the backdoor at any system
you do not control. See the clause at the bottom of [`LICENSE`](LICENSE).

## Built-in safety boundaries

The lab is designed to be **safe by default** and dangerous only when you
explicitly opt in:

| Boundary | Default | How to change | Why |
|---|---|---|---|
| **Network exposure** | Servers bind to `127.0.0.1` (loopback only) | `LAB_BIND_ALL=1` | The backdoored binary is never reachable off your machine. |
| **Remote code execution** | The backdoor returns a *dry-run* (`rce_disabled`, echoing the command it would run) | `LAB_ALLOW_RCE=1` | You can demonstrate the gravity without arbitrary execution running unless you choose it. |
| **Backdoor token** | `secret` | `LAB_BACKDOOR_TOKEN=…` | Not hardcoded; read from the environment at runtime. |
| **Artifacts** | Not committed; built locally | — | The malicious binary never lives in source control. |

The guided demos (`demo_compare.sh`, `demo_compromised.sh`) opt in to live RCE
on loopback for teaching purposes. Running the binary directly
(`./build_compromised/server`) stays in dry-run mode.

## Reporting

This is a teaching artifact, not a production project. If you find a way the lab
is unsafe *beyond its intended scope* (e.g. it can affect a host without an
explicit opt-in), please open an issue describing it.
