# L'Apache : vérification du modèle dans Blender

Rapport de `tools/blender/verifier_personnage.py` sur le modèle retouché de l'Apache (Blender 5.3, sans écran), le 12 novembre 2026. Même chaîne que la Chatte.

## Bilan

- Maillage : 40 197 sommets, 56 349 triangles, une seule matière, une carte UV. Hauteur 1,700 m, pieds au sol.
- Squelette : 24 os Mixamo, hanches à 0,96 m, tête à 1,46 m, symétrique à 1 ou 2 cm près. La pose de contrôle déforme proprement.
- Peau : tous les sommets ont un poids, au plus 4 influences, sommes égales à 1.
- Texture : `rehausser_texture.py saturation=1.8 tons_clairs=0.6` (saturation moyenne 0,165 → 0,230, écart 0,133 → 0,186). Le réglage par défaut (2,1) rougissait la peau.
- Animations : les six de la Chatte, la marche « ramasser » remplacée par sa version d'homme (Male_Bend_Over_Pick_Up, n° 276). Écarts de repos de 5 à 8 mm. Marche accroupie remise sur place (1,55 m par cycle de 28 images), marche furtive déjà sur place.
- Mains : `ajouter_doigts.py jointure=0.135 phalange=0.175 pouce_avant=0.045 pouce_debut=0.04 pli_pouce=25 pouce_vers_doigts=0`. Sa main est plus longue que celle de la Chatte (21 cm du poignet au bout des doigts, contre 17,5) et son pouce pend déjà le long des doigts au repos : il n'est que peu replié. `pouce_debut` écarte la manchette, large, du pouce.

## Rapport brut

```
Modèle : apache.glb (avant animations et doigts) (15.9 Mo)
Maillage « char1 » : 40199 sommets, 56349 faces, 56349 triangles, UV : ['UVMap']
  Encombrement : largeur 0.952 m, profondeur 0.352 m, hauteur 1.700 m (pieds à z = -0.000)
Squelette « Armature » : 24 os, échelle de l'objet 0.01
  Hips (articulation à 0.962 m, x = -0.015)
    LeftUpLeg (articulation à 0.872 m, x = +0.083)
      LeftLeg (articulation à 0.513 m, x = +0.128)
        LeftFoot (articulation à 0.146 m, x = +0.158)
          LeftToeBase (articulation à 0.036 m, x = +0.177)
    RightUpLeg (articulation à 0.871 m, x = -0.111)
      RightLeg (articulation à 0.505 m, x = -0.154)
        RightFoot (articulation à 0.143 m, x = -0.147)
          RightToeBase (articulation à 0.030 m, x = -0.216)
    Spine02 (articulation à 1.077 m, x = -0.012)
      Spine01 (articulation à 1.191 m, x = -0.010)
        Spine (articulation à 1.309 m, x = -0.007)
          LeftShoulder (articulation à 1.334 m, x = +0.033)
            LeftArm (articulation à 1.334 m, x = +0.180)
              LeftForeArm (articulation à 1.110 m, x = +0.264)
                LeftHand (articulation à 0.934 m, x = +0.381)
          neck (articulation à 1.384 m, x = -0.004)
            Head (articulation à 1.457 m, x = +0.000)
              head_end (articulation à 1.687 m, x = +0.018)
              headfront (articulation à 1.457 m, x = +0.000)
          RightShoulder (articulation à 1.341 m, x = -0.038)
            RightArm (articulation à 1.341 m, x = -0.176)
              RightForeArm (articulation à 1.118 m, x = -0.271)
                RightHand (articulation à 0.931 m, x = -0.392)
Peau de « char1 » : 24 groupes, modificateurs ['ARMATURE']
  Sommets sans poids : 0 ; influences au plus : 4 ; sommes de poids hors de 1 : 0
  Groupes sans os : aucun ; os sans sommet : aucun
Matière « Material_0 »
  Texture couleur : 2048×2048, espace sRGB, vers ['Base Color']
  Texture metal_rugosite : 2048×2048, espace Non-Color, vers ['Color']
  Texture normales : 2048×2048, espace Non-Color, vers ['Color']
Animation « Armature|clip0|baselayer » : images 0 à 0
```
