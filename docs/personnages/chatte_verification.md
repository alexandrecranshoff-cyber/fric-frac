# La Chatte : vérification du modèle dans Blender

Rapport de `tools/blender/verifier_personnage.py` sur `assets/models/personnages/chatte/chatte.glb` (Blender 5.3, sans écran), le 12 novembre 2026.

## Bilan

- Maillage : 39 049 sommets, 57 049 triangles, une seule matière, une carte UV. Hauteur 1,650 m, pieds au sol.
- Squelette : 24 os à la nomenclature Mixamo (Hips, Spine, LeftArm…), articulations bien placées (hanches à 0,93 m, tête à 1,40 m), symétrique à quelques millimètres près. Pas d'os pour les doigts, le visage ni le foulard : mains et foulard suivent le poignet et la tête.
- Peau : tous les sommets ont un poids, au plus 4 influences, sommes égales à 1. La pose de contrôle (bras levés, genou plié) déforme proprement.
- Animations : six, ajoutées le 12 novembre 2026 par `tools/blender/fusionner_animations.py` (attente 4,0 s, aux aguets 7,8 s, marche furtive 2,8 s, marche accroupie 1,1 s, ouvrir une porte 5,2 s, ramasser 9,5 s). Les squelettes des animations Higgsfield ne s'écartent du modèle que de 5 à 10 mm au repos. La marche accroupie avance d'elle-même (déplacement porté par les hanches) ; les autres restent sur place.
- Texture : couleur 2048 rehaussée par `tools/blender/rehausser_texture.py` (saturation moyenne 0,11 → 0,16, écart 0,10 → 0,14, noirs creusés), normales et métal-rugosité 2048 inchangées. L'émission noire inutile du modèle brut est retirée.
- Échelle de l'objet squelette : 0,01 (héritage d'un passage par le centimètre), compensée dans la hiérarchie : Godot l'importe à la bonne taille.

## Rapport brut

```
Modèle : chatte.glb (13.6 Mo)
Maillage « char1 » : 39049 sommets, 57049 faces, 57049 triangles, UV : ['UVMap']
  Encombrement : largeur 0.987 m, profondeur 0.306 m, hauteur 1.650 m (pieds à z = 0.000)
Squelette « Armature » : 24 os, échelle de l'objet 0.01
  Hips (articulation à 0.934 m, x = -0.004)
    LeftUpLeg (articulation à 0.846 m, x = +0.090)
      LeftLeg (articulation à 0.494 m, x = +0.132)
        LeftFoot (articulation à 0.134 m, x = +0.167)
          LeftToeBase (articulation à 0.032 m, x = +0.202)
    RightUpLeg (articulation à 0.846 m, x = -0.092)
      RightLeg (articulation à 0.494 m, x = -0.132)
        RightFoot (articulation à 0.138 m, x = -0.171)
          RightToeBase (articulation à 0.032 m, x = -0.202)
    Spine02 (articulation à 1.042 m, x = -0.003)
      Spine01 (articulation à 1.151 m, x = -0.002)
        Spine (articulation à 1.263 m, x = -0.002)
          LeftShoulder (articulation à 1.302 m, x = +0.030)
            LeftArm (articulation à 1.302 m, x = +0.153)
              LeftForeArm (articulation à 1.117 m, x = +0.253)
                LeftHand (articulation à 0.942 m, x = +0.395)
          neck (articulation à 1.338 m, x = -0.001)
            Head (articulation à 1.404 m, x = -0.000)
              head_end (articulation à 1.638 m, x = +0.017)
              headfront (articulation à 1.404 m, x = -0.000)
          RightShoulder (articulation à 1.309 m, x = -0.031)
            RightArm (articulation à 1.309 m, x = -0.153)
              RightForeArm (articulation à 1.113 m, x = -0.263)
                RightHand (articulation à 0.942 m, x = -0.402)
Peau de « char1 » : 24 groupes, modificateurs ['ARMATURE']
  Sommets sans poids : 0 ; influences au plus : 4 ; sommes de poids hors de 1 : 0
  Groupes sans os : aucun ; os sans sommet : aucun
Matière « Material_0 »
  Texture couleur : 2048×2048, espace sRGB, vers ['Base Color']
  Texture metal_rugosite : 2048×2048, espace Non-Color, vers ['Color']
  Texture normales : 2048×2048, espace Non-Color, vers ['Color']
Animation « Armature|clip0|baselayer » : images 0 à 0
```
