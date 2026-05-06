#!/usr/bin/env bash
# Launch llama-server reading models/active.json.
# Prefers native llama-server binary (~/llama.cpp/build/bin or PATH),
# falls back to python -m llama_cpp.server.
# Linux + macOS. Windows users: see start-server.ps1.
set -euo pipefail

cd "$(dirname "$0")/.."

MODEL=$(python3 -c 'import json; print(json.load(open("models/active.json"))["primary_model"])')
THREADS=$(python3 -c 'import json; hw=json.load(open("hardware.json")); print(hw["cpu"].get("cores_physical") or 4)')
GPU_LAYERS="${LAB_N_GPU_LAYERS:-99}"
PARALLEL="${LAB_PARALLEL:-4}"
CTX="${LAB_N_CTX:-2048}"

echo "==> Starting llama-server"
echo "    model     : $MODEL"
echo "    threads   : $THREADS"
echo "    gpu_layers: $GPU_LAYERS"
echo "    parallel  : $PARALLEL"
echo "    ctx       : $CTX"
echo "    listening : http://0.0.0.0:8080"
echo

# Prefer native binary — works even before llama-cpp-python is installed
LLAMA_SERVER_BIN=""
if [[ -x "$HOME/llama.cpp/build/bin/llama-server" ]]; then
  LLAMA_SERVER_BIN="$HOME/llama.cpp/build/bin/llama-server"
elif command -v llama-server &>/dev/null; then
  LLAMA_SERVER_BIN="$(command -v llama-server)"
fi

if [[ -n "$LLAMA_SERVER_BIN" ]]; then
  echo "    binary    : $LLAMA_SERVER_BIN"
  # Expose shared libs so the binary resolves libllama.so etc.
  export LD_LIBRARY_PATH="$HOME/llama.cpp/build/bin:${LD_LIBRARY_PATH:-}"
  exec "$LLAMA_SERVER_BIN" \
      --model "$MODEL" \
      --host 0.0.0.0 --port 8080 \
      --threads "$THREADS" \
      --n-gpu-layers "$GPU_LAYERS" \
      --ctx-size "$CTX" \
      --parallel "$PARALLEL"
else
  echo "    (using python -m llama_cpp.server)"
  source .venv/bin/activate 2>/dev/null || true
  exec python -m llama_cpp.server \
      --model "$MODEL" \
      --host 0.0.0.0 --port 8080 \
      --n_threads "$THREADS" \
      --n_gpu_layers "$GPU_LAYERS" \
      --n_ctx "$CTX"
fi
