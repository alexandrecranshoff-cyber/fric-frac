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

## Le garde

| Fichier | Rôle | Génération Higgsfield |
| --- | --- | --- |
| (non gardée) | illustration du garde en livrée et lanterne | `c4e33272-9cac-4632-bde9-3285309845bc` |
| `garde/garde_pose_a_face.png` | vue de face en pose A, pour la 3D | `147c6fcb-fbb2-4f54-b0d7-bdee4b7ffad6` |
| `garde/garde_pose_a_profil.png` | vue de profil | `fe9af8e0-00d4-4af3-9299-121dd00ed8a1` |
| `garde/garde_pose_a_dos.png` | vue de dos en pose A | `eb777c0e-ae86-4ea7-8430-e6157c5a99f2` |

Modèle 3D tiré de ces trois vues (« multi_image_to_3d », texturé, riggé, 1,78 m) : génération `4a8058b6-71cb-4fb6-91aa-00bba62e6b94`. Animations (« 3d_rigging », 1,78 m) ci-dessous ; voir `docs/personnages/garde_verification.md`.

| Animation | Mouvement de la bibliothèque | Génération Higgsfield |
| --- | --- | --- |
| `attente` | Idle (n° 0) | `362d7068-722c-47af-b3cb-c6fed90bd3e1` |
| `ronde` | Walk_Slowly_and_Look_Around (n° 341), coupée en boucle | `ac270af7-a012-4044-ac92-0d23a7843157` |
| `course` | Run_02 (n° 14) | `cdf6492d-7ed3-4d75-9a42-803b889b9e96` |

## Les meubles et le dormeur

Une image par meuble (Nano Banana 2.1), puis un modèle 3D (« sam_3_3d », ou Tripo H3.1 quand SAM échouait), préparé par `tools/blender/preparer_meuble.py`. Bruts dans `assets/models/meubles/<type>/source/`.

| Meuble | Image | Modèle 3D | Réglages de `preparer_meuble.py` |
| --- | --- | --- | --- |
| `secretaire` | `f7afaf8a-d5c5-476a-b00a-04b854237f9c` | Tripo `80976e55-e420-499a-9f50-26885555a3c7` | `hauteur=1.15 quart=-1` |
| `coffre_fort` | `5df0a54f-eac3-4233-abd8-e240779b7e0b` | SAM `3657a084-1b66-4ded-bd0f-7f0508298f70` | `hauteur=0.85` |
| `armoire` | `160745bb-2942-4d6d-b558-909cf8c4ac3c` | SAM `f5e8cf62-ce45-4b4e-9aa8-98450d56977a` | `hauteur=1.4` |
| `gueridon` | `317c788b-82c3-4fba-b058-12a7b810bb02` | Tripo `53bd8067-4fde-4825-b020-1e282424c8b7` | `hauteur=1.0` |
| `fauteuil` | `644f0927-cc59-4d22-b14b-d8f07757ac99` | SAM `fc441788-7c78-4ad7-b553-cf946cff49b4` | `hauteur=0.95` |
| `lit` | `5f638ffe-4bd3-4592-8ce0-789902aaefe6` | SAM `10a16261-d4e7-43c9-b970-7099c5e7a1e8` | `hauteur=1.0 quart=1` |
| `housse` (meuble encore caché) | `8b13677a-e685-4211-97bc-e0ef1eb37782` | SAM `fc76e0ae-44a6-4ce4-84e1-88d4504c15cb` | `hauteur=0.9` |
| `dormeur` (sous sa couverture) | `adeeb81b-d3a2-4698-9b2a-fc55035ef2b3` | Tripo `d228ea3e-3b3d-46d7-b847-3c45d4de8884` | `hauteur=0.4` (tête vers -x) |

## Le décor de la villa

Images Nano Banana 2.1 du 12 novembre 2026. Les matières passent par `tools/preparer_matiere.py` (couleur, normales et rugosité 2048 dans `assets/textures/villa/`), tapis et tableaux sont recadrés dans `assets/textures/villa/decor/`, les accessoires 3D (Tripo H3.1) sont préparés par `tools/blender/preparer_meuble.py` dans `assets/models/decor/<nom>/`.

| Élément | Image | Réglages ou modèle 3D |
| --- | --- | --- |
| `parquet` (point de Hongrie) | `e55950d2-f573-4642-8f71-b816d604700b` | `relief=2 rugosite=0.4,0.75` |
| `carrelage` (marbre à cabochons) | `5e0c5fb6-7cf3-4937-9567-7d6c6d1a3f57` | `relief=1.5 rugosite=0.15,0.5` |
| `boiserie` (murs intérieurs) | `5735b9da-e37c-4bc8-b319-3dfcbf49e709` | `relief=2.5 rugosite=0.35,0.7` |
| `facade` (pierre de taille) | `c0821ab4-2443-4560-86ca-6b7531a19351` | `relief=2 rugosite=0.7,0.95` |
| `dallage` (terrasse, perron) | `97fb995f-160f-463b-8fa0-89cd5e1db49e` | `relief=2 rugosite=0.7,0.95` |
| `herbe` | `2f6ac03c-e9f1-479f-b8a3-d3534ee6e07e` | `raccord=oui relief=2 rugosite=0.85,1.0 clarte=0.85` |
| `gravier` | `19cee380-7be1-42e1-81fd-3c14c3b37a5d` | `raccord=oui relief=3 rugosite=0.8,1.0` |
| `brique` (mur d'enceinte) | `bccfb52d-a82c-48f1-9a45-6fee2eed658f` | `relief=3 rugosite=0.75,0.95` |
| `tapis_rouge`, `tapis_jaune`, `tapis_brun`, `tapis_rond` | `4801bd84-e7db-4f94-8e41-b4bf0eff2e48`, `8dabd704-3e75-4810-912c-7e97d7079348`, `c6b6ed20-6ef2-47ff-8743-1f105726b4ba`, `e8cd4de0-34d8-46f1-bbe3-554537f2ba3f` | recadrés |
| `tableau_monsieur`, `tableau_paysage`, `tableau_dame`, `tableau_nature_morte` | `4533f6fa-4024-4771-bfdc-475de56795af`, `11c4b749-d475-419e-9a31-e90aedf998d7`, `cef8efd1-3779-40fc-a6e3-8fb656e2b47d`, `ec6703c4-1eea-42c6-bfc5-bfdf38dbea06` | recadrés, 1024 |
| `arbre` (marronnier) | `68e0b19b-014d-4493-acd0-a25145f45a90` | Tripo `5ba976bc-f64f-46e8-af05-7ce35bbaed6e`, `hauteur=2.4 triangles=15000` |
| `reverbere` | `f39aea74-9243-4c38-8849-7de7e1573c04` | Tripo `c8f58213-b413-4938-8733-d9fafe7a9ca4`, `hauteur=2.9 triangles=8000` |
| `lampe_petrole` | `788758b3-f99d-4522-9499-5521a0eecfea` | Tripo `21ccb810-1626-4c81-91fe-5b00b50c4cd5`, `hauteur=0.34 triangles=4000` |

La moquette des chambres reste la matière calculée, teintée par pièce : Higgsfield a refusé deux fois l'image.

## L'interface

Images Nano Banana 2.1 du 13 novembre 2026, redimensionnées dans `assets/ui/` (les panneaux s'étirent en neuf morceaux, coins ornés gardés tels quels).

| Fichier | Rôle | Génération Higgsfield |
| --- | --- | --- |
| `panneau_bois.png` | fiches, carnet, dés, effraction : acajou verni à filets de laiton (256 px, coins de 30 px) | `2894b4be-94be-4109-b58a-4e82e2dfd9e6` |
| `panneau_papier.png` | rapport de fin de casse : papier vergé à filet double (768 px, coins de 80 px) | `1bc8f197-d2fe-4ebc-86ed-9076a1797f87` |
| `bouton_laiton.png` | boutons : plaque de laiton biseautée | `7abd7cb2-6b90-4c13-a876-2a747838e07d` |
| `menu_fond.jpg` | fond du menu : la villa la nuit, la bande à la grille | `82dfbc0b-41a6-4620-9d46-96375e006668` |

Polices sous licence SIL OFL (texte de la licence à côté) dans `assets/fonts/` : EB Garamond pour le texte, Cormorant Garamond pour les titres, toutes deux en fichier variable (la graisse se règle dans `game_hud.gd`). Les dés sont dessinés par le jeu (`scripts/ui/dice_tray.gd`) : aucune image.

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

## Sons et musiques

Générés le 13 novembre 2026 sur Higgsfield : bruitages par « mirelo_text_to_audio » (0,75 crédit), musiques instrumentales par « elevenlabs_music_v2_5 » (environ 13 crédits la minute et demie). Mis en OGG au même volume perçu par `tools/preparer_son.py` ; les réglages employés sont notés après chaque nom.

| Son | Génération Higgsfield | Réglages |
| --- | --- | --- |
| `bruitages/pas_voleur` | `6c9aa710-9e1a-45b1-9849-1fc05790510f` | volume=-24 boucle=oui fondu=0.3 |
| `bruitages/pas_garde` | `a1d5adbf-c83d-46ce-b395-645ebf11ef60` | volume=-22 boucle=oui fondu=0.3 |
| `bruitages/crochetage` | `6f2ddb81-a4f0-4879-9082-8fd435eb3d1a` | volume=-20 |
| `bruitages/porte` | `bc5924c6-4dd2-4e5e-bff3-b6838366ba8b` | volume=-18 |
| `bruitages/fenetre` | `e10499a9-4ba5-4432-8a06-ebd36fdba115` | volume=-18 |
| `bruitages/tiroir` | `e492de3f-1173-454c-8df6-025647aea993` | volume=-19 |
| `bruitages/coffre_fort` | `1ed3d1cd-aec9-4978-a06d-98f284d77cc2` | volume=-18 debut=1.6 |
| `bruitages/grille` | `5f4f1293-53fe-4a88-97bf-eed8f34af0b5` | volume=-18 |
| `bruitages/des` | `c816f6c0-8bfd-4c10-9d54-4865f1e7d505` | volume=-19 |
| `bruitages/butin` | `22a15b88-e6c6-4a6b-a0e2-bf01a790fd8f` | volume=-18 |
| `bruitages/sonnerie_alarme` | `195580ba-d92a-41fb-abd9-dde745921ac3` | volume=-15 |
| `bruitages/sifflet` | `dfca407e-abb1-4b26-b332-2a5ac5c83402` | volume=-17 |
| `bruitages/coup` | `0a664a12-cb09-4597-a3bb-785aecdc3f69` | volume=-16 |
| `bruitages/saut` | `bae43ff5-c7af-487e-8720-2bad517ac805` | volume=-19 |
| `bruitages/escalade` | `57c20054-616a-4f1a-bfe4-9ca9d689484b` | volume=-20 |
| `bruitages/aube` | `534d3cc2-6caa-439d-bcc8-58898a417491` | volume=-18 |
| `bruitages/horloge` | `b2329e7d-b341-4117-ab92-c9b4398de5e2` | volume=-20 |
| `bruitages/ambiance_nuit` | `8485ab4a-2192-42c5-8970-cda6436dd17c` | volume=-28 boucle=oui fondu=4 |
| `musiques/menu` | `b14c3f8b-19d0-4a5f-8a47-cd26a3727c77` | volume=-20 boucle=oui fondu=4 fin=0.6 |
| `musiques/nuit` | `28bc9215-a59c-4e13-9b40-e207a12e7aca` | volume=-23 boucle=oui fondu=5 |
| `musiques/alerte` | `4c77b20d-ba6a-45fb-993a-45f194c1a8b4` | volume=-20 boucle=oui fondu=3 |

Écartés : un premier sifflet sans son de sifflet, une grille sans grincement et des dés trop sourds sur feutre (refaits sur une table de bois).
