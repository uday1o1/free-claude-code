
#!/bin/bash
# Universal launcher for free-claude-code
# Supports: macOS, Linux (GNOME, KDE, XFCE, fallback)
# https://github.com/Alishahryar1/free-claude-code

# ─── Detect OS and terminal ───────────────────────────────────────────────────
OS="$(uname -s)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

detect_linux_terminal() {
    for term in gnome-terminal konsole xfce4-terminal xterm lxterminal tilix kitty alacritty; do
        if command -v "$term" &>/dev/null; then
            echo "$term"
            return
        fi
    done
    echo "none"
}

open_terminal_window() {
    local title="$1"
    local cmd="$2"

    case "$OS" in
        Darwin)
            osascript -e "tell application \"Terminal\"
                do script \"$cmd\"
                set custom title of front window to \"$title\"
            end tell"
            ;;
        Linux)
            TERM_APP=$(detect_linux_terminal)
            case "$TERM_APP" in
                gnome-terminal)
                    gnome-terminal --title="$title" -- bash -c "$cmd; exec bash" &
                    ;;
                konsole)
                    konsole --title "$title" -e bash -c "$cmd; exec bash" &
                    ;;
                xfce4-terminal)
                    xfce4-terminal --title="$title" -e "bash -c '$cmd; exec bash'" &
                    ;;
                kitty|alacritty)
                    $TERM_APP -e bash -c "$cmd; exec bash" &
                    ;;
                xterm|lxterminal|tilix)
                    $TERM_APP -e "bash -c '$cmd; exec bash'" &
                    ;;
                none)
                    echo "⚠️  No supported terminal found."
                    echo "   Run manually: $cmd"
                    ;;
            esac
            ;;
        *)
            echo "⚠️  Unsupported OS: $OS"
            echo "   Run manually: $cmd"
            ;;
    esac
}

fix_sed() {
    # BSD sed (Mac) needs -i '', GNU sed (Linux) needs -i
    if [ "$OS" = "Darwin" ]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# ─── Check prerequisites ──────────────────────────────────────────────────────
echo ""
echo "🚀 Free Claude Code Launcher"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  .env not found. Creating from .env.example..."
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
        cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
        echo "✅ Created .env — please add your API keys then re-run."
        exit 0
    else
        echo "❌ .env.example not found. Run from the free-claude-code directory."
        exit 1
    fi
fi

if ! command -v uv &>/dev/null; then
    echo "❌ uv not found. Install it: pip install uv"
    exit 1
fi

if ! command -v claude &>/dev/null; then
    echo "❌ Claude Code not found. Install it: npm install -g @anthropic-ai/claude-code"
    exit 1
fi

# ─── Provider selection ───────────────────────────────────────────────────────
echo "Select provider:"
echo "1. NVIDIA NIM    (free, 40 req/min)"
echo "2. OpenRouter    (free models available)"
echo "3. DeepSeek      (usage-based, cheap)"
echo "4. LM Studio     (fully local, unlimited)"
echo "5. llama.cpp     (fully local, unlimited)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Provider (1-5) [1]: " provider_choice

case "$provider_choice" in
    2) PROVIDER="openrouter" ;;
    3) PROVIDER="deepseek" ;;
    4) PROVIDER="lmstudio" ;;
    5) PROVIDER="llamacpp" ;;
    *) PROVIDER="nvidia_nim" ;;
esac

echo ""

# ─── Model selection ──────────────────────────────────────────────────────────
if [ "$PROVIDER" = "nvidia_nim" ]; then
    echo "Select model:"
    echo "1. kimi-k2-thinking          (🧠 best quality, extended reasoning, default)"
    echo "2. deepseek-ai/deepseek-v4-flash  (⚡ fast coding, 1M context)"
    echo "3. kimi-k2-instruct          (🚀 fast, everyday tasks)"
    echo "4. mistral-large-3-675b-instruct-2512 (✍️  writing, emails)"
    echo "5. Custom                    (type any NIM model name)"
    read -p "Model (1-5) [1]: " model_choice

    case "$model_choice" in
        2) MODEL="nvidia_nim/deepseek-ai/deepseek-v4-flash" ;;
        3) MODEL="nvidia_nim/moonshotai/kimi-k2-instruct" ;;
        4) MODEL="nvidia_nim/mistralai/mistral-large-3-675b-instruct-2512" ;;
        5)
            read -p "Enter NIM model name (e.g. moonshotai/kimi-k2-thinking): " custom
            MODEL="nvidia_nim/$custom"
            ;;
        *) MODEL="nvidia_nim/moonshotai/kimi-k2-thinking" ;;
    esac

elif [ "$PROVIDER" = "openrouter" ]; then
    echo "Select model:"
    echo "1. deepseek/deepseek-r1-0528:free   (default)"
    echo "2. openai/gpt-oss-120b:free"
    echo "3. stepfun/step-3.5-flash:free"
    echo "4. Custom"
    read -p "Model (1-4) [1]: " model_choice

    case "$model_choice" in
        2) MODEL="open_router/openai/gpt-oss-120b:free" ;;
        3) MODEL="open_router/stepfun/step-3.5-flash:free" ;;
        4)
            read -p "Enter OpenRouter model name: " custom
            MODEL="open_router/$custom"
            ;;
        *) MODEL="open_router/deepseek/deepseek-r1-0528:free" ;;
    esac

elif [ "$PROVIDER" = "deepseek" ]; then
    echo "Select model:"
    echo "1. deepseek-chat      (default)"
    echo "2. deepseek-reasoner"
    echo "3. Custom"
    read -p "Model (1-3) [1]: " model_choice

    case "$model_choice" in
        2) MODEL="deepseek/deepseek-reasoner" ;;
        3)
            read -p "Enter DeepSeek model name: " custom
            MODEL="deepseek/$custom"
            ;;
        *) MODEL="deepseek/deepseek-chat" ;;
    esac

elif [ "$PROVIDER" = "lmstudio" ]; then
    read -p "Enter LM Studio model name (e.g. unsloth/Qwen3.5-35B-A3B-GGUF): " custom
    MODEL="lmstudio/$custom"

elif [ "$PROVIDER" = "llamacpp" ]; then
    read -p "Enter llama.cpp model name: " custom
    MODEL="llamacpp/$custom"
fi

echo ""
echo "✅ Provider : $PROVIDER"
echo "✅ Model    : $MODEL"
echo ""

# ─── Update .env ──────────────────────────────────────────────────────────────
fix_sed "s|^MODEL_OPUS=.*|MODEL_OPUS=\"$MODEL\"|" "$ENV_FILE"
fix_sed "s|^MODEL_SONNET=.*|MODEL_SONNET=\"$MODEL\"|" "$ENV_FILE"
fix_sed "s|^MODEL_HAIKU=.*|MODEL_HAIKU=\"$MODEL\"|" "$ENV_FILE"
fix_sed "s|^MODEL=.*|MODEL=\"$MODEL\"|" "$ENV_FILE"
echo "✅ Updated .env"

# ─── Launch proxy ─────────────────────────────────────────────────────────────
PROXY_CMD="cd $SCRIPT_DIR && uv run uvicorn server:app --host 0.0.0.0 --port 8082"
open_terminal_window "Claude Proxy ($PROVIDER)" "$PROXY_CMD"
echo "✅ Proxy starting..."
sleep 3

# ─── Launch Claude Code ───────────────────────────────────────────────────────
CLAUDE_CMD="ANTHROPIC_AUTH_TOKEN=freecc ANTHROPIC_BASE_URL=http://localhost:8082 claude"
open_terminal_window "Claude Code ($MODEL)" "$CLAUDE_CMD"

echo "✅ Claude Code launched!"
echo ""
echo "   Proxy  → Terminal: 'Claude Proxy ($PROVIDER)'"
echo "   Claude → Terminal: 'Claude Code ($MODEL)'"
echo ""
echo "💡 To stop: Ctrl+C in the proxy terminal"
