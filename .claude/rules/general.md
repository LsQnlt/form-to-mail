# Règles générales

## Réponses

- Répondre de façon concise : la conclusion d'abord, le détail seulement s'il change quelque chose pour le lecteur.
- Quand on parle de code, le relier à ce que vit le visiteur qui envoie le formulaire : « ce contrôle d'origine décide si le message atteint la boîte de réception », plutôt qu'une description technique seule.
- Répondre en français ; le code, les identifiants et les messages de commit restent en anglais.

## KISS

- Préférer la solution la plus simple qui résout le besoin exprimé. Pas d'abstraction, d'option ou de généralisation « au cas où ». Le service tient en une route `POST /send`, un état en mémoire, aucun stockage persistant : garder cette forme.
- Utiliser d'abord ce que Sinatra, Rack et la gem `mail` fournissent avant une gem ou un helper maison.
- Une modification touche le minimum de fichiers. Ne pas réécrire du code voisin qui fonctionne.
- Si deux approches sont possibles, en proposer une et dire pourquoi, sans dérouler toutes les alternatives.

## Git

- Ne jamais lancer `git add`, `git commit`, `git push` ni aucune commande qui modifie l'historique. La revue et le commit appartiennent au développeur.
- En fin de tâche, proposer un message de commit prêt à copier : impératif présent en anglais, une ligne de titre, puis un court corps si le pourquoi n'est pas évident.

## Vocabulaire métier

- **Service** : ce dépôt. Reçoit le formulaire de contact d'un site statique et l'envoie par email via un relais SMTP. Remplace Netlify Forms ou Formspree. Une seule instance sert plusieurs sites.
- **Visiteur** : la personne qui remplit le formulaire sur un site branché au service.
- **Origine autorisée** : une entrée de `ALLOWED_ORIGINS`. Seul un POST dont l'`Origin` y figure est traité ; le navigateur envoie toujours cet en-tête sur un POST cross-domain.
- **Stamp** : la preuve de travail hashcash calculée dans le navigateur pendant la saisie, revérifiée par le serveur. Voir `hashcash.md`.
- **Champ piège (honeypot)** : le champ `website`, invisible ; rempli, le message est ignoré en silence.
- **Limites** : plafond par IP et par heure, et plafond global par jour, tenus en mémoire.
