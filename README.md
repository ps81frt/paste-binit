# pastebinit — Module PowerShell

Envoyez du texte ou des fichiers vers des services pastebin directement depuis PowerShell.  
Compatible **Windows 7 SP1 → Windows 11** (PowerShell 5.1 et PowerShell 7+).

---

## Prérequis

| Composant | Version minimum | Notes |
|---|---|---|
| Windows | 7 SP1 | SP1 obligatoire |
| PowerShell | 5.1 | Inclus dans Win 7 SP1+ via WMF 5.1 |
| .NET Framework | 4.5 | **4.8 recommandé** — requis pour TLS 1.2 |

---

## Installation

### Étape 1 — Installer .NET Framework 4.8 (si pas encore installé)

Requis pour le support TLS 1.2 (connexions HTTPS vers les services pastebin).

**Installateur hors-ligne (recommandé — pas besoin d'internet pendant l'install) :**  
https://support.microsoft.com/en-us/topic/microsoft-net-framework-4-8-offline-installer-for-windows-9d23f658-3b97-68ab-d013-aa3c3e7495e0

> Windows 10 et 11 incluent déjà .NET 4.8 ou supérieur — passez cette étape.

Après installation, **redémarrez votre PC**.

---

### Étape 2 — Installer WMF 5.1 (Windows 7 / 8.1 uniquement)

Windows 7 a besoin de Windows Management Framework 5.1 pour obtenir PowerShell 5.1.

**Télécharger WMF 5.1 :**  
https://www.microsoft.com/en-us/download/details.aspx?id=54616

Choisissez le fichier correspondant à votre système :
- `Win7AndW2K8R2-KB3191566-x64.zip` → Windows 7 64 bits
- `Win7-KB3191566-x86.zip` → Windows 7 32 bits

Après installation, **redémarrez votre PC**.

> Windows 8.1, 10 et 11 incluent déjà PowerShell 5.1 — passez cette étape.

---

### Étape 3 — Installer le module pastebinit

Ouvrez PowerShell et exécutez :

```powershell
# Forcer TLS 1.2 (obligatoire sur Windows 7 avant l'installation de .NET 4.8)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Créer le dossier du module
$modulePath = "$HOME\Documents\WindowsPowerShell\Modules\pastebinit"
New-Item -ItemType Directory -Force -Path $modulePath

# Télécharger le module
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ps81frt/paste-binit/main/pastebinit.psm1" `
    -OutFile "$modulePath\pastebinit.psm1"

# Importer le module
Import-Module pastebinit

# Vérifier
pastebinit -List
```

> **Utilisateurs PowerShell 7+ :** remplacez `WindowsPowerShell` par `PowerShell` dans le chemin ci-dessus.

---

### Étape 4 — Chargement automatique au démarrage (optionnel)

Pour charger pastebinit automatiquement à chaque ouverture de PowerShell :

```powershell
# Ajouter au profil PowerShell
Add-Content $PROFILE "`nImport-Module pastebinit"
```

---

## Utilisation

### Envoyer du texte via le pipeline

```powershell
"Bonjour le monde" | pastebinit
```

### Envoyer un fichier

```powershell
pastebinit -InputFile "C:\script.ps1"
```

### Choisir un service

```powershell
"Bonjour" | pastebinit -Service dpaste.com
```

### Lister les services disponibles

```powershell
pastebinit -List
```

### Avec des options

```powershell
pastebinit -InputFile "C:\script.ps1" -Service dpaste.com -Format powershell -Title "Mon script"
```

### Afficher le contenu avant envoi

```powershell
Get-Content fichier.txt | pastebinit -PrintContent
```

---

## Paramètres

| Paramètre | Alias | Description | Défaut |
|---|---|---|---|
| `-InputText` | — | Texte via le pipeline | — |
| `-InputFile` | — | Chemin vers le(s) fichier(s) à envoyer | — |
| `-List` | — | Afficher les services disponibles | — |
| `-Service` | `-b` | Service cible | `paste.debian.net` |
| `-Author` | `-a` | Nom de l'auteur | Nom d'utilisateur Windows |
| `-Title` | `-t` | Titre du paste | — |
| `-Format` | `-f` | Coloration syntaxique (text, python, powershell…) | `text` |
| `-Private` | `-P` | Visibilité : 1 = privé, 0 = public | `1` |
| `-Expiry` | `-e` | Expiration (selon le service) | — |
| `-Username` | `-u` | Nom d'utilisateur (si requis) | — |
| `-Password` | `-pw` | Mot de passe (si requis) | — |
| `-PrintContent` | `-pc` | Afficher le contenu avant l'envoi | — |

---

## Services supportés

| Service | Authentification | Variable clé API |
|---|---|---|
| `paste.debian.net` | Non | — |
| `dpaste.com` | Non | — |
| `nekobin.com` | Non | — |
| `0x0.st` | Non | — |
| `gofile.io` | Non | — |
| `pastebin.com` | Clé API | `$env:PASTEBIN_API_KEY` |
| `hastebin.com` | Token | `$env:HASTEBIN_TOKEN` |
| `paste.ubuntu.com` | Compte Ubuntu | — |
| `fpaste.org` | ⚠ Instable | — |

### Définir une clé API

```powershell
# Pour la session en cours uniquement
$env:PASTEBIN_API_KEY = "votre_clé_ici"

# Permanent (ajouter au profil)
Add-Content $PROFILE "`n`$env:PASTEBIN_API_KEY = 'votre_clé_ici'"
```

---

## Dépannage

**Erreur `AliasDeclaredMultipleTimes`**  
Vous avez une ancienne version du module. Re-téléchargez le dernier `pastebinit.psm1` depuis le dépôt et remplacez le fichier existant, puis rechargez :
```powershell
Remove-Module pastebinit -ErrorAction SilentlyContinue
Import-Module pastebinit
```

**Avertissement TLS 1.2 sur Windows 7**  
Installez .NET Framework 4.8 (voir Étape 1) et redémarrez. En attendant, forcez TLS 1.2 manuellement :
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

**Commande `pastebinit` introuvable**  
Vérifiez que le module est dans le bon dossier :
```powershell
$HOME\Documents\WindowsPowerShell\Modules\pastebinit\pastebinit.psm1
```

---

## Licence

MIT — voir le dépôt pour les détails.  
https://github.com/ps81frt/paste-binit
