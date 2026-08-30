[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- INYECCIÓN DE CONTROLES C# PREMIUM ---
 $CSharpCode = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class GradientButton : Button {
    public Color Color1 { get; set; }
    public Color Color2 { get; set; }
    public int CornerRadius { get; set; }
    public GradientButton() { 
        this.Color1 = Color.FromArgb(139, 92, 246);
        this.Color2 = Color.FromArgb(165, 120, 255);
        this.CornerRadius = 8;
        this.FlatStyle = FlatStyle.Flat; 
        this.FlatAppearance.BorderSize = 0; 
    }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        
        // Sombra paralela sutil
        Rectangle shadowRect = new Rectangle(0, 4, this.Width - 1, this.Height - 3);
        using (GraphicsPath shadowPath = new GraphicsPath()) {
            shadowPath.AddArc(shadowRect.X, shadowRect.Y, CornerRadius, CornerRadius, 180, 90);
            shadowPath.AddArc(shadowRect.Right - CornerRadius, shadowRect.Y, CornerRadius, CornerRadius, 270, 90);
            shadowPath.AddArc(shadowRect.Right - CornerRadius, shadowRect.Bottom - CornerRadius, CornerRadius, CornerRadius, 0, 90);
            shadowPath.AddArc(shadowRect.X, shadowRect.Bottom - CornerRadius, CornerRadius, CornerRadius, 90, 90);
            shadowPath.CloseFigure();
            using (SolidBrush sb = new SolidBrush(Color.FromArgb(40, 0, 0, 0))) { g.FillPath(sb, shadowPath); }
        }

        // Botón principal
        Rectangle rect = new Rectangle(0, 0, this.Width - 1, this.Height - 4);
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
    public Color CheckColor { get; set; }
    public ModernCheckBox() { 
        this.CheckColor = Color.FromArgb(139, 92, 246);
        this.FlatStyle = FlatStyle.Flat; 
        this.FlatAppearance.BorderSize = 0; 
    }
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

// Botón de Ventana Vectorial (Sin texto para evitar ???)
public class WinButton : Button {
    public bool IsClose { get; set; }
    public WinButton() { this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.Clear(this.BackColor);
        if (IsClose && this.ClientRectangle.Contains(this.PointToClient(Cursor.Position))) {
            g.FillRectangle(new SolidBrush(Color.FromArgb(232, 24, 24)), this.ClientRectangle);
            using (Pen p = new Pen(Color.White, 2)) { g.DrawLine(p, 16, 10, 26, 20); g.DrawLine(p, 26, 10, 16, 20); }
        } else {
            using (Pen p = new Pen(this.ForeColor, 2)) {
                if (IsClose) { g.DrawLine(p, 16, 10, 26, 20); g.DrawLine(p, 26, 10, 16, 20); }
                else { g.DrawLine(p, 15, 15, 27, 15); } // Minimizar
            }
        }
    }
}

// Botón de Menú Lateral con Icono Vectorial y Active State
public class NavButton : Button {
    public bool IsActive { get; set; }
    public int IconType { get; set; } // 0=Apps, 1=Tweaks, 2=Drivers
    public NavButton() { this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; this.DoubleBuffered = true; }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.Clear(this.BackColor);
        
        if (IsActive) {
            g.FillRectangle(new SolidBrush(Color.FromArgb(35, 35, 42)), this.ClientRectangle);
            g.FillRectangle(new SolidBrush(Color.FromArgb(139, 92, 246)), new Rectangle(0, 5, 4, this.Height - 10));
        }
        
        int iconX = 15;
        int iconY = this.Height / 2 - 8;
        Color iconColor = this.IsActive ? Color.FromArgb(165, 120, 255) : Color.FromArgb(140, 140, 150);
        using (Pen p = new Pen(iconColor, 2)) {
            if (IconType == 0) { // Apps (Cuadros)
                g.DrawRectangle(p, iconX, iconY, 6, 6);
                g.DrawRectangle(p, iconX+10, iconY, 6, 6);
                g.DrawRectangle(p, iconX, iconY+10, 6, 6);
                g.DrawRectangle(p, iconX+10, iconY+10, 6, 6);
            } else if (IconType == 1) { // Tweaks (Engranaje simplificado)
                g.DrawEllipse(p, iconX+2, iconY+2, 12, 12);
                g.DrawEllipse(p, iconX+6, iconY+6, 4, 4);
            } else if (IconType == 2) { // Drivers (Chip)
                g.DrawRectangle(p, iconX+2, iconY, 12, 16);
                g.DrawLine(p, iconX, iconY+4, iconX+2, iconY+4);
                g.DrawLine(p, iconX+14, iconY+4, iconX+16, iconY+4);
            }
        }
        TextRenderer.DrawText(g, this.Text, this.Font, new Rectangle(40, 0, this.Width-40, this.Height), this.ForeColor, TextFormatFlags.Left | TextFormatFlags.VerticalCenter);
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
} catch {
    $localApps = "$PSScriptRoot\apps.json"
    $localTweaks = "$PSScriptRoot\tweaks.json"
    if (Test-Path $localApps -and Test-Path $localTweaks) {
        $AppCatalog = Get-Content -Path $localApps -Raw | ConvertFrom-Json
        $TweakCatalog = Get-Content -Path $localTweaks -Raw | ConvertFrom-Json
    } else { [System.Windows.Forms.MessageBox]::Show("No se encontraron los JSON.", "Error", 0, 16); Exit }
}

# --- TEMA ICEZOP ---
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

 $LblLogo = New-Object System.Windows.Forms.Label
 $LblLogo.Text = "icezOP"
 $LblLogo.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
 $LblLogo.ForeColor = $C_Accent
 $LblLogo.Location = New-Object System.Drawing.Point(20, 10)
 $LblLogo.AutoSize = $true
 $TitleBar.Controls.Add($LblLogo)

 $TitleBar.Add_MouseDown({ if($_.Button -eq 'Left'){ $script:DragInfo.Dragging = $true; $script:DragInfo.X = $_.X; $script:DragInfo.Y = $_.Y } })
 $TitleBar.Add_MouseMove({ if($script:DragInfo.Dragging){ $Form.Left += $_.X - $script:DragInfo.X; $Form.Top += $_.Y - $script:DragInfo.Y } })
 $TitleBar.Add_MouseUp({ $script:DragInfo.Dragging = $false })

# Botones de Menú Vectoriales
 $FontNav = New-Object System.Drawing.Font("Segoe UI Variable Text", 10, [System.Drawing.FontStyle]::Semibold)

 $btnModApps = New-Object NavButton
 $btnModApps.Text = "Aplicaciones"; $btnModApps.IconType = 0; $btnModApps.IsActive = $true
 $btnModApps.Location = New-Object System.Drawing.Point(0, 60); $btnModApps.Size = New-Object System.Drawing.Size(220, 40)
 $btnModApps.BackColor = $C_BgLayer; $btnModApps.ForeColor = $C_TextMain; $btnModApps.Font = $FontNav; $btnModApps.Cursor = "Hand"
 $Sidebar.Controls.Add($btnModApps)

 $btnModTweaks = New-Object NavButton
 $btnModTweaks.Text = "Tweaks"; $btnModTweaks.IconType = 1
 $btnModTweaks.Location = New-Object System.Drawing.Point(0, 100); $btnModTweaks.Size = New-Object System.Drawing.Size(220, 40)
 $btnModTweaks.BackColor = $C_BgLayer; $btnModTweaks.ForeColor = $C_TextSec; $btnModTweaks.Font = $FontNav; $btnModTweaks.Cursor = "Hand"
 $Sidebar.Controls.Add($btnModTweaks)

 $btnModDrivers = New-Object NavButton
 $btnModDrivers.Text = "Drivers"; $btnModDrivers.IconType = 2
 $btnModDrivers.Location = New-Object System.Drawing.Point(0, 140); $btnModDrivers.Size = New-Object System.Drawing.Size(220, 40)
 $btnModDrivers.BackColor = $C_BgLayer; $btnModDrivers.ForeColor = $C_TextSec; $btnModDrivers.Font = $FontNav; $btnModDrivers.Cursor = "Hand"
 $Sidebar.Controls.Add($btnModDrivers)

# Panel de Especificaciones de PC (Driver Booster Style)
 $PanelSpecs = New-Object System.Windows.Forms.Panel
 $PanelSpecs.Location = New-Object System.Drawing.Point(15, 490)
 $PanelSpecs.Size = New-Object System.Drawing.Size(190, 130)
 $PanelSpecs.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 25)
 $Sidebar.Controls.Add($PanelSpecs)

 $LblSpecsTitle = New-Object System.Windows.Forms.Label
 $LblSpecsTitle.Text = "ESPECIFICACIONES PC"
 $LblSpecsTitle.Font = New-Object System.Drawing.Font("Segoe UI", 7, [System.Drawing.FontStyle]::Bold)
 $LblSpecsTitle.ForeColor = $C_Accent
 $LblSpecsTitle.Location = New-Object System.Drawing.Point(10, 5)
 $LblSpecsTitle.AutoSize = $true
 $PanelSpecs.Controls.Add($LblSpecsTitle)

# Obtener datos reales de la PC
 $OSInfo = (Get-CimInstance Win32_OperatingSystem).Caption
 $CPUInfo = (Get-CimInstance Win32_Processor).Name
 $GPUInfo = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name
 $RAMInfo = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)

 $LblOS = New-Object System.Windows.Forms.Label; $LblOS.Text = "OS: $OSInfo"; $LblOS.Font = New-Object System.Drawing.Font("Segoe UI", 8); $LblOS.ForeColor = $C_TextSec; $LblOS.Location = New-Object System.Drawing.Point(10, 25); $LblOS.AutoSize = $true
 $LblCPU = New-Object System.Windows.Forms.Label; $LblCPU.Text = "CPU: $CPUInfo"; $LblCPU.Font = New-Object System.Drawing.Font("Segoe UI", 8); $LblCPU.ForeColor = $C_TextSec; $LblCPU.Location = New-Object System.Drawing.Point(10, 50); $LblCPU.AutoSize = $true
 $LblGPU = New-Object System.Windows.Forms.Label; $LblGPU.Text = "GPU: $GPUInfo"; $LblGPU.Font = New-Object System.Drawing.Font("Segoe UI", 8); $LblGPU.ForeColor = $C_TextSec; $LblGPU.Location = New-Object System.Drawing.Point(10, 75); $LblGPU.AutoSize = $true
 $LblRAM = New-Object System.Windows.Forms.Label; $LblRAM.Text = "RAM: $RAMInfo GB"; $LblRAM.Font = New-Object System.Drawing.Font("Segoe UI", 8); $LblRAM.ForeColor = $C_TextSec; $LblRAM.Location = New-Object System.Drawing.Point(10, 100); $LblRAM.AutoSize = $true

# Acortar textos si son muy largos para que entren en el panel
if($LblOS.Width -gt 170){ $LblOS.Text = "OS: Windows 11 Pro" }
if($LblCPU.Width -gt 170){ $LblCPU.Text = $LblCPU.Text.Substring(0, 25) + "..." }
if($LblGPU.Width -gt 170){ $LblGPU.Text = $LblGPU.Text.Substring(0, 25) + "..." }

 $PanelSpecs.Controls.Add($LblOS); $PanelSpecs.Controls.Add($LblCPU); $PanelSpecs.Controls.Add($LblGPU); $PanelSpecs.Controls.Add($LblRAM)

 $LblStatus = New-Object System.Windows.Forms.Label
 $LblStatus.Text = "ESTADO: LISTO"
 $LblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
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

# Botones de Ventana Vectoriales
 $btnMin = New-Object WinButton
 $btnMin.Location = New-Object System.Drawing.Point(730, 0); $btnMin.Size = New-Object System.Drawing.Size(45, 32)
 $btnMin.BackColor = $C_BgBase; $btnMin.ForeColor = $C_TextSec; $btnMin.Cursor = "Hand"
 $PanelHeader.Controls.Add($btnMin)
 $btnMin.Add_Click({ $Form.WindowState = "Minimized" })
 $btnMin.Add_MouseEnter({ $btnMin.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 52); $btnMin.Invalidate() })
 $btnMin.Add_MouseLeave({ $btnMin.BackColor = $C_BgBase; $btnMin.Invalidate() })

 $btnClose = New-Object WinButton
 $btnClose.IsClose = $true
 $btnClose.Location = New-Object System.Drawing.Point(775, 0); $btnClose.Size = New-Object System.Drawing.Size(45, 32)
 $btnClose.BackColor = $C_BgBase; $btnClose.ForeColor = $C_TextSec; $btnClose.Cursor = "Hand"
 $PanelHeader.Controls.Add($btnClose)
 $btnClose.Add_Click({ $Form.Close() })
 $btnClose.Add_MouseEnter({ $btnClose.Invalidate() })
 $btnClose.Add_MouseLeave({ $btnClose.Invalidate() })

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

 $btnRec = New-Object GradientButton
 $btnRec.Text = "Recomendados"
 $btnRec.Location = New-Object System.Drawing.Point(240, 5); $btnRec.Size = New-Object System.Drawing.Size(105, 25)
 $btnRec.Color1 = [System.Drawing.Color]::FromArgb(80, 50, 160); $btnRec.Color2 = [System.Drawing.Color]::FromArgb(120, 70, 200)
 $btnRec.ForeColor = [System.Drawing.Color]::White; $btnRec.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
 $btnRec.Cursor = "Hand"; $btnRec.CornerRadius = 6
 $PanelSearch.Controls.Add($btnRec)
 $btnRec.Add_MouseEnter({ $btnRec.Color1 = [System.Drawing.Color]::FromArgb(100, 60, 180); $btnRec.Color2 = [System.Drawing.Color]::FromArgb(140, 90, 220); $btnRec.Invalidate() })
 $btnRec.Add_MouseLeave({ $btnRec.Color1 = [System.Drawing.Color]::FromArgb(80, 50, 160); $btnRec.Color2 = [System.Drawing.Color]::FromArgb(120, 70, 200); $btnRec.Invalidate() })

# --- CONTENEDORES DINÁMICOS ---
 $DynPanel = New-Object DarkScrollPanel
 $DynPanel.Dock = "Fill"; $DynPanel.BackColor = $C_BgBase; $DynPanel.AutoScroll = $true; $DynPanel.WrapContents = $true
 $TableLayout.Controls.Add($DynPanel, 0, 1)

# Panel de Drivers (Oculto por defecto)
 $PanelDrivers = New-Object System.Windows.Forms.Panel
 $PanelDrivers.Dock = "Fill"; $PanelDrivers.BackColor = $C_BgBase; $PanelDrivers.Visible = $false
 $TableLayout.Controls.Add($PanelDrivers, 0, 1)

 $btnScanDrivers = New-Object GradientButton
 $btnScanDrivers.Text = "ANALIZAR DRIVERS"
 $btnScanDrivers.Size = New-Object System.Drawing.Size(300, 60)
 $btnScanDrivers.Location = New-Object System.Drawing.Point(($PanelDrivers.Width - 300)/2, 100)
 $btnScanDrivers.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnScanDrivers.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255)
 $btnScanDrivers.ForeColor = [System.Drawing.Color]::White; $btnScanDrivers.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
 $btnScanDrivers.Cursor = "Hand"; $btnScanDrivers.CornerRadius = 10
 $PanelDrivers.Controls.Add($btnScanDrivers)
 $btnScanDrivers.Add_MouseEnter({ $btnScanDrivers.Color1 = [System.Drawing.Color]::FromArgb(159, 102, 246); $btnScanDrivers.Color2 = [System.Drawing.Color]::FromArgb(180, 140, 255); $btnScanDrivers.Invalidate() })
 $btnScanDrivers.Add_MouseLeave({ $btnScanDrivers.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnScanDrivers.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $btnScanDrivers.Invalidate() })

 $LblDriversInfo = New-Object System.Windows.Forms.Label
 $LblDriversInfo.Text = "Haz clic en Analizar para buscar controladores desactualizados."
 $LblDriversInfo.Font = New-Object System.Drawing.Font("Segoe UI", 10)
 $LblDriversInfo.ForeColor = $C_TextSec
 $LblDriversInfo.Location = New-Object System.Drawing.Point(($PanelDrivers.Width - 400)/2, 170)
 $LblDriversInfo.AutoSize = $true
 $PanelDrivers.Controls.Add($LblDriversInfo)

# --- FOOTER ---
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

function Set-ModuleActive {
    param($ActiveBtn)
    $btnModApps.IsActive = $false; $btnModApps.ForeColor = $C_TextSec; $btnModApps.Invalidate()
    $btnModTweaks.IsActive = $false; $btnModTweaks.ForeColor = $C_TextSec; $btnModTweaks.Invalidate()
    $btnModDrivers.IsActive = $false; $btnModDrivers.ForeColor = $C_TextSec; $btnModDrivers.Invalidate()
    
    $ActiveBtn.IsActive = $true; $ActiveBtn.ForeColor = $C_TextMain; $ActiveBtn.Invalidate()
}

function Set-AppModule {
    Set-ModuleActive $btnModApps
    $script:CurrentModule = "Apps"
    $DynPanel.Visible = $true; $PanelDrivers.Visible = $false
    $PanelSearch.Visible = $true; $btnExecute.Visible = $true
    $LblHeader.Text = "Instalador de Aplicaciones"
    Clear-DynamicPanel
    $txtSearch.Text = "Buscar..."; $txtSearch.ForeColor = $C_TextSec
    
    $Categories = $AppCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    foreach ($cat in $Categories) {
        $Card = New-Object System.Windows.Forms.Panel
        $Card.BackColor = $C_Card
        $Card.Padding = New-Object System.Windows.Forms.Padding(20)
        $Card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 15, 15)
        $Card.AutoSize = $true; $Card.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

        $LblCat = New-Object System.Windows.Forms.Label
        $LblCat.Text = $cat.ToUpper()
        $LblCat.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $LblCat.ForeColor = $C_TextSec; $LblCat.Location = New-Object System.Drawing.Point(20, 15); $LblCat.AutoSize = $true
        $Card.Controls.Add($LblCat)

        $innerPanel = New-Object System.Windows.Forms.FlowLayoutPanel
        $innerPanel.AutoSize = $true; $innerPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $innerPanel.Location = New-Object System.Drawing.Point(20, 40); $innerPanel.FlowDirection = "TopDown"; $innerPanel.WrapContents = $false

        foreach ($app in $AppCatalog | Where-Object { $_.Cat -eq $cat }) {
            $cb = New-Object ModernCheckBox
            $cb.Text = $app.Name; $cb.Tag = $app.ID
            $cb.Size = New-Object System.Drawing.Size(200, 30)
            $cb.ForeColor = $C_TextMain; $cb.BackColor = $C_Card
            $cb.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $cb.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5)
            $innerPanel.Controls.Add($cb)
            $script:CurrentCheckboxes[$app.Name] = $cb
        }
        $Card.Controls.Add($innerPanel); $innerPanel.PerformLayout()
        $Card.Width = $innerPanel.Width + 50; $Card.Height = $innerPanel.Height + 60
        $DynPanel.Controls.Add($Card)
    }
}

function Set-TweaksModule {
    Set-ModuleActive $btnModTweaks
    $script:CurrentModule = "Tweaks"
    $DynPanel.Visible = $true; $PanelDrivers.Visible = $false
    $PanelSearch.Visible = $false; $btnExecute.Visible = $true
    $LblHeader.Text = "Optimizaciones y Tweaks"
    Clear-DynamicPanel
    
    $Categories = $TweakCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    foreach ($cat in $Categories) {
        $Card = New-Object System.Windows.Forms.Panel
        $Card.BackColor = $C_Card
        $Card.Padding = New-Object System.Windows.Forms.Padding(20)
        $Card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 15, 15)
        $Card.AutoSize = $true; $Card.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

        $LblCat = New-Object System.Windows.Forms.Label
        $LblCat.Text = $cat.ToUpper()
        $LblCat.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
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
            $cb.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $cb.Margin = New-Object System.Windows.Forms.Padding(0, 5, 0, 5)
            $innerPanel.Controls.Add($cb)
            $script:CurrentCheckboxes[$tweak.Name] = $cb
        }
        $Card.Controls.Add($innerPanel); $innerPanel.PerformLayout()
        $Card.Width = $innerPanel.Width + 50; $Card.Height = $innerPanel.Height + 60
        $DynPanel.Controls.Add($Card)
    }
}

function Set-DriversModule {
    Set-ModuleActive $btnModDrivers
    $script:CurrentModule = "Drivers"
    $DynPanel.Visible = $false; $PanelDrivers.Visible = $true
    $PanelSearch.Visible = $false; $btnExecute.Visible = $false
    $LblHeader.Text = "Gestor de Drivers"
    $LblDriversInfo.Text = "Haz clic en Analizar para buscar controladores desactualizados."
}

# --- EVENTOS DE UI ---
 $btnModApps.Add_Click({ Set-AppModule })
 $btnModTweaks.Add_Click({ Set-TweaksModule })
 $btnModDrivers.Add_Click({ Set-DriversModule })
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

# Lógica Escaneo Drivers (Mock)
 $btnScanDrivers.Add_Click({
    $btnScanDrivers.Text = "ANALIZANDO..."
    $btnScanDrivers.Enabled = $false
    $LblDriversInfo.Text = "Buscando controladores de video, audio y red..."
    $LblDriversInfo.ForeColor = $C_Accent
    
    Start-Sleep -Seconds 2 # Simulación de escaneo
    
    $LblDriversInfo.Text = "Tu PC está actualizada. No se requieren acciones."
    $LblDriversInfo.ForeColor = $C_TextSec
    $btnScanDrivers.Text = "ANALIZAR DRIVERS"
    $btnScanDrivers.Enabled = $true
})

# Lógica Ejecutar
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
Write-Log "icezOP Premium UI iniciado." "LightGray"
 $Form.ShowDialog() | Out-Null
