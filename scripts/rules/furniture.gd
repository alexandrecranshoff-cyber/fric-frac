class_name Furniture
extends RefCounted
## Un pion mobilier, posé face cachée dans une pièce. Pure donnée.

var id := 0
## Clé de data/mobilier.json : "secretaire", "armoire", "coffre_fort", "gueridon", "fauteuil", "lit".
var type := ""
## Une ou deux cases. Pour un lit, la première est celle de la tête du dormeur.
var cells: Array[Vector2i] = []
## Retourné : un voleur est passé sur une case voisine.
var revealed := false
## Voleur qui l'a découvert. Dès qu'il s'éloigne, le meuble est perdu.
var discovered_by := -1
## Forcé par effraction.
var forced := false
## « Considéré comme vide » : fouillé, ou abandonné par celui qui l'a découvert.
var emptied := false


func head() -> Vector2i:
	return cells[0]


func touches(cell: Vector2i) -> bool:
	for c in cells:
		if Hex.distance(c, cell) == 1:
			return true
	return false
