---
description: Tests Minitest
paths:
  - "test/**/*.rb"
---

# Tests

- Minitest + `rack-test`, lancés avec `bundle exec ruby -Itest -e 'Dir["test/*_test.rb"].each { |f| require "./#{f}" }'`. La configuration de test (origines, SMTP, bits faibles) est fixée en tête de `test/app_test.rb` ; `HASHCASH_BITS=8` garde le minage rapide.
- L'envoi passe par la livraison `:test` de la gem `mail` (`Mail::TestMailer.deliveries`) : aucun SMTP réel. Un test qui ouvre une vraie connexion est un test cassé.
- `test/hashcash_test.rb` couvre le module isolément, `test/app_test.rb` le flux complet. `setup` remet l'état à zéro avec `FormToMail.reset_state!`.
- Un comportement de sécurité se double d'un test qui vérifie l'échec attendu : origine inconnue → `403`, honeypot → faux succès, stamp rejeté ou rejoué, `_redirect` hors-site neutralisé, bits absurdes rejetés sans allocation, limites atteintes. Toucher à un invariant de `sinatra.md` ou de `hashcash.md` sans mettre à jour son test est une régression.
