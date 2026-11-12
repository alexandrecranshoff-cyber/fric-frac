class_name Pawn
extends RefCounted
## Un pion : voleur, garde ou dormeur. Pure donnée.

enum Kind { THIEF, GUARD, SLEEPER }
enum Status {
	OUTSIDE,   ## voleur pas encore entré : hors du plateau, dans la rue
	ACTIVE,    ## en jeu
	KO,        ## assommé ou blessé, reste sur place
	DEAD,      ## mort : son corps reste sur sa case
	ARRESTED,  ## voleur pris par un garde ou par le lever du jour
	ESCAPED,   ## voleur sorti du plateau avec son butin
}

const NO_CELL := Vector2i(-1, -1)

var id := 0
var kind: Kind = Kind.THIEF
var name := ""
var status: Status = Status.ACTIVE
var pos := NO_CELL
## Sur une case porte, fenêtre ou grille : côté du mur où se tient le voleur (0 ou 1). -1 ailleurs.
var side := -1

# --- Voleur ---
## Joueur qui le dirige (tour de rôle), 0 en solo.
var player := 0
var ap := 0
var equipment: Array = []
var loot: Array = []
## Cases parcourues depuis le début de son tour : c'est la portée du bruit de ses pas.
var moved := 0
var has_attacked := false
## Tours à passer sur place (saut manqué, gaz étourdissant).
var stunned_turns := 0
## Passe le tour en cours sur place.
var skips_turn := false
## Serrure sur laquelle il travaille, et points d'action déjà passés dessus.
var work_target := ""
var work_points := 0
## Vient de franchir par effraction l'ouverture où il se tient.
var crossed := false
var seen := false
var has_knocked_out := false
var has_killed := false
## Meubles dont il connaît le passage secret.
var secret_passages: Array = []

# --- Assommé ---
## Pion qui l'a assommé, et tours de ce pion qui restent avant le réveil.
var ko_by := -1
var ko_turns := 0
## Corps déjà découvert par un garde.
var found := false

# --- Garde ---
## Chiffres imprimés autour de sa base : face du dé -> direction.
var directions: Dictionary = {}
var heading := ""
var alerted := false
## Case suspecte vers laquelle il court.
var target := NO_CELL
## Voleur qu'il poursuit.
var chase_id := -1
## A bougé pendant le dernier tour de la maison : les voleurs proches l'entendent.
var moved_last_phase := false

# --- Dormeur ---
var furniture_id := -1
var awake := false


func is_thief() -> bool:
	return kind == Kind.THIEF


func is_guard() -> bool:
	return kind == Kind.GUARD


func is_sleeper() -> bool:
	return kind == Kind.SLEEPER


## Présent sur le plateau, debout, assommé ou mort.
func on_board() -> bool:
	return status == Status.ACTIVE or status == Status.KO or status == Status.DEAD


## Voleur qui joue encore : dans la rue, en jeu ou assommé.
func in_play() -> bool:
	return status == Status.OUTSIDE or status == Status.ACTIVE or status == Status.KO


func has_item(item: String) -> bool:
	return equipment.has(item)
