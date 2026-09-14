#!/bin/bash
# ==============================================================================
# HardCode Academy: Kokoro-82M Neural TTS Automated Provisioning Script
# Sets up Kokoro-82M with the flagship af_heart mascot voice on Ubuntu/Debian.
# ==============================================================================

set -e

INSTALL_DIR="/opt/kokoro_tts"
SERVICE_NAME="kokoro-tts"
PORT=8088

echo "======================================================="
echo " [Kokoro-82M] Provisioning Neural TTS on Callisto VM"
echo "======================================================="

# 1. Install System Dependencies
echo "[1/6] Installing system dependencies..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 python3-venv python3-pip libsndfile1 espeak-ng curl

# 2. Setup Directory and Virtual Environment
echo "[2/6] Preparing /opt/kokoro_tts directory..."
sudo mkdir -p "$INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR/cache"

# Copy service code if run from deploy location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo cp "$SCRIPT_DIR/app.py" "$INSTALL_DIR/"
sudo cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"

if [ ! -d "$INSTALL_DIR/venv" ]; then
    echo "Creating Python virtual environment..."
    sudo python3 -m venv "$INSTALL_DIR/venv"
fi

echo "Installing Python dependencies..."
sudo "$INSTALL_DIR/venv/bin/pip" install --upgrade pip -q
sudo "$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/requirements.txt" -q

# 3. Download Model Weights and Voice Vectors (Kokoro v1.0)
echo "[3/6] Verifying Kokoro-82M model files..."
MODEL_FILE="$INSTALL_DIR/kokoro-v1.0.onnx"
VOICES_FILE="$INSTALL_DIR/voices-v1.0.bin"

if [ ! -f "$MODEL_FILE" ]; then
    echo "Downloading Kokoro-82M ONNX model (~310MB)..."
    sudo curl -L -s -o "$MODEL_FILE" \
        "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
fi

if [ ! -f "$VOICES_FILE" ]; then
    echo "Downloading Kokoro voices bundle (including af_heart)..."
    sudo curl -L -s -o "$VOICES_FILE" \
        "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"
fi

# 4. Set Permissions
echo "[4/6] Setting permissions for www-data..."
sudo chown -R www-data:www-data "$INSTALL_DIR"
sudo chmod -R 755 "$INSTALL_DIR"

# 5. Configure Systemd Service
echo "[5/6] Configuring systemd service: $SERVICE_NAME..."
cat << 'SYSTEMD_EOF' | sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null
[Unit]
Description=HardCode Kokoro Neural TTS Service (af_heart)
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/kokoro_tts
Environment="KOKORO_DIR=/opt/kokoro_tts"
Environment="KOKORO_MODEL_PATH=/opt/kokoro_tts/kokoro-v1.0.onnx"
Environment="KOKORO_VOICES_PATH=/opt/kokoro_tts/voices-v1.0.bin"
Environment="KOKORO_CACHE_DIR=/opt/kokoro_tts/cache"
ExecStart=/opt/kokoro_tts/venv/bin/uvicorn app:app --host 127.0.0.1 --port 8088 --workers 2
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SYSTEMD_EOF

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

# 6. Configure Nginx Reverse Proxy Route for /api/voice/
echo "[6/6] Checking Nginx reverse proxy configuration..."
sudo python3 -c '
import glob, re, os, subprocess

clean_pattern = r"([ \t]*#[^\n]*\n)?[ \t]*location\s+[\^~*]*\s*/api/voice/[^{]*\{[^}]*\}[ \t]*\n?"
proxy_block = """    # Kokoro-82M Neural Voice Synthesis Endpoint
    location /api/voice/ {
        proxy_pass http://127.0.0.1:8088;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering on;
        proxy_read_timeout 60s;
    }
"""

def update_nginx_config(content):
    clean = re.sub(clean_pattern, "", content)
    server_blocks = re.split(r"(server\s*\{)", clean)
    if len(server_blocks) <= 1:
        return content
    out = [server_blocks[0]]
    for i in range(1, len(server_blocks), 2):
        keyword = server_blocks[i]
        body = server_blocks[i+1]
        is_only_block = (len(server_blocks) == 3)
        should_inject = is_only_block or (("root" in body or "ssl" in body or "443" in body or "hardcode" in body or "index" in body) and ("return 301" not in body or "root" in body))
        if should_inject:
            loc_match = re.search(r"(\n[ \t]*location\s+[/~^])", body)
            if loc_match:
                idx = loc_match.start()
                body = body[:idx] + "\n\n" + proxy_block + body[idx:]
            else:
                last_brace = body.rfind("}")
                if last_brace != -1:
                    body = body[:last_brace] + "\n" + proxy_block + "\n" + body[last_brace:]
                else:
                    body = "\n" + proxy_block + body
        out.append(keyword)
        out.append(body)
    return "".join(out)

conf_candidates = glob.glob("/etc/nginx/sites-enabled/*") + glob.glob("/etc/nginx/conf.d/*.conf")
visited_paths = set()
backups = {}

for conf_file in conf_candidates:
    if not os.path.isfile(conf_file):
        continue
    real_p = os.path.realpath(conf_file)
    if real_p in visited_paths:
        continue
    visited_paths.add(real_p)

    try:
        with open(real_p, "r") as fp:
            orig = fp.read()
        updated = update_nginx_config(orig)
        if updated != orig:
            backups[real_p] = orig
            with open(real_p, "w") as fp:
                fp.write(updated)
            print(f"Configured /api/voice/ proxy in: {real_p}")
    except Exception as e:
        print(f"Notice on {real_p}: {e}")

# Validate Nginx syntax before committing
test_res = subprocess.run(["nginx", "-t"], capture_output=True, text=True)
if test_res.returncode != 0:
    print(f"Nginx configuration test failed! Rolling back changes...\n{test_res.stderr}")
    for path, orig in backups.items():
        with open(path, "w") as fp:
            fp.write(orig)
    raise SystemExit(1)

print("Nginx syntax validation passed.")
reload_res = subprocess.run(["systemctl", "reload", "nginx"])
if reload_res.returncode != 0:
    print("Reload returned non-zero, restarting Nginx...")
    subprocess.run(["systemctl", "restart", "nginx"], check=True)
print("Nginx successfully reloaded.")
'

# Verify Service Health
sleep 3
echo "Verifying local service health directly on port 8088..."
curl -s http://127.0.0.1:8088/api/voice/health || echo "Notice: Service starting up..."

echo "Verifying service via Nginx on localhost..."
curl -s -k -H "Host: hardcode.academy" https://127.0.0.1/api/voice/health || curl -s http://127.0.0.1/api/voice/health || echo "Notice: Nginx proxy..."

echo "======================================================="
echo " [Kokoro-82M] af_heart Voice Service Setup Completed!"
echo "======================================================="
