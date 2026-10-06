# Mandala VR

Version Meta Quest 3 de Mandala Studio (Godot 4.6 + OpenXR). Version 4 : 4 nouveaux mondes (lucioles, volcan, glacier, rêve rose). Version 3 : modèles, mondes immersifs, dôme, sons.

## Ce qu'il y a dedans

- les 48 genres du téléphone (familles : Bases, Tissages, Matières, Symboles, Fractales, Thèmes), avec les 24 symboles, les perles, les 6 pavages et les 10 dispositions ;
- les fractales (Koch, Cesaro, Lévy, Minkowski, Dragon), récursion, niveaux d'échelle, réduction, torsion, et le zoom infini / gouffre ;
- le choix de l'épaisseur du trait (0,3 à 12) et de l'opacité ;
- 66 palettes (les 20 du téléphone + 46 nouvelles), 14 modes de coloration, ta propre palette (sélecteur de couleur), 6 fonds ;
- effets lumineux : traits additifs, halo, cœur blanc, scintillement, pulsation, arc-en-ciel mobile, 10 ambiances toutes prêtes ;
- 10 reliefs en vrai 3D et 10 mouvements ;
- sauvegarde et chargement des créations, listes de diffusion avec séquences (durée, mouvement, transitions), Vizu automatique, 14 scènes livrées, tirage au sort.

## Immersion (version 3)

- Modèles en un clic : Matrix, Pluie Matrix, Vitrail, Rosace de vitrail, Smiley, Guirlande de smileys, Semis de smileys, Smileys sans fin, plus les 14 scènes livrées.
- 11 mondes autour de toi : nuit étoilée, nébuleuse, aurore boréale, abysses, crépuscule, code Matrix, cathédrale (rayons de lumière), lucioles, volcan, glacier, rêve rose, avec de la poussière lumineuse qui flotte.
- Dôme : le mandala se plaque sur une voûte autour de toi, tu es au centre et tu dessines sur la voûte. Onglet Monde : Plan / Dôme, ouverture réglable, recentrage.
- Sons du téléphone : 5 ambiances, notes pendant le tracé (5 gammes), jingle de démarrage. Les manettes vibrent quand tu dessines et quand tu cliques dans le menu.

## Manettes

- Joystick gauche : voler vers où tu regardes (gâchette gauche : plus vite). Joystick droit : tourner par crans, monter, descendre.
- Gâchette droite : dessiner sur l'image (ou cliquer dans le menu).
- Bouton menu (gauche) : ouvre tous les réglages. Le joystick droit fait défiler le menu quand le rayon le vise.
- A : genre suivant. B : palette suivante. X : mode de coloration. Y : relief suivant.
- Clic joystick droit : tirage au sort. Clic joystick gauche : pause de l'animation.
- Grip droit : annuler. Grip gauche : retour au départ. Les deux grips : toile vierge.

## Créations

Les créations sont enregistrées dans le casque (dossier utilisateur de l'application). Le format est le même que celui du téléphone, donc une création du téléphone se charge ici : copier son texte, puis « Coller depuis le presse-papiers » dans l'onglet Créations.
Des exemples sont fournis dans le dossier `creations/` du dépôt : tout fichier `.json` ajouté là est intégré à l'application à la prochaine compilation.

## Qualité

L'onglet Trait propose Éco / Normal / Maximum. Le nombre d'éléments est limité automatiquement selon la qualité ; si une scène est très chargée, le dessin est allégé plutôt que de ralentir le casque.

## Compilation

L'APK se compile sur GitHub (onglet Actions) et se publie dans Releases sous le nom `derniere-version`.

## Importer les creations du telephone (v5)
1. Telephone (appli v36) : Bibliotheque, icone VR en haut, puis enregistrer le fichier `mandala_vr_creations.json` (par exemple vers Termux ou Telechargements).
2. Termux : copier ce fichier dans `mandala_vr/creations/`, puis lancer la mise a jour habituelle.
3. Dans le casque, onglet Creations : elles apparaissent avec la mention (telephone).
