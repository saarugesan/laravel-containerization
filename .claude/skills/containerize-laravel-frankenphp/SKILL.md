---
name: containerize-laravel-frankenphp
description: Containerize a Laravel app with FrankenPHP + Laravel Octane (dev + prod Docker images, Compose file, Supervisor config). Use when the user asks to containerize, dockerize, or add Docker support to a Laravel project, or to set up FrankenPHP/Octane for one.
---

# Containerize a Laravel app with FrankenPHP + Octane

This is a checklist for scaffolding a known-good Docker setup for a Laravel app, based on a
template extracted from a working production project. FrankenPHP is a single binary (built on
Caddy) that replaces both Nginx and PHP-FPM, and runs Laravel through Octane so the framework
boots once and stays resident in memory. Do not introduce Nginx or PHP-FPM config — they are not
needed with this stack.

## Before starting

Confirm with the user (or infer from the repo) rather than guessing:
- Where does the Laravel app live relative to the repo root? This template assumes the app is
  under `./src` (i.e. `./src/app`, `./src/composer.json`, `./src/artisan`, etc.) with the
  Dockerfiles living one level up. If the app is at the repo root instead, adjust every `COPY
  ./src/...` path accordingly.
- Does the app use Vite for frontend assets? If not, drop the Node build stage in the prod
  Dockerfile and the `5173` port in Compose.
- Is a database/Redis already hosted externally, or does this project need one spun up locally?
  Default assumption: **externally hosted, reachable via `.env`** — don't add `db`/`redis`
  services to Compose unless the user asks for them.
- What PHP extensions does the app actually require (check `composer.json` for hints like
  `ext-gd`, `ext-redis`, `predis` vs `phpredis`, `pdo_pgsql` vs `pdo_mysql`)? Don't blindly copy
  the full extension list below — trim/extend to fit.
- Does the app have a health-check route (e.g. `/api/health` or `/up`)? Point the Dockerfile's
  `HEALTHCHECK` at it, or drop the `HEALTHCHECK` if there isn't one yet.

## Files to create

Base every file on this template's copies (read them for the full content — this checklist only
calls out what to change):

1. **`Dockerfile.dev`** — dev image. `FROM dunglas/frankenphp:1-php8.3-bookworm` (bump the PHP
   version to match the target app), installs PHP extensions via `install-php-extensions`, Node
   (only if Vite is used), Composer, and copies in a dev entrypoint script.
2. **`docker-entrypoint.dev.sh`** — installs Composer/NPM deps on container start if missing,
   then `exec php artisan octane:frankenphp --host=0.0.0.0 --port=80 [--watch]`. Gate `--watch`
   behind a `WATCH_FILES=true` env var.
3. **`docker-compose.yml`** — one service, bind-mount the app source into `/var/www`, expose
   `8080:80` (and `5173:5173` if Vite is used). Use a project-specific `container_name` (or an
   overridable `${COMPOSE_PROJECT_NAME:-app}`), not a name copied from another project.
4. **`Dockerfile.prod`** — multi-stage: a Node stage that runs `npm ci && npm run build` (skip if
   no frontend build step), then a FrankenPHP runtime stage that:
   - Installs system deps + PHP extensions (`apt-get install` + `install-php-extensions`, plus
     `cron` and `supervisor` packages).
   - Copies `composer.json`/`composer.lock` and runs `composer install --no-dev --no-scripts
     --no-autoloader` **before** copying the rest of the app source, so app-only changes don't
     bust the dependency layer cache; copy the app source; then run `composer dump-autoload
     --optimize --no-dev`.
   - Copies the built frontend assets from the Node stage (skip if not applicable).
   - Sets `TZ` as a build `ARG` with a project-appropriate default, not hardcoded from another
     project.
   - Copies `docker/php/local.ini` to `$PHP_INI_DIR/conf.d/99-custom.ini` for shared PHP ini
     overrides (upload size, memory limit, timeouts — tune per project).
   - Configures the Laravel scheduler via `/etc/cron.d/laravel-scheduler` running
     `php artisan schedule:run` every minute.
   - Copies in `docker/supervisor/supervisord.conf` and `docker/entrypoint.prod.sh` (below)
     rather than building them inline with chained `echo` statements — keep them as real,
     readable files.
   - Sets a `HEALTHCHECK` against the app's actual health route.
5. **`docker/supervisor/supervisord.conf`** — supervises exactly the long-running processes the
   app needs: at minimum `octane` (the Octane server) and, if the app uses queues/scheduled
   jobs, `queue-worker` (`php artisan queue:work --tries=1 --timeout=370`) and `cron`
   (`/usr/sbin/cron -f`). Every long-running process should be under Supervisor (not backgrounded
   with `&` in the entrypoint script) so a crash actually gets restarted.
6. **`docker/entrypoint.prod.sh`** — if `.env` is present, run `php artisan config:cache
   route:cache view:cache`, then `exec /usr/bin/supervisord -c
   /etc/supervisor/conf.d/supervisord.conf`.
7. **`docker/php/local.ini`** — shared PHP ini tuning (e.g. `upload_max_filesize`,
   `post_max_size`, `memory_limit`, `max_execution_time=0` since Octane workers are long-lived).

## Explicit non-goals

- Don't add Nginx or PHP-FPM config — FrankenPHP replaces both.
- Don't add `db`/`redis` Compose services unless the user asks for local ones — default to
  externally-hosted services configured via `.env`.
- Don't bake project-specific throwaway scaffolding (mock API servers, one-off scripts) into the
  base template — keep it generic; project-specific extras belong in the target repo, not this
  pattern.
- Keep the Supervisor/entrypoint config as plain files, not inline `echo`-chain generation.

## Verification

- `docker build -f Dockerfile.dev .` succeeds.
- `docker compose up --build` serves the app on the mapped port.
- `docker build -f Dockerfile.prod .` succeeds; inside the container, `supervisorctl status`
  shows every configured program `RUNNING`; the `HEALTHCHECK` route responds.
