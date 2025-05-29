# Voraussetzungen

Neben einer **ClassInsights-Lizenz** benötigen Sie:

- **Private IP** des Servers, auf dem Dashboard und lokale API laufen sollen (Linux empfohlen; Windows-Support folgt bald)  
- **Windows Active Directory**¹ (diese Anleitung setzt eine Windows-AD-Umgebung voraus)
- **Computernamen** müssen mithilfe eines Pattern oder Regex den WebUntis Räumen zugeordnet werden können

> ¹ Wenn Ihre Schule ein anderes Authentifizierungs- oder Verzeichnisdienst-System nutzt, setzen Sie sich bitte vor Beginn mit uns in Verbindung: office@classinsights.at

---

## 1. Vorbereitung auf dem Domain Controller

**1. ExecutionPolicy ändern** 
Bevor Sie starten, vergewissern Sie sich, dass Sie PowerShell-Skripte ausführen dürfen:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
> Dadurch sind lokale Skripte und signierte Skripte aus dem Internet erlaubt.

**2. Installationsskript herunterladen**

[Hier](https://raw.githubusercontent.com/classinsights/installer/refs/heads/main/gen_files.ps1) finden Sie das PowerShell Installationsskript zum herunterladen und ausführen:
```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/classinsights/installer/main/classinsights.ps1 -OutFile .\classinsights.ps1
```

**3. Skript starten**
```powershell
.\classinsights.ps1
```
> Der Assistent führt Sie durch die Erstellung aller benötigten Dateien.

**4. Lizenz-Key & Server-IP eingeben**
```
Bitte gib deinen ClassInsights Lizenz Key ein
Lizenz: <Ihr-Lizenz-Key>

Was ist die IP Addresse des ClassInsights API Server?
IP: <Server-IP>    # z. B. 172.16.32.104
```

**5. Dateien auf den Server hochladen**

Wenn der Assistent fragt:
```
Wollen Sie die Dateien für die lokale API nun auf den Server hochladen? (J/N) J
```
geben Sie Ihre SSH-Zugangsdaten für ihren lokalen ClassInsights Server ein, damit alle benötigten Dateien auf den Zielserver kopiert werden:
```
Username: <Ihr-Username>
IP des Servers: <Server-IP>
```
> Bei Problemen können Sie den Befehl auch manuell eingeben:
> scp -r api username@server:~/."

Nun können wir uns ein `ClassInsights` Gruppenrichtlinienobjekt erstellen lassen:
```
Wollen Sie nun zu der Erstellung des Gruppenrichtlinienobjekts übergehen? (J/N): J
```
> Hierbei wird das generierte `gpo_install.ps1` Skript ausgeführt

**Verzeichnisstruktur zur Orientierung**
```
api/
├─ api.env
├─ cert.pfx
├─ classinsights.sh
├─ docker-compose.yml
gpo/
├─ gpo_install.ps1
├─ ClassInsights_CA.cer
├─ ClassInsights.msi
classinsights.ps1
```

## 2. Konfigurierung der Gruppenrichtlinie (GPO)

**1. Dateien für Clients bereitstellen**
Kopieren Sie in einen freigegebenen Netzwerk-Ordner (z. B.<br> `\\ihre.ad.domain\SYSVOL\ihre.ad.domain\scripts`):

-   `ClassInsights_CA.cer`  
-   `ClassInsights.msi`

> Die Dateien befinden sich in dem erstellten `gpo` Ordner

**2. GPO konfigurieren**
Als nächstes öffnen wir die Gruppenrichtlinienverwaltung und wählen bei den Gruppenrichtlinienobjekte `ClassInsights` zum Bearbeiten aus:

**2.1 Softwareinstallation**
```
Computerkonfiguration
└─ Richtlinien
   └─ Softwareeinstellungen
      └─ Softwareinstallation
```

- → Rechtsklick → `Neu > Paket` → `ClassInsights.msi` → `OK`

**2.2 Stammzertifikat importieren**
```
Computerkonfiguration
└─ Richtlinien
   └─ Windows-Einstellungen
      └─ Sicherheitseinstellungen
         └─ Richtlinien für öffentliche Schlüssel
            └─ Vertrauenswürdige Stammzertifizierungsstellen
```
-   Rechtsklick → **Importieren** → `ClassInsights_CA.cer`
-   Folgen Sie dem Zertifikat-Import-Assistenten

**3. GPO aktivieren**
- Weisen Sie das **ClassInsights**-GPO den gewünschten Organisationseinheiten zu.

> Nach der nächsten Gruppenrichtlinienauffrischung installieren sich die Clients automatisch.

## 3. Installation auf dem ClassInsights API Server

**1. SSH-Verbindung herstellen**  
Verwenden Sie z. B.  [Putty](https://www.putty.org/), PowerShell oder ein anderes Terminal:

```
ssh <Ihr-Username>@<Server-IP>
```
**2. In das API-Verzeichnis wechseln & Installation starten**
```bash
cd api
chmod +x classinsights.sh && sudo ./classinsights.sh install
```

-   Das Skript installiert [Docker](https://www.docker.com/)  und startet alle benötigten Container automatisch.
-   Standard-Port für die API: **52001**.
-   Standard-Port für das Dashboard: **52000**

> **Hinweis:** Stellen Sie sicher, dass Port 52000 und 52001 in Ihrer Firewall geöffnet sind und alle Clients Zugriff haben.

## 4. Räume konfigurieren
- Rufen Sie im Browser das Dashboard auf:
- Unter **Konfiguration → Raum-Pattern** legen Sie ein Namensmuster fest (z. B. `DV1*`), damit ClassInsights WebUntis-Räume automatisch zuordnet.
> Achten Sie darauf, dass das Muster genau zu Ihren Computernamen passt.


## Fragen/Probleme?

> Bitte senden Sie alle Fehlermeldungen und eine Beschreibung an: office@classinsights.at

## FAQ

### Lokale Dashboard URL ändern
...