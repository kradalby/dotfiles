# Local inference

`inference.nix` serves Qwen 3.5 2B Q4_K_M and Gemma 4 E2B Q4_K_M through
Ollama on the Pi's CPU. Models load on demand, with one resident model and one
request at a time. The default context is 4096 tokens; it is not a hard limit.

The OpenAI-compatible base URL is `http://llm-rpi5.dalby.ts.net/v1`.
Ollama's native API is also available at `http://llm-rpi5.dalby.ts.net/api`.
Clients select the exact model tag in each request:

```sh
curl http://llm-rpi5.dalby.ts.net/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3.5:2b-q4_K_M",
    "messages": [{"role": "user", "content": "Reply with a short greeting."}],
    "max_tokens": 64,
    "stream": false
  }'
```

For Gemma, use `gemma4:e2b-it-q4_K_M`. For fast responses through the native
API, set `"think": false`; reasoning can otherwise consume much of a small
output budget. HTTP runs inside the encrypted tailnet.

The matching VIP and client grant live in `infrastructure/tailscale`.
`tag:llm-client` opts tagged callers into this service; owner devices and
monitoring also have access. The backend port 11434 stays closed.

The shared module is `modules/inference`. Another Linux host uses the same
options with `acceleration = "cuda"`, `"rocm"`, or `"vulkan"`, and the
appropriate GPU drivers. Its firewall must keep the wildcard listener private;
the module rejects trusted LAN interfaces and an open backend port.
Give each new host a VIP and grant in infrastructure, and add its strict API
probe and expected model metrics to `machines/core.oracldn/monitoring.nix`.

On Apple Silicon, use `acceleration = "mlx"`, MLX-compatible model tags, and
the official Ollama app. Select an existing tagged userspace Tailscale instance
with `tailscaleInstance`. The Mac backend follows the existing loopback Caddy
Host-rewrite pattern; Linux needs no proxy. Enabling this on a Mac replaces its
existing manually configured runner and proxy; do not run both on the same ports.

Prometheus probes the VIP's `/api/version` and periodically checks inference for
each model via the Pi's node-exporter textfile collector. Model weights are
downloadable cache; conversation history belongs to clients.
