#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# m1-webserver/run.sh — Docker Compose wrapper for multi-site Nginx
# Layout (top-level): docker/ config/ data/ backups/
# -----------------------------------------------------------------------------

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$PROJECT_ROOT/docker"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
SERVICE_NAME="sites_nginx"

NGINX_CONF_DIR="$PROJECT_ROOT/config/nginx"
SITES_DIR="$PROJECT_ROOT/data/sites"
BACKUP_SCRIPT="$PROJECT_ROOT/backups/backup.sh"

# Detect docker compose command
if command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  DC="docker compose"
fi

print_help() {
  cat <<EOF
Usage: $(basename "$0") <command> [args...]

Core:
  start                 🟢 Start Nginx stack (Docker Compose up -d)
  stop                  🔴 Stop & remove containers
  restart               🔁 Restart stack
  status                📊 Show compose services
  logs                  📜 Tail Nginx logs (Ctrl-C to exit)

Nginx:
  test-conf             🧪 Validate Nginx config (inside container or ephemeral)
  reload                ♻️  Reload Nginx (after adding/editing vhosts)
  list-sites            📂 List sites in data/sites

Deploy:
  deploy <site> <src>   🚀 Copy built site (e.g., ./dist) into data/sites/<site>/

Backup:
  backup                💾 Run backups/backup.sh (config + sites snapshot)

Misc:
  doctor                🩺 Check required paths and tools
  help                  ❓ Show this help
EOF
}

need_compose() {
  [[ -f "$COMPOSE_FILE" ]] || { echo "❌ Missing $COMPOSE_FILE"; exit 1; }
}

ensure_dirs() {
  mkdir -p "$SITES_DIR"
}

start_stack() {
  need_compose
  ensure_dirs
  echo "🟢 Starting stack..."
  (cd "$COMPOSE_DIR" && $DC up -d)
}

stop_stack() {
  need_compose
  echo "🔴 Stopping stack..."
  (cd "$COMPOSE_DIR" && $DC down)
}

restart_stack() {
  need_compose
  ensure_dirs
  echo "🔁 Restarting stack..."
  (cd "$COMPOSE_DIR" && $DC down && $DC up -d)
}

status_stack() {
  need_compose
  (cd "$COMPOSE_DIR" && $DC ps)
}

logs_stack() {
  need_compose
  (cd "$COMPOSE_DIR" && $DC logs -f "$SERVICE_NAME")
}

test_conf() {
  need_compose
  echo "🧪 Testing Nginx config..."
  # If container is running, exec; otherwise run a one-shot container with same mounts.
  if (cd "$COMPOSE_DIR" && $DC ps --status running | grep -q "$SERVICE_NAME"); then
    (cd "$COMPOSE_DIR" && $DC exec "$SERVICE_NAME" nginx -t)
  else
    echo "ℹ️ Container not running — using ephemeral container to validate config."
    (cd "$COMPOSE_DIR" && $DC run --rm "$SERVICE_NAME" nginx -t)
  fi
  echo "✅ nginx -t OK"
}

reload_nginx() {
  need_compose
  echo "♻️  Reloading Nginx..."
  (cd "$COMPOSE_DIR" && $DC exec "$SERVICE_NAME" nginx -s reload)
  echo "✅ Reloaded."
}

list_sites() {
  ensure_dirs
  echo "📂 Sites in $SITES_DIR:"
  ls -1 "$SITES_DIR" || true
}

deploy_site() {
  local site="${1:-}"
  local src="${2:-}"
  [[ -n "$site" && -n "$src" ]] || { echo "Usage: $0 deploy <site> <src_dir>"; exit 1; }
  [[ -d "$src" ]] || { echo "❌ Source dir not found: $src"; exit 1; }
  local dst="$SITES_DIR/$site"
  mkdir -p "$dst"
  echo "🚀 Deploying '$site' from '$src' -> '$dst' ..."
  rsync -a --delete "$src"/ "$dst"/
  echo "✅ Deployed. (Tip: $0 test-conf && $0 reload)"
}

backup_all() {
  [[ -x "$BACKUP_SCRIPT" ]] || { echo "❌ Backup script not found or not executable: $BACKUP_SCRIPT"; exit 1; }
  "$BACKUP_SCRIPT"
}

doctor() {
  local ok=1
  for d in "$COMPOSE_DIR" "$NGINX_CONF_DIR" "$SITES_DIR"; do
    if [[ ! -d "$d" ]]; then
      echo "❌ Missing dir: $d"
      ok=0
    fi
  done
  [[ -f "$COMPOSE_FILE" ]] || { echo "❌ Missing compose file: $COMPOSE_FILE"; ok=0; }
  command -v docker >/dev/null 2>&1 || { echo "❌ docker not found"; ok=0; }
  if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
    echo "❌ docker compose not available"; ok=0
  fi
  if [[ $ok -eq 1 ]]; then
    echo "✅ Doctor checks passed."
  else
    exit 1
  fi
}

cmd="${1:-help}"
case "$cmd" in
  start)        start_stack ;;
  stop)         stop_stack ;;
  restart)      restart_stack ;;
  status)       status_stack ;;
  logs)         logs_stack ;;
  test-conf)    test_conf ;;
  reload)       reload_nginx ;;
  list-sites)   list_sites ;;
  deploy)       shift; deploy_site "${1:-}" "${2:-}" ;;
  backup)       backup_all ;;
  doctor)       doctor ;;
  help|*)       print_help ;;
esac