# Laravel Containerization (FrankenPHP + Octane)

A reusable Docker/Compose setup for running a Laravel app on **[Laravel Octane](https://laravel.com/docs/octane)** with the **[FrankenPHP](https://frankenphp.dev)** server, extracted from a working production project so it can be dropped into new Laravel projects as a starting point. See [`laravel-octane.md`](laravel-octane.md) for why this stack (it replaces Nginx + PHP-FPM with a single binary).

## What's here

| File | Purpose |
|---|---|
| `Dockerfile.dev` | Local dev image: installs PHP extensions, Node, Composer; expects the app bind-mounted at `/var/www`. |
| `docker-entrypoint.dev.sh` | Dev entrypoint — installs Composer/NPM deps if missing, then runs Octane (`--watch` when `WATCH_FILES=true`). |
| `docker-compose.yml` | Local dev topology: one `app` service, bind-mounts `./src`, exposes `8080` (HTTP), `443` (HTTPS/HTTP3), `5173` (Vite). |
| `Dockerfile.prod` | Multi-stage prod image: builds Vite assets in a Node stage, then a FrankenPHP/Octane runtime stage that runs Octane, the Laravel scheduler (cron), and a queue worker under Supervisor. |
| `docker/entrypoint.prod.sh` | Prod entrypoint — warms Laravel caches when `.env` is present, then hands off to Supervisor. |
| `docker/supervisor/supervisord.conf` | Supervises `octane`, `cron`, and `queue-worker` in the prod image. |
| `docker/php/local.ini` | Shared PHP ini overrides (upload size, memory limit, timeouts) applied in both dev and prod images. |

## Using this in a new project

1. Copy this repo's files into the target project (or copy the target project's Laravel app into `./src` here).
2. The Laravel app must live under `./src` — both Dockerfiles expect that layout (`./src/app`, `./src/composer.json`, etc.).
3. Supply the app's own `.env` at runtime (`DB_*`, `REDIS_*`, `APP_KEY`, ...). This template assumes the database and Redis are already hosted somewhere reachable — it does not stand up its own DB/Redis containers. If a project needs those locally, add them as extra services in `docker-compose.yml`.
4. A few values are meant to be adjusted per project:
   - `docker-compose.yml`: set `COMPOSE_PROJECT_NAME` (or just rename the service/container) instead of the generic `app`.
   - `Dockerfile.prod`: `ARG TZ=Asia/Singapore` and `ARG APP_VERSION` — override at build time with `--build-arg`, or edit the defaults.
   - `Dockerfile.dev` / `Dockerfile.prod`: the PHP extension list — trim/extend to what the target app actually needs.
   - `Dockerfile.prod`'s `HEALTHCHECK` — points at `/api/health`; point it at whatever health route the target app actually has.

## Dev vs. prod

- **Dev**: source is bind-mounted (`./src:/var/www`), dependencies install on container start via `docker-entrypoint.dev.sh`, Octane runs with `--watch` for live reload.
- **Prod**: source and built assets are baked into the image at build time, dependencies are installed with `--no-dev`, and Octane/cron/the queue worker are all supervised so a crash gets restarted automatically.

## Quick start (dev)

```bash
docker compose up --build
```

Serves the app on http://localhost:8080.

## Reusing this as a Claude Code Skill

[`.claude/skills/containerize-laravel-frankenphp/SKILL.md`](.claude/skills/containerize-laravel-frankenphp/SKILL.md) packages the checklist above as a Claude Code Skill. Point Claude Code at this repo (or copy the skill folder into another project's `.claude/skills/` or into `~/.claude/skills/`) and ask it to containerize a Laravel project with FrankenPHP/Octane.
