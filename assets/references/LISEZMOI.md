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

## L'Apache (voleur à la marinière)

| Fichier | Rôle | Génération Higgsfield |
| --- | --- | --- |
| `apache/apache_illustration.png` | illustration retenue pour la bande | `17fc3d3b-bbe0-49c7-8626-666e1786a006` |
| `apache/apache_pose_a_face.png` | vue de face en pose A, pour la 3D (couteau rangé dans la ceinture) | `377ca452-2334-451b-93e0-ecaf19acc091` |
| `apache/apache_pose_a_profil.png` | vue de profil | `fe633af2-ffda-4e5c-8528-6fd1238c51a2` |
| `apache/apache_pose_a_dos.png` | vue de dos en pose A | `7eb37083-aa87-49a3-85c1-d7f33e05612f` |

Modèle 3D tiré de ces trois vues (« multi_image_to_3d », texturé, riggé en pose A, 1,70 m, 30 000 polygones visés, consignes de couleur) : génération `2f4cb28e-ea0b-483a-81a4-3c5d295f2c68`.

## Le Gros bras

| Fichier | Rôle | Génération Higgsfield |
| --- | --- | --- |
| `gros_bras/gros_bras_illustration.png` | illustration retenue pour la bande | `b07b032e-8094-4f8f-bf52-ff6341cc5afb` |
| `gros_bras/gros_bras_pose_a_face.png` | vue de face en pose A, pour la 3D (matraque pendue à la ceinture) | `fe72c9ef-9296-4104-b57b-534523b7ae82` |
| `gros_bras/gros_bras_pose_a_profil.png` | vue de profil | `fe736c8d-f57f-46bc-a2f8-4c5af1fcc701` |
| `gros_bras/gros_bras_pose_a_dos.png` | vue de dos en pose A | `ea03659c-8e43-4e46-832c-231eb753444f` |

Modèle 3D tiré de ces trois vues (mêmes réglages, 1,92 m) : génération `faaf0284-b228-491f-9fa5-2ce95773dff2`.

Les armes tenues en main (couteau, matraque) sont rangées sur les vues : une arme dans la main gênerait la peau et les animations. Elles pourront revenir en objets séparés, accrochés à l'os de la main.

## À ranger plus tard

Le reste de la bande retenue (Serrurier `92da6d4f`, Môme `826c0c37`) suivra si le jeu en a besoin, d'après Alexandre (12 novembre 2026).

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

## Animations de l'Apache et du Gros bras

Générées le 12 novembre 2026 comme celles de la Chatte, sur leur modèle multi-vues (1,70 m et 1,92 m). Pour « ramasser », la version d'homme de la bibliothèque. Le Gros bras a pour base le GLB de son « attente » (voir `docs/personnages/gros_bras_verification.md`).

| Animation | Mouvement de la bibliothèque | Apache | Gros bras |
| --- | --- | --- | --- |
| `attente` | Idle (n° 0) | `b1e32f82-b7de-4a5b-b215-fb0456dd20bb` | `3a31d0d3-72ba-4ea3-bf90-630e31f6060c` |
| `aux_aguets` | Short_Breathe_and_Look_Around (n° 338) | `aceefc30-2767-4299-8e4a-7b4648f21931` | `bf253498-56eb-45a3-8439-4e5a66eda575` |
| `marche_furtive` | Sneaky_Walk_inplace (n° 671) | `9886db13-cefe-4d32-9850-300d46c41eca` | `b4bdf96a-b9ca-4ed3-964e-dd753ee37914` |
| `marche_accroupie` | Cautious_Crouch_Walk_Forward (n° 524) | `17f60c7b-d953-477c-9134-fda94fe123db` | `3050bb2f-ee23-485f-9128-41eb52df1ffe` |
| `ouvrir_porte` | open_door (n° 285) | `f6da96d4-1ef8-4082-a202-db0ddd4247eb` | `d609b102-1436-4c32-ab99-f64ce9de18ec` |
| `ramasser` | Male_Bend_Over_Pick_Up (n° 276) | `0db0c0b8-58f9-4133-b409-4f0172becfe3` | `fb9a564e-fc32-448b-a4d6-10edee54da7d` |
