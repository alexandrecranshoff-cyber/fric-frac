# Le Gros bras : vérification du modèle dans Blender

Rapport de `tools/blender/verifier_personnage.py` sur le modèle retouché du Gros bras (Blender 5.3, sans écran), le 12 novembre 2026. Même chaîne que la Chatte.

## Bilan

- Maillage : 39 858 sommets, 54 308 triangles, une seule matière, une carte UV. Hauteur 1,920 m, pieds au sol. La matraque pend à la ceinture, dans le maillage de la jambe : elle suit la hanche.
- Squelette : 24 os Mixamo, hanches à 1,05 m, tête à 1,63 m, symétrique à quelques millimètres près.
- Peau : tous les sommets ont un poids, au plus 4 influences, sommes égales à 1.
- Base retenue : le GLB de l'animation « attente » (génération `3a31d0d3`), et non le modèle multi-vues lui-même. Le second rigging de Higgsfield place les orteils 3 cm plus loin que le premier, au-delà de la tolérance de `fusionner_animations.py` ; les six animations s'accordent entre elles à 1 cm près. Le maillage et la texture sont les mêmes. C'est ce GLB qui est rangé dans `source/`.
- Texture : `rehausser_texture.py saturation=1.4 tons_clairs=0.8` (saturation moyenne 0,266 → 0,373, écart 0,154 → 0,205). Sa texture brute est déjà franche : au réglage par défaut, la peau et la veste tournaient au rouge et à l'orangé.
- Animations : les mêmes que l'Apache. Écarts de repos de 6 à 10 mm. Marche accroupie remise sur place (1,68 m par cycle de 28 images).
- Mains : `ajouter_doigts.py jointure=0.175 phalange=0.225 fondu=0.02 pouce_avant=0.082 pouce_debut=0.05 pli_doigts=50 pli_bouts=45 pli_pouce=15 pouce_vers_doigts=0`. Ses mains sont énormes (27 cm) et à demi refermées en griffe au repos : un pli plus fort écrasait les doigts les uns dans les autres. Le poing reste donc entrouvert.

## Rapport brut (modèle multi-vues, avant le second rigging)

```
Modèle : gros_bras.glb (avant animations et doigts) (15.9 Mo)
Maillage « char1 » : 39858 sommets, 54308 faces, 54308 triangles, UV : ['UVMap']
  Encombrement : largeur 1.532 m, profondeur 0.556 m, hauteur 1.920 m (pieds à z = 0.000)
Squelette « Armature » : 24 os, échelle de l'objet 0.01
  Hips (articulation à 1.049 m, x = +0.004)
    LeftUpLeg (articulation à 0.950 m, x = +0.135)
      LeftLeg (articulation à 0.550 m, x = +0.199)
        LeftFoot (articulation à 0.181 m, x = +0.215)
          LeftToeBase (articulation à 0.059 m, x = +0.256)
    RightUpLeg (articulation à 0.950 m, x = -0.133)
      RightLeg (articulation à 0.554 m, x = -0.203)
        RightFoot (articulation à 0.181 m, x = -0.224)
          RightToeBase (articulation à 0.055 m, x = -0.271)
    Spine02 (articulation à 1.182 m, x = +0.003)
      Spine01 (articulation à 1.315 m, x = +0.003)
        Spine (articulation à 1.452 m, x = +0.002)
          LeftShoulder (articulation à 1.507 m, x = +0.056)
            LeftArm (articulation à 1.507 m, x = +0.278)
              LeftForeArm (articulation à 1.262 m, x = +0.443)
                LeftHand (articulation à 1.076 m, x = +0.642)
          neck (articulation à 1.548 m, x = +0.001)
            Head (articulation à 1.625 m, x = +0.000)
              head_end (articulation à 1.895 m, x = +0.017)
              headfront (articulation à 1.625 m, x = -0.000)
          RightShoulder (articulation à 1.511 m, x = -0.056)
            RightArm (articulation à 1.511 m, x = -0.282)
              RightForeArm (articulation à 1.262 m, x = -0.456)
                RightHand (articulation à 1.072 m, x = -0.646)
Peau de « char1 » : 24 groupes, modificateurs ['ARMATURE']
  Sommets sans poids : 0 ; influences au plus : 4 ; sommes de poids hors de 1 : 0
  Groupes sans os : aucun ; os sans sommet : aucun
Matière « Material_0 »
  Texture couleur : 2048×2048, espace sRGB, vers ['Base Color']
  Texture metal_rugosite : 2048×2048, espace Non-Color, vers ['Color']
  Texture normales : 2048×2048, espace Non-Color, vers ['Color']
Animation « Armature|clip0|baselayer » : images 0 à 0
```
