# Mandala VR — architecture après v55

Les anciennes couches runtime v38, v39, v40, v41, v43, v44, v45 et v46
ont été consolidées.

Runtime actuel pour les effets Grand 8 / Course :
- V53RideFXManager : flux, événements, mise en scène, architecture/bifurcations.
- V52VisualManager : profondeur, architecture vivante, grands moments, vertige.

Ne pas réinstancier les anciens managers v38-v46 dans main.tscn.
Leurs fichiers restent uniquement comme archives inactives.

Tir Mandala reste dans v47_manager.gd.
