# Le garde : vérification du modèle dans Blender

Rapport de `tools/blender/verifier_personnage.py` sur le modèle du garde (Blender 5.3, sans écran), le 12 novembre 2026. Même chaîne que les voleurs ; les deux gardes de la villa partagent ce modèle.

## Bilan

- Maillage : 30 679 sommets, 31 156 triangles, une seule matière, une carte UV. Hauteur 1,780 m, pieds au sol. Livrée bleu nuit à passepoils rouges, képi, gants blancs, trousseau de clés et étui à la ceinture.
- Squelette : 24 os Mixamo, hanches à 0,97 m, tête à 1,51 m, symétrique à 1 cm près.
- Peau : tous les sommets ont un poids, au plus 4 influences, sommes égales à 1.
- Base retenue : le GLB de l'animation « ronde » (génération `ac270af7`), rangé dans `source/`. Les riggings de Higgsfield sortent en deux familles qui diffèrent de 4,5 cm au pied gauche ; ronde, course et la seconde attente s'accordent à moins de 1 cm. La première attente et « aux aguets » (`fa8a42ae`, `8a03ea98`) sont de l'autre famille et n'ont pas servi.
- Texture : `rehausser_texture.py contraste=1.2 saturation=1.4 clarte=0.5` (saturation moyenne 0,29 → 0,38). L'émission (texture noire) est retirée.
- Animations : `attente` (Idle), `ronde` (Walk_Slowly_and_Look_Around, coupée en boucle par `couper_boucle.py ronde.glb ronde_coupee.glb 55 110 460 530`, images 63 à 496 : l'original attend deux secondes avant de partir et à la fin), `course` (Run_02). Ronde et course remises sur place.
- Mains : `ajouter_doigts.py` aux réglages par défaut (avant-bras 0,254 m, distances × 1,13).
- Dans le jeu (`pieces_view.gd`) : la lanterne pend au poing droit (os `RightHand`). Le garde joue « ronde » à chaque pas, « course » dès l'alerte, et revient à « attente » quand il s'arrête. La silhouette d'un garde perdu de vue est le même modèle, figé dans l'attente.

## Rapport brut (modèle riggé avant animations)

```
Modèle : garde_higgsfield.glb (12.6 Mo)
Maillage « char1 » : 30679 sommets, 31156 faces, 31156 triangles, UV : ['UVMap']
  Encombrement : largeur 1.167 m, profondeur 0.410 m, hauteur 1.780 m (pieds à z = -0.000)
Squelette « Armature » : 24 os, échelle de l'objet 0.01
  Hips (articulation à 0.973 m, x = -0.008)
    Spine02 (articulation à 1.098 m, x = -0.006)
      Spine01 (articulation à 1.223 m, x = -0.005)
        Spine (articulation à 1.352 m, x = -0.004)
          neck (articulation à 1.440 m, x = -0.002)
            Head (articulation à 1.514 m, x = -0.000)
              head_end (articulation à 1.767 m, x = +0.019)
              headfront (articulation à 1.514 m, x = -0.000)
          LeftShoulder (articulation à 1.385 m, x = +0.039)
            LeftArm (articulation à 1.385 m, x = +0.204)
              LeftForeArm (articulation à 1.182 m, x = +0.326)
                LeftHand (articulation à 1.013 m, x = +0.488)
          RightShoulder (articulation à 1.389 m, x = -0.042)
            RightArm (articulation à 1.389 m, x = -0.204)
              RightForeArm (articulation à 1.174 m, x = -0.346)
                RightHand (articulation à 1.005 m, x = -0.503)
    LeftUpLeg (articulation à 0.876 m, x = +0.083)
      LeftLeg (articulation à 0.491 m, x = +0.123)
        LeftFoot (articulation à 0.141 m, x = +0.134)
          LeftToeBase (articulation à 0.039 m, x = +0.173)
    RightUpLeg (articulation à 0.876 m, x = -0.093)
      RightLeg (articulation à 0.487 m, x = -0.131)
        RightFoot (articulation à 0.139 m, x = -0.138)
          RightToeBase (articulation à 0.036 m, x = -0.173)
Peau de « char1 » : 24 groupes, modificateurs ['ARMATURE']
  Sommets sans poids : 0 ; influences au plus : 4 ; sommes de poids hors de 1 : 0
  Groupes sans os : aucun ; os sans sommet : aucun
Matière « Material_0 »
  Texture Image_3 : 2048×2048, espace sRGB, vers ['Emission Color']
  Texture Image_0 : 2048×2048, espace sRGB, vers ['Base Color']
  Texture Image_1 : 2048×2048, espace Non-Color, vers ['Color']
  Texture normal : 2048×2048, espace Non-Color, vers ['Color']
```
