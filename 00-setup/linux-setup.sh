#!/usr/bin/env bash
# Linux setup for Day 20 lab. Tested on Ubuntu 22.04 / 24.04 and Fedora 40.
set -euo pipefail

cd "$(dirname "$0")/.."
LAB_ROOT="$(pwd)"

echo "==> Day 20 lab setup (Linux)"
echo "    repo: $LAB_ROOT"

# 1. Python virtualenv
if [[ ! -d .venv ]]; then
  echo "==> Creating .venv"
  python3 -m venv .venv
fi
source .venv/bin/activate

echo "==> Upgrading pip"
python -m pip install --upgrade pip wheel > /dev/null

echo "==> Installing Python deps from requirements.txt"
pip install -r requirements.txt

# ──────────────────────────────────────────────────────────────────────────────
# 2. llama-cpp-python
#
# Strategy:
#   a) LLAMA_CUDA=1 set     → prebuilt CUDA wheel from abetlen index (no nvcc needed!)
#   b) LLAMA_VULKAN=1 set   → build from source with Vulkan
#   c) ~/llama.cpp exists   → prebuilt CPU wheel from abetlen index (no compile)
#                             + LLAMA_CPP_LIB written to .env for runtime
#   d) fallback             → prebuilt CPU wheel from abetlen index
#
# Abetlen's index has ready-made wheels for cpu / cu121 / cu122 / cu124 / cu125
# for Python 3.10-3.13 on Linux x86_64 — no compiler required.
# ──────────────────────────────────────────────────────────────────────────────

ABETLEN_CPU_INDEX="https://abetlen.github.io/llama-cpp-python/whl/cpu"
ABETLEN_CUDA_INDEX="https://abetlen.github.io/llama-cpp-python/whl/cu124"

PREBUILT_LLAMA_LIB="$HOME/llama.cpp/build/bin/libllama.so"
PREBUILT_LLAMA_BIN="$HOME/llama.cpp/build/bin"

_install_cpu_wheel() {
  echo "==> Installing prebuilt CPU wheel (no compile, no nvcc needed)"
  pip install --upgrade --force-reinstall \
    --only-binary=:all: \
    --extra-index-url "$ABETLEN_CPU_INDEX" \
    llama-cpp-python
}

if [[ "${LLAMA_CUDA:-0}" == "1" ]]; then
  # Detect CUDA version for correct wheel index
  CUDA_VER=$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9]+\.[0-9]+' || echo "12.4")
  MAJOR="${CUDA_VER%%.*}"
  MINOR="${CUDA_VER##*.}"
  CUDA_TAG="cu${MAJOR}${MINOR}"
  CUDA_INDEX="https://abetlen.github.io/llama-cpp-python/whl/${CUDA_TAG}"
  echo "==> Installing prebuilt CUDA wheel (${CUDA_TAG}) — no nvcc compile needed"
  pip install --upgrade --force-reinstall \
    --only-binary=:all: \
    --extra-index-url "$CUDA_INDEX" \
    llama-cpp-python \
  || {
    echo "    Prebuilt CUDA wheel not found for ${CUDA_TAG}. Falling back to source build..."
    CMAKE_ARGS="-DGGML_CUDA=on" pip install --upgrade --force-reinstall llama-cpp-python
  }

elif [[ "${LLAMA_VULKAN:-0}" == "1" ]]; then
  echo "==> Building llama-cpp-python with Vulkan support (source build)"
  CMAKE_ARGS="-DGGML_VULKAN=on" pip install --upgrade --force-reinstall llama-cpp-python

else
  _install_cpu_wheel

  # If ~/llama.cpp pre-built lib exists, set LLAMA_CPP_LIB in .env for runtime
  if [[ -f "$PREBUILT_LLAMA_LIB" ]]; then
    ENV_FILE="$LAB_ROOT/.env"
    [[ ! -f "$ENV_FILE" ]] && cp "$LAB_ROOT/.env.example" "$ENV_FILE" 2>/dev/null || touch "$ENV_FILE"
    # Remove old entries, then append
    { grep -v "^LLAMA_CPP_LIB" "$ENV_FILE" || true; } > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
    { grep -v "^LD_LIBRARY_PATH" "$ENV_FILE" || true; } > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
    echo "LLAMA_CPP_LIB=$PREBUILT_LLAMA_LIB" >> "$ENV_FILE"
    echo "LD_LIBRARY_PATH=$PREBUILT_LLAMA_BIN" >> "$ENV_FILE"
    echo "    Written to .env: LLAMA_CPP_LIB=$PREBUILT_LLAMA_LIB"
    echo
    echo "    ┌─ GPU Upgrade Path ─────────────────────────────────────────────────┐"
    echo "    │  Once 'sudo apt install nvidia-cuda-toolkit' finishes:             │"
    echo "    │    make rebuild-llama-cuda    # recompile ~/llama.cpp with CUDA    │"
    echo "    │    LLAMA_CUDA=1 make setup    # reinstall llama-cpp-python (CUDA)  │"
    echo "    └────────────────────────────────────────────────────────────────────┘"
  fi
fi

# 3. Probe hardware (writes hardware.json)
echo "==> Probing hardware"
python 00-setup/detect-hardware.py

# 4. Pull the recommended GGUF model
#    If ~/llama.cpp already has a GGUF, skip download and write active.json.
TINYLLAMA_LOCAL="$HOME/llama.cpp/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
if [[ -f "$TINYLLAMA_LOCAL" ]]; then
  echo "==> Found existing GGUF: $TINYLLAMA_LOCAL"
  echo "    Skipping Hugging Face download — writing models/active.json"
  mkdir -p models
  python3 - <<PYEOF
import json, pathlib
primary = "$TINYLLAMA_LOCAL"
q2 = pathlib.Path(primary).parent / "tinyllama-1.1b-chat-v1.0.Q2_K.gguf"
compare = str(q2) if q2.exists() else primary
config = {
    "tier": "TinyLlama-1.1B",
    "repo_id": "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
    "primary_model": primary,
    "compare_model": compare,
}
pathlib.Path("models/active.json").write_text(json.dumps(config, indent=2))
print(f"    primary_model : {primary}")
print(f"    compare_model : {compare}")
PYEOF
else
  python 00-setup/download-model.py
fi

echo
echo "==> Setup complete!"
echo "    Activate venv : source .venv/bin/activate"
echo "    Run benchmark : make bench"
echo "    Run server    : make serve"
echo "    Native binary : $HOME/llama.cpp/build/bin/llama-server"
