# KPNF
KIS Patienten Notfalldaten

Das Powershell Module KIS Patienten Notfalldaten hält bei einem System-/Netzwerkausfall die wichtigesten Patientendaten aus dem KIS vor.
Dazu werden alle Daten aus den jeweiligen KIS Datenbank exportiert und pro Patient in einer XML Datei an einer zentralen Position zusammengefügt.
Diese XML Datei kann mit jedem Browser betrachtet und ausgedruckt werden.

Features
  - Zyklischer Export über einen geplanten Task
  - Kopieren der Notfalldaten auf die lokalen Festplatten der Notfallpc
  - Anpassbarkeit der zu exportierenden Daten
