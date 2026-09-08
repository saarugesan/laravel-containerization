#!/bin/bash
set -e

# Warm caches once a real .env is mounted/present
if [ -f /var/www/.env ]; then
    echo "Environment file found, warming caches..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
fi

# Start Octane, cron, and the queue worker under Supervisor
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
