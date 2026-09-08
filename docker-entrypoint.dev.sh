#!/bin/bash

set -e

echo "=================================="
echo "Development Environment Starting"
echo "=================================="

# Install Composer dependencies if vendor directory doesn't exist or is empty
if [ ! -d "vendor" ] || [ -z "$(ls -A vendor 2>/dev/null)" ]; then
    echo "Installing Composer dependencies..."
    composer install --no-interaction --prefer-dist
else
    echo "Verifying Composer dependencies..."
    composer install --no-interaction --prefer-dist
fi

# Install NPM dependencies if node_modules directory doesn't exist or is empty
if [ ! -d "node_modules" ] || [ -z "$(ls -A node_modules 2>/dev/null)" ]; then
    echo "Installing NPM dependencies..."
    npm install
else
    echo "✓ NPM dependencies already installed"
fi

echo "=================================="
echo "Starting Laravel Octane with FrankenPHP..."
echo "=================================="

# Start Laravel Octane with FrankenPHP with file watching enabled
if [ "$WATCH_FILES" = "true" ]; then
    echo "File watching enabled - PHP files will auto-reload on change"
    exec php artisan octane:frankenphp --host=0.0.0.0 --port=80 --watch
else
    exec php artisan octane:frankenphp --host=0.0.0.0 --port=80
fi
