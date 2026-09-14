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
sudo apt-get install -y -qq python3 python3-venv python3-pip libsndfile1 curl

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

# 3. Download Model Weights and Voice Vectors (if not already cached)
echo "[3/6] Verifying Kokoro-82M model files..."
MODEL_FILE="$INSTALL_DIR/kokoro-v0_19.onnx"
VOICES_FILE="$INSTALL_DIR/voices.bin"

if [ ! -f "$MODEL_FILE" ]; then
    echo "Downloading Kokoro-82M ONNX model (~300MB)..."
    sudo curl -L -s -o "$MODEL_FILE" \
        "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files/kokoro-v0_19.onnx"
fi

if [ ! -f "$VOICES_FILE" ]; then
    echo "Downloading Kokoro voices bundle (including af_heart)..."
    sudo curl -L -s -o "$VOICES_FILE" \
        "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files/voices.bin"
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
Environment="KOKORO_MODEL_PATH=/opt/kokoro_tts/kokoro-v0_19.onnx"
Environment="KOKORO_VOICES_PATH=/opt/kokoro_tts/voices.bin"
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
NGINX_CONF_SNIPPET="
    # Kokoro-82M Neural Voice Synthesis Endpoint
    location /api/voice/ {
        proxy_pass http://127.0.0.1:8088;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering on;
        proxy_read_timeout 60s;
    }
"

# Find existing Nginx site config
SITE_CONF=$(grep -l "server_name" /etc/nginx/sites-enabled/* 2>/dev/null | head -n 1 || true)
if [ -n "$SITE_CONF" ] && ! grep -q "/api/voice/" "$SITE_CONF"; then
    echo "Adding /api/voice/ proxy pass to $SITE_CONF..."
    sudo sed -i "/server_name/a $NGINX_CONF_SNIPPET" "$SITE_CONF"
    sudo nginx -t && sudo systemctl reload nginx
    echo "Nginx successfully configured with /api/voice/ proxy."
fi

# Verify Service Health
sleep 2
echo "Verifying local service health..."
curl -s http://127.0.0.1:8088/api/voice/health || echo "Notice: Service starting up..."

echo "======================================================="
echo " [Kokoro-82M] af_heart Voice Service Setup Completed!"
echo "======================================================="
