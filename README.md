# form-to-mail

Reçoit le formulaire de contact d'un site statique et l'envoie par email via un relais SMTP. Remplace Netlify Forms ou Formspree. Une seule instance peut servir plusieurs sites.

Protection anti-spam sans captcha ni service tiers :

- **Preuve de travail (hashcash)** : pendant que le visiteur remplit le formulaire, `hashcash.js` calcule dans un Web Worker un stamp dont le SHA-256 commence par N bits à zéro. Une à deux secondes pour un humain, un coût par message pour un robot. Le serveur vérifie le stamp, sa date et refuse un stamp déjà utilisé. Le script est celui du gem [active_hashcash](https://github.com/BaseSecrete/active_hashcash) (MIT), servi tel quel sur `/hashcash.js`.
- **Champ piège** : un champ `website` invisible ; s'il est rempli, le message est ignoré sans le dire.
- **Limites** : par IP et par heure, et un plafond global par jour, pour borner ce qui peut atteindre la boîte de réception.

Le service ne stocke rien : les stamps vus et les compteurs sont en mémoire et repartent de zéro au redémarrage.

## Variables d'environnement

| Variable          | Rôle                                                                                                 |
| ----------------- | ---------------------------------------------------------------------------------------------------- |
| `SMTP_URL`        | `smtp://utilisateur:motdepasse@hote:587` (STARTTLS) ou `smtps://…:465` (TLS). Encoder `@` en `%40` |
| `MAIL_FROM`       | Adresse d'expédition, sur un domaine que le relais SMTP est autorisé à envoyer                       |
| `MAIL_TO`         | Adresse qui reçoit les messages                                                                      |
| `ALLOWED_ORIGINS` | Origines des sites autorisés à poster, séparées par des virgules, sans slash final                   |
| `HASHCASH_BITS`   | Difficulté de la preuve de travail, `18` par défaut                                                  |
| `RATE_LIMIT_HOUR` | Messages par IP et par heure, `5` par défaut                                                         |
| `RATE_LIMIT_DAY`  | Messages par jour tous sites confondus, `100` par défaut                                             |
| `PORT`            | Port d'écoute, `3000` par défaut                                                                     |

## Déployer

1. Chez le relais SMTP (Brevo, Postmark, boîte OVH…), authentifier le domaine de `MAIL_FROM` et récupérer les identifiants SMTP.
2. Déployer ce dépôt comme application Docker sur un domaine, par exemple `forms.example.org`, avec les variables ci-dessus. Le mot de passe SMTP va dans les variables de l'hébergeur, jamais dans un fichier versionné.
3. Vérifier que `https://forms.example.org/` répond `ok`.

## Brancher un site

1. Ajouter l'origine du site à `ALLOWED_ORIGINS` et redémarrer.
2. Dans la page du site :

   ```html
   <form action="https://forms.example.org/send" method="POST">
     <input type="text" name="name" required>
     <input type="email" name="email" required>
     <textarea name="message" required></textarea>
     <input type="text" name="website" tabindex="-1" autocomplete="off" style="display: none">
     <input type="hidden" name="_redirect" value="/#contact">
     <input type="hidden" name="hashcash" id="hashcash">
     <button type="submit">Envoyer</button>
   </form>
   <script>
     document.getElementById("hashcash").dataset.hashcash = JSON.stringify({
       resource: location.hostname,
       bits: 18,
       waiting_message: "Un instant…",
     });
   </script>
   <script src="https://forms.example.org/hashcash.js"></script>
   ```

   `resource` doit être l'hôte de la page et `bits` au moins `HASHCASH_BITS`. Le bouton est désactivé le temps du calcul, puis reprend son texte.

3. Après envoi, le visiteur est renvoyé sur `_redirect` du même site, avec `?sent=1` ajouté. La page affiche la confirmation qu'elle veut.

Réponses d'erreur : `403` origine inconnue, `422` champ manquant, email invalide ou preuve de travail absente, fausse ou déjà utilisée, `429` limite atteinte. Les navigateurs envoient toujours l'en-tête `Origin` sur un POST de formulaire vers un autre domaine, c'est sur lui que repose le contrôle d'origine.

## Développement

```sh
bundle install
bundle exec ruby -Itest -e 'Dir["test/*_test.rb"].each { |f| require "./#{f}" }'
ALLOWED_ORIGINS=http://localhost:4000 MAIL_FROM=site@example.org MAIL_TO=moi@example.org SMTP_URL=smtp://u:p@localhost:1025 bundle exec puma -C puma.rb
```

Les tests utilisent la livraison de test du gem `mail` : aucun SMTP n'est nécessaire.
