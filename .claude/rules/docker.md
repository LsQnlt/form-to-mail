---
description: Image Docker et déploiement
paths:
  - "Dockerfile"
  - ".dockerignore"
  - "puma.rb"
---

# Docker et déploiement

- Image unique `ruby:3.2-slim`, `bundle install` avec `BUNDLE_FROZEN` et `BUNDLE_WITHOUT="test"`, lancée en `USER app` non root. Garder l'utilisateur non privilégié et `Gemfile.lock` à jour (`bundle install` modifie le lock, pas le Dockerfile).
- Le service écoute sur `PORT` (3000 par défaut), un seul worker Puma, 0 à 4 threads. Comme l'état anti-spam est en mémoire de ce processus, garder un seul worker : plusieurs workers ne partageraient pas les stamps dépensés ni les compteurs.
- Déployé derrière un reverse proxy qui termine le TLS (Traefik via Coolify). Le service partage son hôte avec d'autres applications : une fuite de mémoire ou un DoS ici les menace toutes, d'où l'importance du bornage des bits (voir `hashcash.md`).
- Les secrets (`SMTP_URL` surtout) vont dans les variables d'environnement de l'hébergeur, **jamais** dans le `Dockerfile` ni un fichier versionné. `.env` est ignoré par Git et exclu de l'image via `.dockerignore`.
- `.dockerignore` garde l'image minimale : pas de `.git`, pas de `test`, pas de `README`. `public/` reste dans l'image car `hashcash.js` y est servi.
