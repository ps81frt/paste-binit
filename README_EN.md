# pastebinit — PowerShell Module

Send text or files to pastebin services directly from PowerShell.  
Compatible with **Windows 7 SP1 → Windows 11** (PowerShell 5.1 and PowerShell 7+).

---

## Requirements

| Component | Minimum version | Notes |
|---|---|---|
| Windows | 7 SP1 | SP1 mandatory |
| PowerShell | 5.1 | Already included in Win 7 SP1+ via WMF 5.1 |
| .NET Framework | 4.5 | **4.8 recommended** — required for TLS 1.2 |

---

## Installation

### Step 1 — Install .NET Framework 4.8 (if not already installed)

Required for TLS 1.2 support (HTTPS connections to paste services).

**Offline installer (recommended — no internet needed during install):**  
https://support.microsoft.com/en-us/topic/microsoft-net-framework-4-8-offline-installer-for-windows-9d23f658-3b97-68ab-d013-aa3c3e7495e0

> Windows 10 and 11 already include .NET 4.8 or higher — skip this step.

After installing, **restart your PC**.

---

### Step 2 — Install WMF 5.1 (Windows 7 / 8.1 only)

Windows 7 needs Windows Management Framework 5.1 to get PowerShell 5.1.

**Download WMF 5.1:**  
https://www.microsoft.com/en-us/download/details.aspx?id=54616

Choose the file matching your system:
- `Win7AndW2K8R2-KB3191566-x64.zip` → Windows 7 64-bit
- `Win7-KB3191566-x86.zip` → Windows 7 32-bit

After installing, **restart your PC**.

> Windows 8.1, 10, and 11 already include PowerShell 5.1 — skip this step.

---

### Step 3 — Install the pastebinit module

Open PowerShell and run:

```powershell
# Forcer TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Ensuite relancer le téléchargement
$modulePath = "$HOME\Documents\WindowsPowerShell\Modules\pastebinit"
New-Item -ItemType Directory -Force -Path $modulePath

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ps81frt/paste-binit/main/pastebinit.psm1" `
    -OutFile "$modulePath\pastebinit.psm1"

Import-Module pastebinit
pastebinit -List
```

> **PowerShell 7+ users:** replace `WindowsPowerShell` with `PowerShell` in the path above.

---

### Step 4 — Auto-load on startup (optional)

To load pastebinit automatically every time PowerShell opens:

```powershell
# Add to your PowerShell profile
Add-Content $PROFILE "`nImport-Module pastebinit"
```

---

## Usage

### Send text via pipeline

```powershell
"Hello World" | pastebinit
```

### Send a file

```powershell
pastebinit -InputFile "C:\script.ps1"
```

### Choose a service

```powershell
"Hello" | pastebinit -Service dpaste.com
```

### List available services

```powershell
pastebinit -List
```

### With options

```powershell
pastebinit -InputFile "C:\script.ps1" -Service dpaste.com -Format powershell -Title "My script"
```

### Show content before sending

```powershell
Get-Content file.txt | pastebinit -PrintContent
```

---

## Parameters

| Parameter | Alias | Description | Default |
|---|---|---|---|
| `-InputText` | — | Text via pipeline | — |
| `-InputFile` | — | Path to file(s) to send | — |
| `-List` | — | Show available services | — |
| `-Service` | `-b` | Target service | `paste.debian.net` |
| `-Author` | `-a` | Author name | Current Windows username |
| `-Title` | `-t` | Paste title | — |
| `-Format` | `-f` | Syntax highlight (text, python, powershell…) | `text` |
| `-Private` | `-P` | Visibility: 1 = private, 0 = public | `1` |
| `-Expiry` | `-e` | Expiration (depends on service) | — |
| `-Username` | `-u` | Username (if required) | — |
| `-Password` | `-pw` | Password (if required) | — |
| `-PrintContent` | `-pc` | Print content before upload | — |

---

## Supported Services

| Service | Auth required | API key variable |
|---|---|---|
| `paste.debian.net` | No | — |
| `dpaste.com` | No | — |
| `nekobin.com` | No | — |
| `0x0.st` | No | — |
| `gofile.io` | No | — |
| `pastebin.com` | API key | `$env:PASTEBIN_API_KEY` |
| `hastebin.com` | Token | `$env:HASTEBIN_TOKEN` |
| `paste.ubuntu.com` | Ubuntu account | — |
| `fpaste.org` | ⚠ Unstable | — |

### Set an API key

```powershell
# For current session only
$env:PASTEBIN_API_KEY = "your_key_here"

# Permanent (add to profile)
Add-Content $PROFILE "`n`$env:PASTEBIN_API_KEY = 'your_key_here'"
```

---

## Troubleshooting

**`AliasDeclaredMultipleTimes` error**  
You have an old version of the module. Re-download the latest `pastebinit.psm1` from the repository and replace the existing file, then reload:
```powershell
Remove-Module pastebinit -ErrorAction SilentlyContinue
Import-Module pastebinit
```

**TLS 1.2 warning on Windows 7**  
Install .NET Framework 4.8 (see Step 1) and restart.

**`pastebinit` command not found**  
Check that the module is in the correct folder:
```powershell
$HOME\Documents\WindowsPowerShell\Modules\pastebinit\pastebinit.psm1
```

---

## License

MIT — see repository for details.  
https://github.com/ps81frt/paste-binit
