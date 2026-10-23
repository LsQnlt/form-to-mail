---
description: Style Ruby du service
paths:
  - "app.rb"
  - "lib/**/*.rb"
  - "config.ru"
  - "puma.rb"
  - "Gemfile"
---

# Ruby

- Le service est `app.rb` (classe `FormToMail < Sinatra::Base`) plus `lib/hashcash.rb`, monté par `config.ru`. Garder le hashcash dans son module isolé et testable.
- Toute configuration passe par des variables d'environnement lues au chargement avec `ENV.fetch` : une variable manquante doit faire échouer le démarrage. Les entiers sont lus avec `Integer(ENV.fetch(...), 10)`.
- Noms précis, sorties anticipées (`fail_back("...") unless ...`), prédicats en `?` sans préfixe `is_`.
- Guillemets doubles, `# frozen_string_literal: true` en tête de chaque fichier, Ruby 3.2 (voir `Gemfile`).
- L'état partagé (`spent_stamps`, `sent_at`) est protégé par un `Mutex` : toute lecture-écriture passe par `state_lock.synchronize`. Ne pas lire ou muter ces structures hors du verrou.
- Ne jamais journaliser le contenu d'un message ni le mot de passe SMTP. Les logs donnent IP, origine et résultat, rien du corps.
- Appliquer `.claude/rules/no-explanatory-comments.md`.
