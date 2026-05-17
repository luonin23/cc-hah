#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# cc-hah 一键启动脚本
# 必须以 root 执行（用于清理端口和进程），但服务以 claudeuser 运行
# ============================================================

USER="claudeuser"
PROJECT_DIR="/home/claudeuser/cc-haha"
BACKEND_PORT=3456
FRONTEND_PORT=2024
BACKEND_LOG="/tmp/cc-haha-backend.log"
FRONTEND_LOG="/tmp/cc-haha-frontend.log"
HEALTH_URL="http://127.0.0.1:${BACKEND_PORT}/health"

echo "=========================================="
echo "  cc-hah Startup"
echo "=========================================="
echo ""

# --------------------------------------------------
# Step 1: Stop ALL previous processes (as claudeuser)
# --------------------------------------------------
echo "[INFO] Step 1: Stopping previous processes..."

# Kill as the target user to avoid accidentally killing root processes
su - "$USER" -c "
  for pattern in 'bun run src/server/index.ts' 'vite.*${FRONTEND_PORT}' 'bun run dev.*${FRONTEND_PORT}'; do
    pids=\$(pgrep -f \"\$pattern\" 2>/dev/null || true)
    if [ -n \"\$pids\" ]; then
      echo \"[INFO] Killing: \$pattern (PIDs: \$pids)\"
      pkill -f \"\$pattern\" 2>/dev/null || true
      sleep 1
      pkill -9 -f \"\$pattern\" 2>/dev/null || true
    fi
  done
"

sleep 1

echo "[SUCCESS] Processes stopped"
echo ""

# --------------------------------------------------
# Step 2: Clean logs
# --------------------------------------------------
echo "[INFO] Step 2: Cleaning logs..."
: > "$BACKEND_LOG"
: > "$FRONTEND_LOG"
echo "[SUCCESS] Logs cleaned"
echo ""

# --------------------------------------------------
# Step 3: Start backend
# --------------------------------------------------
echo "[INFO] Step 3: Starting backend (port ${BACKEND_PORT})..."
su - "$USER" -c "cd ${PROJECT_DIR} && nohup bun run src/server/index.ts > ${BACKEND_LOG} 2>&1 &"
sleep 2

# Health check with retry
for i in $(seq 1 15); do
  if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
    echo "[SUCCESS] Backend health OK"
    break
  fi
  if [ "$i" -eq 15 ]; then
    echo "[ERROR] Backend failed to start. Check ${BACKEND_LOG}"
    tail -20 "$BACKEND_LOG"
    exit 1
  fi
  sleep 1
done
echo ""

# --------------------------------------------------
# Step 4: Start frontend
# --------------------------------------------------
echo "[INFO] Step 4: Starting frontend (port ${FRONTEND_PORT})..."
su - "$USER" -c "cd ${PROJECT_DIR}/desktop && nohup bun run dev --host 0.0.0.0 --port ${FRONTEND_PORT} > ${FRONTEND_LOG} 2>&1 &"
sleep 2
echo "[SUCCESS] Frontend started"
echo ""

# --------------------------------------------------
# Step 5: Verify
# --------------------------------------------------
echo "[INFO] Step 5: Verifying services..."
BACKEND_UP=false
FRONTEND_UP=false

if ss -tlnp 2>/dev/null | grep -q ":${BACKEND_PORT} "; then
  echo "[SUCCESS] Backend listening on ${BACKEND_PORT}"
  BACKEND_UP=true
else
  echo "[WARN] Backend port ${BACKEND_PORT} not detected"
fi

if ss -tlnp 2>/dev/null | grep -q ":${FRONTEND_PORT} "; then
  echo "[SUCCESS] Frontend listening on ${FRONTEND_PORT}"
  FRONTEND_UP=true
else
  echo "[WARN] Frontend port ${FRONTEND_PORT} not detected"
fi

if [ "$BACKEND_UP" = true ] && [ "$FRONTEND_UP" = true ]; then
  echo ""
  echo "=========================================="
  echo "  All services up!"
  echo "=========================================="
  PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
  echo "WebUI:   http://${PUBLIC_IP}:${FRONTEND_PORT}"
  echo "Backend: http://127.0.0.1:${BACKEND_PORT}"
  echo "Logs:    ${BACKEND_LOG}  ${FRONTEND_LOG}"
else
  echo ""
  echo "[WARN] Some services may not be fully ready yet."
fi
