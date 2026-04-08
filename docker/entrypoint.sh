#!/bin/bash
set -e

export NVM_DIR=/home/frappe/.nvm
source "$NVM_DIR/nvm.sh"

cd /home/frappe/frappe-bench

if [ ! -f "sites/apps.txt" ]; then
    echo "Initializing sites directory from template..."
    cp -r sites-init/* sites/
fi

bench set-mariadb-host "${DB_HOST:-mariadb}"
bench set-redis-cache-host "redis://${REDIS_CACHE_HOST:-redis-cache}:6379"
bench set-redis-queue-host "redis://${REDIS_QUEUE_HOST:-redis-queue}:6379"
bench set-redis-socketio-host "redis://${REDIS_QUEUE_HOST:-redis-queue}:6379"

echo "Waiting for MariaDB at ${DB_HOST:-mariadb}:${DB_PORT:-3306}..."
timeout=120
elapsed=0
until nc -z "${DB_HOST:-mariadb}" "${DB_PORT:-3306}" 2>/dev/null; do
    elapsed=$((elapsed + 2))
    if [ $elapsed -ge $timeout ]; then
        echo "ERROR: Timed out waiting for MariaDB after ${timeout}s"
        exit 1
    fi
    sleep 2
done
echo "MariaDB is ready."

SITE_NAME="${SITE_NAME:-hrms.localhost}"

if [ ! -d "sites/${SITE_NAME}" ]; then
    echo "Creating site ${SITE_NAME}..."

    bench new-site "${SITE_NAME}" \
        --mariadb-root-password "${DB_ROOT_PASSWORD:-root}" \
        --admin-password "${ADMIN_PASSWORD:-admin}" \
        --no-mariadb-socket \
        --force

    bench --site "${SITE_NAME}" install-app erpnext
    bench --site "${SITE_NAME}" install-app hrms
    bench --site "${SITE_NAME}" enable-scheduler
    bench --site "${SITE_NAME}" clear-cache

    echo "Site ${SITE_NAME} created successfully."
fi

bench use "${SITE_NAME}"

if [ -n "${FRAPPE_HOST_NAME}" ]; then
    bench --site "${SITE_NAME}" set-config host_name "${FRAPPE_HOST_NAME}"
fi

bench --site "${SITE_NAME}" set-config serve_default_site true

exec "$@"
