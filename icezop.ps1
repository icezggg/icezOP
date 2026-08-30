[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- MOTOR ASÍNCRONO, LOGS Y PROGRESO ---
 $sync = [Hashtable]::Synchronized(@{ 
    LogQueue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())
    IsRunning = $false 
    MaxProgress = 0
    CurrentProgress = 0
})
 $UITimer = New-Object System.Windows.Forms.Timer
 $UITimer.Interval = 150

 $UITimer.Add_Tick({
    while ($script:sync.LogQueue.Count -gt 0) {
        $msg = $script:sync.LogQueue.Dequeue()
        $script:LogBox.SelectionStart = $script:LogBox.TextLength
        $script:LogBox.SelectionLength = 0
        $script:LogBox.SelectionColor = $msg.Color
        $script:LogBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] $($msg.Text)`r`n")
        $script:LogBox.ScrollToCaret()
    }
    
    if ($script:sync.MaxProgress -gt 0) {
        $script:ProgressBar.Maximum = $script:sync.MaxProgress
        if ($script:sync.CurrentProgress -gt $script:ProgressBar.Maximum) { $script:sync.CurrentProgress = $script:ProgressBar.Maximum }
        $script:ProgressBar.Value = $script:sync.CurrentProgress
        $script:LblStatus.Text = "ESTADO: $($script:sync.CurrentProgress) / $($script:sync.MaxProgress)"
    }
    
    if (-not $script:sync.IsRunning -and $script:btnExecute.Text -ne "EJECUTAR") {
        $script:btnExecute.Text = "EJECUTAR"
        $script:btnExecute.Enabled = $true
        $script:btnExecute.BackColor = $script:C_Accent
        $script:sync.MaxProgress = 0
        $script:sync.CurrentProgress = 0
        $script:ProgressBar.Value = 0
        $script:LblStatus.Text = "ESTADO: LISTO"
        $script:LblStatus.ForeColor = $script:C_Accent
    }
})

function Write-Log($texto, $color = "White") {
    $sync.LogQueue.Enqueue(@{ Text = $texto; Color = $color })
}

# --- CARGA DE JSON (DUAL: GITHUB O LOCAL) ---
 $RepoURL = "https://raw.githubusercontent.com/icezggg/icezOP/main"
try {
    Write-Host "Intentando descargar catálogos desde GitHub..."
    $AppCatalog = Invoke-RestMethod -Uri "$RepoURL/apps.json" -ErrorAction Stop
    $TweakCatalog = Invoke-RestMethod -Uri "$RepoURL/tweaks.json" -ErrorAction Stop
    $DataSource = "GitHub (Online)"
} catch {
    Write-Host "Falló GitHub. Intentando cargar archivos locales..."
    $localApps = "$PSScriptRoot\apps.json"
    $localTweaks = "$PSScriptRoot\tweaks.json"
    if (Test-Path $localApps -and Test-Path $localTweaks) {
        $AppCatalog = Get-Content -Path $localApps -Raw | ConvertFrom-Json
        $TweakCatalog = Get-Content -Path $localTweaks -Raw | ConvertFrom-Json
        $DataSource = "Archivos Locales"
    } else {
        [System.Windows.Forms.MessageBox]::Show("No se pudieron descargar los catálogos desde GitHub ni encontrarlos localmente.", "Error Fatal", 0, 16)
        Exit
    }
}

# --- TEMA ICEZOP PRO ---
 $C_Background = [System.Drawing.Color]::FromArgb(12, 12, 16)
 $C_Sidebar = [System.Drawing.Color]::FromArgb(18, 18, 26)
 $C_Card = [System.Drawing.Color]::FromArgb(25, 25, 35)
 $C_CardBorder = [System.Drawing.Color]::FromArgb(35, 35, 45)
 $C_Accent = [System.Drawing.Color]::FromArgb(168, 85, 247)
 $C_AccentDark = [System.Drawing.Color]::FromArgb(100, 50, 150)
 $C_Text = [System.Drawing.Color]::FromArgb(230, 230, 240)
 $C_TextSec = [System.Drawing.Color]::FromArgb(150, 150, 160)
 $C_LogBg = [System.Drawing.Color]::FromArgb(8, 8, 12)

# --- DISEÑO UI/UX ---
 $Form = New-Object System.Windows.Forms.Form
 $Form.Text = "icezOP - Windows Modular Toolkit"
 $Form.Size = New-Object System.Drawing.Size(1100, 750)
 $Form.StartPosition = "CenterScreen"
 $Form.BackColor = $C_Background
 $Form.FormBorderStyle = "FixedSingle"
 $Form.MaximizeBox = $false

 $RootLayout = New-Object System.Windows.Forms.TableLayoutPanel
 $RootLayout.Dock = "Fill"
 $RootLayout.ColumnCount = 2
 $RootLayout.RowCount = 1
 $RootLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 220))) | Out-Null
 $RootLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
 $RootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
 $Form.Controls.Add($RootLayout)

# 1. SIDEBAR
 $Sidebar = New-Object System.Windows.Forms.Panel
 $Sidebar.Dock = "Fill"
 $Sidebar.BackColor = $C_Sidebar
 $RootLayout.Controls.Add($Sidebar, 0, 0)

 $LblLogo = New-Object System.Windows.Forms.Label
 $LblLogo.Text = "icezOP"
 $LblLogo.Font = New-Object System.Drawing.Font("Segoe UI", 26, [System.Drawing.FontStyle]::Bold)
 $LblLogo.ForeColor = $C_Accent
 $LblLogo.Location = New-Object System.Drawing.Point(20, 20)
 $LblLogo.AutoSize = $true
 $Sidebar.Controls.Add($LblLogo)

 $LblSubLogo = New-Object System.Windows.Forms.Label
 $LblSubLogo.Text = "TOOLKIT PRO"
 $LblSubLogo.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
 $LblSubLogo.ForeColor = $C_TextSec
 $LblSubLogo.Location = New-Object System.Drawing.Point(22, 58)
 $LblSubLogo.AutoSize = $true
 $Sidebar.Controls.Add($LblSubLogo)

 $SepLine = New-Object System.Windows.Forms.Panel
 $SepLine.Location = New-Object System.Drawing.Point(20, 85)
 $SepLine.Size = New-Object System.Drawing.Size(180, 1)
 $SepLine.BackColor = $C_CardBorder
 $Sidebar.Controls.Add($SepLine)

 $btnModApps = New-Object System.Windows.Forms.Button
 $btnModApps.Text = "   Aplicaciones"
 $btnModApps.Location = New-Object System.Drawing.Point(20, 105)
 $btnModApps.Size = New-Object System.Drawing.Size(180, 45)
 $btnModApps.FlatStyle = "Flat"
 $btnModApps.FlatAppearance.BorderSize = 0
 $btnModApps.BackColor = $C_Sidebar
 $btnModApps.ForeColor = $C_Text
 $btnModApps.Font = New-Object System.Drawing.Font("Segoe UI", 10)
 $btnModApps.TextAlign = "MiddleLeft"
 $btnModApps.Cursor = "Hand"
 $Sidebar.Controls.Add($btnModApps)

 $btnModTweaks = New-Object System.Windows.Forms.Button
 $btnModTweaks.Text = "   Optimizaciones"
 $btnModTweaks.Location = New-Object System.Drawing.Point(20, 160)
 $btnModTweaks.Size = New-Object System.Drawing.Size(180, 45)
 $btnModTweaks.FlatStyle = "Flat"
 $btnModTweaks.FlatAppearance.BorderSize = 0
 $btnModTweaks.BackColor = $C_Sidebar
 $btnModTweaks.ForeColor = $C_Text
 $btnModTweaks.Font = New-Object System.Drawing.Font("Segoe UI", 10)
 $btnModTweaks.TextAlign = "MiddleLeft"
 $btnModTweaks.Cursor = "Hand"
 $Sidebar.Controls.Add($btnModTweaks)

 $LblStatus = New-Object System.Windows.Forms.Label
 $LblStatus.Text = "ESTADO: LISTO"
 $LblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
 $LblStatus.ForeColor = $C_Accent
 $LblStatus.Location = New-Object System.Drawing.Point(20, 650)
 $LblStatus.AutoSize = $true
 $Sidebar.Controls.Add($LblStatus)

# 2. CONTENEDOR PRINCIPAL
 $MainContent = New-Object System.Windows.Forms.Panel
 $MainContent.Dock = "Fill"
 $MainContent.BackColor = $C_Background
 $MainContent.Padding = New-Object System.Windows.Forms.Padding(25, 10, 25, 10) # Padding superior reducido
 $RootLayout.Controls.Add($MainContent, 1, 0)

 $TableLayout = New-Object System.Windows.Forms.TableLayoutPanel
 $TableLayout.Dock = "Fill"
 $TableLayout.RowCount = 3
 $TableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100))) | Out-Null # Altura 100
 $TableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
 $TableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 150))) | Out-Null
 $TableLayout.ColumnCount = 1
 $MainContent.Controls.Add($TableLayout)

# Header
 $PanelHeader = New-Object System.Windows.Forms.Panel
 $PanelHeader.Dock = "Fill"
 $PanelHeader.BackColor = $C_Background
 $TableLayout.Controls.Add($PanelHeader, 0, 0)

 $LblHeader = New-Object System.Windows.Forms.Label
 $LblHeader.Text = "Instalador de Aplicaciones"
 $LblHeader.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
 $LblHeader.ForeColor = $C_Text
 $LblHeader.Location = New-Object System.Drawing.Point(0, 0) # Subido a 0
 $LblHeader.AutoSize = $true
 $PanelHeader.Controls.Add($LblHeader)

# FIX: Subpanel para evitar que el buscador se incruste con las tarjetas
 $PanelSearch = New-Object System.Windows.Forms.Panel
 $PanelSearch.Location = New-Object System.Drawing.Point(0, 45)
 $PanelSearch.Size = New-Object System.Drawing.Size(500, 40)
 $PanelSearch.BackColor = $C_Background
 $PanelHeader.Controls.Add($PanelSearch)

 $txtSearch = New-Object System.Windows.Forms.TextBox
 $txtSearch.Location = New-Object System.Drawing.Point(0, 5)
 $txtSearch.Size = New-Object System.Drawing.Size(300, 31)
 $txtSearch.BackColor = $C_Card
 $txtSearch.ForeColor = $C_TextSec
 $txtSearch.BorderStyle = "FixedSingle"
 $txtSearch.Font = New-Object System.Drawing.Font("Segoe UI", 10)
 $txtSearch.Text = "Buscar..."
 $PanelSearch.Controls.Add($txtSearch)

 $btnRec = New-Object System.Windows.Forms.Button
 $btnRec.Text = "Filtrar Recomendados"
 $btnRec.Location = New-Object System.Drawing.Point(310, 5)
 $btnRec.Size = New-Object System.Drawing.Size(170, 31)
 $btnRec.FlatStyle = "Flat"
 $btnRec.FlatAppearance.BorderSize = 1
 $btnRec.FlatAppearance.BorderColor = $C_Accent
 $btnRec.BackColor = $C_Background
 $btnRec.ForeColor = $C_Accent
 $btnRec.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
 $btnRec.Cursor = "Hand"
 $PanelSearch.Controls.Add($btnRec)

# Contenido Dinámico (Cards)
 $DynPanel = New-Object System.Windows.Forms.FlowLayoutPanel
 $DynPanel.Dock = "Fill"
 $DynPanel.BackColor = $C_Background
 $DynPanel.AutoScroll = $true
 $DynPanel.WrapContents = $true
 $TableLayout.Controls.Add($DynPanel, 0, 1)

# Footer
 $PanelFooter = New-Object System.Windows.Forms.Panel
 $PanelFooter.Dock = "Fill"
 $PanelFooter.BackColor = $C_Background
 $TableLayout.Controls.Add($PanelFooter, 0, 2)

 $LogBox = New-Object System.Windows.Forms.RichTextBox
 $LogBox.BackColor = $C_LogBg
 $LogBox.ForeColor = $C_TextSec
 $LogBox.Font = New-Object System.Drawing.Font("Consolas", 9)
 $LogBox.Dock = "Top"
 $LogBox.Height = 75
 $LogBox.ReadOnly = $true
 $LogBox.BorderStyle = "FixedSingle"
 $PanelFooter.Controls.Add($LogBox)

 $ProgressBar = New-Object System.Windows.Forms.ProgressBar
 $ProgressBar.Dock = "Bottom"
 $ProgressBar.Height = 15
 $ProgressBar.Style = "Continuous"
 $ProgressBar.ForeColor = $C_Accent
 $ProgressBar.BackColor = $C_Card
 $PanelFooter.Controls.Add($ProgressBar)

 $btnExecute = New-Object System.Windows.Forms.Button
 $btnExecute.Text = "EJECUTAR"
 $btnExecute.Dock = "Bottom"
 $btnExecute.FlatStyle = "Flat"
 $btnExecute.BackColor = $C_Accent
 $btnExecute.ForeColor = [System.Drawing.Color]::White
 $btnExecute.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
 $btnExecute.Height = 40
 $btnExecute.Cursor = "Hand"
 $PanelFooter.Controls.Add($btnExecute)

 # --- MOTOR DE MÓDULOS ---
 $CurrentModule = "Apps"
 $CurrentCheckboxes = @{}

function Clear-DynamicPanel {
    $DynPanel.Controls.Clear()
    $script:CurrentCheckboxes = @{}
}

function Set-AppModule {
    Clear-DynamicPanel
    $script:CurrentModule = "Apps"
    $LblHeader.Text = "Instalador de Aplicaciones"
    $PanelSearch.Visible = $true
    $txtSearch.Text = "Buscar..."
    $txtSearch.ForeColor = $C_TextSec
    
    $Categories = $AppCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    
    foreach ($cat in $Categories) {
        $Card = New-Object System.Windows.Forms.Panel
        $Card.BackColor = $C_Card
        $Card.Padding = New-Object System.Windows.Forms.Padding(15, 15, 15, 15)
        $Card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 15, 15)
        $Card.AutoSize = $true
        $Card.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

        $LblCat = New-Object System.Windows.Forms.Label
        $LblCat.Text = $cat.ToUpper()
        $LblCat.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $LblCat.ForeColor = $C_Accent
        $LblCat.Location = New-Object System.Drawing.Point(15, 10)
        $LblCat.AutoSize = $true
        $Card.Controls.Add($LblCat)

        $innerPanel = New-Object System.Windows.Forms.FlowLayoutPanel
        $innerPanel.AutoSize = $true
        $innerPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $innerPanel.Location = New-Object System.Drawing.Point(15, 40)
        $innerPanel.FlowDirection = "TopDown"
        $innerPanel.WrapContents = $false

        foreach ($app in $AppCatalog | Where-Object { $_.Cat -eq $cat }) {
            $cb = New-Object System.Windows.Forms.CheckBox
            $cb.Text = $app.Name
            $cb.Tag = $app.ID
            $cb.Size = New-Object System.Drawing.Size(220, 25)
            $cb.ForeColor = $C_Text
            $cb.BackColor = $C_Card
            $cb.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $innerPanel.Controls.Add($cb)
            $script:CurrentCheckboxes[$app.Name] = $cb
        }
        $Card.Controls.Add($innerPanel)
        $innerPanel.PerformLayout()
        $Card.Width = $innerPanel.Width + 40
        $Card.Height = $innerPanel.Height + 50
        $DynPanel.Controls.Add($Card)
    }
}

function Set-TweaksModule {
    Clear-DynamicPanel
    $script:CurrentModule = "Tweaks"
    $LblHeader.Text = "Optimizaciones y Tweaks"
    $PanelSearch.Visible = $false # Ocultar buscador en tweaks
    
    $Categories = $TweakCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    
    foreach ($cat in $Categories) {
        $Card = New-Object System.Windows.Forms.Panel
        $Card.BackColor = $C_Card
        $Card.Padding = New-Object System.Windows.Forms.Padding(15, 15, 15, 15)
        $Card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 15, 15)
        $Card.AutoSize = $true
        $Card.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

        $LblCat = New-Object System.Windows.Forms.Label
        $LblCat.Text = $cat.ToUpper()
        $LblCat.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $LblCat.ForeColor = $C_Accent
        $LblCat.Location = New-Object System.Drawing.Point(15, 10)
        $LblCat.AutoSize = $true
        $Card.Controls.Add($LblCat)

        $innerPanel = New-Object System.Windows.Forms.FlowLayoutPanel
        $innerPanel.AutoSize = $true
        $innerPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $innerPanel.Location = New-Object System.Drawing.Point(15, 40)
        $innerPanel.FlowDirection = "TopDown"
        $innerPanel.WrapContents = $false

        foreach ($tweak in $TweakCatalog | Where-Object { $_.Cat -eq $cat }) {
            $cb = New-Object System.Windows.Forms.CheckBox
            $cb.Text = $tweak.Name
            $cb.Tag = $tweak.Script
            $cb.Size = New-Object System.Drawing.Size(300, 25)
            $cb.ForeColor = $C_Text
            $cb.BackColor = $C_Card
            $cb.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $innerPanel.Controls.Add($cb)
            $script:CurrentCheckboxes[$tweak.Name] = $cb
        }
        $Card.Controls.Add($innerPanel)
        $innerPanel.PerformLayout()
        $Card.Width = $innerPanel.Width + 40
        $Card.Height = $innerPanel.Height + 50
        $DynPanel.Controls.Add($Card)
    }
}

# --- EVENTOS DE UI ---
 $btnModApps.Add_Click({ Set-AppModule; $btnModApps.BackColor = $C_AccentDark; $btnModTweaks.BackColor = $C_Sidebar })
 $btnModTweaks.Add_Click({ Set-TweaksModule; $btnModTweaks.BackColor = $C_AccentDark; $btnModApps.BackColor = $C_Sidebar })
 $btnRec.Add_Click({ foreach($app in $AppCatalog) { $CurrentCheckboxes[$app.Name].Checked = $app.Rec } })

# Filtro de Búsqueda Dinámico
 $txtSearch.Add_GotFocus({ if ($txtSearch.Text -eq "Buscar...") { $txtSearch.Text = ""; $txtSearch.ForeColor = $C_Text } })
 $txtSearch.Add_LostFocus({ if ($txtSearch.Text -eq "") { $txtSearch.Text = "Buscar..."; $txtSearch.ForeColor = $C_TextSec } })

 $txtSearch.Add_TextChanged({
    $searchText = $txtSearch.Text.ToLower()
    if ($txtSearch.Text -eq "Buscar...") { $searchText = "" }
    
    foreach($card in $DynPanel.Controls) {
        $cardVisible = $false
        foreach($ctrl in $card.Controls) {
            if($ctrl -is [System.Windows.Forms.FlowLayoutPanel]) {
                foreach($cb in $ctrl.Controls) {
                    if($cb.Text.ToLower() -match $searchText) {
                        $cb.Visible = $true
                        $cardVisible = $true
                    } else {
                        $cb.Visible = $false
                    }
                }
            }
        }
        $card.Visible = $cardVisible
    }
})

 $btnExecute.Add_Click({
    $visibleChecks = $CurrentCheckboxes.Values | Where-Object { $_.Checked -and $_.Visible }
    if (-not $visibleChecks.Count) {
        Write-Log "No hay opciones marcadas para ejecutar." "Yellow"
        return
    }

    $sync.IsRunning = $true
    $sync.MaxProgress = $visibleChecks.Count
    $sync.CurrentProgress = 0
    $btnExecute.Text = "PROCESANDO..."
    $btnExecute.Enabled = $false
    $btnExecute.BackColor = $C_AccentDark
    $LblStatus.ForeColor = [System.Drawing.Color]::FromArgb(250, 150, 50)
    
    $selectedItems = $visibleChecks
    
    $job = {
        param($items, $mod, $syncHash)
        
        foreach ($item in $items) {
            $name = $item.Text
            $tag = $item.Tag
            
            if ($mod -eq "Apps") {
                $syncHash.LogQueue.Enqueue(@{ Text="Instalando $name (ID: $tag) vía Winget..."; Color="Cyan" })
                try {
                    $proc = Start-Process winget -ArgumentList "install --id $tag -e --accept-package-agreements --accept-source-agreements -h" -Wait -PassThru -NoNewWindow
                    if ($proc.ExitCode -eq 0) { $syncHash.LogQueue.Enqueue(@{ Text="$name instalado correctamente."; Color="MediumPurple" }) }
                    else { $syncHash.LogQueue.Enqueue(@{ Text="Error instalando $name (Código: $($proc.ExitCode))."; Color="Red" }) }
                } catch { $syncHash.LogQueue.Enqueue(@{ Text="Excepción al instalar $name."; Color="Red" }) }
            }
            elseif ($mod -eq "Tweaks") {
                $syncHash.LogQueue.Enqueue(@{ Text="Aplicando Tweak: $name"; Color="Cyan" })
                try {
                    $scriptBlock = [ScriptBlock]::Create($tag.ToString())
                    & $scriptBlock
                    $syncHash.LogQueue.Enqueue(@{ Text="OK: $name aplicado."; Color="MediumPurple" })
                } catch { $syncHash.LogQueue.Enqueue(@{ Text="Error en: $name -> $($_.Exception.Message)"; Color="Red" }) }
            }
            $syncHash.CurrentProgress++
        }
        $syncHash.LogQueue.Enqueue(@{ Text="--- PROCESO FINALIZADO ---"; Color="Plum" })
        $syncHash.IsRunning = $false
    }
    
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript($job).AddArgument($selectedItems).AddArgument($CurrentModule).AddArgument($sync) | Out-Null
    $ps.BeginInvoke() | Out-Null
})

# Inicializar
 $UITimer.Start()
Set-AppModule
 $btnModApps.BackColor = $C_AccentDark

Write-Log "icezOP iniciado. Fuente de datos: $DataSource" "LightGray"
 $Form.ShowDialog() | Out-Null
