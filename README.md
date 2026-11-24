# Valdbrume

Nouveau jeu mobile (Godot 4.7, Android). Étape 1 : la ville de départ.

- `tools/layout.py` : plan de la ville, chaque bâtiment posé à la main.
- `tools/streets.py` : rues, trottoirs, carrefours, place du Portail.
- `tools/build_project.py` : génère les zones fusionnées, l'atlas des façades,
  les collisions et les occulteurs dans `project/assets/city/gen/`.
- `project/` : projet Godot (rendu Mobile).
- CI (`.github/workflows/build.yml`) : génération, import, traversée du
  boulevard, captures en jeu (branche `captures`), APK (release `apk-ville`).

Assets : Downtown City MegaKit (Quaternius, CC0), Human Animations
(Kevin Iglesias, version gratuite).
