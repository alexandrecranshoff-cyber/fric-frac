# Images de référence des personnages

Images générées sur Higgsfield (Nano Banana 2.1), retenues par Alexandre le 12 novembre 2026. Godot ignore ce dossier (`.gdignore`).

## La Chatte (voleuse au foulard)

| Fichier | Rôle | Génération Higgsfield |
| --- | --- | --- |
| `chatte/chatte_illustration.png` | illustration retenue pour la bande | `7d40b8ce-802f-4e73-810a-2d37f7fab2a3` |
| `chatte/chatte_pose_a_face.png` | vue de face en pose A, pour la 3D | `dc79524d-99e2-4535-851a-20f757dce9c7` |
| `chatte/chatte_pose_a_profil.png` | vue de profil en pose A | `2323af06-6784-4ae7-9cad-c22fa4ce3e8d` |
| `chatte/chatte_pose_a_dos.png` | vue de dos en pose A | `3a1651f6-61fd-4a5c-995f-7ad66f549f6b` |

Modèle 3D tiré de ces trois vues (Higgsfield « multi_image_to_3d », texturé, riggé en pose A, 1,65 m, 30 000 polygones visés, consignes de couleur) : génération `412b4f3a-8141-4164-9361-763dd48d469b`, version v2 validée par Alexandre. Brut dans `assets/models/personnages/chatte/source/chatte_higgsfield_v2.glb`, version retouchée dans `assets/models/personnages/chatte/chatte.glb`.

## À ranger plus tard

Le reste de la bande retenue (Serrurier `92da6d4f`, Gros bras `b07b032e`, Apache `17fc3d3b`, Môme `826c0c37`) suivra quand chaque personnage passera en 3D.

## Animations de la Chatte

Générées le 12 novembre 2026 par Higgsfield « 3d_rigging » (bibliothèque Meshy, 8 crédits chacune) sur le modèle v2, puis rassemblées sur `chatte.glb` par `tools/blender/fusionner_animations.py`. Les GLB bruts (un maillage complet par animation, 10 Mo chacun) ne sont pas gardés dans le dépôt : ces numéros permettent de les retélécharger.

| Animation | Mouvement de la bibliothèque | Génération Higgsfield |
| --- | --- | --- |
| `attente` | Idle (n° 0) | `40f88240-2940-412c-a598-021b9aa5e017` |
| `aux_aguets` | Short_Breathe_and_Look_Around (n° 338) | `4507605e-c9db-40db-856a-6ba0fcb6ed35` |
| `marche_furtive` | Sneaky_Walk_inplace (n° 671) | `ff1d3a8e-ad7f-46fd-b384-9102ee82c95c` |
| `marche_accroupie` | Cautious_Crouch_Walk_Forward (n° 524) | `852a43c0-a9fd-4dd7-9bb6-647e43b10f28` |
| `ouvrir_porte` | open_door (n° 285) | `789117ad-cf94-4e59-acce-cd8039131a43` |
| `ramasser` | Female_Crouch_Pick_Up_Place_Side (n° 274) | `38cde735-dda8-44cb-b5f8-a50981a81327` |

La bibliothèque n'a pas de crochetage de serrure : à faire plus tard (capture vidéo ou retouche dans Blender).
