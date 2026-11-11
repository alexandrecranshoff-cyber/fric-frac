# Règles du jeu de plateau

Transcription structurée du livret « Fric-Frac » (encart de Jeux & Stratégie, 1982, règle de François Nédélec, plateau dessiné par Claude Lacroix). Sert de référence pour le moteur de règles. Les adaptations au jeu vidéo seront décidées dans le document de game design, pas ici. Les points que le livret laisse flous sont listés dans `interpretations-regles.md`.

Les valeurs chiffrées sont dans `data/` : `effraction.json`, `combat.json`, `butin.json`, `equipement.json`, `mobilier.json`. Le plan est dans `data/villa.json` et se contrôle sur `plan_villa.svg`.

## Thème

Un cambrioleur, « mais néanmoins gentleman », surveille depuis deux mois un petit hôtel particulier de Neuilly, ses propriétaires et la ronde de ses deux gardes. Monsieur vient d'offrir à Madame une rivière de diamants : le casse est pour ce soir.

## Matériel et but

- 2 à 6 joueurs, ou en solitaire.
- Le plan d'une villa, 2 pions gardiens, 6 pions voleurs, 36 pions mobilier. Un dé, du papier et des crayons.
- But : pénétrer dans la villa et rafler, sans se faire voir des gardes, le plus grand nombre d'objets de valeur. Ils se trouvent dans le mobilier.

## Mise en place

- On mélange les 36 pions mobilier et on les pose au hasard, face cachée, dans les pièces de la villa.
- On n'obstrue pas une porte, et on ne pose pas deux meubles sur des cases adjacentes.
- À partir de quatre joueurs, on distribue les meubles entre les joueurs : chacun installe à sa convenance sa part du mobilier, qu'il est seul à connaître.
- Les deux gardes sont posés à leurs places, en A et en B.

## Équipement

Chaque joueur a trois points pour équiper son voleur.

| Objet | Effet | Coût |
| --- | --- | --- |
| Passe-partout, 1 tour | ouvrir plus vite les serrures | 2 |
| Passe-partout, 2 tours | ouvrir plus vite les serrures | 3 |
| Chaussures silencieuses | se déplacer sans bruit | 1 |
| Pare-balles 1 | se protéger des gardes et des autres voleurs | 1 |
| Pare-balles 2 | se protéger des gardes et des autres voleurs | 2 |
| Matraque | arme | 1 |
| Couteau | arme | 2 |
| Revolver | arme | 3 |

## Tour d'un joueur

Dans l'ordre :

1. Ouvrir, le plus silencieusement possible, les serrures qui se présentent, et rafler éventuellement un butin.
2. Déplacer son voleur.
3. Combattre un garde ou un autre voleur, si on l'estime nécessaire.
4. Déplacer les gardes.

## Entrer dans le jardin

- Au début, tous les voleurs sont hors du tapis de jeu.
- Pour entrer, le joueur pose son pion sur une case-mur de son choix. Au tour suivant, il peut sauter dans le jardin en consultant la table de combat, colonne « saut ». Le pare-balles ne protège pas des conséquences du saut.
- On peut aussi ouvrir la grille dès le premier tour, avec la table d'effraction.

## Effraction

- Les grilles, les portes intérieures et extérieures (en rouge sur le plan) et les fenêtres (en bleu) sont des obstacles à franchir par effraction. Tous les meubles doivent aussi être forcés pour y prendre le butin.
- L'effraction est à refaire même si l'obstacle a déjà été franchi par un autre voleur, ou par son propre pion.
- Les deux ennemis du voleur sont le temps et le bruit : plus on va vite, plus on fait de bruit. Chaque tour passé sur place diminue la portée du bruit.
- Si un garde ou un dormeur se trouve à portée du bruit, l'alarme est donnée.
- Pour franchir une porte ou une fenêtre, il faut être, au début de son tour, sur la case où se trouve l'obstacle. Pour un meuble, sur une case adjacente.
- Plusieurs effractions possibles sans déplacer le pion peuvent être commises dans le même tour. On vérifie le bruit pour chacune.

### Tableau 1 : table d'effraction

Portée du bruit en cases, selon le nombre de tours passés sur place. « 0 » : pas de bruit.

| Objet | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Grille | 6 | 5 | 4 | 3 | 2 | 1 | 0 | 0 |
| Porte extérieure | 4 | 3 | 2 | 1 | 0 | 0 | 0 | 0 |
| Fenêtre | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Porte intérieure | 2 | 1 | 0 | 0 | 0 | 0 | 0 | 0 |
| Secrétaire | 3 | 2 | 1 | 0 | 0 | 0 | 0 | 0 |
| Armoire | 5 | 4 | 3 | 2 | 1 | 0 | 0 | 0 |
| Coffre-fort | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |

## Butin

- Il n'y a de butin que dans les secrétaires, les armoires et les coffres-forts.
- Une fois le meuble forcé, le joueur lance deux dés l'un après l'autre : le premier donne les dizaines, le second les unités. Le résultat de la table s'applique tout de suite.
- Un butin : le joueur note sa valeur. Un bruit : on vérifie s'il est entendu.
- On tire 1 fois pour un secrétaire, 2 fois pour une armoire, 3 fois pour un coffre-fort.
- Passage secret : il permet de sortir du tapis de jeu sans effraction, en passant par le meuble. Seul le joueur qui a obtenu ce résultat peut l'utiliser, quand il le veut.
- Sur un 22, les gardes se déplacent de trois cases dans le tour de ce joueur.

### Tableau 3 : table de butin

| Tirage | Résultat |
| --- | --- |
| 11 | signal d'alarme : 2 dés, soit 2 à 12 cases |
| 12, 14, 16, 21, 23, 25, 31 | rien |
| 13 | gaz étourdissant : 2 tours sur place |
| 15 | les charnières grincent : bruit à 3 cases |
| 22 | les gardes avancent de 3 cases |
| 24 | le meuble tombe : bruit à 4 cases |
| 26 | le chalumeau explose : bruit à 6 cases |
| 32 | passage secret vers l'extérieur |
| 33 | signal d'alarme : 3 dés, soit 3 à 18 cases |
| 34, 35, 36 | portefeuille contenant 1 000 F |
| 41, 42, 43 | des pièces d'or pour 3 000 F |
| 44 | bague : 100 000 F |
| 45, 46, 51 | lingot d'or : 5 000 F |
| 52, 53, 54 | lettre compromettante négociable à 10 000 F |
| 55 | collier de perles : 300 000 F |
| 56, 61, 62 | portefeuille d'actions de 30 000 F |
| 63, 64, 65 | dossier secret négociable à 50 000 F |
| 66 | rivière de diamants : 500 000 F |

## Mouvement des voleurs

- Un voleur se déplace dans toutes les directions, d'autant de cases qu'il y a de joueurs dans la partie, ou moins.
- Sans chaussures silencieuses, un déplacement d'une case s'entend à une case du point d'arrivée, un déplacement de deux cases à deux cases, et ainsi de suite.
- On ne passe pas sur une case où se trouve un meuble.
- Dès qu'un pion passe sur une case adjacente à un meuble, on retourne le meuble. Le joueur choisit alors de continuer son mouvement, ou de rester pour forcer le meuble au tour suivant.
- Dès que le pion qui a découvert un meuble s'en éloigne, le meuble est considéré comme vide, qu'il ait été forcé ou non.
- Si le meuble découvert est un lit, le pion doit s'éloigner sans bruit : le dormeur se réveille et donne l'alarme si la case où se trouve sa tête est dans une zone de bruit.
- Les escaliers se franchissent comme des cases normales. Les cases-fenêtres adjacentes à un arbre aussi. Les autres cases-fenêtres coûtent deux points de déplacement pour entrer dans la villa.
- Si l'on sort de la villa par une case-fenêtre sans arbre, on consulte la table de combat pour connaître le résultat du saut.

## Mouvement des gardes

- Dès qu'un voleur entre dans la villa, les gardes commencent leur ronde.
- Le joueur lance un dé : il donne la direction prise par chacun des gardes, selon les chiffres imprimés autour de sa base de départ.
- Un garde avance en ligne droite jusqu'à un obstacle (mur, meuble, fenêtre ou porte extérieure). On relance alors le dé pour sa nouvelle direction, jusqu'à en trouver une libre.
- Chaque joueur déplace les deux gardes d'une case.
- Si l'alarme est donnée, ou si les gardes sont dans la zone d'un bruit, ou dans la même pièce qu'un voleur, ils se déplacent de deux cases par tour, jusqu'à la fin de la partie. Ils vont par le chemin le plus court vers la case suspecte.
- S'il n'y a personne dans la pièce à leur arrivée, ils reprennent leur déplacement aléatoire.
- Si une nouvelle alarme survient avant qu'ils aient atteint le lieu de la première, ils se dirigent aussitôt vers la seconde.
- Un garde qui se trouve dans la même pièce qu'un voleur le poursuit jusqu'à son arrestation, même dans le jardin.

## Combats

Quand deux pions (voleur, garde, dormeur) sont dans la même pièce, il peut y avoir combat.

- Main nue, matraque, couteau : les adversaires doivent être sur des cases adjacentes.
- Revolver et couteau lancé : chaque case qui sépare les adversaires enlève un point au dé.
- Un pare-balles retire 1 ou 2 points au dé de l'adversaire.

a. **Entre voleurs.** Un voleur peut décider d'en attaquer un autre. Le joueur dont c'est le tour est l'attaquant : il lance un dé. Si l'adversaire n'est pas neutralisé, celui-ci lance un dé à son tour, et ainsi de suite jusqu'à résolution. Le vainqueur peut s'emparer du butin de son adversaire.

b. **Avec un dormeur.** Le voleur doit lancer le dé avant que le dormeur ait pu donner l'alarme. Sur un OK, le dormeur ne combat pas le voleur mais donne immédiatement l'alarme.

c. **Avec un garde.** C'est toujours le voleur qui attaque. Le but du garde est d'arrêter le voleur en se plaçant sur sa case : s'il y parvient, la partie est terminée pour ce voleur. Si le tour du voleur arrive avant qu'il soit atteint, il peut combattre. Le joueur placé à gauche de l'attaquant lance le dé pour le garde. Les gardes sont armés de revolvers.

### Tableau 2 : table de combat

| Dé | Saut | Main nue | Matraque | Couteau | Revolver |
| --- | --- | --- | --- | --- | --- |
| 1 | OK | OK | OK | OK | KO |
| 2 | OK | OK | OK | KO | KO |
| 3 | OK | OK | KO | KO | KO |
| 4 | KO | KO | KO | KO | tué |
| 5 | KO | KO | KO | tué | tué |
| 6 | KO | KO | tué | tué | tué |

- OK : le défenseur est indemne.
- KO : le défenseur est assommé ou blessé. Il reste sur place jusqu'à ce que l'attaquant ait pu jouer deux tours. Pour un saut, le sauteur malchanceux passe deux tours sur place.
- Tué : le défenseur est mort. Si un garde entre dans la pièce où se trouve le cadavre, l'alarme est donnée.
- Le bruit d'un revolver s'entend dans toute la villa et donne immédiatement l'alarme. On peut cependant s'en servir comme d'une matraque.

## Fin de partie

- Quand un joueur estime avoir amassé assez de butin, il peut essayer de faire sortir son pion. Dès que le pion est sorti du tapis de jeu, on évalue son butin : c'est le « passage chez le receleur ».
- L'argent des portefeuilles, les pièces et les lingots d'or sont comptés intégralement.
- Pour le reste du butin :
  - si le voleur n'a pas été vu par un dormeur ou un garde, le butin garde sa valeur ;
  - s'il a dû assommer un garde ou un dormeur, la valeur est divisée par cinq ;
  - s'il a dû tuer un garde ou un dormeur, elle est divisée par dix.
- Le gagnant est le joueur le plus riche après le passage chez le receleur.
