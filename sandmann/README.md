# Download der Videos von Sandmann.de

## Verwendung

Das Skript, gibt auf der Standardausgabe (stdout) ein Shellskript aus, welches danach bearbeitet und ausgeführt (oder ge-`source`-t) werden kann.

## Vorausgesetzte Pakete usw.

Als Voraussetzung sollte unter Debian/Ubuntu folgendes Paket installiert werden:

```
apt install firefox-geckodriver
```

Weiterhin wird die Anbindung für Python an Selenium benötigt:

```
python -m pip install -U selenium
```

(ggf. `python` durch `python3` ersetzen oder das gewünschte Virtualenv aktivieren usw.)

Das ausgegebene Shellskript setzt aktuell `wget` voraus.
