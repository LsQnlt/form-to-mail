# Commentaires

Exprimer l'intention par les noms, les blocs courts et la structure du code. Ne pas ajouter spontanément de commentaires explicatifs, TODO, bandeaux de section ou code commenté. Renommer, extraire ou simplifier lorsque cela rend le code compréhensible.

Les commentaires explicitement demandés sont autorisés. Conserver :

- l'en-tête de `app.rb` qui liste les variables d'environnement et les champs attendus du formulaire, parce qu'il documente le contrat avec les sites branchés ;
- une très courte explication d'une contrainte de sécurité ou d'un choix anti-spam quand elle n'est pas évidente à la lecture (bornage des bits du stamp, état gardé en mémoire volontairement, honeypot traité comme un succès silencieux).

Le fichier `public/hashcash.js` est une copie non modifiée de la gem `active_hashcash` : ne pas y toucher, ni le commenter. Voir `hashcash.md`.
