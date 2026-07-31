# Deployment

Three environments, all on free tiers (~$0/month):

| Env    | Relay                                   | Web app          | Purpose                  |
|--------|-----------------------------------------|------------------|--------------------------|
| DEV    | fly.io `farmchore-dev` (ephemeral)      | Cloudflare Pages | Continuous integration   |
| STAGING| fly.io `farmchore-staging`              | Cloudflare Pages | Release candidate        |
| PROD   | fly.io `farmchore`                      | Cloudflare Pages | Live farm use            |

## Relay (fly.io)

The `relay/` directory contains a minimal NIP-01 relay (Go, pure-Go SQLite).

Per-app fly config is generated from `relay/fly.toml` with a volume per
environment:

```sh
# one-time: create apps + volumes
fly apps create farmchore-dev
fly volumes create data --app farmchore-dev --size 1
# deploy
fly deploy --app farmchore-dev --config relay/fly.toml
```

Production relay URL: `wss://farmchore.fly.dev` (DEV/STAGING use their own
subdomains). Clients take the relay URL + farm pubkey at onboarding.

## Web app (Cloudflare Pages)

`flutter build web` output (`app/build/web`) is deployed to Cloudflare Pages.
The build runs in CI and publishes per branch:

- `main` -> PROD
- `staging` branch -> STAGING
- PR previews -> DEV

## Mobile builds

- Android: `flutter build apk` / `appbundle` in CI on tags (issue #28)
- iOS: macOS runner + TestFlight via `altool` in CI (issue #29)

## Cost

| Item            | Cost/month |
|-----------------|-----------|
| fly.io (3 apps, free allowance) | $0 |
| Cloudflare Pages | $0 |
| GitHub Actions (public repo) | $0 |
| **Total** | **$0** |
