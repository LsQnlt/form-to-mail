---
description: Preuve de travail hashcash, côté serveur et côté navigateur
paths:
  - "lib/hashcash.rb"
  - "public/hashcash.js"
---

# Hashcash

- La preuve de travail est la défense anti-spam principale : le navigateur mine un stamp dont le SHA-256 commence par N bits à zéro, le serveur le vérifie. Un coût d'une à deux secondes pour un humain, un coût par message pour un robot.
- Format du stamp, identique des deux côtés : `version:bits:YYMMDD:resource:sha256:rand:counter`. `resource` est l'hôte de la page, la date doit être aujourd'hui ou hier.

## Côté serveur (`lib/hashcash.rb`)

- `valid?` vérifie le format, la resource, la date, **et borne les bits** : `stamp.bits.between?(bits, bits + BITS_MARGIN)`. Cette borne haute est une protection, pas un détail. `authentic?` décale de `256 - bits` ; un `bits` non borné devient un décalage à gauche géant qui alloue des gigaoctets pour une seule requête. Ne jamais revenir à un simple `stamp.bits >= bits`.
- Un stamp n'est accepté qu'une fois : `app.rb` tient les stamps dépensés en mémoire (`spend`). La vérification cryptographique et l'unicité vont ensemble.
- `mint` ne sert qu'aux tests, pour fabriquer un stamp valide sans le navigateur.

## Côté navigateur (`public/hashcash.js`)

- Copie **non modifiée** de la gem [`active_hashcash`](https://github.com/BaseSecrete/active_hashcash) (MIT), servie telle quelle. Ne pas la patcher ni la reformater : une mise à jour se fait en reprenant la version amont, pas en éditant le fichier.
- Le site branché configure `resource` (l'hôte de la page) et `bits` (au moins `HASHCASH_BITS`) dans l'attribut `data-hashcash`. Le `bits` du client et le `HASHCASH_BITS` du serveur doivent rester cohérents, dans la fenêtre tolérée par `BITS_MARGIN`.
