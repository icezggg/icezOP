<#
    ═══════════════════════════════════════════════════════════════
     icezOP · drivers-engine.ps1 (v1.0)
     Motor dinamico de deteccion y actualizacion de controladores
    ═══════════════════════════════════════════════════════════════
     · SIN listas predefinidas de modelos/versiones: analiza la PC real.
     · Drivers generales: Windows Update (API COM oficial Microsoft).
     · GPU NVIDIA: API JSON oficial que usa la web de NVIDIA
       (lookupValueSearch + AjaxDriverService) y descarga desde el CDN
       oficial de NVIDIA. NOTA: esa API no esta documentada publicamente
       y puede cambiar; ante fallo se informa y se abre la pagina oficial.
     · GPU AMD / Intel: NO existe API publica de consulta de versiones.
       Se usa el metodo oficial mas robusto disponible (herramienta
       oficial de autodeteccion de AMD / Intel DSA) con verificacion de
       firma digital, y si falla se abre la pagina oficial de soporte.
     · OpenGL / Vulkan: solo diagnostico (vienen con el driver de GPU).
     · Todo instalador descargado se verifica con Get-AuthenticodeSignature.
     · Log: %ProgramData%\PostInstall\Logs\drivers.log
     Este archivo se carga con dot-sourcing desde icezop.ps1 (UI) y
     tambien dentro de cada runspace de trabajo.
    ═══════════════════════════════════════════════════════════════
#>

# ─────────────────────────── Constantes ───────────────────────────
 $Script:DriverLogDir     = Join-Path $env:ProgramData 'PostInstall\Logs'
 $Script:DriverLogFile    = Join-Path $Script:DriverLogDir 'drivers.log'
 $Script:NvidiaLookupBase = 'https://www.nvidia.com/Download/API/lookupValueSearch.json'
 $Script:NvidiaApiBase    = 'https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php'

# URLs de herramientas oficiales (constantes actualizables: si el fabricante
# mueve su herramienta, se cambia aqui sin tocar ninguna logica):
 $Script:AmdAutoDetectUrl = 'https://drivers.amd.com/drivers/amd-driver-autodetect.exe'
 $Script:IntelDsaUrl      = 'https://dsadata.intel.com/installer'

# Componentes de sistema via Winget (paquetes publicados por Microsoft/vendors):
 $Script:CompWingetMap = @{
    'vcredist-x64'   = 'Microsoft.VCRedist.2015+.x64'
    'vcredist-x86'   = 'Microsoft.VCRedist.2015+.x86'
    'dotnet-desktop' = 'Microsoft.DotNet.DesktopRuntime.8'
    'java-jre'       = 'EclipseAdoptium.Temurin.21.JRE'
    'directx-legacy' = 'Microsoft.DirectX'
}

 $Script:WuLastError = ''

# ─────────────────────────── Logging ───────────────────────────
function Write-DriverLog {
    param([string]$Message, [string]$Level = 'INFO')
    try {
        if (-not (Test-Path -LiteralPath $Script:DriverLogDir)) {
            New-Item -ItemType Directory -Path $Script:DriverLogDir -Force | Out-Null
        }
        $line = ('{0} [{1,-5}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message)
        Add-Content -LiteralPath $Script:DriverLogFile -Value $line -Encoding UTF8
    } catch {}
}

# ─────────────────────── Utilidades de version ───────────────────────
function ConvertTo-VersionNumbers {
    # Convierte "31.0.15.6109" en @(31,0,15,6109). Ignora sufijos no numericos.
    param([string]$Version)
    $nums = @()
    if ([string]::IsNullOrWhiteSpace($Version)) { return $nums }
    foreach ($part in ($Version -split '[\.\-\+ ]')) {
        $n = 0
        if ([int]::TryParse($part, [ref]$n)) { $nums += $n }
    }
    return $nums
}

function Compare-DriverVersion {
    # Devuelve 1 si A>B, -1 si A<B, 0 si iguales. Comparacion numerica
    # segmento a segmento (1.2.10 > 1.2.9 funciona correctamente).
    param([string]$VersionA, [string]$VersionB)
    if ([string]::IsNullOrWhiteSpace($VersionA) -and [string]::IsNullOrWhiteSpace($VersionB)) { return 0 }
    if ([string]::IsNullOrWhiteSpace($VersionA)) { return -1 }
    if ([string]::IsNullOrWhiteSpace($VersionB)) { return 1 }
    $a = ConvertTo-VersionNumbers $VersionA
    $b = ConvertTo-VersionNumbers $VersionB
    $len = [Math]::Max($a.Count, $b.Count)
    for ($i = 0; $i -lt $len; $i++) {
        $va = 0; if ($i -lt $a.Count) { $va = $a[$i] }
        $vb = 0; if ($i -lt $b.Count) { $vb = $b[$i] }
        if ($va -gt $vb) { return 1 }
        if ($va -lt $vb) { return -1 }
    }
    return 0
}

function ConvertFrom-NvidiaWmiVersion {
    # El WMI de NVIDIA reporta p.ej. "32.0.15.6109" que corresponde al
    # driver "561.09": se toman los ultimos 5 digitos de los 2 ultimos
    # grupos y se inserta el punto decimal.
    param([string]$Version)
    if ($Version -match '^\d+\.\d+\.(\d+)\.(\d+)$') {
        $tail = $Matches[1] + $Matches[2]
        if ($tail.Length -gt 5) { $tail = $tail.Substring($tail.Length - 5) }
        if ($tail.Length -ge 3) { return ($tail.Substring(0, $tail.Length - 2) + '.' + $tail.Substring($tail.Length - 2)) }
        return $tail
    }
    return $Version
}

# ─────────────────────── Seguridad ───────────────────────
function Test-InstallerSignature {
    # Verifica firma Authenticode valida + publisher esperado.
    # (NVIDIA/AMD/Intel no publican hashes oficiales por API, la firma
    # digital es la verificacion mas robusta disponible.)
    param([string]$Path, [string]$Publisher)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return $false }
        $sig = Get-AuthenticodeSignature -FilePath $Path
        if ($sig.Status -ne [System.Management.Automation.SignatureStatus]::Valid) { return $false }
        if (-not $sig.SignerCertificate) { return $false }
        if (([string]$sig.SignerCertificate.Subject) -match $Publisher) { return $true }
        return $false
    } catch { return $false }
}

function Get-IcezWinget {
    $w = (Get-Command winget -ErrorAction SilentlyContinue).Source
    if (-not $w) {
        $a = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
        if (Test-Path $a) { $w = $a }
    }
    return $w
}

# ─────────────────────── Inventario de hardware ───────────────────────
function Get-PnpDriverInventory {
    # Mapa DeviceID -> registro de driver firmado (Win32_PnPSignedDriver)
    $map = @{}
    foreach ($d in @(Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction SilentlyContinue)) {
        if ($d.DeviceID) { $map[[string]$d.DeviceID] = $d }
    }
    return $map
}

 $Script:PciVenMap = @{
    '8086' = 'Intel';            '10DE' = 'NVIDIA';        '1002' = 'AMD/ATI'
    '1022' = 'AMD';              '10EC' = 'Realtek';       '14E4' = 'Broadcom'
    '168C' = 'Qualcomm Atheros'; '8087' = 'Intel';         '1106' = 'VIA'
    '1969' = 'Aquantia';         '14F1' = 'Conexant';      '1043' = 'ASUS'
    '1462' = 'MSI';              '1458' = 'Gigabyte'
}

function Get-VendorFromHardwareId {
    # Identifica el fabricante por VEN_xxxx (PCI) o VID_xxxx (USB).
    param([string]$HwId)
    if (-not $HwId) { return '' }
    if ($HwId -match '(?i)(?:VEN|VID)_([0-9A-F]{4})') {
        $v = $Matches[1].ToUpper()
        if ($Script:PciVenMap[$v]) { return $Script:PciVenMap[$v] }
        return $v
    }
    return ''
}

 $Script:ProblemNames = @{
    1 = 'Configuracion incorrecta';    10 = 'El dispositivo no puede iniciar'
    12 = 'Recursos insuficientes';     14 = 'Reinstalar driver'
    18 = 'Reinstalar driver';          19 = 'Configuracion desconocida'
    21 = 'Windows esta quitando el dispositivo'; 22 = 'Dispositivo deshabilitado'
    28 = 'Driver no instalado';        31 = 'El dispositivo no funciona correctamente'
    43 = 'Windows detuvo el dispositivo (error de hardware)'; 45 = 'No conectado'
    52 = 'No se puede verificar la firma del driver'
}

function Get-HardwareInventory {
    # Fusiona Get-PnpDevice (dispositivos presentes, incluidos SIN driver)
    # + Win32_PnPSignedDriver (info del driver) + Win32_PnPEntity (codigo de
    # problema). Maneja valores nulos en todos los campos.
    $list = New-Object System.Collections.ArrayList
    $drvMap = Get-PnpDriverInventory
    $errMap = @{}
    foreach ($e in @(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue)) {
        if ($e.PNPDeviceID) { $errMap[[string]$e.PNPDeviceID] = [int]($e.ConfigManagerErrorCode) }
    }
    $devices = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId })
    foreach ($dev in $devices) {
        $id = [string]$dev.InstanceId
        $drv = $null
        if ($drvMap.ContainsKey($id)) { $drv = $drvMap[$id] }
        $prob = 0
        if ($errMap.ContainsKey($id)) { $prob = $errMap[$id] }
        $probName = ''
        if ($prob -ne 0 -and $Script:ProblemNames[$prob]) { $probName = $Script:ProblemNames[$prob] }
        elseif ($prob -ne 0) { $probName = ('codigo ' + $prob) }
        $dateStr = ''
        if ($drv -and $drv.DriverDate) {
            try { $dateStr = ([datetime]$drv.DriverDate).ToString('yyyy-MM-dd') } catch { $dateStr = [string]$drv.DriverDate }
        }
        [void]$list.Add(@{
            Name           = [string]$dev.FriendlyName
            Class          = [string]$dev.Class
            InstanceId     = $id
            Problem        = $prob
            ProblemName    = $probName
            HasDriver      = [bool]($drv -and ($drv.DriverVersion -or $drv.InfName))
            DriverProvider = [string]$(if ($drv) { $drv.DriverProvider })
            DriverVersion  = [string]$(if ($drv) { $drv.DriverVersion })
            DriverDate     = $dateStr
            Mfr            = [string]$(if ($drv) { $drv.Manufacturer })
            HardwareIds    = @()
            Vendor         = ''
            WuMatch        = $false
            WuTitle        = ''
        })
    }
    # Hardware IDs solo para dispositivos con problema o sin driver (barato).
    foreach ($d in $list) {
        if ($d.Problem -ne 0 -or -not $d.HasDriver) {
            try {
                $hw = Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop
                $d.HardwareIds = @($hw.Data)
            } catch {
                # Fallback: pnputil (herramienta nativa)
                try {
                    $out = & pnputil.exe /enum-devices /problem /deviceids 2>$null
                    $d.HardwareIds = @($out | Where-Object { $_ -match '^[A-Z]{3}_' })
                } catch {}
            }
            $first = @($d.HardwareIds | Select-Object -First 1)
            if ($first.Count -gt 0) { $d.Vendor = Get-VendorFromHardwareId ([string]$first[0]) }
        }
    }
    return $list
}

function Get-ProblemDevices {
    param($Inventory)
    return @($Inventory | Where-Object { $_.Problem -ne 0 -or -not $_.HasDriver })
}

function Get-GPUInventory {
    # Detecta TODAS las GPUs (soporta iGPU + dGPU simultaneas).
    $gpus = New-Object System.Collections.ArrayList
    foreach ($vc in @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue)) {
        $raw = ('' + $vc.Name + ' ' + $vc.AdapterCompatibility + ' ' + $vc.VideoProcessor)
        $vendor = 'Other'
        if ($raw -match 'NVIDIA') { $vendor = 'NVIDIA' }
        elseif ($raw -match 'AMD|Advanced Micro Devices|Radeon') { $vendor = 'AMD' }
        elseif ($raw -match 'Intel') { $vendor = 'Intel' }
        $wmiVer = [string]$vc.DriverVersion
        $friendly = $wmiVer
        if ($vendor -eq 'NVIDIA') { $friendly = ConvertFrom-NvidiaWmiVersion $wmiVer }
        $dateStr = ''
        if ($vc.DriverDate) { try { $dateStr = ([datetime]$vc.DriverDate).ToString('yyyy-MM-dd') } catch {} }
        [void]$gpus.Add(@{
            Name            = [string]$vc.Name
            Vendor          = $vendor
            WmiVersion      = $wmiVer
            FriendlyVersion = $friendly
            Date            = $dateStr
            InstanceId      = [string]$vc.PNPDeviceID
            State           = 'checking'
            Latest          = ''
            LatestSource    = ''
            Note            = ''
        })
    }
    return $gpus
}

# ─────────────────────── Windows Update (API COM oficial) ───────────────────────
function Search-WindowsUpdateDrivers {
    # Busca drivers ofrecidos por Windows Update. NO instala nada.
    $out = New-Object System.Collections.ArrayList
    $Script:WuLastError = ''
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        try { $searcher.Online = $true } catch {}
        $result = $searcher.Search("IsInstalled=0 and Type='Driver'")
        foreach ($u in @($result.Updates)) {
            $dateStr = ''
            try { if ($u.DriverVerDate) { $dateStr = ([datetime]$u.DriverVerDate).ToString('yyyy-MM-dd') } } catch {}
            [void]$out.Add(@{
                Title       = [string]$u.Title
                Model       = [string]$u.DriverModel
                Mfr         = [string]$u.DriverManufacturer
                Class       = [string]$u.DriverClass
                Version     = [string]$u.DriverVerVersion
                Date        = $dateStr
                Recommended = [bool]$u.AutoSelectOnWebSites
            })
        }
    } catch {
        $Script:WuLastError = ('Windows Update no accesible: ' + $_.Exception.Message)
        Write-DriverLog $Script:WuLastError 'WARN'
    }
    return $out
}

function Install-WindowsUpdateDrivers {
    # Re-busca en WU (los objetos COM no cruzan hilos), selecciona por titulo
    # exacto y descarga+instala. Devuelve conteos y si requiere reinicio.
    param([string[]]$Titles)
    $res = @{ Installed = 0; Failed = 0; Reboot = $false }
    if (-not $Titles -or @($Titles).Count -eq 0) { return $res }
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        try { $searcher.Online = $true } catch {}
        $result = $searcher.Search("IsInstalled=0 and Type='Driver'")
        $coll = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($t in $Titles) {
            $found = $null
            foreach ($u in @($result.Updates)) {
                if ([string]$u.Title -eq $t) { $found = $u; break }
            }
            if ($found) {
                if (-not $found.EulaAccepted) { try { $found.AcceptEula() } catch {} }
                [void]$coll.Add($found)
            } else {
                Write-DriverLog ('WU: ya no disponible: ' + $t) 'WARN'
            }
        }
        if ($coll.Count -gt 0) {
            $dl = $session.CreateUpdateDownloader()
            $dl.Updates = $coll
            $null = $dl.Download()
            $ins = $session.CreateUpdateInstaller()
            $ins.Updates = $coll
            $r = $ins.Install()
            # ResultCode: 2=OK, 3=OK con errores, 4=Error, 5=Abortado
            if ($r.ResultCode -eq 2 -or $r.ResultCode -eq 3) { $res.Installed = $coll.Count }
            else { $res.Failed = $coll.Count }
            if ($r.RebootRequired) { $res.Reboot = $true }
            Write-DriverLog ('WU: instaladas ' + $res.Installed + ' / fallos ' + $res.Failed + ' / reinicio ' + $res.Reboot)
        }
    } catch {
        $res.Failed = @($Titles).Count
        Write-DriverLog ('WU install: ' + $_.Exception.Message) 'ERROR'
    }
    return $res
}

# ─────────────────────── NVIDIA (fuente oficial, dinamica) ───────────────────────
function ConvertTo-IcezPairs {
    # Extrae recursivamente pares {Name, Value} de cualquier JSON de lookup
    # de NVIDIA, sea cual sea la estructura exacta del envoltorio.
    param($Node)
    $pairs = @()
    if ($Node -is [System.Array]) {
        foreach ($i in $Node) { $pairs += @(ConvertTo-IcezPairs $i) }
    } elseif ($Node -is [System.Management.Automation.PSCustomObject]) {
        $names = @($Node.PSObject.Properties | Where-Object { $_.Name -ieq 'name' })
        $vals  = @($Node.PSObject.Properties | Where-Object { $_.Name -ieq 'value' })
        if ($names.Count -ge 1 -and $vals.Count -ge 1) {
            $pairs += @{ Name = [string]$names[0].Value; Value = [string]$vals[0].Value }
        } else {
            foreach ($p in $Node.PSObject.Properties) { $pairs += @(ConvertTo-IcezPairs $p.Value) }
        }
    }
    return $pairs
}

function Get-NvidiaLookupPairs {
    param([string]$Url)
    $pairs = @()
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $json = Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec 30 -UserAgent 'Mozilla/5.0'
        $pairs = @(ConvertTo-IcezPairs $json)
    } catch { Write-DriverLog ('NVIDIA lookup: ' + $_.Exception.Message) 'WARN' }
    return $pairs
}

function Get-NvidiaLatestDriver {
    # Consulta la ultima version para el modelo EXACTO detectado, sin listas
    # hardcodeadas: 1) series de producto (psid) 2) producto exacto (pfid)
    # 3) driver via AjaxDriverService (DCH para Windows 11, osID=135).
    param([string]$GpuName)
    $r = @{ Ok = $false; Version = ''; Url = ''; Note = ''; Series = ''; Product = '' }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $name = ($GpuName -replace '(?i)^nvidia\s+', '').Trim()
        if (-not $name) { $r.Note = 'nombre de GPU vacio'; return $r }

        # 1) Series dinamicas desde la API de nvidia.com
        $series = @(Get-NvidiaLookupPairs -Url ($Script:NvidiaLookupBase + '?TypeID=2&ParentID=1'))
        if ($series.Count -eq 0) { $r.Note = 'sin respuesta de lookupValueSearch'; return $r }

        # 2) Derivar series candidatas desde el nombre (RTX 3060 -> serie "30")
        $modelNum = ''
        if ($name -match '(\d{2,5})') { $modelNum = $Matches[1] }
        $cands = @()
        foreach ($s in $series) {
            $sn = [string]$s.Name
            $sd = ''
            if ($sn -match '(\d+)') { $sd = $Matches[1] }
            if (-not $sd -or -not $modelNum) { continue }
            $letters = ($sn -replace '[\d\(\)].*$', '').Trim()
            if ($letters -and $name -notlike ('*' + $letters + '*')) { continue }
            if ($modelNum.StartsWith($sd) -or $modelNum.StartsWith($sd.Substring(0, 1))) { $cands += $s }
        }

        # 3) Producto exacto (pfid): match exacto > substring > variantes laptop
        $best = $null; $bestScore = 0; $bestSeries = $null
        foreach ($s in $cands) {
            $prods = @(Get-NvidiaLookupPairs -Url ($Script:NvidiaLookupBase + '?TypeID=3&ParentID=' + $s.Value))
            foreach ($prd in $prods) {
                $pn = ([string]$prd.Name).Trim()
                $score = 0
                if ($pn -ieq $name) { $score = 3 }
                elseif ($name -like ('*' + $pn + '*')) { $score = 2 }
                else {
                    $n1 = ($name -replace '(?i)\s*(laptop|notebook)\s*gpu\s*$', '' -replace '(?i)\s*with\s*max-?q.*$', '')
                    $p1 = ($pn -replace '(?i)\s*(laptop|notebook)\s*gpu\s*$', '')
                    if ($p1 -and $n1 -like ('*' + $p1 + '*')) { $score = 1 }
                }
                if ($score -gt $bestScore -or ($score -eq $bestScore -and $score -gt 0 -and $best -and $pn.Length -gt ([string]$best.Name).Length)) {
                    $best = $prd; $bestScore = $score; $bestSeries = $s
                }
            }
        }
        if (-not $best) { $r.Note = 'modelo no encontrado en el catalogo de NVIDIA'; return $r }

        # 4) Driver (DCH primero; reintenta con estandar por si acaso)
        foreach ($dch in @(1, 0)) {
            $api = $Script:NvidiaApiBase + '?func=DriverManualLookup&psid=' + $bestSeries.Value + '&pfid=' + $best.Value + '&osID=135&languageCode=1033&beta=0&isWHQL=1&dltype=-1&dch=' + $dch + '&upCRD=0&qnf=0&sort1=0&numberOfResults=3'
            $json = Invoke-RestMethod -Uri $api -UseBasicParsing -TimeoutSec 30 -UserAgent 'Mozilla/5.0'
            $ids = @()
            foreach ($p in $json.PSObject.Properties) { if ($p.Name -ieq 'IDS') { $ids = @($p.Value) } }
            if ($ids.Count -eq 0) { continue }
            $first = $ids | Select-Object -First 1
            $ver = ''; $url = ''
            foreach ($p in $first.PSObject.Properties) {
                if ($p.Name -ieq 'Version') { $ver = [string]$p.Value }
                if ($p.Name -ieq 'DownloadURL') { $url = [string]$p.Value }
            }
            if ($ver -and $url) {
                if ($url -notmatch '^https?://') { $url = 'https://us.download.nvidia.com' + $url }
                $r.Ok = $true; $r.Version = $ver; $r.Url = $url
                $r.Series = [string]$bestSeries.Name; $r.Product = [string]$best.Name
                return $r
            }
        }
        $r.Note = 'la API no devolvio descargas'
    } catch { $r.Note = $_.Exception.Message }
    return $r
}

function Update-NvidiaDriver {
    param($Gpu)
    Write-DriverLog ('NVIDIA: consultando driver para "' + $Gpu.Name + '"')
    $latest = Get-NvidiaLatestDriver -GpuName $Gpu.Name
    if (-not $latest.Ok) {
        Write-DriverLog ('NVIDIA: no se pudo consultar la API: ' + $latest.Note) 'WARN'
        Start-Process 'https://www.nvidia.com/download/index.aspx'
        return @{ Ok = $false; Note = 'API no accesible; se abrio la pagina oficial de NVIDIA' }
    }
    Write-DriverLog ('NVIDIA: ultima version: ' + $latest.Version + ' (' + $latest.Product + ' / ' + $latest.Series + ')')
    if ($Gpu.FriendlyVersion) {
        $cmp = Compare-DriverVersion $Gpu.FriendlyVersion $latest.Version
        if ($cmp -ge 0) {
            return @{ Ok = $true; Note = 'Ya tienes la ultima version publicada por NVIDIA (' + $latest.Version + ')' }
        }
    }
    # Descarga desde CDN oficial + verificacion de firma + instalacion silenciosa
    $dir = Join-Path $env:TEMP 'icezOP\nvidia'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $file = Join-Path $dir ('nvidia-' + ($latest.Version -replace '[^0-9A-Za-z\.\-]', '_') + '.exe')
    Write-DriverLog ('NVIDIA: descargando ' + $latest.Url)
    Invoke-WebRequest -Uri $latest.Url -OutFile $file -UseBasicParsing
    if (-not (Test-Path -LiteralPath $file)) { return @{ Ok = $false; Note = 'La descarga fallo (no se ejecuta nada)' } }
    if (-not (Test-InstallerSignature -Path $file -Publisher 'NVIDIA')) {
        Remove-Item $file -Force -ErrorAction SilentlyContinue
        Write-DriverLog 'NVIDIA: firma digital invalida, descartado por seguridad' 'ERROR'
        return @{ Ok = $false; Note = 'Firma digital invalida; instalador descartado por seguridad' }
    }
    # Instalacion silenciosa con flags oficiales (puede tardar varios minutos)
    $p = Start-Process -FilePath $file -ArgumentList '-s', '-noreboot', '-noeula' -Wait -PassThru
    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 1) {
        Write-DriverLog ('NVIDIA: instalado ' + $latest.Version + ' (exit ' + $p.ExitCode + ')')
        return @{ Ok = $true; Note = 'Driver NVIDIA ' + $latest.Version + ' instalado (reinicio recomendado)'; Reboot = $true }
    }
    return @{ Ok = $false; Note = 'El instalador devolvio el codigo ' + $p.ExitCode }
}

# ─────────────────────── AMD e Intel (metodo oficial, sin scraping) ───────────────────────
function Update-AmdDriver {
    param($Gpu)
    # ── LIMITACION EXPLICADA ──
    # AMD no publica una API publica y estable para consultar la ultima version
    # de driver de un modelo concreto. Por seguridad NO se hace scraping de
    # amd.com. Metodo oficial mas robusto disponible:
    #   1) Herramienta oficial "AMD Driver Auto-Detect" (autodetecta e instala).
    #   2) Si no se puede descargar/verificar, se abre la pagina oficial.
    Write-DriverLog ('AMD: metodo oficial para "' + $Gpu.Name + '"')
    try {
        $dir = Join-Path $env:TEMP 'icezOP\amd'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $file = Join-Path $dir 'amd-autodetect.exe'
        Invoke-WebRequest -Uri $Script:AmdAutoDetectUrl -OutFile $file -UseBasicParsing
        if ((Test-Path -LiteralPath $file) -and (Test-InstallerSignature -Path $file -Publisher 'Advanced Micro Devices|AMD')) {
            Start-Process -FilePath $file
            return @{ Ok = $true; Note = 'Herramienta oficial AMD en ejecucion (autodetecta e instala)' }
        }
        Remove-Item $file -Force -ErrorAction SilentlyContinue
    } catch { Write-DriverLog ('AMD: ' + $_.Exception.Message) 'WARN' }
    Start-Process 'https://www.amd.com/support'
    return @{ Ok = $false; Note = 'Se abrio la pagina oficial de soporte de AMD' }
}

function Update-IntelDriver {
    param($Gpu)
    # ── LIMITACION EXPLICADA ──
    # Intel tampoco expone API publica de versiones. Metodo oficial:
    # Intel Driver & Support Assistant (DSA), que detecta el hardware Intel
    # e instala/actualiza sus drivers desde servidores oficiales de Intel.
    Write-DriverLog 'Intel: instalando Driver & Support Assistant oficial'
    try {
        $dir = Join-Path $env:TEMP 'icezOP\intel'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $file = Join-Path $dir 'intel-dsa.exe'
        Invoke-WebRequest -Uri $Script:IntelDsaUrl -OutFile $file -UseBasicParsing
        if ((Test-Path -LiteralPath $file) -and (Test-InstallerSignature -Path $file -Publisher 'Intel')) {
            Start-Process -FilePath $file
            return @{ Ok = $true; Note = 'Intel DSA en ejecucion; completa desde su interfaz oficial' }
        }
        Remove-Item $file -Force -ErrorAction SilentlyContinue
    } catch { Write-DriverLog ('Intel: ' + $_.Exception.Message) 'WARN' }
    Start-Process 'https://www.intel.com/content/www/us/en/support/detect.html'
    return @{ Ok = $false; Note = 'Se abrio la pagina oficial de deteccion de Intel' }
}

# ─────────────────────── Componentes de sistema ───────────────────────
function Test-DirectX {
    # Windows 11 ya incluye DirectX 12: NO se reemplaza ni se "actualiza".
    # El DirectX End-User Runtime oficial de Microsoft SOLO agrega componentes
    # legacy (D3DX, XAudio, etc.) para juegos antiguos; no toca el DX del sistema.
    $legacy = (Test-Path (Join-Path $env:windir 'System32\d3dx9_43.dll'))
    $e1 = @{ Key = 'dx-main'; Name = 'DirectX (principal)'; Detail = 'DirectX 12 - integrado en Windows 11 (no se toca)'; Action = ''; Precheck = $false }
    $e2 = @{ Key = 'dx-legacy'; Name = 'DirectX End-User Runtime (legacy)'; Detail = ''; Action = ''; Precheck = $false }
    if ($legacy) { $e2.Detail = 'Componentes legacy presentes' }
    else { $e2.Detail = 'Falta (solo para juegos antiguos). Instalador oficial Microsoft via Winget.'; $e2.Action = 'directx-legacy' }
    return @($e1, $e2)
}

function Test-Vulkan {
    # IMPORTANTE: no existe un "driver Vulkan/OpenGL" independiente que instalar:
    # llegan junto con el driver grafico del fabricante. Solo diagnostico.
    $dll = Join-Path $env:windir 'System32\vulkan-1.dll'
    $e = @{ Key = 'vulkan'; Name = 'Vulkan Runtime'; Detail = ''; Action = ''; Precheck = $false }
    if (Test-Path $dll) {
        $v = (Get-Item $dll).VersionInfo.FileVersion
        $e.Detail = ('Cargador presente v' + $v + ' (instalado por el driver de GPU)')
    } else {
        $e.Detail = 'No detectado. Se instala junto al driver de la GPU (seccion GPU).'
    }
    return $e
}

function Test-DotNet {
    $out = @()
    $rel = $null
    try { $rel = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction Stop).Release } catch {}
    $fx = 'desconocido'
    if ($rel) {
        if ($rel -ge 533320) { $fx = '4.8.1' } elseif ($rel -ge 528040) { $fx = '4.8' }
        elseif ($rel -ge 461808) { $fx = '4.7.2' } else { $fx = ('build ' + $rel) }
    }
    $out += @{ Key = 'netfx'; Name = '.NET Framework'; Detail = ('Version ' + $fx + ' (incluido en Windows; no se elimina)'); Action = ''; Precheck = $false }
    $desktop = ''
    $dn = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dn) {
        try {
            $lines = @(& dotnet --list-runtimes 2>$null)
            $vers = @($lines | Where-Object { $_ -match '^Microsoft\.WindowsDesktop\.App\s+(\d+\.\d+\.\d+)' } | ForEach-Object { $Matches[1] })
            if ($vers.Count -gt 0) {
                $desktop = (($vers | ForEach-Object { [version]$_ } | Sort-Object | Select-Object -Last 1).ToString())
            }
        } catch {}
    }
    if ($desktop) {
        $out += @{ Key = 'netdesk'; Name = '.NET Desktop Runtime'; Detail = ('v' + $desktop + ' instalado'); Action = ''; Precheck = $false }
    } else {
        $out += @{ Key = 'netdesk'; Name = '.NET Desktop Runtime'; Detail = 'No detectado. Instalacion oficial (Microsoft) via Winget.'; Action = 'dotnet-desktop'; Precheck = $true }
    }
    return $out
}

function Test-VisualCpp {
    # Detecta x64 y x86. NO se eliminan versiones antiguas (2015-2022 cubre
    # 2015-2019 por compatibilidad). Instalacion solo desde Microsoft (Winget).
    $found = @{ x64 = $false; x86 = $false }
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($p in $paths) {
        try {
            foreach ($i in @(Get-ItemProperty $p -ErrorAction SilentlyContinue)) {
                if (([string]$i.DisplayName) -match 'Visual C\+\+.*Redistributable') {
                    if ($i.DisplayName -match 'x64') { $found.x64 = $true }
                    elseif ($i.DisplayName -match 'x86') { $found.x86 = $true }
                }
            }
        } catch {}
    }
    $out = @()
    if ($found.x64) { $out += @{ Key = 'vcx64'; Name = 'Visual C++ Redistributable (x64)'; Detail = 'Instalado'; Action = ''; Precheck = $false } }
    else { $out += @{ Key = 'vcx64'; Name = 'Visual C++ Redistributable (x64)'; Detail = 'Falta. Paquete oficial Microsoft via Winget.'; Action = 'vcredist-x64'; Precheck = $true } }
    if ($found.x86) { $out += @{ Key = 'vcx86'; Name = 'Visual C++ Redistributable (x86)'; Detail = 'Instalado'; Action = ''; Precheck = $false } }
    else { $out += @{ Key = 'vcx86'; Name = 'Visual C++ Redistributable (x86)'; Detail = 'Falta. Paquete oficial Microsoft via Winget.'; Action = 'vcredist-x86'; Precheck = $true } }
    return $out
}

function Test-Java {
    # Comprueba java -version de verdad (no asume por carpeta).
    $e = @{ Key = 'java'; Name = 'Java (JRE)'; Detail = ''; Action = ''; Precheck = $false }
    $ver = ''
    try {
        $out = & "$env:windir\System32\cmd.exe" /c "java -version 2>&1"
        if ($LASTEXITCODE -eq 0 -and $out) { $ver = [string](@($out)[0]) }
    } catch {}
    if (-not $ver) {
        foreach ($p in @("$env:ProgramFiles\Java", "$env:ProgramFiles\Eclipse Adoptium", "${env:ProgramFiles(x86)}\Java", "$env:ProgramFiles\Microsoft")) {
            if (Test-Path $p) {
                $sub = Get-ChildItem $p -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'jdk|jre|temurin' } | Select-Object -First 1
                if ($sub) { $ver = 'detectado: ' + $sub.Name; break }
            }
        }
    }
    if ($ver) { $e.Detail = $ver }
    else {
        $e.Detail = 'No detectado. Eclipse Temurin 21 LTS desde su fuente oficial via Winget.'
        $e.Action = 'java-jre'; $e.Precheck = $true
    }
    return $e
}

function Get-RuntimeComponents {
    $all = New-Object System.Collections.ArrayList
    foreach ($t in @(Test-DirectX)) { [void]$all.Add($t) }
    [void]$all.Add((Test-Vulkan))
    foreach ($t in @(Test-DotNet)) { [void]$all.Add($t) }
    foreach ($t in @(Test-VisualCpp)) { [void]$all.Add($t) }
    [void]$all.Add((Test-Java))
    return $all
}

function Install-RuntimeComponent {
    param([string]$Key)
    $id = $Script:CompWingetMap[$Key]
    if (-not $id) { return @{ Ok = $false; Note = 'componente desconocido' } }
    $w = Get-IcezWinget
    if (-not $w) { return @{ Ok = $false; Note = 'Winget no disponible' } }
    Write-DriverLog ('Componente ' + $Key + ': instalando ' + $id + ' (Winget)')
    & $w install --id $id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { return @{ Ok = $true } }
    & $w list --id $id --exact --disable-interactivity 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { return @{ Ok = $true; Already = $true } }
    return @{ Ok = $false; Note = ('Winget devolvio el codigo ' + $LASTEXITCODE) }
}

# ─────────────────────── Resumen ───────────────────────
function Show-DriverSummary {
    param($Stats)
    if (-not $Stats) { return '' }
    return ('Dispositivos: {0} · Al dia (segun Windows Update): {1} · Con actualizacion: {2} · Sin driver: {3} · Con problemas: {4}' -f `
        [int]$Stats.Total, [int]$Stats.Ok, [int]$Stats.Update, [int]$Stats.NoDriver, [int]$Stats.Problem)
}

# ─────────────────────── Orquestadores (runspace) ───────────────────────
function Scan-Drivers {
    # SOLO analiza. No instala nada. Actualiza $sync por fases:
    # scanning -> hw -> wu -> gpu -> done | error
    param($Sync)
    $Sync.DriverPhase = 'scanning'
    $Sync.DriverError = ''
    Write-DriverLog '==================== INICIO DE ESCANEO ===================='
    try {
        $os = [Environment]::OSVersion.Version
        Write-DriverLog ('Entorno: Windows build ' + $os.Build + ' · 64 bits: ' + [Environment]::Is64BitOperatingSystem)

        # 1) Hardware + drivers instalados (local, rapido)
        $hw = Get-HardwareInventory
        $Sync.DrvHardware = $hw
        $gpus = Get-GPUInventory
        $Sync.DrvGpus = $gpus
        $probs = Get-ProblemDevices -Inventory $hw
        Write-DriverLog ('Dispositivos: ' + $hw.Count + ' · GPUs: ' + $gpus.Count + ' · con problemas/sin driver: ' + $probs.Count)
        $Sync.DriverPhase = 'hw'

        # 2) Componentes del sistema (local, rapido)
        $Sync.DrvComponents = Get-RuntimeComponents

        # 3) Windows Update (online)
        $Sync.DrvWuNote = ''
        $wu = Search-WindowsUpdateDrivers
        if ($wu.Count -eq 0 -and $Script:WuLastError) { $Sync.DrvWuNote = $Script:WuLastError }
        $Sync.DrvWu = $wu
        Write-DriverLog ('Windows Update: ' + $wu.Count + ' actualizacion(es) de driver ofrecidas')
        $Sync.DriverPhase = 'wu'

        # 4) Relacionar dispositivos con ofertas de WU
        foreach ($d in $hw) {
            foreach ($u in $wu) {
                $t = [string]$u.Title; $m = [string]$u.Model
                if (($m -and (($d.Name -like ('*' + $m + '*')) -or ($m -like ('*' + $d.Name + '*')))) -or `
                    ($d.Name -and $t -like ('*' + $d.Name + '*'))) {
                    $d.WuMatch = $true; $d.WuTitle = $t
                    break
                }
            }
        }

        # 5) GPUs contra el fabricante (cada GPU individualmente)
        foreach ($g in $gpus) {
            if ($g.Vendor -eq 'NVIDIA') {
                $l = Get-NvidiaLatestDriver -GpuName $g.Name
                if ($l.Ok) {
                    $g.Latest = $l.Version
                    $g.LatestSource = 'NVIDIA (API oficial web)'
                    if ((Compare-DriverVersion $g.FriendlyVersion $l.Version) -ge 0) { $g.State = 'ok' }
                    else { $g.State = 'update' }
                } else { $g.State = 'unknown'; $g.Note = $l.Note }
            } else {
                $g.State = 'unknown'
                $g.Note = 'Sin API publica de consulta de versiones; metodo oficial disponible'
            }
            Write-DriverLog ('GPU: ' + $g.Name + ' · v' + $g.FriendlyVersion + ' · estado: ' + $g.State + ' ' + $g.Latest)
        }
        $Sync.DriverPhase = 'gpu'

        # 6) Estadisticas finales
        $stats = @{ Total = $hw.Count; Problem = 0; NoDriver = 0; Update = 0; Ok = 0 }
        foreach ($d in $hw) {
            if ($d.Problem -ne 0) { $stats.Problem++ }
            elseif (-not $d.HasDriver) { $stats.NoDriver++ }
            elseif ($d.WuMatch) { $stats.Update++ }
            else { $stats.Ok++ }
        }
        $Sync.DrvStats = $stats
        Write-DriverLog (Show-DriverSummary -Stats $stats)
        $Sync.DriverPhase = 'done'
    } catch {
        $Sync.DriverError = $_.Exception.Message
        $Sync.DriverPhase = 'error'
        Write-DriverLog ('ERROR escaneo: ' + $_.Exception.Message) 'ERROR'
    }
}

function Update-Drivers {
    # Ejecuta el plan seleccionado, re-escanea al final y compara before/after.
    param($Sync, $Plan)
    $R = $Sync.DrvRun
    function L([string]$m) { $R.Log.Enqueue($m) }
    Write-DriverLog '==================== INICIO DE ACTUALIZACION ===================='
    $steps = New-Object System.Collections.ArrayList
    if (@($Plan.WuTitles).Count -gt 0) { [void]$steps.Add('WU') }
    foreach ($k in @($Plan.GpuKeys)) { [void]$steps.Add('GPU|' + $k) }
    foreach ($c in @($Plan.Components)) { [void]$steps.Add('COMP|' + $c) }
    $total = $steps.Count
    $i = 0
    foreach ($s in $steps) {
        if ($R.Cancel) { L '  !  Cancelado por el usuario.'; break }
        $i++
        $R.Percent = [math]::Round((($i - 1) / $total) * 100, 1)
        try {
            if ($s -eq 'WU') {
                $R.Status = 'Instalando drivers desde Windows Update...'
                L ('> Windows Update: ' + @($Plan.WuTitles).Count + ' actualizacion(es) seleccionada(s)')
                foreach ($t in @($Plan.WuTitles)) { L ('     · ' + $t) }
                $r = Install-WindowsUpdateDrivers -Titles @($Plan.WuTitles)
                if ($r.Installed -gt 0) { L ('  OK  ' + $r.Installed + ' instalada(s) correctamente'); $R.Ok++ }
                elseif ($r.Failed -gt 0) { L '  X   Fallo la instalacion'; $R.Fail++ }
                if ($r.Reboot) { $R.Reboot = $true; L '  !  Windows requiere reinicio' }
            }
            elseif ($s.StartsWith('GPU|')) {
                $key = $s.Substring(4)
                $parts = $key -split '\|', 2
                $vendor = $parts[0]; $gname = $parts[1]
                $gpu = @($Plan.Before.Gpus | Where-Object { $_.Name -eq $gname }) | Select-Object -First 1
                if (-not $gpu) { $gpu = @{ Name = $gname; FriendlyVersion = ''; Vendor = $vendor } }
                $R.Status = ('GPU ' + $vendor + ': ' + $gname)
                L ('> GPU ' + $vendor + ' · ' + $gname + '  (v' + $gpu.FriendlyVersion + ')')
                $r = $null
                if ($vendor -eq 'NVIDIA') { $r = Update-NvidiaDriver -Gpu $gpu }
                elseif ($vendor -eq 'AMD') { $r = Update-AmdDriver -Gpu $gpu }
                elseif ($vendor -eq 'INTEL') { $r = Update-IntelDriver -Gpu $gpu }
                if ($r) {
                    if ($r.Ok) { L ('  OK  ' + $r.Note); $R.Ok++ } else { L ('  X   ' + $r.Note); $R.Fail++ }
                    if ($r.Reboot) { $R.Reboot = $true }
                }
            }
            elseif ($s.StartsWith('COMP|')) {
                $c = $s.Substring(5)
                $R.Status = ('Componente: ' + $c)
                L ('> Componente: ' + $c)
                $r = Install-RuntimeComponent -Key $c
                if ($r.Ok) {
                    if ($r.Already) { L '  OK  ya estaba instalado' } else { L '  OK  instalado' }
                    $R.Ok++
                } else { L ('  X   ' + $r.Note); $R.Fail++ }
            }
        } catch {
            L ('  X   ' + $_.Exception.Message); $R.Fail++
            Write-DriverLog ('ERROR: ' + $_.Exception.Message) 'ERROR'
        }
    }

    # Verificacion final: re-escaneo y comparacion before/after
    if (-not $R.Cancel) {
        $R.Status = 'Verificando cambios (re-escaneo)...'
        $R.Percent = 97
        L ''
        L '> Re-escaneando hardware para verificar...'
        try {
            $after = Get-HardwareInventory
            $afterGpus = Get-GPUInventory
            $n = 0
            foreach ($a in $after) {
                $b = @($Plan.Before.Hardware | Where-Object { $_.InstanceId -eq $a.InstanceId }) | Select-Object -First 1
                if ($b -and $a.DriverVersion -and ($b.DriverVersion -ne $a.DriverVersion)) {
                    $n++
                    $line = ('  ~  ' + $a.Name + ' : v' + $b.DriverVersion + '  ->  v' + $a.DriverVersion)
                    L $line
                    [void]$R.Changes.Add(@{ Name = $a.Name; Before = $b.DriverVersion; After = $a.DriverVersion })
                    Write-DriverLog $line
                }
            }
            foreach ($ag in $afterGpus) {
                $bg = @($Plan.Before.Gpus | Where-Object { $_.Name -eq $ag.Name }) | Select-Object -First 1
                if ($bg -and $bg.FriendlyVersion -and $ag.FriendlyVersion -and ($bg.FriendlyVersion -ne $ag.FriendlyVersion)) {
                    $n++
                    $line = ('  ~  ' + $ag.Name + ' : v' + $bg.FriendlyVersion + '  ->  v' + $ag.FriendlyVersion)
                    L $line
                    [void]$R.Changes.Add(@{ Name = $ag.Name; Before = $bg.FriendlyVersion; After = $ag.FriendlyVersion })
                    Write-DriverLog $line
                }
            }
            L ('Dispositivos tras el re-escaneo: ' + $after.Count + ' · cambios de driver detectados: ' + $n)
        } catch { L ('  !  No se pudo completar la verificacion: ' + $_.Exception.Message) }
    }

    $R.Percent = 100
    $R.Status = 'Completado'
    $R.Summary = ('Tareas OK: {0} · Errores: {1} · Drivers cambiados: {2} · Reinicio requerido: {3}' -f `
        [int]$R.Ok, [int]$R.Fail, @($R.Changes).Count, $(if ($R.Reboot) { 'SI' } else { 'NO' }))
    $R.Done = $true
    Write-DriverLog ('RESUMEN: ' + $R.Summary)
    Write-DriverLog '==================== FIN DE ACTUALIZACION ===================='
}

# ═══════════════════ UI (se ejecuta en el hilo principal) ═══════════════════
# v0.3.1 — FIX IMPORTANTE: ningun event handler usa GetNewClosure().
# GetNewClosure() encierra el scriptblock en un modulo propio donde las
# referencias $Script:..., $sync y las funciones NO existen (se vuelven $null
# y producen "La propiedad 'X' no se encuentra en este objeto").
# Donde hace falta un dato por-item (titulo, clave GPU, componente) se guarda
# en $control.Tag y el handler generico lo lee desde ahi.

function Initialize-DriverPage {
    param($Page)

    # Estado de la UI + canal de datos
    $Script:DrvUI = @{ SelWu = @{}; SelGpu = @{}; SelComp = @{}; LastPhase = '' }
    $Script:DrvRunPs = $null
    $Script:DrvRunRs = $null
    $Script:DrvRunUI = $null
    $Script:DrvRunTimer = $null
    $Script:DrvRunModalF = $null
    $sync.DriverPhase = 'idle'
    $sync.DriverError = ''
    $sync.DrvWuNote = ''
    $sync.DrvHardware = @()
    $sync.DrvGpus = @()
    $sync.DrvWu = @()
    $sync.DrvComponents = @()
    $sync.DrvStats = $null

    # Handler generico para TODOS los checkboxes de seleccion (lee el Tag)
    $Script:DrvSelHandler = {
        param($s, $e)
        if (-not $Script:DrvUI) { return }
        $tag = [string]$s.Tag
        if (-not $tag) { return }
        $parts = $tag -split '\|', 2
        if ($parts.Count -lt 2) { return }
        $k = $parts[1]
        if ($tag.StartsWith('wu|'))       { $Script:DrvUI.SelWu[$k] = $s.Checked }
        elseif ($tag.StartsWith('gpu|'))  { $Script:DrvUI.SelGpu[$k] = $s.Checked }
        elseif ($tag.StartsWith('comp|')) { $Script:DrvUI.SelComp[$k] = $s.Checked }
        Update-DriverUpdateBtn
    }

    $Page.AutoScroll = $true
    $Page.Controls.Add((New-Label 'Controladores' 24 16 420 34 15 'Text' -Bold))
    $Page.Controls.Add((New-Label 'Analisis dinamico del hardware de ESTA PC. Drivers generales via Windows Update; GPU via fabricante. Sin listas manuales.' 24 48 880 22 9.5 'Sub'))

    $scanCard = New-Card 24 80 892 84
    $scanCard.Controls.Add((New-Label 'Escaneo (solo analiza, no instala nada)' 20 12 460 22 10.5 'Text' -Bold))
    $Script:DrvStatusLbl = New-Label 'Pulsa ESCANEAR para analizar los controladores de este equipo.' 20 40 580 20 9 'Sub'
    $scanCard.Controls.Add($Script:DrvStatusLbl)

    $btnLog = New-Object IcezOP.GhostButton
    $btnLog.Location = Pt 616 26
    $btnLog.Size = Sz 64 32
    $btnLog.Text = 'LOG'
    $btnLog.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)
    $btnLog.Add_Click({
        try {
            if (Test-Path -LiteralPath $Script:DriverLogFile) { Start-Process notepad.exe -ArgumentList ('"{0}"' -f $Script:DriverLogFile) }
            else { Start-Process explorer.exe -ArgumentList $Script:DriverLogDir }
        } catch {}
    })
    $scanCard.Controls.Add($btnLog)

    $btnScan = New-Object IcezOP.GradientButton
    $btnScan.Location = Pt 692 22
    $btnScan.Size = Sz 176 40
    $btnScan.Text = 'ESCANEAR'
    $btnScan.Glyph = (icezG 'Drv')
    $btnScan.GlyphFont = $Script:GlyphFont
    $btnScan.Add_Click({
        if ($Script:DrvPs -and $Script:DrvPs.InvocationStateInfo.State -eq 'Running') { return }
        if (-not $Script:DrvUI) { $Script:DrvUI = @{ SelWu = @{}; SelGpu = @{}; SelComp = @{}; LastPhase = '' } }
        $Script:DrvUI.LastPhase = ''
        $Script:DrvUI.SelWu = @{}
        $Script:DrvUI.SelGpu = @{}
        $Script:DrvUI.SelComp = @{}
        if ($Script:DrvStatusLbl) { $Script:DrvStatusLbl.Text = 'Detectando hardware...' }
        $sync.DriverPhase = 'scanning'
        try { if ($Script:DrvPs) { $Script:DrvPs.Dispose(); $Script:DrvRs.Dispose() } } catch {}
        $Script:DrvRs = [runspacefactory]::CreateRunspace()
        $Script:DrvRs.ApartmentState = 'STA'
        $Script:DrvRs.ThreadOptions = 'ReuseThread'
        $Script:DrvRs.Open()
        $Script:DrvPs = [powershell]::Create()
        $Script:DrvPs.Runspace = $Script:DrvRs
        [void]$Script:DrvPs.AddScript('. $args[0]; Scan-Drivers -Sync $args[1]')
        [void]$Script:DrvPs.AddArgument($Script:EnginePath)
        [void]$Script:DrvPs.AddArgument($sync)
        $null = $Script:DrvPs.BeginInvoke()
    })
    $scanCard.Controls.Add($btnScan)
    $Page.Controls.Add($scanCard)

    $Script:DrvSummaryLbl = New-Label '' 24 172 880 20 9 'Sub'
    $Page.Controls.Add($Script:DrvSummaryLbl)

    $Script:DrvDyn = New-Object System.Windows.Forms.Panel
    $Script:DrvDyn.Location = Pt 0 198
    $Script:DrvDyn.Size = Sz 940 400
    $Script:DrvDyn.BackColor = (icezCol 'Bg')
    $Page.Controls.Add($Script:DrvDyn)

    $Script:DrvUpdBtn = New-Object IcezOP.GradientButton
    $Script:DrvUpdBtn.Size = Sz 300 42
    $Script:DrvUpdBtn.Text = 'ACTUALIZAR SELECCIONADOS'
    $Script:DrvUpdBtn.Visible = $false
    $Script:DrvUpdBtn.Add_Click({ Invoke-DriverUpdateFromUI })
}

function Update-DriverUpdateBtn {
    if (-not $Script:DrvUpdBtn) { return }
    $sel = $Script:DrvUI
    if ($null -eq $sel) { return }
    $n = @($sel.SelWu.Keys | Where-Object { $sel.SelWu[$_] }).Count +
         @($sel.SelGpu.Keys | Where-Object { $sel.SelGpu[$_] }).Count +
         @($sel.SelComp.Keys | Where-Object { $sel.SelComp[$_] }).Count
    if ($n -gt 0) {
        $Script:DrvUpdBtn.Visible = $true
        $Script:DrvUpdBtn.Text = ('ACTUALIZAR SELECCIONADOS ({0})' -f $n)
    } else {
        $Script:DrvUpdBtn.Visible = $false
    }
}

function Render-DriverResults {
    $dyn = $Script:DrvDyn
    if ($null -eq $dyn) { return }
    if (-not $Script:DrvUI) { $Script:DrvUI = @{ SelWu = @{}; SelGpu = @{}; SelComp = @{}; LastPhase = '' } }
    $dyn.SuspendLayout()
    $dyn.Controls.Clear()

    $gpus = @($sync.DrvGpus)
    $wu = @($sync.DrvWu)
    $hw = @($sync.DrvHardware)
    $comps = @($sync.DrvComponents)
    $wuFailed = [bool]([string]$sync.DrvWuNote)
    $y = 6

    # ── GPUs ──
    $dyn.Controls.Add((New-Label 'GPU detectadas' 24 $y 500 24 11 'Text' -Bold))
    $y += 30
    if ($gpus.Count -eq 0) {
        $dyn.Controls.Add((New-Label 'Ninguna GPU detectada.' 24 $y 600 20 9 'Sub'))
        $y += 26
    }
    foreach ($g in $gpus) {
        $c = New-Card 24 $y 892 86
        $c.Controls.Add((New-Label ([string]$g.Name) 20 10 620 22 10.5 'Text' -Bold))
        $c.Controls.Add((New-Label ('v' + $g.FriendlyVersion + '  ·  ' + $g.Vendor + '  ·  ' + $g.Date) 20 34 620 18 8.5 'Sub'))
        $statusText = ''
        $statusCol = 'Sub'
        switch ([string]$g.State) {
            'checking' { $statusText = 'Consultando fabricante...' }
            'ok'       { $statusText = ('Al dia segun NVIDIA (ultima publicada: v' + $g.Latest + ')'); $statusCol = 'Ok' }
            'update'   { $statusText = ('UPDATE DISPONIBLE: v' + $g.Latest + '  ·  Fuente: NVIDIA (descarga oficial, firma verificada)'); $statusCol = 'Acc'; $c.BorderColor = (icezCol 'Acc') }
            default    { $statusText = ('UNKNOWN - no se pudo determinar automaticamente. ' + $g.Note); $statusCol = 'Warn' }
        }
        $c.Controls.Add((New-Label $statusText 20 58 630 18 8.5 $statusCol))
        $key = ''
        $cbText = ''
        if ($g.Vendor -eq 'NVIDIA' -and $g.State -eq 'update') { $key = 'NVIDIA|' + $g.Name; $cbText = 'Actualizar via NVIDIA' }
        elseif ($g.Vendor -eq 'AMD')   { $key = 'AMD|' + $g.Name;   $cbText = 'Herramienta oficial AMD' }
        elseif ($g.Vendor -eq 'Intel') { $key = 'INTEL|' + $g.Name; $cbText = 'Intel DSA (oficial)' }
        if ($key -and $Script:DrvSelHandler) {
            $cb = New-Object IcezOP.IcezCheckBox
            $cb.Location = Pt 650 30
            $cb.Size = Sz 230 26
            $cb.Text = $cbText
            $cb.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
            $cb.Tag = ('gpu|' + $key)
            $map = $Script:DrvUI.SelGpu
            $kk = [string]$key
            if ($map.ContainsKey($kk)) { $cb.Checked = [bool]$map[$kk] } else { $map[$kk] = $false }
            $cb.Add_CheckedChanged($Script:DrvSelHandler)
            $c.Controls.Add($cb)
        }
        $dyn.Controls.Add($c)
        $y += 94
    }

    # ── Windows Update ──
    $dyn.Controls.Add((New-Label ('Windows Update · {0} actualizacion(es) de drivers' -f $wu.Count) 24 $y 600 24 11 'Text' -Bold))
    $y += 26
    if ($wuFailed) {
        $dyn.Controls.Add((New-Label ([string]$sync.DrvWuNote) 24 $y 860 18 8.5 'Warn'))
        $y += 22
    }
    if ($wu.Count -eq 0) {
        $note = 'Windows Update no ofrecio drivers nuevos. Los drivers instalados estan al dia SEGUN WINDOWS UPDATE (el fabricante puede tener versiones mas nuevas).'
        if ($wuFailed) { $note = 'No se pudo consultar Windows Update.' }
        $dyn.Controls.Add((New-Label $note 24 $y 860 32 8.5 'Sub'))
        $y += 36
    } else {
        foreach ($u in $wu) {
            $c = New-Card 24 $y 892 48
            $cb = New-Object IcezOP.IcezCheckBox
            $cb.Location = Pt 12 3
            $cb.Size = Sz 700 26
            $cb.Font = New-Object System.Drawing.Font('Segoe UI', 9)
            $cb.Text = [string]$u.Title
            $cb.Tag = ('wu|' + [string]$u.Title)
            $map = $Script:DrvUI.SelWu
            $kk = [string]$u.Title
            $pre = [bool]$u.Recommended
            if ($map.ContainsKey($kk)) { $cb.Checked = [bool]$map[$kk] }
            else { $map[$kk] = $pre; if ($pre) { $cb.Checked = $true } }
            $cb.Add_CheckedChanged($Script:DrvSelHandler)
            $c.Controls.Add($cb)
            $sub = ''
            if ($u.Version) { $sub += ('v' + $u.Version) }
            if ($u.Class) { $sub += (' · ' + $u.Class) }
            if ($u.Date) { $sub += (' · ' + $u.Date) }
            $sub += ' · Fuente: Windows Update'
            $c.Controls.Add((New-Label $sub 40 27 820 16 8 'Sub'))
            $dyn.Controls.Add($c)
            $y += 54
        }
    }

    # ── Componentes del sistema ──
    $dyn.Controls.Add((New-Label 'Componentes del sistema' 24 $y 500 24 11 'Text' -Bold))
    $y += 26
    foreach ($cp in $comps) {
        $dyn.Controls.Add((New-Label ([string]$cp.Name) 24 $y 250 20 9 'Text'))
        $dyn.Controls.Add((New-Label ([string]$cp.Detail) 280 $y 490 20 8.5 'Sub'))
        if ($cp.Action -and $Script:DrvSelHandler) {
            $cb = New-Object IcezOP.IcezCheckBox
            $cb.Location = Pt 786 $y
            $cb.Size = Sz 130 22
            $cb.Text = 'Instalar'
            $cb.Font = New-Object System.Drawing.Font('Segoe UI', 8.5)
            $cb.Tag = ('comp|' + [string]$cp.Action)
            $map = $Script:DrvUI.SelComp
            $kk = [string]$cp.Action
            $pre = [bool]$cp.Precheck
            if ($map.ContainsKey($kk)) { $cb.Checked = [bool]$map[$kk] }
            else { $map[$kk] = $pre; if ($pre) { $cb.Checked = $true } }
            $cb.Add_CheckedChanged($Script:DrvSelHandler)
            $dyn.Controls.Add($cb)
        }
        $y += 28
    }

    # ── Dispositivos (completo; al dia = tenue abajo) ──
    $dyn.Controls.Add((New-Label ('Dispositivos detectados ({0})' -f $hw.Count) 24 $y 500 24 11 'Text' -Bold))
    $y += 24
    $dyn.Controls.Add((New-Label 'Leyenda: [OK] al dia segun Windows Update · [UPDATE] hay version mas nueva · [NO DRIVER] sin driver · [ERROR] dispositivo con problema · [UNKNOWN] no se pudo determinar' 24 $y 880 18 8 'Dim'))
    $y += 22
    $shown = 0
    foreach ($d in $hw) {
        if ($shown -ge 200) {
            $dyn.Controls.Add((New-Label ('... y ' + ($hw.Count - $shown) + ' dispositivos mas') 24 $y 600 18 8 'Sub'))
            $y += 22
            break
        }
        $tag = 'OK'; $col = 'Dim'
        if ($d.Problem -ne 0) { $tag = 'ERROR'; $col = 'Err' }
        elseif (-not $d.HasDriver) { $tag = 'NO DRIVER'; $col = 'Err' }
        elseif ($d.WuMatch) { $tag = 'UPDATE'; $col = 'Acc' }
        elseif (([string]$d.Class) -ieq 'DISPLAY') { $tag = 'GPU'; $col = 'Sub' }
        elseif ($wuFailed) { $tag = 'UNKNOWN'; $col = 'Sub' }
        $dyn.Controls.Add((New-Label ('[' + $tag + ']  ' + $d.Name) 24 $y 620 20 8.5 $col))
        $verTxt = 'N/A'
        if ($d.DriverVersion) { $verTxt = ('v' + $d.DriverVersion) }
        elseif ($d.Vendor) { $verTxt = $d.Vendor }
        $dyn.Controls.Add((New-Label $verTxt 660 ($y + 1) 250 18 8 'Dim2'))
        $y += 24
        $shown++
    }

    # ── Boton de actualizacion al final ──
    $y += 10
    $Script:DrvUpdBtn.Location = Pt 24 $y
    $dyn.Controls.Add($Script:DrvUpdBtn)
    $y += 54
    $dyn.Size = Sz 940 $y
    $dyn.ResumeLayout()

    if ($sync.DrvStats) { $Script:DrvSummaryLbl.Text = (Show-DriverSummary -Stats $sync.DrvStats) }
    Update-DriverUpdateBtn
}

function Update-DriverUITick {
    if ($null -eq $Script:DrvUI) { return }
    if ($null -eq $Script:DrvStatusLbl) { return }
    $ph = [string]$sync.DriverPhase
    if ($ph -eq 'idle' -or $ph -eq $Script:DrvUI.LastPhase) { return }
    switch ($ph) {
        'scanning' { $Script:DrvStatusLbl.Text = 'Detectando hardware...' }
        'hw'       { $Script:DrvStatusLbl.Text = 'Consultando Windows Update (puede tardar)...'; Render-DriverResults }
        'wu'       { $Script:DrvStatusLbl.Text = 'Consultando fabricantes de GPU...'; Render-DriverResults }
        'gpu'      { $Script:DrvStatusLbl.Text = 'Generando resumen...'; Render-DriverResults }
        'done'     { $Script:DrvStatusLbl.Text = 'Escaneo completado. Revisa las secciones de abajo.'; Render-DriverResults }
        'error'    { $Script:DrvStatusLbl.Text = ('Error: ' + [string]$sync.DriverError) }
    }
    $Script:DrvUI.LastPhase = $ph
}

function Invoke-DriverUpdateFromUI {
    if (-not $Script:DrvUI) { return }
    $sel = $Script:DrvUI
    $wuT = @($sel.SelWu.Keys | Where-Object { $sel.SelWu[$_] })
    $gpuA = @($sel.SelGpu.Keys | Where-Object { $sel.SelGpu[$_] })
    $comp = @($sel.SelComp.Keys | Where-Object { $sel.SelComp[$_] })
    if (($wuT.Count + $gpuA.Count + $comp.Count) -eq 0) { return }
    $plan = @{
        WuTitles   = $wuT
        GpuKeys    = $gpuA
        Components = $comp
        Before     = @{ Hardware = @($sync.DrvHardware); Gpus = @($sync.DrvGpus) }
    }
    Start-DriverRunModal -Plan $plan
}

function Start-DriverRunModal {
    param($Plan)

    $sync.DrvRun = @{
        Log     = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
        Percent = 0
        Status  = 'Preparando...'
        Done    = $false
        Cancel  = $false
        Ok      = 0
        Fail    = 0
        Reboot  = $false
        Changes = (New-Object System.Collections.ArrayList)
        Summary = ''
    }

    $ov = Show-IcezOverlay
    $mw = 700; $mh = 540
    $modal = New-Object System.Windows.Forms.Form
    $modal.FormBorderStyle = 'None'
    $modal.ShowInTaskbar = $false
    $modal.StartPosition = 'Manual'
    $modal.Size = Sz $mw $mh
    $modal.Location = Pt ([int]($Script:Form.Left + ($Script:Form.Width - $mw) / 2)) ([int]($Script:Form.Top + ($Script:Form.Height - $mh) / 2))
    $modal.BackColor = (icezCol 'Bg')
    Set-FormRounded $modal 18

    $modal.Controls.Add((New-Label 'Actualizando controladores' 28 20 520 30 13.5 'Text' -Bold))
    $statusLbl = New-Label 'Preparando...' 28 62 620 22 9.75 'Sub'
    $modal.Controls.Add($statusLbl)
    $prog = New-Object IcezOP.IcezProgressBar
    $prog.Location = Pt 28 94
    $prog.Size = Sz 644 10
    $modal.Controls.Add($prog)
    $logBox = New-Object System.Windows.Forms.ListBox
    $logBox.Location = Pt 28 120
    $logBox.Size = Sz 644 296
    $logBox.BorderStyle = 'None'
    $logBox.BackColor = (icezCol 'LogBg')
    $logBox.ForeColor = (icezCol 'LogFg')
    $logBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $logBox.IntegralHeight = $false
    $logBox.HorizontalScrollbar = $true
    $modal.Controls.Add($logBox)

    $cancelBtn = New-Object IcezOP.GhostButton
    $cancelBtn.Location = Pt 28 436
    $cancelBtn.Size = Sz 160 42
    $cancelBtn.Text = 'CANCELAR'
    $cancelBtn.ForeColor = (icezCol 'Err')
    $cancelBtn.Add_Click({
        $sync.DrvRun.Cancel = $true
        if ($Script:DrvRunUI) {
            $Script:DrvRunUI.Cancel.Enabled = $false
            $Script:DrvRunUI.Cancel.Text = 'CANCELANDO...'
        }
    })
    $modal.Controls.Add($cancelBtn)

    $summaryLbl = New-Label '' 28 56 644 60 10.5 'Text' -Bold
    $summaryLbl.Visible = $false
    $modal.Controls.Add($summaryLbl)

    $rebootBtn = New-Object IcezOP.GradientButton
    $rebootBtn.Location = Pt 370 436
    $rebootBtn.Size = Sz 200 42
    $rebootBtn.Text = 'REINICIAR AHORA'
    $rebootBtn.Visible = $false
    $rebootBtn.Add_Click({
        Start-Process 'shutdown.exe' -ArgumentList @('/r', '/t', '5', '/c', 'icezOP - drivers')
        $Script:Form.Close()
    })
    $modal.Controls.Add($rebootBtn)

    $finishBtn = New-Object IcezOP.GhostButton
    $finishBtn.Location = Pt 582 436
    $finishBtn.Size = Sz 90 42
    $finishBtn.Text = 'FINALIZAR'
    $finishBtn.Visible = $false
    $finishBtn.Add_Click({ if ($Script:DrvRunModalF) { $Script:DrvRunModalF.Close() } })
    $modal.Controls.Add($finishBtn)

    # Referencias en scope de SCRIPT para que los handlers (sin closures)
    # puedan alcanzar los controles despues de que la funcion retorne:
    $Script:DrvRunUI = @{ LogBox = $logBox; StatusLbl = $statusLbl; Prog = $prog; Summary = $summaryLbl; Reboot = $rebootBtn; Finish = $finishBtn; Cancel = $cancelBtn; Shown = $false }
    $Script:DrvRunModalF = $modal

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 120
    $timer.Add_Tick({
        $R = $sync.DrvRun
        $ui = $Script:DrvRunUI
        if ($null -eq $R -or $null -eq $ui) { return }
        while ($R.Log.Count -gt 0) { [void]$ui.LogBox.Items.Add([string]$R.Log.Dequeue()) }
        if ($ui.LogBox.Items.Count -gt 0) { $ui.LogBox.TopIndex = $ui.LogBox.Items.Count - 1 }
        $ui.StatusLbl.Text = [string]$R.Status
        $ui.Prog.Percent = [double]$R.Percent
        if ($R.Done -and -not $ui.Shown) {
            $ui.Shown = $true
            $this.Stop()
            $ui.StatusLbl.Visible = $false
            $ui.Prog.Visible = $false
            $ui.Cancel.Visible = $false
            $txt = [string]$R.Summary
            if (@($R.Changes).Count -gt 0) {
                $txt += "`r`nDrivers actualizados:"
                foreach ($ch in @($R.Changes)) { $txt += ("`r`n  · " + $ch.Name + ' : v' + $ch.Before + '  ->  v' + $ch.After) }
            }
            $ui.Summary.Text = $txt
            $ui.Summary.Visible = $true
            if ($R.Reboot) { $ui.Reboot.Visible = $true }
            $ui.Finish.Visible = $true
        }
    })
    $Script:DrvRunTimer = $timer

    $modal.Add_FormClosed({
        if ($Script:DrvRunTimer) { $Script:DrvRunTimer.Stop(); $Script:DrvRunTimer.Dispose(); $Script:DrvRunTimer = $null }
        try { if ($Script:DrvRunPs) { $Script:DrvRunPs.Dispose() } } catch {}
        try { if ($Script:DrvRunRs) { $Script:DrvRunRs.Dispose() } } catch {}
    })

    # Worker en runspace (el motor se dot-sourcing dentro del runspace)
    try { if ($Script:DrvRunPs) { $Script:DrvRunPs.Dispose(); $Script:DrvRunRs.Dispose() } } catch {}
    $Script:DrvRunRs = [runspacefactory]::CreateRunspace()
    $Script:DrvRunRs.ApartmentState = 'STA'
    $Script:DrvRunRs.ThreadOptions = 'ReuseThread'
    $Script:DrvRunRs.Open()
    $Script:DrvRunPs = [powershell]::Create()
    $Script:DrvRunPs.Runspace = $Script:DrvRunRs
    [void]$Script:DrvRunPs.AddScript('. $args[0]; Update-Drivers -Sync $args[1] -Plan $args[2]')
    [void]$Script:DrvRunPs.AddArgument($Script:EnginePath)
    [void]$Script:DrvRunPs.AddArgument($sync)
    [void]$Script:DrvRunPs.AddArgument($Plan)
    $null = $Script:DrvRunPs.BeginInvoke()

    $timer.Start()
    [void]$modal.ShowDialog($ov)
    $ov.Close()
    $ov.Dispose()
    if ($Script:DrvStatusLbl) { $Script:DrvStatusLbl.Text = 'Actualizacion finalizada. Vuelve a ESCANEAR para refrescar el estado.' }
}
