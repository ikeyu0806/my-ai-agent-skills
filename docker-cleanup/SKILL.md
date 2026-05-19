---
name: docker-cleanup
description: Use when asked to inspect, reclaim, or reduce Docker disk usage; prune unused Docker containers, images, volumes, networks, build cache, BuildKit/buildx cache, or Docker Compose project resources; clean Docker Desktop storage; or choose safe Docker cleanup commands. This skill emphasizes read-only inspection first and requires explicit approval before destructive cleanup.
---

# Docker Cleanup

## Overview

Use this skill to recover Docker disk space with a predictable inspection-first workflow. Docker cleanup is destructive: stopped containers, unused images, build cache, networks, and especially volumes can contain data the user still needs.

Prefer the bundled script for repeatable inspection and command planning:

```bash
bash docker-cleanup/scripts/docker_cleanup_plan.sh
```

Add `--execute` only after the user explicitly approves the specific cleanup scope.

## Safety Rules

- Start with read-only inspection unless the user explicitly asks for a specific prune command.
- Ask before deleting anything. Treat `--force`, `-f`, `--volumes`, `volume prune`, `volume prune -a`, `system prune -a`, `compose down -v`, and manual filesystem deletion as destructive.
- Never remove `/var/lib/docker`, Docker Desktop VM files, `overlay2`, `containerd`, or Docker log files manually unless the user explicitly accepts platform-specific risk and a backup plan.
- Do not prune named volumes by default. Named volumes often hold databases, caches, and local development state.
- Check running containers and Compose projects before cleanup. An unused volume is not attached to a container, but it can still hold valuable data.
- Use age filters such as `--filter "until=24h"` or `--filter "until=168h"` when the user wants routine maintenance instead of maximum reclamation.
- Prefer labels to protect resources, for example `label!=keep` or project labels such as `com.docker.compose.project`.
- Summarize expected blast radius before executing: object types, age filter, whether named volumes are included, and whether all unused images are included.

## Workflow

1. Inspect current usage and candidates:

```bash
bash docker-cleanup/scripts/docker_cleanup_plan.sh --profile inspect
```

2. For routine cleanup planning, keep recent resources and named volumes:

```bash
bash docker-cleanup/scripts/docker_cleanup_plan.sh --profile standard --until 24h
```

3. For low-risk cleanup, plan separate prunes for stopped containers, unused networks, dangling images, and old build cache:

```bash
bash docker-cleanup/scripts/docker_cleanup_plan.sh --profile safe --until 24h
```

4. For aggressive image/cache cleanup, plan removal of all unused images and broader build cache:

```bash
bash docker-cleanup/scripts/docker_cleanup_plan.sh --profile aggressive --until 168h
```

5. If the user approves the exact plan, rerun with `--execute`:

```bash
bash docker-cleanup/scripts/docker_cleanup_plan.sh --profile standard --until 24h --execute
```

6. Re-run inspection after cleanup and report reclaimed space from Docker output:

```bash
bash docker-cleanup/scripts/docker_cleanup_plan.sh --profile inspect
```

## Cleanup Options

Use these commands as building blocks when a custom plan is better than the bundled script.

**Inspection**

```bash
docker system df -v
docker ps -a --size
docker image ls
docker volume ls
docker network ls
docker builder du
docker buildx du
docker compose ls -a
```

**Stopped containers**

```bash
docker container prune -f --filter "until=24h"
```

Removes stopped containers only. It does not remove running containers.

**Images**

```bash
docker image prune -f --filter "until=24h"
docker image prune -a -f --filter "until=168h"
```

Without `-a`, prune only dangling images. With `-a`, remove images not used by any existing container; this can force future rebuilds or pulls.

**Networks**

```bash
docker network prune -f --filter "until=24h"
```

Removes custom networks unused by containers. Default Docker networks are not removed.

**Volumes**

```bash
docker volume prune -f
docker volume prune -a -f
docker volume prune -f --filter "label!=keep"
```

Volume pruning can delete databases and application state. On modern Docker, plain `docker volume prune` removes unused anonymous volumes by default, while `-a` also includes unused named volumes. Check `docker volume prune --help` on the target host if behavior matters.

**System prune**

```bash
docker system prune -f --filter "until=24h"
docker system prune -a -f --filter "until=168h"
docker system prune -a --volumes -f --filter "until=168h"
```

`docker system prune` combines stopped containers, unused networks, dangling images, and build cache. It does not prune volumes unless `--volumes` is included. `-a` includes all unused images, not just dangling images.

**Build cache**

```bash
docker builder prune -f --filter "until=24h" --keep-storage 10GB
docker builder prune -a -f --filter "until=168h" --keep-storage 5GB
docker buildx prune -f --filter "until=24h" --max-used-space 20GB
docker buildx prune -a -f --filter "until=168h" --reserved-space 5GB
```

Use `docker buildx du` to inspect selected builder cache. If multiple builders exist, check `docker buildx ls` and target the intended builder with `--builder`.

**Compose projects**

```bash
docker compose down --remove-orphans
docker compose down --remove-orphans --rmi local
docker compose down -v --remove-orphans
docker volume ls --filter "label=com.docker.compose.project=PROJECT"
```

Use `compose down -v` only when the user accepts deleting that project's named and anonymous volumes. Compose labels are useful for identifying project-owned volumes before pruning.

## Routine Profiles

- **inspect**: read-only usage report and candidate lists.
- **safe**: stopped containers, unused networks, dangling images, and old build cache.
- **standard**: `docker system prune` with an age filter plus old build cache. No volumes unless `--include-volumes` is passed.
- **aggressive**: all unused images and broader build cache. Volumes still require `--include-volumes`; named volumes require `--all-volumes`.

## Output Pattern

When reporting results, use:

- **Status**: what was inspected, planned, or executed.
- **Scope**: object types, age filter, and whether volumes/named volumes were included.
- **Evidence**: key usage numbers or Docker output, especially reclaimed space.
- **Next action**: ask for approval before destructive cleanup, or suggest the smallest sufficient command.
