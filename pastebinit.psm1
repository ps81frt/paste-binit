<#
.SYNOPSIS
    Envoie du texte ou un fichier vers un service pastebin.

.DESCRIPTION
    Module pastebinit — compatible PowerShell 5.1 (Windows 7+) et PowerShell 7+.
    Charge automatiquement via le dossier Modules, aucun dot-sourcing requis.

    Certains services necessitent une cle API via variable d'environnement :
      - pastebin.com  : $env:PASTEBIN_API_KEY
      - hastebin.com  : $env:HASTEBIN_TOKEN

    paste.ubuntu.com necessite un compte Ubuntu actif.
    fpaste.org : API non officielle, peut être instable.

.PARAMETER InputText
    Texte à envoyer via le pipeline.

.PARAMETER InputFile
    Chemin(s) vers le(s) fichier(s) à envoyer.

.PARAMETER List
    Affiche la liste des services supportes.

.PARAMETER Service
    Nom du service cible. Par defaut : paste.debian.net.

.PARAMETER Author
    Nom de l'auteur du paste. Par defaut : nom d'utilisateur système.

.PARAMETER Title
    Titre du paste.

.PARAMETER Format
    Format/syntaxe du paste (ex: text, python, bash...). Par defaut : text.

.PARAMETER Private
    Visibilite du paste. 1 = prive, 0 = public. Par defaut : 1.

.PARAMETER Expiry
    Duree d'expiration du paste (selon le service).

.PARAMETER Username
    Nom d'utilisateur (si requis par le service).

.PARAMETER Password
    Mot de passe (si requis par le service).

.PARAMETER PrintContent
    Affiche le contenu envoye avant l'upload.

.EXAMPLE
    "Hello World" | pastebinit
    Envoie "Hello World" vers paste.debian.net.

.EXAMPLE
    pastebinit -InputFile "C:\script.ps1" -Service dpaste.com -Format powershell
    Envoie un fichier vers dpaste.com avec la syntaxe PowerShell.

.EXAMPLE
    pastebinit -List
    Affiche tous les services disponibles.

.EXAMPLE
    Get-Content fichier.txt | pastebinit -Service nekobin.com -PrintContent
    Envoie le contenu d'un fichier vers nekobin et affiche ce qui est envoye.

.EXAMPLE
    Get-Content fichier.txt | pastebinit -Service hastebin.com
    Necessite $env:HASTEBIN_TOKEN defini au prealable.
#>
function pastebinit {
    [CmdletBinding(DefaultParameterSetName = 'Pipeline')]
    param(
        [Parameter(ParameterSetName = 'Pipeline', Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$InputText,

        [Parameter(ParameterSetName = 'File', Mandatory = $true)]
        [string[]]$InputFile,

        [Parameter(ParameterSetName = 'List')]
        [switch]$List,

        [Alias('b')]
        [string]$Service = 'paste.debian.net',

        [Alias('a')]
        [string]$Author = $env:USERNAME,

        [Alias('t')]
        [string]$Title,

        [Alias('f')]
        [string]$Format = 'text',

        [Alias('P')]
        [int]$Private = 1,

        [Alias('e')]
        [string]$Expiry,

        [Alias('u')]
        [string]$Username,

        [Alias('pw')]
        [string]$Password,

        [Alias('pc')]
        [switch]$PrintContent
    )

    begin {
        # --- Verification des dependances (une seule fois par session) ---
        if (-not $script:_pastebinit_checked) {
            $script:_pastebinit_checked = $true

            $psVer = $PSVersionTable.PSVersion.Major
            Write-Verbose "PowerShell version : $psVer"

            if ($psVer -lt 5) {
                Write-Error "pastebinit necessite PowerShell 5.1 minimum."
                return
            }

            if ($psVer -eq 5) {
                Write-Warning "PowerShell 5.1 detecte : les uploads de fichiers (0x0.st, gofile.io) utilisent un multipart manuel."
            }

            $netVer = [System.Environment]::Version
            Write-Verbose ".NET version detectee : $netVer"
            if ($netVer.Major -lt 4 -or ($netVer.Major -eq 4 -and $netVer.Minor -lt 5)) {
                Write-Warning ".NET Framework 4.5 minimum requis pour TLS 1.2. Version detectee : $netVer"
            }

            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            }
            catch {
                Write-Warning "Impossible d'activer TLS 1.2 : $_"
            }
        }

        $allText = [System.Collections.Generic.List[string]]::new()

        $script:pasteServices = @{

            # ----------------------------------------------------------------
            # paste.debian.net — POST form, reponse JSON avec champ "id"
            # ----------------------------------------------------------------
            'paste.debian.net' = @{
                Uri    = 'https://paste.debian.net/api/pastes'
                Method = 'Post'
                IsJson = $false
                BodyParams = @{
                    poster     = $Author
                    title      = if ($Title) { $Title } else { 'paste' }
                    format     = $Format
                    private    = $Private
                    expiration = $Expiry
                    code       = $null
                }
                TextField       = 'code'
                UrlTemplate     = 'https://paste.debian.net/pastes/{id}/'
                ResponseIdField = 'id'
            }

            # ----------------------------------------------------------------
            # dpaste.com — POST form, reponse = URL brute
            # ----------------------------------------------------------------
            'dpaste.com' = @{
                Uri    = 'https://dpaste.com/api/'
                Method = 'Post'
                IsJson = $false
                BodyParams = @{
                    content     = $null
                    syntax      = $Format
                    expiry_days = if ($Expiry -match '^\d+$') { $Expiry } else { 7 }
                }
                TextField       = 'content'
                UrlTemplate     = '{response}'
                ResponseIdField = $null
            }

            # ----------------------------------------------------------------
            # 0x0.st — upload multipart, reponse = URL brute
            # ----------------------------------------------------------------
            '0x0.st' = @{
                Uri           = 'https://0x0.st'
                Method        = 'Post'
                IsFileUpload  = $true
                FileFieldName = 'file'
                UrlTemplate   = '{response}'
            }

            # ----------------------------------------------------------------
            # gofile.io — upload multipart, reponse JSON imbriquee
            # ----------------------------------------------------------------
            'gofile.io' = @{
                Uri                 = 'https://store1.gofile.io/uploadFile'
                Method              = 'Post'
                IsFileUpload        = $true
                FileFieldName       = 'file'
                UrlTemplate         = '{data.downloadPage}'
                ResponseStatusField = 'status'
                ResponseOkValue     = 'ok'
            }

            # ----------------------------------------------------------------
            # nekobin.com — POST JSON, reponse JSON {"result":{"key":"..."}}
            # Aucune authentification requise
            # ----------------------------------------------------------------
            'nekobin.com' = @{
                Uri    = 'https://nekobin.com/api/documents'
                Method = 'Post'
                IsJson = $true
                JsonBodyBuilder = {
                    param($text)
                    @{ document = @{ content = $text } } | ConvertTo-Json -Compress
                }
                UrlTemplate     = 'https://nekobin.com/{key}'
                ResponseIdField = 'result.key'
            }

            # ----------------------------------------------------------------
            # hastebin.com (Toptal) — POST text/plain avec Bearer token
            # Necessite $env:HASTEBIN_TOKEN
            # ----------------------------------------------------------------
            'hastebin.com' = @{
                Uri            = 'https://hastebin.com/documents'
                Method         = 'Post'
                IsJson         = $false
                IsRawBody      = $true
                ContentType    = 'text/plain'
                RequiresEnvVar = 'HASTEBIN_TOKEN'
                UrlTemplate    = 'https://hastebin.com/{key}'
                ResponseIdField = 'key'
            }

            # ----------------------------------------------------------------
            # pastebin.com — POST form avec cle API obligatoire
            # Necessite $env:PASTEBIN_API_KEY
            # ----------------------------------------------------------------
            'pastebin.com' = @{
                Uri    = 'https://pastebin.com/api/api_post.php'
                Method = 'Post'
                IsJson = $false
                RequiresEnvVar = 'PASTEBIN_API_KEY'
                BodyParams = @{
                    api_dev_key           = $env:PASTEBIN_API_KEY
                    api_option            = 'paste'
                    api_paste_code        = $null
                    api_paste_name        = $Title
                    api_paste_format      = $Format
                    api_paste_private     = $Private
                    api_paste_expire_date = $Expiry
                }
                TextField   = 'api_paste_code'
                UrlTemplate = '{response}'
            }

            # ----------------------------------------------------------------
            # paste.ubuntu.com — POST form, authentification requise
            # Fonctionne uniquement si un compte valide est accessible
            # ----------------------------------------------------------------
            'paste.ubuntu.com' = @{
                Uri    = 'https://paste.ubuntu.com'
                Method = 'Post'
                IsJson = $false
                Warning = "paste.ubuntu.com necessite un compte Ubuntu valide. Le POST anonyme ne fonctionnera pas."
                BodyParams = @{
                    poster  = $Author
                    syntax  = $Format
                    content = $null
                    expiry  = $Expiry
                }
                TextField       = 'content'
                UrlTemplate     = 'https://paste.ubuntu.com/{id}/'
                ResponseIdField = 'id'
            }

            # ----------------------------------------------------------------
            # fpaste.org (Fedora) — API non officielle, instable
            # ----------------------------------------------------------------
            'fpaste.org' = @{
                Uri    = 'https://paste.fedoraproject.org/api/paste/submit'
                Method = 'Post'
                IsJson = $false
                Warning = "fpaste.org : API non officielle, peut être instable ou indisponible."
                BodyParams = @{
                    title   = $Title
                    format  = $Format
                    content = $null
                    private = $Private
                    expire  = $Expiry
                }
                TextField       = 'content'
                UrlTemplate     = 'https://paste.fedoraproject.org/paste/{id}'
                ResponseIdField = 'id'
            }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Pipeline') {
            $allText.Add($InputText)
        }
    }

    end {
        if ($List) {
            Write-Host "Services supportes :"
            $script:pasteServices.Keys | Sort-Object | ForEach-Object {
                $svcInfo = $script:pasteServices[$_]
                $note = ''
                if ($svcInfo.RequiresEnvVar) {
                    $note = " [cle API : `$env:$($svcInfo.RequiresEnvVar)]"
                }
                elseif ($svcInfo.Warning) {
                    $note = " [⚠ authentification requise]"
                }
                Write-Host " - $_$note"
            }
            return
        }

        if ($PSCmdlet.ParameterSetName -eq 'File') {
            foreach ($f in $InputFile) {
                $allText.Add((Get-Content -Path $f -Raw -ErrorAction Stop))
            }
        }

        $finalText = $allText -join "`n"

        if (-not $finalText) {
            Write-Error "Aucun texte fourni. Utilisez le pipeline, -InputFile, ou -List."
            return
        }

        if ($PrintContent) {
            Write-Host $finalText
        }

        if (-not $script:pasteServices.ContainsKey($Service)) {
            Write-Error "Service '$Service' non supporte. Utilisez -List pour voir les services disponibles."
            return
        }

        $svc = $script:pasteServices[$Service]

        # --- Verification cle API si service l'exige ---
        if ($svc.RequiresEnvVar) {
            $envVal = [System.Environment]::GetEnvironmentVariable($svc.RequiresEnvVar)
            if (-not $envVal) {
                Write-Error "$Service necessite une cle API dans `$env:$($svc.RequiresEnvVar)."
                return
            }
        }

        # --- Warning informatif si service risque ---
        if ($svc.Warning) {
            Write-Warning $svc.Warning
        }

        $resultUrl = $null

        try {
            # ----------------------------------------------------------------
            # CAS 1 : Upload fichier (multipart manuel — compatible PS 5.1)
            # ----------------------------------------------------------------
            if ($svc.IsFileUpload) {
                $tmpFile = [System.IO.Path]::GetTempFileName()
                [System.IO.File]::WriteAllText($tmpFile, $finalText, [System.Text.Encoding]::UTF8)

                try {
                    $boundary    = [System.Guid]::NewGuid().ToString()
                    $fieldName   = $svc.FileFieldName
                    $fileName    = 'paste.txt'

                    $headerBytes = [System.Text.Encoding]::UTF8.GetBytes(
                        "--$boundary`r`n" +
                        "Content-Disposition: form-data; name=`"$fieldName`"; filename=`"$fileName`"`r`n" +
                        "Content-Type: text/plain`r`n`r`n"
                    )
                    $fileBytes   = [System.IO.File]::ReadAllBytes($tmpFile)
                    $footerBytes = [System.Text.Encoding]::UTF8.GetBytes("`r`n--$boundary--`r`n")

                    $bodyList = [System.Collections.Generic.List[byte]]::new()
                    $bodyList.AddRange($headerBytes)
                    $bodyList.AddRange($fileBytes)
                    $bodyList.AddRange($footerBytes)
                    $bodyArray = $bodyList.ToArray()

                    $response = Invoke-RestMethod `
                        -Uri         $svc.Uri `
                        -Method      Post `
                        -Body        $bodyArray `
                        -ContentType "multipart/form-data; boundary=$boundary" `
                        -TimeoutSec  30

                    if ($Service -eq 'gofile.io') {
                        if ($response.status -eq $svc.ResponseOkValue) {
                            $resultUrl = $response.data.downloadPage
                        }
                        else {
                            throw "Erreur gofile.io : $($response.status)"
                        }
                    }
                    else {
                        # 0x0.st : reponse brute = URL
                        if ($response -is [string]) {
                            $resultUrl = $response.Trim()
                        }
                        else {
                            $resultUrl = $response.ToString().Trim()
                        }
                    }
                }
                finally {
                    Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
                }
            }

            # ----------------------------------------------------------------
            # CAS 2 : Corps JSON (nekobin.com)
            # ----------------------------------------------------------------
            elseif ($svc.IsJson) {
                $jsonBody = & $svc.JsonBodyBuilder $finalText

                $response = Invoke-RestMethod `
                    -Uri         $svc.Uri `
                    -Method      Post `
                    -Body        $jsonBody `
                    -ContentType 'application/json' `
                    -TimeoutSec  30

                $fieldPath = $svc.ResponseIdField
                $val       = $response
                foreach ($part in $fieldPath.Split('.')) {
                    $val = $val.$part
                }
                $resultUrl = $svc.UrlTemplate -replace '\{key\}', $val
            }

            # ----------------------------------------------------------------
            # CAS 3 : Corps texte brut avec header Authorization (hastebin.com)
            # ----------------------------------------------------------------
            elseif ($svc.IsRawBody) {
                $token   = [System.Environment]::GetEnvironmentVariable($svc.RequiresEnvVar)
                $headers = @{ Authorization = "Bearer $token" }

                $response = Invoke-RestMethod `
                    -Uri         $svc.Uri `
                    -Method      Post `
                    -Body        $finalText `
                    -ContentType $svc.ContentType `
                    -Headers     $headers `
                    -TimeoutSec  30

                $id        = $response.$($svc.ResponseIdField)
                $resultUrl = $svc.UrlTemplate -replace '\{key\}', $id
            }

            # ----------------------------------------------------------------
            # CAS 4 : POST form standard
            # ----------------------------------------------------------------
            else {
                $body = @{}

                foreach ($key in $svc.BodyParams.Keys) {
                    $val = $svc.BodyParams[$key]
                    if ($null -ne $val) {
                        $body[$key] = $val
                    }
                }

                if ($svc.TextField) {
                    $body[$svc.TextField] = $finalText
                }

                $response = Invoke-RestMethod `
                    -Uri        $svc.Uri `
                    -Method     $svc.Method `
                    -Body       $body `
                    -TimeoutSec 30

                if ($svc.ResponseIdField) {
                    $id        = $response.$($svc.ResponseIdField)
                    $resultUrl = $svc.UrlTemplate -replace '\{id\}', $id
                }
                else {
                    if ($svc.UrlTemplate -eq '{response}') {
                        if ($response -is [string]) {
                            $resultUrl = $response.Trim()
                        }
                        else {
                            $resultUrl = $response.ToString().Trim()
                        }
                    }
                    else {
                        $resultUrl = $svc.UrlTemplate
                        $matches2  = [regex]::Matches($svc.UrlTemplate, '\{([^}]+)\}')
                        foreach ($m in $matches2) {
                            $propPath = $m.Groups[1].Value
                            $val      = $response
                            foreach ($part in $propPath.Split('.')) {
                                $val = $val.$part
                            }
                            $resultUrl = $resultUrl.Replace($m.Value, $val)
                        }
                    }
                }
            }
        }
        catch {
            Write-Error "echec de l'envoi vers $Service : $_"
            return
        }

        if ($resultUrl) {
            Write-Output $resultUrl
        }
    }
}

Export-ModuleMember -Function pastebinit