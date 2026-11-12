# Lectures et points à trancher

Ce que le livret ou le plateau ne disent pas clairement, et la lecture retenue pour l'instant dans `data/`. Rien ici n'est définitif : chaque point se décide avec Alexandre, au plus tard dans le document de game design.

## Plan de la villa

1. **Murs, portes et fenêtres.** Sur le plateau, les murs suivent les côtés des hexagones, puis coupent un hexagone en deux, puis reprennent un côté, et ainsi de suite. Chaque hexagone coupé en deux porte une porte (orange) ou une fenêtre (bleue). Lecture retenue : cet hexagone est la « case où se trouve l'obstacle » du livret. Une porte ou une fenêtre est donc une case entière, à cheval sur le mur, et on ne passe d'une pièce à l'autre que par ces cases.
2. **Trois portes ne coupent pas leur case en deux.** Les deux portes rouges du perron et une porte du nord-est sont dessinées à plat, sur le haut d'une case, et une porte du sud-est coupe un coin de case. Lecture retenue : la case touchée devient la case-porte, comme les autres. Sur le plan redessiné : cases [12, 20], [14, 20], [22, 11] et [21, 20].
3. **Couleur des murs.** Le livret dit « portes rouges, fenêtres bleues ». Les murs eux-mêmes sont peints de la couleur de la pièce, et celle de la pièce du nord-ouest est bleue. J'ai compté comme fenêtre du nord-ouest la seule case coupée de son mur nord (case [4, 5]), par symétrie avec la pièce du nord-est.
4. **Fenêtres vues de dos.** Sur les murs dont on ne voit pas la face, la fenêtre n'est qu'un double trait fin. J'en ai compté six de cette sorte, dont trois confirmées par leur appui de fenêtre dessiné côté jardin.
5. **Portes extérieures.** Huit en tout : trois à l'ouest, trois à l'est, deux sur le perron. Celles des côtés ont un petit seuil dessiné comme l'appui des fenêtres ; je les ai lues comme des portes à cause de leur couleur rouge.
6. **Mur d'enceinte.** Le livret parle de « cases-mur ». J'ai fait du mur un anneau de cases tout autour du jardin, avec deux cases pour la grille au sud.
7. **Balustrade de la terrasse.** Tranché dans le game design : obstacle bas. Elle sépare la terrasse et le perron du jardin et de la cour, coûte 2 points pour l'enjamber et arrête un garde en ronde. L'escalier du perron la contourne.
8. **Arbres.** Sept massifs, relevés sur 21 cases. Ils servent à la règle des fenêtres « adjacentes à un arbre ».
9. **Étages.** Le saut par une fenêtre sans arbre suggère des fenêtres en hauteur, mais le plan n'a qu'un niveau. On garde un seul niveau.
21. **Deux ouvertures côte à côte.** Sept fois sur le plan, une porte touche une autre porte ou une fenêtre (par exemple la porte [22, 11] et la fenêtre [23, 10]). Lecture retenue : on passe de l'une à l'autre si elles se touchent du même côté de leurs murs, c'est-à-dire si aucun mur n'est dessiné entre elles. C'est aussi ce que montre la maquette 3D.

## Mobilier

10. **Les six types de pions.** La planche montre six dessins, six pions de chaque. Le livret n'en nomme que quatre : secrétaire, armoire, coffre-fort, lit. Lecture des deux autres : un guéridon (table ronde avec un service à thé) et un fauteuil, tous deux sans butin. Ce sont des leurres.
11. **Meubles de deux cases.** Les pions armoire et lit sont deux fois plus larges que les autres. Lecture retenue : ils occupent deux cases, et le lit a une case « tête », comme le dit le livret.
12. **Meuble « considéré comme vide ».** Un meuble découvert puis quitté est perdu pour tout le monde, ou seulement pour celui qui l'a découvert ? Le texte dit « sera considéré comme vide » : retenu pour tout le monde.

## Règles

13. **Passe-partout.** « 1 tour » et « 2 tours » : lecture retenue, on lit la table d'effraction comme si l'on avait déjà passé 1 ou 2 tours de plus sur place.
14. **Dé inférieur à 1.** Avec la distance et le pare-balles, le dé de combat peut tomber sous 1. Retenu : il se lit comme un 1.
15. **Portefeuille d'actions.** Le livret compte en entier « l'argent des portefeuilles, les pièces et les lingots d'or ». Retenu : le portefeuille de 1 000 F est de l'argent, le portefeuille d'actions est un butin à négocier, donc soumis à la division.
16. **Signal d'alarme (11 et 33).** Lu comme un bruit dont la portée est la somme des dés.
17. **Vitesse des gardes.** « Chaque joueur déplace les deux gardes d'une case » : à six joueurs, les gardes font six cases par tour de table, quand un voleur en fait six aussi. Retenu tel quel.
18. **Portes intérieures et gardes.** La liste des obstacles qui arrêtent un garde ne cite pas les portes intérieures. Retenu : les gardes les franchissent librement.
19. **Solitaire.** Tranché dans le game design : une bande de trois voleurs, contre une horloge de 24 tours de table. Au lever du jour, tout voleur encore dans la propriété est pris.
20. **Voleur arrêté.** Sa partie est terminée ; le livret ne dit pas si son butin compte. Retenu : il ne compte pas.

## Moteur de règles (étape 4)

Lectures prises en programmant les règles, avec les réglages de `data/regles_video.json`.

22. **Un point d'action, un tour.** Le livret compte l'effraction en tours passés sur place. Un point d'action passé sur une serrure vaut un tour : on lit le tableau 1 à la colonne du nombre de points dépensés, passe-partout compris. Les points s'ajoutent d'un tour à l'autre tant que le voleur ne bouge pas.
23. **Bruit des pas.** Il porte aussi loin que le nombre de cases parcourues depuis le début du tour, et s'entend depuis la case d'arrivée de chaque déplacement.
24. **Dormeurs.** Un dormeur n'entend le bruit qu'une fois son lit découvert : le livret ne parle de réveil qu'à propos du lit qu'on vient de retourner. Tant que le pion est face cachée, personne ne sait qu'il y a là un lit.
25. **Voir et être vu.** Un garde repère un voleur dans la même pièce que lui, le jardin comptant pour une pièce. Sur une case de porte, un garde voit les deux pièces ; un voleur n'est que d'un côté du mur, celui d'où il vient ou celui qu'il a franchi par effraction.
26. **Où vont les gardes.** En ronde, ils s'arrêtent devant les murs, les meubles, les fenêtres, les portes extérieures et la balustrade. En alerte ou en poursuite, ils prennent le chemin le plus court et passent aussi les portes extérieures et la balustrade, jamais les fenêtres. Une porte intérieure ne les arrête jamais.
27. **Allure des gardes.** Six cases par tour de table, réparties entre les voleurs qui jouent, et le double dès la première alerte. Avec trois voleurs, deux cases après chacun, quatre en alerte.
28. **Assommé.** Un pion assommé reste à terre pendant les deux tours entiers que l'attaquant joue ensuite. Assommé par un garde, un voleur perd ses deux tours suivants. Un garde ou un dormeur qui revient à lui donne l'alarme.
29. **Riposte.** Le garde riposte toujours au revolver. Un voleur attaqué riposte avec son arme la plus sûre, et ne tire au revolver que s'il n'a rien d'autre à cette distance. Le revolver peut servir de matraque, sans bruit (livret).
30. **Butin entre voleurs.** Assommer ou tuer un voleur rival ne déprécie pas son butin chez le receleur : la division ne vise que les gardes et les dormeurs, comme le dit le livret.
31. **Saut.** Il se tente en sautant du mur d'enceinte, ou en quittant la villa par une fenêtre sans arbre qu'on vient de franchir. Un saut manqué coûte les deux tours suivants.
32. **Mobilier.** Aucun meuble sur les postes des gardes, et chaque porte et chaque fenêtre garde une case libre de chaque côté de son mur.
