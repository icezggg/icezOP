[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- INYECCIÓN DE CONTROLES C# PERSONALIZADOS ---
 $CSharpCode = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class GradientButton : Button {
    public Color Color1 { get; set; } = Color.FromArgb(139, 92, 246);
    public Color Color2 { get; set; } = Color.FromArgb(165, 120, 255);
    public int CornerRadius { get; set; } = 8;
    public GradientButton() { this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle rect = new Rectangle(0, 0, this.Width - 1, this.Height - 1);
        using (GraphicsPath path = new GraphicsPath()) {
            path.AddArc(rect.X, rect.Y, CornerRadius, CornerRadius, 180, 90);
            path.AddArc(rect.Right - CornerRadius, rect.Y, CornerRadius, CornerRadius, 270, 90);
            path.AddArc(rect.Right - CornerRadius, rect.Bottom - CornerRadius, CornerRadius, CornerRadius, 0, 90);
            path.AddArc(rect.X, rect.Bottom - CornerRadius, CornerRadius, CornerRadius, 90, 90);
            path.CloseFigure();
            this.Region = new Region(path);
            using (LinearGradientBrush brush = new LinearGradientBrush(rect, Color1, Color2, LinearGradientMode.Vertical)) { g.FillPath(brush, path); }
        }
        TextRenderer.DrawText(g, this.Text, this.Font, rect, this.ForeColor, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
    }
}

public class ModernCheckBox : CheckBox {
    public Color CheckColor { get; set; } = Color.FromArgb(139, 92, 246);
    public ModernCheckBox() { this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.Clear(this.BackColor);
        Rectangle boxRect = new Rectangle(0, (this.Height - 16) / 2, 16, 16);
        using (GraphicsPath path = new GraphicsPath()) {
            int r = 4;
            path.AddArc(boxRect.X, boxRect.Y, r, r, 180, 90);
            path.AddArc(boxRect.Right - r, boxRect.Y, r, r, 270, 90);
            path.AddArc(boxRect.Right - r, boxRect.Bottom - r, r, r, 0, 90);
            path.AddArc(boxRect.X, boxRect.Bottom - r, r, r, 90, 90);
            path.CloseFigure();
            if (this.Checked) {
                using (SolidBrush b = new SolidBrush(CheckColor)) { g.FillPath(b, path); }
                using (Pen p = new Pen(Color.White, 2)) {
                    g.DrawLine(p, boxRect.X + 3, boxRect.Y + 8, boxRect.X + 7, boxRect.Y + 12);
                    g.DrawLine(p, boxRect.X + 7, boxRect.Y + 12, boxRect.X + 13, boxRect.Y + 4);
                }
            } else {
                using (SolidBrush b = new SolidBrush(Color.FromArgb(45, 45, 52))) { g.FillPath(b, path); }
                using (Pen p = new Pen(Color.FromArgb(70, 70, 80), 1)) { g.DrawPath(p, path); }
            }
        }
        Rectangle textRect = new Rectangle(boxRect.Right + 8, 0, this.Width - boxRect.Right - 8, this.Height);
        TextRenderer.DrawText(g, this.Text, this.Font, textRect, this.ForeColor, TextFormatFlags.Left | TextFormatFlags.VerticalCenter);
    }
}

public class ShadowLabel : Label {
    public Color ShadowColor { get; set; } = Color.FromArgb(100, 0, 0, 0);
    public int ShadowOffset { get; set; } = 2;
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;
        using (SolidBrush b = new SolidBrush(ShadowColor)) { g.DrawString(this.Text, this.Font, b, new PointF(this.ShadowOffset, this.ShadowOffset)); }
        using (SolidBrush b = new SolidBrush(this.ForeColor)) { g.DrawString(this.Text, this.Font, b, new PointF(0, 0)); }
    }
}

public class DarkScrollPanel : FlowLayoutPanel {
    [DllImport("uxtheme.dll", ExactSpelling = true, CharSet = CharSet.Unicode)]
    private static extern int SetWindowTheme(IntPtr hWnd, string pszSubAppName, string pszSubIdList);
    public DarkScrollPanel() {
        this.HandleCreated += (s, e) => { try { SetWindowTheme(this.Handle, "DarkMode_Explorer", null); } catch { } };
    }
}
"@
Add-Type -TypeDefinition $CSharpCode -ReferencedAssemblies System.Windows.Forms, System.Drawing

# --- MOTOR ASÍNCRONO Y PROGRESO ---
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
        $script:btnExecute.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246)
        $script:btnExecute.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255)
        $script:btnExecute.Invalidate()
        $script:sync.MaxProgress = 0
        $script:sync.CurrentProgress = 0
        $script:ProgressBar.Value = 0
        $script:LblStatus.Text = "ESTADO: LISTO"
        $script:LblStatus.ForeColor = [System.Drawing.Color]::FromArgb(139, 92, 246)
    }
})

function Write-Log($texto, $color = "White") { $sync.LogQueue.Enqueue(@{ Text = $texto; Color = $color }) }

# --- CARGA DE JSON ---
 $RepoURL = "https://raw.githubusercontent.com/icezggg/icezOP/main"
try {
    $AppCatalog = Invoke-RestMethod -Uri "$RepoURL/apps.json" -ErrorAction Stop
    $TweakCatalog = Invoke-RestMethod -Uri "$RepoURL/tweaks.json" -ErrorAction Stop
    $DataSource = "GitHub"
} catch {
    $localApps = "$PSScriptRoot\apps.json"
    $localTweaks = "$PSScriptRoot\tweaks.json"
    if (Test-Path $localApps -and Test-Path $localTweaks) {
        $AppCatalog = Get-Content -Path $localApps -Raw | ConvertFrom-Json
        $TweakCatalog = Get-Content -Path $localTweaks -Raw | ConvertFrom-Json
        $DataSource = "Local"
    } else { [System.Windows.Forms.MessageBox]::Show("No se encontraron los JSON.", "Error", 0, 16); Exit }
}

# --- TEMA ICEZOP PREMIUM ---
 $C_BgBase = [System.Drawing.Color]::FromArgb(15, 15, 18)
 $C_BgLayer = [System.Drawing.Color]::FromArgb(25, 25, 30)
 $C_Card = [System.Drawing.Color]::FromArgb(30, 30, 36)
 $C_Accent = [System.Drawing.Color]::FromArgb(139, 92, 246)
 $C_AccentHover = [System.Drawing.Color]::FromArgb(165, 120, 255)
 $C_TextMain = [System.Drawing.Color]::FromArgb(245, 245, 250)
 $C_TextSec = [System.Drawing.Color]::FromArgb(140, 140, 150)
 $C_Red = [System.Drawing.Color]::FromArgb(239, 68, 68)

# --- FORMULARIO BORDERLESS ---
 $Form = New-Object System.Windows.Forms.Form
 $Form.Text = "icezOP"
 $Form.Size = New-Object System.Drawing.Size(1100, 750)
 $Form.StartPosition = "CenterScreen"
 $Form.BackColor = $C_BgBase
 $Form.FormBorderStyle = "None"

 $Radius = 15
 $FormPath = New-Object System.Drawing.Drawing2D.GraphicsPath
 $FormPath.AddArc(0, 0, $Radius, $Radius, 180, 90)
 $FormPath.AddArc($Form.Width - $Radius, 0, $Radius, $Radius, 270, 90)
 $FormPath.AddArc($Form.Width - $Radius, $Form.Height - $Radius, $Radius, $Radius, 0, 90)
 $FormPath.AddArc(0, $Form.Height - $Radius, $Radius, $Radius, 90, 90)
 $FormPath.CloseFigure()
 $Form.Region = New-Object System.Drawing.Region($FormPath)

 $DragInfo = @{ Dragging = $false; X = 0; Y = 0 }

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
 $Sidebar.BackColor = $C_BgLayer
 $RootLayout.Controls.Add($Sidebar, 0, 0)

 $TitleBar = New-Object System.Windows.Forms.Panel
 $TitleBar.Location = New-Object System.Drawing.Point(0, 0)
 $TitleBar.Size = New-Object System.Drawing.Size(220, 40)
 $TitleBar.BackColor = $C_BgLayer
 $Sidebar.Controls.Add($TitleBar)

# Logo con Sombra y Tipografía Cursiva
 $LblLogo = New-Object ShadowLabel
 $LblLogo.Text = "icezOP"
 $LblLogo.Font = New-Object System.Drawing.Font("Segoe Script", 22, [System.Drawing.FontStyle]::Bold)
 $LblLogo.ForeColor = $C_Accent
 $LblLogo.ShadowColor = [System.Drawing.Color]::FromArgb(50, 0, 0, 20)
 $LblLogo.ShadowOffset = 3
 $LblLogo.Location = New-Object System.Drawing.Point(20, 5)
 $LblLogo.AutoSize = $true
 $TitleBar.Controls.Add($LblLogo)

 $TitleBar.Add_MouseDown({ if($_.Button -eq 'Left'){ $script:DragInfo.Dragging = $true; $script:DragInfo.X = $_.X; $script:DragInfo.Y = $_.Y } })
 $TitleBar.Add_MouseMove({ if($script:DragInfo.Dragging){ $Form.Left += $_.X - $script:DragInfo.X; $Form.Top += $_.Y - $script:DragInfo.Y } })
 $TitleBar.Add_MouseUp({ $script:DragInfo.Dragging = $false })

 $btnModApps = New-Object System.Windows.Forms.Button
 $btnModApps.Text = "   Aplicaciones"
 $btnModApps.Location = New-Object System.Drawing.Point(15, 60)
 $btnModApps.Size = New-Object System.Drawing.Size(190, 40)
 $btnModApps.FlatStyle = "Flat"
 $btnModApps.FlatAppearance.BorderSize = 0
 $btnModApps.BackColor = $C_BgLayer
 $btnModApps.ForeColor = $C_TextSec
 $btnModApps.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10)
 $btnModApps.TextAlign = "MiddleLeft"
 $btnModApps.Cursor = "Hand"
 $Sidebar.Controls.Add($btnModApps)

 $btnModTweaks = New-Object System.Windows.Forms.Button
 $btnModTweaks.Text = "   Optimizaciones"
 $btnModTweaks.Location = New-Object System.Drawing.Point(15, 105)
 $btnModTweaks.Size = New-Object System.Drawing.Size(190, 40)
 $btnModTweaks.FlatStyle = "Flat"
 $btnModTweaks.FlatAppearance.BorderSize = 0
 $btnModTweaks.BackColor = $C_BgLayer
 $btnModTweaks.ForeColor = $C_TextSec
 $btnModTweaks.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10)
 $btnModTweaks.TextAlign = "MiddleLeft"
 $btnModTweaks.Cursor = "Hand"
 $Sidebar.Controls.Add($btnModTweaks)

 $LblStatus = New-Object System.Windows.Forms.Label
 $LblStatus.Text = "ESTADO: LISTO"
 $LblStatus.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 8, [System.Drawing.FontStyle]::Bold)
 $LblStatus.ForeColor = $C_Accent
 $LblStatus.Location = New-Object System.Drawing.Point(20, 650)
 $LblStatus.AutoSize = $true
 $Sidebar.Controls.Add($LblStatus)

# 2. MAIN AREA
 $MainContent = New-Object System.Windows.Forms.Panel
 $MainContent.Dock = "Fill"
 $MainContent.BackColor = $C_BgBase
 $MainContent.Padding = New-Object System.Windows.Forms.Padding(25, 10, 25, 10)
 $RootLayout.Controls.Add($MainContent, 1, 0)

 $TableLayout = New-Object System.Windows.Forms.TableLayoutPanel
 $TableLayout.Dock = "Fill"
 $TableLayout.RowCount = 3
 $TableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 90))) | Out-Null
 $TableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
 $TableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 150))) | Out-Null
 $TableLayout.ColumnCount = 1
 $MainContent.Controls.Add($TableLayout)

 $PanelHeader = New-Object System.Windows.Forms.Panel
 $PanelHeader.Dock = "Fill"
 $PanelHeader.BackColor = $C_BgBase
 $TableLayout.Controls.Add($PanelHeader, 0, 0)

# Botones de Ventana (Minimizar / Cerrar)
 $btnMin = New-Object System.Windows.Forms.Button
 $btnMin.Text = "—" ; $btnMin.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10)
 $btnMin.Location = New-Object System.Drawing.Point(730, 0); $btnMin.Size = New-Object System.Drawing.Size(45, 32)
 $btnMin.FlatStyle = "Flat"; $btnMin.FlatAppearance.BorderSize = 0; $btnMin.BackColor = $C_BgBase; $btnMin.ForeColor = $C_TextSec; $btnMin.Cursor = "Hand"
 $PanelHeader.Controls.Add($btnMin)
 $btnMin.Add_Click({ $Form.WindowState = "Minimized" })
 $btnMin.Add_MouseEnter({ $btnMin.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 52) })
 $btnMin.Add_MouseLeave({ $btnMin.BackColor = $C_BgBase })

 $btnClose = New-Object System.Windows.Forms.Button
 $btnClose.Text = "✕" ; $btnClose.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10)
 $btnClose.Location = New-Object System.Drawing.Point(775, 0); $btnClose.Size = New-Object System.Drawing.Size(45, 32)
 $btnClose.FlatStyle = "Flat"; $btnClose.FlatAppearance.BorderSize = 0; $btnClose.BackColor = $C_BgBase; $btnClose.ForeColor = $C_TextSec; $btnClose.Cursor = "Hand"
 $PanelHeader.Controls.Add($btnClose)
 $btnClose.Add_Click({ $Form.Close() })
 $btnClose.Add_MouseEnter({ $btnClose.BackColor = $C_Red; $btnClose.ForeColor = [System.Drawing.Color]::White })
 $btnClose.Add_MouseLeave({ $btnClose.BackColor = $C_BgBase; $btnClose.ForeColor = $C_TextSec })

 $LblHeader = New-Object System.Windows.Forms.Label
 $LblHeader.Text = "Instalador de Aplicaciones"
 $LblHeader.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 16, [System.Drawing.FontStyle]::Bold)
 $LblHeader.ForeColor = $C_TextMain
 $LblHeader.Location = New-Object System.Drawing.Point(0, 35); $LblHeader.AutoSize = $true
 $PanelHeader.Controls.Add($LblHeader)

 $PanelSearch = New-Object System.Windows.Forms.Panel
 $PanelSearch.Location = New-Object System.Drawing.Point(300, 35); $PanelSearch.Size = New-Object System.Drawing.Size(350, 35)
 $PanelSearch.BackColor = $C_Card
 $PanelHeader.Controls.Add($PanelSearch)

 $txtSearch = New-Object System.Windows.Forms.TextBox
 $txtSearch.Location = New-Object System.Drawing.Point(10, 8); $txtSearch.Size = New-Object System.Drawing.Size(220, 20)
 $txtSearch.BorderStyle = "None"; $txtSearch.BackColor = $C_Card; $txtSearch.ForeColor = $C_TextMain
 $txtSearch.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 10); $txtSearch.Text = "Buscar..."
 $PanelSearch.Controls.Add($txtSearch)

# Botón Recomendados con Degradado
 $btnRec = New-Object GradientButton
 $btnRec.Text = "Recomendados"
 $btnRec.Location = New-Object System.Drawing.Point(240, 5); $btnRec.Size = New-Object System.Drawing.Size(105, 25)
 $btnRec.Color1 = [System.Drawing.Color]::FromArgb(80, 50, 160); $btnRec.Color2 = [System.Drawing.Color]::FromArgb(120, 70, 200)
 $btnRec.ForeColor = [System.Drawing.Color]::White; $btnRec.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 8, [System.Drawing.FontStyle]::Bold)
 $btnRec.Cursor = "Hand"; $btnRec.CornerRadius = 6
 $PanelSearch.Controls.Add($btnRec)
 $btnRec.Add_MouseEnter({ $btnRec.Color1 = [System.Drawing.Color]::FromArgb(100, 60, 180); $btnRec.Color2 = [System.Drawing.Color]::FromArgb(140, 90, 220); $btnRec.Invalidate() })
 $btnRec.Add_MouseLeave({ $btnRec.Color1 = [System.Drawing.Color]::FromArgb(80, 50, 160); $btnRec.Color2 = [System.Drawing.Color]::FromArgb(120, 70, 200); $btnRec.Invalidate() })

# Panel Dinámico con Scrollbar Oscura
 $DynPanel = New-Object DarkScrollPanel
 $DynPanel.Dock = "Fill"; $DynPanel.BackColor = $C_BgBase; $DynPanel.AutoScroll = $true; $DynPanel.WrapContents = $true
 $TableLayout.Controls.Add($DynPanel, 0, 1)

 $PanelFooter = New-Object System.Windows.Forms.Panel
 $PanelFooter.Dock = "Fill"; $PanelFooter.BackColor = $C_BgBase
 $TableLayout.Controls.Add($PanelFooter, 0, 2)

 $LogBox = New-Object System.Windows.Forms.RichTextBox
 $LogBox.BackColor = [System.Drawing.Color]::FromArgb(10, 10, 12); $LogBox.ForeColor = $C_TextSec
 $LogBox.Font = New-Object System.Drawing.Font("Cascadia Code", 8); $LogBox.Dock = "Top"; $LogBox.Height = 80; $LogBox.ReadOnly = $true; $LogBox.BorderStyle = "None"
 $PanelFooter.Controls.Add($LogBox)

 $ProgressBar = New-Object System.Windows.Forms.ProgressBar
 $ProgressBar.Dock = "Bottom"; $ProgressBar.Height = 4; $ProgressBar.Style = "Continuous"; $ProgressBar.ForeColor = $C_Accent; $ProgressBar.BackColor = $C_Card
 $PanelFooter.Controls.Add($ProgressBar)

# Botón Ejecutar con Degradado y Hover
 $btnExecute = New-Object GradientButton
 $btnExecute.Text = "EJECUTAR"
 $btnExecute.Dock = "Bottom"
 $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255)
 $btnExecute.ForeColor = [System.Drawing.Color]::White; $btnExecute.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 12, [System.Drawing.FontStyle]::Bold)
 $btnExecute.Height = 40; $btnExecute.Cursor = "Hand"; $btnExecute.CornerRadius = 8
 $PanelFooter.Controls.Add($btnExecute)
 $btnExecute.Add_MouseEnter({ if(-not $sync.IsRunning){ $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(159, 102, 246); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(180, 140, 255); $btnExecute.Invalidate() } })
 $btnExecute.Add_MouseLeave({ if(-not $sync.IsRunning){ $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $btnExecute.Invalidate() } })

  $CurrentModule = "Apps"
 $CurrentCheckboxes = @{}

function Clear-DynamicPanel { $DynPanel.Controls.Clear(); $script:CurrentCheckboxes = @{} }

function Set-AppModule {
    Clear-DynamicPanel
    $script:CurrentModule = "Apps"
    $LblHeader.Text = "Instalador de Aplicaciones"
    $PanelSearch.Visible = $true
    $txtSearch.Text = "Buscar..."; $txtSearch.ForeColor = $C_TextSec
    
    $Categories = $AppCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    foreach ($cat in $Categories) {
        $Card = New-Object System.Windows.Forms.Panel
        $Card.BackColor = $C_Card
        $Card.Padding = New-Object System.Windows.Forms.Padding(20) # Padding aumentado
        $Card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 15, 15)
        $Card.AutoSize = $true; $Card.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

        $LblCat = New-Object System.Windows.Forms.Label
        $LblCat.Text = $cat.ToUpper()
        $LblCat.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9, [System.Drawing.FontStyle]::Bold)
        $LblCat.ForeColor = $C_TextSec; $LblCat.Location = New-Object System.Drawing.Point(20, 15); $LblCat.AutoSize = $true
        $Card.Controls.Add($LblCat)

        $innerPanel = New-Object System.Windows.Forms.FlowLayoutPanel
        $innerPanel.AutoSize = $true; $innerPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $innerPanel.Location = New-Object System.Drawing.Point(20, 40); $innerPanel.FlowDirection = "TopDown"; $innerPanel.WrapContents = $false

        foreach ($app in $AppCatalog | Where-Object { $_.Cat -eq $cat }) {
            $cb = New-Object ModernCheckBox # CheckBox Moderno C#
            $cb.Text = $app.Name; $cb.Tag = $app.ID
            $cb.Size = New-Object System.Drawing.Size(220, 30) # Más espacio vertical
            $cb.ForeColor = $C_TextMain; $cb.BackColor = $C_Card
            $cb.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
            $cb.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5) # Separación entre items
            $innerPanel.Controls.Add($cb)
            $script:CurrentCheckboxes[$app.Name] = $cb
        }
        $Card.Controls.Add($innerPanel); $innerPanel.PerformLayout()
        $Card.Width = $innerPanel.Width + 50; $Card.Height = $innerPanel.Height + 60
        $DynPanel.Controls.Add($Card)
    }
}

function Set-TweaksModule {
    Clear-DynamicPanel
    $script:CurrentModule = "Tweaks"
    $LblHeader.Text = "Optimizaciones y Tweaks"
    $PanelSearch.Visible = $false
    
    $Categories = $TweakCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    foreach ($cat in $Categories) {
        $Card = New-Object System.Windows.Forms.Panel
        $Card.BackColor = $C_Card
        $Card.Padding = New-Object System.Windows.Forms.Padding(20)
        $Card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 15, 15)
        $Card.AutoSize = $true; $Card.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

        $LblCat = New-Object System.Windows.Forms.Label
        $LblCat.Text = $cat.ToUpper()
        $LblCat.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9, [System.Drawing.FontStyle]::Bold)
        $LblCat.ForeColor = $C_TextSec; $LblCat.Location = New-Object System.Drawing.Point(20, 15); $LblCat.AutoSize = $true
        $Card.Controls.Add($LblCat)

        $innerPanel = New-Object System.Windows.Forms.FlowLayoutPanel
        $innerPanel.AutoSize = $true; $innerPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $innerPanel.Location = New-Object System.Drawing.Point(20, 40); $innerPanel.FlowDirection = "TopDown"; $innerPanel.WrapContents = $false

        foreach ($tweak in $TweakCatalog | Where-Object { $_.Cat -eq $cat }) {
            $cb = New-Object ModernCheckBox
            $cb.Text = $tweak.Name; $cb.Tag = $tweak.Script
            $cb.Size = New-Object System.Drawing.Size(300, 30)
            $cb.ForeColor = $C_TextMain; $cb.BackColor = $C_Card
            $cb.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 9)
            $cb.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5)
            $innerPanel.Controls.Add($cb)
            $script:CurrentCheckboxes[$tweak.Name] = $cb
        }
        $Card.Controls.Add($innerPanel); $innerPanel.PerformLayout()
        $Card.Width = $innerPanel.Width + 50; $Card.Height = $innerPanel.Height + 60
        $DynPanel.Controls.Add($Card)
    }
}

 $btnModApps.Add_Click({ 
    Set-AppModule
    $btnModApps.BackColor = $C_Card; $btnModApps.ForeColor = $C_TextMain
    $btnModTweaks.BackColor = $C_BgLayer; $btnModTweaks.ForeColor = $C_TextSec
})
 $btnModApps.Add_MouseEnter({ if($CurrentModule -ne "Apps"){ $btnModApps.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 42) } })

 $btnModTweaks.Add_Click({ 
    Set-TweaksModule
    $btnModTweaks.BackColor = $C_Card; $btnModTweaks.ForeColor = $C_TextMain
    $btnModApps.BackColor = $C_BgLayer; $btnModApps.ForeColor = $C_TextSec
})
 $btnModTweaks.Add_MouseEnter({ if($CurrentModule -ne "Tweaks"){ $btnModTweaks.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 42) } })

 $btnRec.Add_Click({ foreach($app in $AppCatalog) { $CurrentCheckboxes[$app.Name].Checked = $app.Rec } })

 $txtSearch.Add_GotFocus({ if ($txtSearch.Text -eq "Buscar...") { $txtSearch.Text = ""; $txtSearch.ForeColor = $C_TextMain } })
 $txtSearch.Add_LostFocus({ if ($txtSearch.Text -eq "") { $txtSearch.Text = "Buscar..."; $txtSearch.ForeColor = $C_TextSec } })
 $txtSearch.Add_TextChanged({
    $searchText = $txtSearch.Text.ToLower()
    if ($txtSearch.Text -eq "Buscar...") { $searchText = "" }
    foreach($card in $DynPanel.Controls) {
        $cardVisible = $false
        foreach($ctrl in $card.Controls) {
            if($ctrl -is [System.Windows.Forms.FlowLayoutPanel]) {
                foreach($cb in $ctrl.Controls) {
                    if($cb.Text.ToLower() -match $searchText) { $cb.Visible = $true; $cardVisible = $true } else { $cb.Visible = $false }
                }
            }
        }
        $card.Visible = $cardVisible
    }
})

 $btnExecute.Add_Click({
    $visibleChecks = $CurrentCheckboxes.Values | Where-Object { $_.Checked -and $_.Visible }
    if (-not $visibleChecks.Count) { Write-Log "No hay opciones marcadas." "Yellow"; return }

    $sync.IsRunning = $true
    $sync.MaxProgress = $visibleChecks.Count
    $sync.CurrentProgress = 0
    $btnExecute.Text = "PROCESANDO..."
    $btnExecute.Enabled = $false
    $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(80, 50, 140)
    $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(100, 60, 160)
    $btnExecute.Invalidate()
    $LblStatus.ForeColor = [System.Drawing.Color]::FromArgb(250, 150, 50)
    
    $job = {
        param($items, $mod, $syncHash)
        foreach ($item in $items) {
            $name = $item.Text; $tag = $item.Tag
            if ($mod -eq "Apps") {
                $syncHash.LogQueue.Enqueue(@{ Text="Instalando $name..."; Color="Cyan" })
                try {
                    $proc = Start-Process winget -ArgumentList "install --id $tag -e --accept-package-agreements --accept-source-agreements -h" -Wait -PassThru -NoNewWindow
                    if ($proc.ExitCode -eq 0) { $syncHash.LogQueue.Enqueue(@{ Text="$name instalado."; Color="MediumPurple" }) } else { $syncHash.LogQueue.Enqueue(@{ Text="Error en $name."; Color="Red" }) }
                } catch { $syncHash.LogQueue.Enqueue(@{ Text="Excepción: $name."; Color="Red" }) }
            } elseif ($mod -eq "Tweaks") {
                $syncHash.LogQueue.Enqueue(@{ Text="Aplicando: $name"; Color="Cyan" })
                try { $sb = [ScriptBlock]::Create($tag.ToString()); & $sb; $syncHash.LogQueue.Enqueue(@{ Text="OK: $name"; Color="MediumPurple" }) } catch { $syncHash.LogQueue.Enqueue(@{ Text="Error: $name"; Color="Red" }) }
            }
            $syncHash.CurrentProgress++
        }
        $syncHash.LogQueue.Enqueue(@{ Text="--- FINALIZADO ---"; Color="Plum" })
        $syncHash.IsRunning = $false
    }
    $runspace = [runspacefactory]::CreateRunspace(); $runspace.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $runspace
    $ps.AddScript($job).AddArgument($visibleChecks).AddArgument($CurrentModule).AddArgument($sync) | Out-Null
    $ps.BeginInvoke() | Out-Null
})

# Inicializar
 $UITimer.Start()
Set-AppModule
 $btnModApps.BackColor = $C_Card
 $btnModApps.ForeColor = $C_TextMain
Write-Log "icezOP Premium UI iniciado." "LightGray"
 $Form.ShowDialog() | Out-Null
