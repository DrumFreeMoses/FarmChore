# Deployment

## Production (current)

### Relay (fly.io)

```sh
cd relay
fly deploy --yes
# Set API key (one-time):
fly secrets set API_KEY=$(openssl rand -hex 16) --app farmchore
```

Relay URL: `wss://farmchore.fly.dev`

### Web app (GitHub Pages)

```sh
cd app
flutter build web --release \
  --base-href /FarmChore/ \
  --dart-define=FARMCHORE_RELAY=wss://farmchore.fly.dev \
  --dart-define=FARMCHORE_API_KEY=<api-key>

# Remove Flutter's built-in service worker (causes stale cache)
rm -f build/web/flutter_service_worker.js
python3 -c "
import re
with open('build/web/flutter_bootstrap.js', 'r') as f:
    c = f.read()
c = re.sub(r'serviceWorkerSettings:\s*\{[^}]+\}', '/* sw disabled */', c)
with open('build/web/flutter_bootstrap.js', 'w') as f:
    f.write(c)
"

# Deploy
rm -rf /tmp/gh-pages-deploy
mkdir /tmp/gh-pages-deploy
cp -r build/web/* /tmp/gh-pages-deploy/
cd /tmp/gh-pages-deploy
git init && git checkout -b gh-pages
git add .
git -c user.name="DrumFreeMoses" -c user.email="drumfreemoses@users.noreply.github.com" \
  commit -m "Deploy FarmChore"
git remote add origin https://github.com/DrumFreeMoses/FarmChore.git
git push -f origin gh-pages
rm -rf /tmp/gh-pages-deploy
```

### Rotating the API key

```sh
fly secrets set API_KEY=$(openssl rand -hex 16) --app farmchore
# Then rebuild web with new key and redeploy
```

## Environment tiers (planned)

| Env    | Relay                          | Web app          | Purpose             |
|--------|--------------------------------|------------------|---------------------|
| PROD   | fly.io `farmchore`             | GitHub Pages     | Live farm use       |
| DEV    | fly.io `farmchore-dev`         | GitHub Pages     | Testing             |

## Mobile builds (Sprint 4)

- Android: `flutter build apk` / `appbundle` (issue #28)
- iOS: macOS runner + TestFlight (issue #29)
