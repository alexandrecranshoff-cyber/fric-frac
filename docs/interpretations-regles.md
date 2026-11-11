# Lectures et points à trancher

Ce que le livret ou le plateau ne disent pas clairement, et la lecture retenue pour l'instant dans `data/`. Rien ici n'est définitif : chaque point se décide avec Alexandre, au plus tard dans le document de game design.

## Plan de la villa

1. **Murs, portes et fenêtres.** Sur le plateau, les murs suivent les côtés des hexagones, puis coupent un hexagone en deux, puis reprennent un côté, et ainsi de suite. Chaque hexagone coupé en deux porte une porte (orange) ou une fenêtre (bleue). Lecture retenue : cet hexagone est la « case où se trouve l'obstacle » du livret. Une porte ou une fenêtre est donc une case entière, à cheval sur le mur, et on ne passe d'une pièce à l'autre que par ces cases.
2. **Trois portes ne coupent pas leur case en deux.** Les deux portes rouges du perron et une porte du nord-est sont dessinées à plat, sur le haut d'une case, et une porte du sud-est coupe un coin de case. Lecture retenue : la case touchée devient la case-porte, comme les autres. Sur le plan redessiné : cases [12, 20], [14, 20], [22, 11] et [21, 20].
3. **Couleur des murs.** Le livret dit « portes rouges, fenêtres bleues ». Les murs eux-mêmes sont peints de la couleur de la pièce, et celle de la pièce du nord-ouest est bleue. J'ai compté comme fenêtre du nord-ouest la seule case coupée de son mur nord (case [4, 5]), par symétrie avec la pièce du nord-est.
4. **Fenêtres vues de dos.** Sur les murs dont on ne voit pas la face, la fenêtre n'est qu'un double trait fin. J'en ai compté six de cette sorte, dont trois confirmées par leur appui de fenêtre dessiné côté jardin.
5. **Portes extérieures.** Huit en tout : trois à l'ouest, trois à l'est, deux sur le perron. Celles des côtés ont un petit seuil dessiné comme l'appui des fenêtres ; je les ai lues comme des portes à cause de leur couleur rouge.
6. **Mur d'enceinte.** Le livret parle de « cases-mur ». J'ai fait du mur un anneau de cases tout autour du jardin, avec deux cases pour la grille au sud.
7. **Balustrade de la terrasse.** Une balustrade sépare la terrasse nord du jardin sur toute sa longueur, et une autre borde le perron. Le livret n'en dit rien. À trancher : obstacle, ou simple décor ?
8. **Arbres.** Sept massifs, relevés sur 21 cases. Ils servent à la règle des fenêtres « adjacentes à un arbre ».
9. **Étages.** Le saut par une fenêtre sans arbre suggère des fenêtres en hauteur, mais le plan n'a qu'un niveau. On garde un seul niveau.

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
19. **Solitaire.** Le livret annonce un jeu « même en solitaire » sans règle particulière. À définir dans le game design.
20. **Voleur arrêté.** Sa partie est terminée ; le livret ne dit pas si son butin compte. Retenu : il ne compte pas.
