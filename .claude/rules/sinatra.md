---
description: L'application Sinatra, le flux d'envoi et ses invariants de sécurité
paths:
  - "app.rb"
  - "config.ru"
---

# Sinatra, envoi et sécurité

## La route

- `POST /send` reçoit le formulaire, valide, vérifie l'anti-spam, envoie l'email et renvoie le visiteur sur son site. `GET /` répond `ok` pour le health check. `hashcash.js` est servi en statique depuis `public/`. Ne pas ajouter de route sans besoin démontré.
- Pas de stockage persistant : stamps dépensés et horodatages d'envoi sont en mémoire et repartent de zéro au redémarrage, ce qui est acceptable car les stamps expirent avec leur date et les limites sont horaires et journalières.

## Ordre des contrôles, à conserver

Dans `POST /send`, l'ordre protège le service :

1. Origine dans `ALLOWED_ORIGINS`, sinon `403`.
2. Honeypot `website` rempli → faux succès silencieux.
3. Champs présents, email au bon format, longueurs bornées.
4. Stamp hashcash valide, au bon format et non déjà dépensé.
5. Limites par IP et par jour.

Ne pas placer une opération coûteuse avant une vérification bon marché. Le bornage des bits du stamp (voir `hashcash.md`) existe précisément pour qu'une vérification ne puisse pas allouer de mémoire avant le rate limiting.

## Invariants de sécurité

- **Allowlist d'origines** : `origin` lit `HTTP_ORIGIN`. C'est la protection contre l'abus cross-site depuis un navigateur ; elle ne protège pas d'un client direct qui forge l'en-tête. Les autres contrôles (hashcash, limites) doivent donc tenir seuls.
- **Redirection de retour** : `back_url` n'accepte qu'un chemin commençant par `/` et pas par `//`, et reconstruit l'URL sur l'`origin` du site. C'est ce qui empêche une redirection ouverte vers un domaine tiers via `_redirect`. Ne pas assouplir ce contrôle ; il a un test dédié.
- **En-tête d'email** : le nom du visiteur part en `display_name` via `Mail::Address#format`, qui encode les retours à la ligne. Ne jamais construire un en-tête (`Reply-To`, `Subject`) par concaténation de chaîne brute : ce serait une injection d'en-têtes.
- **Fuite d'information** : le visiteur est renvoyé avec `?sent=1` ou `?sent=0`, jamais avec la raison de l'échec. La raison reste dans les logs. Garder cette discrétion.

## Erreurs

- `show_exceptions`, `raise_errors` et `dump_errors` sont désactivés volontairement. Le bloc `error` renvoie le visiteur sur son site avec `sent=0` quand l'origine est connue, sinon une réponse brute. Garder ce comportement : un échec SMTP ne doit jamais exposer de trace.
