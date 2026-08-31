[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- INYECCIÓN C# (Controles Modernos Anti-Null) ---
if (-not ([System.Management.Automation.PSTypeName]'GradientButton').Type) {
    $CSharpCode = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
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
        this.Cursor = Cursors.Hand; 
        this.Font = new Font("Segoe UI Variable Text", 10, FontStyle.Bold); 
        this.Padding = new Padding(30, 12, 30, 12); 
    }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias;
        Rectangle rect = new Rectangle(0, 0, this.Width - 1, this.Height - 1);
        using (GraphicsPath path = new GraphicsPath()) {
            path.AddArc(rect.X, rect.Y, CornerRadius, CornerRadius, 180, 90); path.AddArc(rect.Right - CornerRadius, rect.Y, CornerRadius, CornerRadius, 270, 90);
            path.AddArc(rect.Right - CornerRadius, rect.Bottom - CornerRadius, CornerRadius, CornerRadius, 0, 90); path.AddArc(rect.X, rect.Bottom - CornerRadius, CornerRadius, CornerRadius, 90, 90); path.CloseFigure();
            this.Region = new Region(path);
            using (LinearGradientBrush brush = new LinearGradientBrush(rect, Color1, Color2, LinearGradientMode.Vertical)) { g.FillPath(brush, path); }
        }
        TextRenderer.DrawText(g, this.Text, this.Font, rect, Color.White, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
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
        Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.Clear(this.BackColor);
        Rectangle boxRect = new Rectangle(0, (this.Height - 16) / 2, 16, 16);
        using (GraphicsPath path = new GraphicsPath()) {
            int r = 4; path.AddArc(boxRect.X, boxRect.Y, r, r, 180, 90); path.AddArc(boxRect.Right - r, boxRect.Y, r, r, 270, 90);
            path.AddArc(boxRect.Right - r, boxRect.Bottom - r, r, r, 0, 90); path.AddArc(boxRect.X, boxRect.Bottom - r, r, r, 90, 90); path.CloseFigure();
            if (this.Checked) {
                using (SolidBrush b = new SolidBrush(CheckColor)) { g.FillPath(b, path); }
                using (Pen p = new Pen(Color.White, 2)) { g.DrawLine(p, boxRect.X + 3, boxRect.Y + 8, boxRect.X + 7, boxRect.Y + 12); g.DrawLine(p, boxRect.X + 7, boxRect.Y + 12, boxRect.X + 13, boxRect.Y + 4); }
            } else {
                using (SolidBrush b = new SolidBrush(Color.FromArgb(45, 45, 52))) { g.FillPath(b, path); }
                using (Pen p = new Pen(Color.FromArgb(70, 70, 80), 1)) { g.DrawPath(p, path); }
            }
        }
        Rectangle textRect = new Rectangle(boxRect.Right + 8, 0, this.Width - boxRect.Right - 8, this.Height);
        TextRenderer.DrawText(g, this.Text, this.Font, textRect, this.ForeColor, TextFormatFlags.Left | TextFormatFlags.VerticalCenter);
    }
}

public class CategoryCard : Panel {
    public Label Header { get; set; } 
    public FlowLayoutPanel Inner { get; set; }
    public CategoryCard() {
        this.BackColor = Color.FromArgb(30, 30, 36); this.Size = new Size(350, 45); this.Margin = new Padding(0, 0, 0, 15); this.Cursor = Cursors.Hand;
        Header = new Label(); Header.Dock = DockStyle.Fill; Header.TextAlign = ContentAlignment.MiddleLeft; Header.Padding = new Padding(20, 0, 0, 0);
        Header.Font = new Font("Segoe UI Variable Text", 10, FontStyle.Bold); Header.ForeColor = Color.White; Header.BackColor = Color.FromArgb(40, 40, 48); 
        Inner = new FlowLayoutPanel(); Inner.AutoSize = true; Inner.AutoSizeMode = AutoSizeMode.GrowAndShrink; Inner.Location = new Point(0, 45);
        Inner.Size = new Size(350, 0); Inner.FlowDirection = FlowDirection.TopDown; Inner.WrapContents = false; Inner.Visible = false; Inner.Padding = new Padding(20, 15,20, 15); 
        
        Controls.Add(Inner); Controls.Add(Header);
        Header.MouseEnter += (s, e) => { this.BackColor = Color.FromArgb(45, 45, 52); Header.BackColor = Color.FromArgb(50, 50, 60); };
        Header.MouseLeave += (s, e) => { this.BackColor = Color.FromArgb(30, 30, 36); Header.BackColor = Color.FromArgb(40, 40, 48); };
    }
}

public class DriverCard : Panel {
    public ModernCheckBox Check { get; set; } 
    public Label LblName { get; set; } 
    public Label LblStatus { get; set; }
    public DriverCard(bool isPending) {
        this.BackColor = Color.FromArgb(30, 30, 36); this.Size = new Size(760, 50); this.Margin = new Padding(0, 0, 0, 10);
        int x = 20;
        if (isPending) {
            Check = new ModernCheckBox(); Check.Location = new Point(x, 17); Check.Size = new Size(20, 20); Check.BackColor = this.BackColor; Controls.Add(Check); x += 35;
        } else { x += 35; }
        LblName = new Label(); LblName.Location = new Point(x, 15); LblName.Font = new Font("Segoe UI Variable Text", 9, FontStyle.Bold); LblName.ForeColor = isPending ? Color.White : Color.FromArgb(100, 100, 100); LblName.AutoSize = true; Controls.Add(LblName);
        LblStatus = new Label(); LblStatus.Location = new Point(630, 17); LblStatus.Font = new Font("Segoe UI Variable Text", 8, FontStyle.Bold); LblStatus.AutoSize = true; Controls.Add(LblStatus);
    }
}

public class WinButton : Button {
    public bool IsClose { get; set; } 
    public int IconType { get; set; }
    public WinButton() { this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; this.Cursor = Cursors.Hand; }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics; g.Clear(this.BackColor);
        if (IsClose && this.ClientRectangle.Contains(this.PointToClient(Cursor.Position))) { g.FillRectangle(new SolidBrush(Color.FromArgb(232, 24, 24)), this.ClientRectangle); using (Pen p = new Pen(Color.White, 2)) { g.DrawLine(p, 16, 10, 26, 20); g.DrawLine(p, 26, 10, 16, 20); } }
        else { using (Pen p = new Pen(this.ForeColor, 2)) { if (IsClose) { g.DrawLine(p, 16, 10, 26, 20); g.DrawLine(p, 26, 10, 16, 20); } else if (IconType == 3) { g.DrawLine(p, 15, 12, 27, 12); g.DrawLine(p, 15, 16, 27, 16); g.DrawLine(p, 15, 20, 27, 20); } else if (IconType == 4) { g.DrawEllipse(p, 19, 11, 10, 10); g.DrawLine(p, 24, 8, 24, 11); g.DrawLine(p, 24, 21, 24, 24); g.DrawLine(p, 16, 16, 19, 16); g.DrawLine(p, 29, 16, 32, 16); } else { g.DrawLine(p, 15, 15, 27, 15); } } }
    }
}

public class NavButton : Button {
    public bool IsActive { get; set; } 
    public int IconType { get; set; }
    public NavButton() { this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; this.DoubleBuffered = true; this.Cursor = Cursors.Hand; }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.Clear(this.BackColor);
        if (IsActive) { g.FillRectangle(new SolidBrush(Color.FromArgb(35, 35, 42)), this.ClientRectangle); g.FillRectangle(new SolidBrush(Color.FromArgb(139, 92, 246)), new Rectangle(0, 5, 4, this.Height - 10)); }
        int iconX = 15; int iconY = this.Height / 2 - 8; Color iconColor = this.IsActive ? Color.FromArgb(165, 120, 255) : Color.FromArgb(140, 140, 150);
        using (Pen p = new Pen(iconColor, 2)) {
            if (IconType == 0) { g.DrawRectangle(p, iconX, iconY, 6, 6); g.DrawRectangle(p, iconX+10, iconY, 6, 6); g.DrawRectangle(p, iconX, iconY+10, 6, 6); g.DrawRectangle(p, iconX+10, iconY+10, 6, 6); }
            else if (IconType == 1) { g.DrawEllipse(p, iconX+2, iconY+2, 12, 12); g.DrawEllipse(p, iconX+6, iconY+6, 4, 4); }
            else if (IconType == 2) { g.DrawRectangle(p, iconX+2, iconY, 12, 16); g.DrawLine(p, iconX, iconY+4, iconX+2, iconY+4); g.DrawLine(p, iconX+14, iconY+4, iconX+16, iconY+4); }
            else if (IconType == 4) { g.DrawEllipse(p, iconX+4, iconY, 10, 10); g.DrawLine(p, iconX+9, iconY-2, iconX+9, iconY); g.DrawLine(p, iconX+9, iconY+10, iconX+9, iconY+12); g.DrawLine(p, iconX+1, iconY+5, iconX+4, iconY+5); g.DrawLine(p, iconX+14, iconY+5, iconX+17, iconY+5); } 
        }
        if (this.Width > 100) { TextRenderer.DrawText(g, this.Text, this.Font, new Rectangle(40, 0, this.Width-40, this.Height), this.ForeColor, TextFormatFlags.Left | TextFormatFlags.VerticalCenter); }
    }
}

public class TransparentOverlay : Panel {
    public TransparentOverlay() { this.DoubleBuffered = true; this.BackColor = Color.FromArgb(180, 0, 0, 0); }
}
"@
    Add-Type -TypeDefinition $CSharpCode -ReferencedAssemblies System.Windows.Forms, System.Drawing
}

# --- MOTOR ASÍNCRONO Y LOGS ---
 $sync = [Hashtable]::Synchronized(@{ LogQueue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new()); IsRunning = $false; MaxProgress = 0; CurrentProgress = 0 })
 $UITimer = New-Object System.Windows.Forms.Timer; $UITimer.Interval = 150
function Write-Log($texto, $color = "White") { $sync.LogQueue.Enqueue(@{ Text = $texto; Color = $color }) }

# --- TEMA ICEZOP ---
 $C_BgBase = [System.Drawing.Color]::FromArgb(15, 15, 18); $C_BgLayer = [System.Drawing.Color]::FromArgb(25, 25, 30); $C_Card = [System.Drawing.Color]::FromArgb(30, 30, 36)
 $C_Accent = [System.Drawing.Color]::FromArgb(139, 92, 246); $C_TextMain = [System.Drawing.Color]::FromArgb(245, 245, 250); $C_TextSec = [System.Drawing.Color]::FromArgb(140, 140, 150)
 $FontGlobal = New-Object System.Drawing.Font("Segoe UI Variable Text", 10)

# --- CARGA DE JSON ---
 $AppsJson = '[ { "Name": "Google Chrome", "ID": "Google.Chrome", "Cat": "Navegadores" }, { "Name": "Firefox", "ID": "Mozilla.Firefox", "Cat": "Navegadores" }, { "Name": "Discord", "ID": "Discord.Discord", "Cat": "Comunicacion" } ]'
 $TweaksJson = '[ { "Name": "Desactivar Telemetría", "Script": "Set-ItemProperty ''HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection'' -Name ''AllowTelemetry'' -Value 0 -Type DWord -Force", "Cat": "Privacidad" }, { "Name": "Desactivar Cortana", "Script": "Set-ItemProperty ''HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Windows Search'' -Name ''AllowCortana'' -Value 0 -Type DWord -Force", "Cat": "Privacidad" } ]'
 $DriversJson = '[ { "Name": "NVIDIA GeForce RTX 4090", "Command": "pnputil /scan-devices", "Status": "Pendiente" }, { "Name": "Realtek Audio Controller", "Command": "pnputil /scan-devices", "Status": "Pendiente" }, { "Name": "Intel Core i9 Processor", "Command": "pnputil /scan-devices", "Status": "Actualizado" } ]'

try { $AppCatalog = Get-Content -Path "$PSScriptRoot\apps.json" -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $AppCatalog = $AppsJson | ConvertFrom-Json }
try { $TweakCatalog = Get-Content -Path "$PSScriptRoot\tweaks.json" -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $TweakCatalog = $TweaksJson | ConvertFrom-Json }
try { $DriverCatalog = Get-Content -Path "$PSScriptRoot\drivers.json" -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $DriverCatalog = $DriversJson | ConvertFrom-Json }

# --- FORMULARIO BASE ---
 $Form = New-Object System.Windows.Forms.Form; $Form.Text = "icezOP"; $Form.Size = New-Object System.Drawing.Size(1100, 750); $Form.StartPosition = "CenterScreen"; $Form.BackColor = $C_BgBase; $Form.FormBorderStyle = "None"
 $Radius = 15; $FormPath = New-Object System.Drawing.Drawing2D.GraphicsPath
 $FormPath.AddArc(0, 0, $Radius, $Radius, 180, 90); $FormPath.AddArc($Form.Width - $Radius, 0, $Radius, $Radius, 270, 90); $FormPath.AddArc($Form.Width - $Radius, $Form.Height - $Radius, $Radius, $Radius, 0, 90); $FormPath.AddArc(0, $Form.Height - $Radius, $Radius, $Radius, 90, 90); $FormPath.CloseFigure(); $Form.Region = New-Object System.Drawing.Region($FormPath)
 $DragInfo = @{ Dragging = $false; X = 0; Y = 0 }

# --- ESTRUCTURA RAIZ ---
 $RootLayout = New-Object System.Windows.Forms.TableLayoutPanel; $RootLayout.Dock = "Fill"; $RootLayout.ColumnCount = 1; $RootLayout.RowCount = 2
 $RootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70))) | Out-Null
 $RootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
 $Form.Controls.Add($RootLayout)

# 1. HEADER CENTRAL
 $PanelHeader = New-Object System.Windows.Forms.Panel; $PanelHeader.Dock = "Fill"; $PanelHeader.BackColor = $C_BgBase; $RootLayout.Controls.Add($PanelHeader, 0, 0)
 $PanelHeader.Add_MouseDown({ if($_.Button -eq 'Left'){ $script:DragInfo.Dragging = $true; $script:DragInfo.X = $_.X; $script:DragInfo.Y = $_.Y } })
 $PanelHeader.Add_MouseMove({ if($script:DragInfo.Dragging){ $Form.Left += $_.X - $script:DragInfo.X; $Form.Top += $_.Y - $script:DragInfo.Y } })
 $PanelHeader.Add_MouseUp({ $script:DragInfo.Dragging = $false })

 $LblTitle = New-Object System.Windows.Forms.Label; $LblTitle.Text = "icezOP"; $LblTitle.Font = New-Object System.Drawing.Font("Segoe Script", 26, [System.Drawing.FontStyle]::Bold); $LblTitle.ForeColor = $C_Accent; $LblTitle.Dock = "Fill"; $LblTitle.TextAlign = "MiddleCenter"; $LblTitle.AutoSize = $false; $PanelHeader.Controls.Add($LblTitle)

 $btnClose = New-Object WinButton; $btnClose.IsClose = $true; $btnClose.Location = New-Object System.Drawing.Point(1030, 10); $btnClose.Size = New-Object System.Drawing.Size(45, 32); $btnClose.BackColor = $C_BgBase; $btnClose.ForeColor = $C_TextSec; $PanelHeader.Controls.Add($btnClose)
 $btnClose.Add_Click({ $Form.Close() })
 $btnMin = New-Object WinButton; $btnMin.Location = New-Object System.Drawing.Point(985, 10); $btnMin.Size = New-Object System.Drawing.Size(45, 32); $btnMin.BackColor = $C_BgBase; $btnMin.ForeColor = $C_TextSec; $PanelHeader.Controls.Add($btnMin)
 $btnMin.Add_Click({ $Form.WindowState = "Minimized" })
 $SepLine = New-Object System.Windows.Forms.Panel; $SepLine.Dock = "Bottom"; $SepLine.Height = 1; $SepLine.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50); $PanelHeader.Controls.Add($SepLine)

# 2. SPLIT CONTAINER
 $SplitCont = New-Object System.Windows.Forms.SplitContainer; $SplitCont.Dock = "Fill"; $SplitCont.SplitterWidth = 0; $SplitCont.SplitterDistance = 220; $SplitCont.BackColor = $C_BgBase; $RootLayout.Controls.Add($SplitCont, 0, 1)

# 2a. SIDEBAR
 $Sidebar = New-Object System.Windows.Forms.Panel; $Sidebar.Dock = "Fill"; $Sidebar.BackColor = $C_BgLayer; $SplitCont.Panel1.Controls.Add($Sidebar)
 $btnHamburger = New-Object WinButton; $btnHamburger.IconType = 3; $btnHamburger.Location = New-Object System.Drawing.Point(0, 0); $btnHamburger.Size = New-Object System.Drawing.Size(45, 32); $btnHamburger.BackColor = $C_BgLayer; $btnHamburger.ForeColor = $C_TextSec; $Sidebar.Controls.Add($btnHamburger)

 $btnModApps = New-Object NavButton; $btnModApps.Text = "Aplicaciones"; $btnModApps.IconType = 0; $btnModApps.IsActive = $true; $btnModApps.Location = New-Object System.Drawing.Point(0, 40); $btnModApps.Size = New-Object System.Drawing.Size(220, 40); $btnModApps.BackColor = $C_BgLayer; $btnModApps.ForeColor = $C_TextMain; $btnModApps.Font = $FontGlobal; $Sidebar.Controls.Add($btnModApps)
 $btnModTweaks = New-Object NavButton; $btnModTweaks.Text = "Tweaks"; $btnModTweaks.IconType = 1; $btnModTweaks.Location = New-Object System.Drawing.Point(0, 80); $btnModTweaks.Size = New-Object System.Drawing.Size(220, 40); $btnModTweaks.BackColor = $C_BgLayer; $btnModTweaks.ForeColor = $C_TextSec; $btnModTweaks.Font = $FontGlobal; $Sidebar.Controls.Add($btnModTweaks)
 $btnModDrivers = New-Object NavButton; $btnModDrivers.Text = "Drivers"; $btnModDrivers.IconType = 2; $btnModDrivers.Location = New-Object System.Drawing.Point(0, 120); $btnModDrivers.Size = New-Object System.Drawing.Size(220, 40); $btnModDrivers.BackColor = $C_BgLayer; $btnModDrivers.ForeColor = $C_TextSec; $btnModDrivers.Font = $FontGlobal; $Sidebar.Controls.Add($btnModDrivers)
 $btnSettings = New-Object NavButton; $btnSettings.Text = "Configuración"; $btnSettings.IconType = 4; $btnSettings.Location = New-Object System.Drawing.Point(0, 620); $btnSettings.Size = New-Object System.Drawing.Size(220, 40); $btnSettings.BackColor = $C_BgLayer; $btnSettings.ForeColor = $C_TextSec; $btnSettings.Font = $FontGlobal; $Sidebar.Controls.Add($btnSettings)

# 2b. CONTENT AREA
 $PanelContent = New-Object System.Windows.Forms.Panel; $PanelContent.Dock = "Fill"; $PanelContent.BackColor = $C_BgBase; $SplitCont.Panel2.Controls.Add($PanelContent)

# --- CONTENEDORES DINÁMICOS ---
 $DynPanel = New-Object System.Windows.Forms.FlowLayoutPanel; $DynPanel.Dock = "Fill"; $DynPanel.BackColor = $C_BgBase; $DynPanel.AutoScroll = $true; $DynPanel.Padding = New-Object System.Windows.Forms.Padding(20); $PanelContent.Controls.Add($DynPanel)

# --- PANEL DRIVERS ---
 $PanelDrivers = New-Object System.Windows.Forms.Panel; $PanelDrivers.Dock = "Fill"; $PanelDrivers.BackColor = $C_BgBase; $PanelDrivers.Visible = $false; $PanelContent.Controls.Add($PanelDrivers)
 $LblDriverTitle = New-Object System.Windows.Forms.Label; $LblDriverTitle.Text = "GESTOR DE DRIVERS"; $LblDriverTitle.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 20, [System.Drawing.FontStyle]::Bold); $LblDriverTitle.ForeColor = $C_TextMain; $LblDriverTitle.Location = New-Object System.Drawing.Point(250, 20); $LblDriverTitle.AutoSize = $true; $PanelDrivers.Controls.Add($LblDriverTitle)
 $DriverListPanel = New-Object System.Windows.Forms.FlowLayoutPanel; $DriverListPanel.Location = New-Object System.Drawing.Point(150, 80); $DriverListPanel.Size = New-Object System.Drawing.Size(760, 450); $DriverListPanel.BackColor = $C_BgBase; $DriverListPanel.AutoScroll = $true; $DriverListPanel.FlowDirection = "TopDown"; $DriverListPanel.WrapContents = $false; $PanelDrivers.Controls.Add($DriverListPanel)
 $PanelDriverFooter = New-Object System.Windows.Forms.Panel; $PanelDriverFooter.Dock = "Bottom"; $PanelDriverFooter.BackColor = $C_BgBase; $PanelDriverFooter.Height = 60; $PanelDrivers.Controls.Add($PanelDriverFooter)
 $btnUpdateSelected = New-Object GradientButton; $btnUpdateSelected.Text = "Actualizar Seleccionados"; $btnUpdateSelected.Location = New-Object System.Drawing.Point(400, 10); $btnUpdateSelected.Size = New-Object System.Drawing.Size(220, 40); $btnUpdateSelected.Color1 = [System.Drawing.Color]::FromArgb(60, 60, 70); $btnUpdateSelected.Color2 = [System.Drawing.Color]::FromArgb(80, 80, 90); $btnUpdateSelected.Visible = $false; $PanelDriverFooter.Controls.Add($btnUpdateSelected)
 $btnUpdateAll = New-Object GradientButton; $btnUpdateAll.Text = "Actualizar Todos"; $btnUpdateAll.Location = New-Object System.Drawing.Point(650, 10); $btnUpdateAll.Size = New-Object System.Drawing.Size(200, 40); $btnUpdateAll.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnUpdateAll.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $PanelDriverFooter.Controls.Add($btnUpdateAll)

# --- OVERLAY Y MODAL HOST ---
 $Overlay = New-Object TransparentOverlay; $Overlay.Dock = "Fill"; $Overlay.Visible = $false; $Form.Controls.Add($Overlay); $Overlay.BringToFront()
 $Overlay.Add_Click({ Hide-Modal })
 $ModalHost = New-Object System.Windows.Forms.Panel; $ModalHost.Size = New-Object System.Drawing.Size(600, 500); $ModalHost.Visible = $false; $ModalHost.BackColor = $C_Card; $Overlay.Controls.Add($ModalHost)
 $ModalRadius = 15; $ModalPath = New-Object System.Drawing.Drawing2D.GraphicsPath
 $ModalPath.AddArc(0, 0, $ModalRadius, $ModalRadius, 180, 90); $ModalPath.AddArc($ModalHost.Width - $ModalRadius, 0, $ModalRadius, $ModalRadius, 270, 90); $ModalPath.AddArc($ModalHost.Width - $ModalRadius, $ModalHost.Height - $ModalRadius, $ModalRadius, $ModalRadius, 0, 90); $ModalPath.AddArc(0, $ModalHost.Height - $ModalRadius, $ModalRadius, $ModalRadius, 90, 90); $ModalPath.CloseFigure(); $ModalHost.Region = New-Object System.Drawing.Region($ModalPath)

function Show-Modal($TitleText, $ContentControl) {
    $ModalHost.Controls.Clear()
    $LblModalTitle = New-Object System.Windows.Forms.Label; $LblModalTitle.Text = $TitleText; $LblModalTitle.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 14, [System.Drawing.FontStyle]::Bold); $LblModalTitle.ForeColor = $C_Accent; $LblModalTitle.Location = New-Object System.Drawing.Point(20, 15); $LblModalTitle.AutoSize = $true; $ModalHost.Controls.Add($LblModalTitle)
    $BtnCloseModal = New-Object WinButton; $BtnCloseModal.IsClose = $true; $BtnCloseModal.Location = New-Object System.Drawing.Point(550, 10); $BtnCloseModal.Size = New-Object System.Drawing.Size(40, 32); $BtnCloseModal.BackColor = $C_Card; $BtnCloseModal.ForeColor = $C_TextSec; $ModalHost.Controls.Add($BtnCloseModal)
    $BtnCloseModal.Add_Click({ Hide-Modal })
    $ContentControl.Location = New-Object System.Drawing.Point(20, 60); $ContentControl.Size = New-Object System.Drawing.Size(560, 420); $ModalHost.Controls.Add($ContentControl)
    $Overlay.Visible = $true; $ModalHost.Visible = $true
    $ModalHost.Location = New-Object System.Drawing.Point(($Overlay.Width - $ModalHost.Width)/2, ($Overlay.Height - $ModalHost.Height)/2)
}
function Hide-Modal { $Overlay.Visible = $false; $ModalHost.Visible = $false }

# --- LÓGICA DE NAVEGACIÓN Y SELECCIÓN PERSISTENTE ---
 $CurrentCheckboxes = @{}
 $CurrentModule = "Apps"

function Set-ModuleActive { param($ActiveBtn); $btnModApps.IsActive = $false; $btnModApps.ForeColor = $C_TextSec; $btnModApps.Invalidate(); $btnModTweaks.IsActive = $false; $btnModTweaks.ForeColor = $C_TextSec; $btnModTweaks.Invalidate(); $btnModDrivers.IsActive = $false; $btnModDrivers.ForeColor = $C_TextSec; $btnModDrivers.Invalidate(); $ActiveBtn.IsActive = $true; $ActiveBtn.ForeColor = $C_TextMain; $ActiveBtn.Invalidate() }

function Open-CategoryModal($CatName, $Items, $IsTweak=$false) {
    $ModalContent = New-Object System.Windows.Forms.Panel; $ModalContent.BackColor = $C_Card; $ModalContent.AutoScroll = $true
    $InnerFlow = New-Object System.Windows.Forms.FlowLayoutPanel; $InnerFlow.Dock = "Fill"; $InnerFlow.FlowDirection = "TopDown"; $InnerFlow.WrapContents = $false; $InnerFlow.BackColor = $C_Card; $InnerFlow.Padding = "10,10,10,10"
    
    foreach ($item in $Items) {
        $cb = New-Object ModernCheckBox; $cb.Text = $item.Name; $cb.Tag = if($IsTweak){$item.Script}else{$item.ID}; $cb.Size = New-Object System.Drawing.Size(500, 30); $cb.ForeColor = $C_TextMain; $cb.BackColor = $C_Card; $cb.Font = $FontGlobal; $cb.Margin = "0,5,0,5"
        
        # Restaurar estado si ya estaba marcado en memoria
        if ($script:CurrentCheckboxes.ContainsKey($item.Name)) { $cb.Checked = $true }
        
        # Evento para guardar/cargar estado en el diccionario global
        $cb.Add_CheckedChanged({
            if ($this.Checked) { $script:CurrentCheckboxes[$this.Text] = $this }
            else { $script:CurrentCheckboxes.Remove($this.Text) }
        }.GetNewClosure())
        
        $InnerFlow.Controls.Add($cb)
    }
    $ModalContent.Controls.Add($InnerFlow)
    Show-Modal $CatName.ToUpper() $ModalContent
}

 $btnModApps.Add_Click({
    Set-ModuleActive $btnModApps; $script:CurrentModule = "Apps"
    $DynPanel.Visible = $true; $PanelDrivers.Visible = $false; $btnExecute.Visible = $true; $DynPanel.Controls.Clear()
    $Cats = $AppCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    foreach ($cat in $Cats) {
        $Card = New-Object CategoryCard; $Card.Width = $DynPanel.Width - 60
        $Card.Header.Text = "  $($cat.ToUpper())"
        $Card.Add_Click({ Open-CategoryModal $cat ($AppCatalog | Where-Object { $_.Cat -eq $cat }) $false }.GetNewClosure())
        $DynPanel.Controls.Add($Card)
    }
})

 $btnModTweaks.Add_Click({
    Set-ModuleActive $btnModTweaks; $script:CurrentModule = "Tweaks"
    $DynPanel.Visible = $true; $PanelDrivers.Visible = $false; $btnExecute.Visible = $true; $DynPanel.Controls.Clear()
    $Cats = $TweakCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    foreach ($cat in $Cats) {
        $Card = New-Object CategoryCard; $Card.Width = $DynPanel.Width - 60
        $Card.Header.Text = "  $($cat.ToUpper())"
        $Card.Add_Click({ Open-CategoryModal $cat ($TweakCatalog | Where-Object { $_.Cat -eq $cat }) $true }.GetNewClosure())
        $DynPanel.Controls.Add($Card)
    }
})

 $btnModDrivers.Add_Click({
    Set-ModuleActive $btnModDrivers; $script:CurrentModule = "Drivers"
    $DynPanel.Visible = $false; $PanelDrivers.Visible = $true; $btnExecute.Visible = $false
    $DriverListPanel.Controls.Clear()
    foreach ($drv in $DriverCatalog) {
        $isPending = ($drv.Status -ne "Actualizado")
        $dCard = New-Object DriverCard($isPending)
        $dCard.LblName.Text = $drv.Name
        $dCard.LblStatus.Text = "[$($drv.Status)]"
        $dCard.LblStatus.ForeColor = if($isPending){[System.Drawing.Color]::FromArgb(250, 204, 21)}else{[System.Drawing.Color]::FromArgb(100, 100, 100)}
        $DriverListPanel.Controls.Add($dCard)
        if($isPending -and $dCard.Check) { 
            $dCard.Check.Add_CheckedChanged({ $anyChecked = $false; foreach($c in $DriverListPanel.Controls) { if($c.Check -and $c.Check.Checked) { $anyChecked = $true; break } }; $btnUpdateSelected.Visible = $anyChecked }) 
        }
    }
})

 $btnSettings.Add_Click({
    $ModalContent = New-Object System.Windows.Forms.Panel; $ModalContent.BackColor = $C_Card
    $LblLang = New-Object System.Windows.Forms.Label; $LblLang.Text = "Idioma"; $LblLang.Location = "20, 20"; $LblLang.Size = "100, 25"; $LblLang.Font = $FontGlobal; $LblLang.ForeColor = $C_TextMain; $ModalContent.Controls.Add($LblLang)
    $ComboLang = New-Object System.Windows.Forms.ComboBox; $ComboLang.Location = "150, 18"; $ComboLang.Size = "200, 25"; $ComboLang.BackColor = $C_BgBase; $ComboLang.ForeColor = $C_TextMain; $ComboLang.FlatStyle = "Flat"; $ComboLang.Items.AddRange(@("Español", "English")); $ComboLang.SelectedIndex = 0; $ModalContent.Controls.Add($ComboLang)
    $LblTheme = New-Object System.Windows.Forms.Label; $LblTheme.Text = "Tema"; $LblTheme.Location = "20, 60"; $LblTheme.Size = "100, 25"; $LblTheme.Font = $FontGlobal; $LblTheme.ForeColor = $C_TextMain; $ModalContent.Controls.Add($LblTheme)
    $ComboTheme = New-Object System.Windows.Forms.ComboBox; $ComboTheme.Location = "150, 58"; $ComboTheme.Size = "200, 25"; $ComboTheme.BackColor = $C_BgBase; $ComboTheme.ForeColor = $C_TextMain; $ComboTheme.FlatStyle = "Flat"; $ComboTheme.Items.AddRange(@("Oscuro", "Claro")); $ComboTheme.SelectedIndex = 0; $ModalContent.Controls.Add($ComboTheme)
    $LblTrans = New-Object System.Windows.Forms.Label; $LblTrans.Text = "Transparencia"; $LblTrans.Location = "20, 100"; $LblTrans.Size = "120, 25"; $LblTrans.Font = $FontGlobal; $LblTrans.ForeColor = $C_TextMain; $ModalContent.Controls.Add($LblTrans)
    $TrackTrans = New-Object System.Windows.Forms.TrackBar; $TrackTrans.Location = "150, 95"; $TrackTrans.Size = "200, 45"; $TrackTrans.Maximum = 100; $TrackTrans.Value = 80; $TrackTrans.BackColor = $C_Card; $ModalContent.Controls.Add($TrackTrans)
    $BtnSave = New-Object GradientButton; $BtnSave.Text = "Guardar y Cerrar"; $BtnSave.Location = "200, 170"; $BtnSave.Size = "200, 40"; $BtnSave.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $BtnSave.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $BtnSave.Add_Click({ Hide-Modal }); $ModalContent.Controls.Add($BtnSave)
    Show-Modal "CONFIGURACIÓN" $ModalContent
})

# --- EJECUCIÓN REAL DE DRIVERS ---
 $btnUpdateAll.Add_Click({ foreach($card in $DriverListPanel.Controls) { if($card.Check) { $card.Check.Checked = $true } }; $btnUpdateSelected.PerformClick() })
 $btnUpdateSelected.Add_Click({
    $sync.IsRunning = $true
    Write-Log "Iniciando escaneo y actualización de drivers..." "Cyan"
    $job = {
        param($syncHash)
        $syncHash.LogQueue.Enqueue(@{ Text="Ejecutando pnputil para escanear dispositivos..."; Color="Cyan" })
        Start-Process pnputil -ArgumentList "/scan-devices" -Wait -NoNewWindow
        $syncHash.LogQueue.Enqueue(@{ Text="Buscando actualizaciones de software vía Winget..."; Color="Cyan" })
        Start-Process winget -ArgumentList "upgrade --all --accept-package-agreements --accept-source-agreements -h" -Wait -NoNewWindow
        $syncHash.LogQueue.Enqueue(@{ Text="Proceso de drivers finalizado."; Color="Plum" })
        $syncHash.IsRunning = $false
    }
    $runspace = [runspacefactory]::CreateRunspace(); $runspace.Open(); $ps = [powershell]::Create(); $ps.Runspace = $runspace; $ps.AddScript($job).AddArgument($sync) | Out-Null; $ps.BeginInvoke() | Out-Null
})

# --- EJECUCIÓN REAL DE APPS Y TWEAKS ---
 $btnExecute = New-Object GradientButton; $btnExecute.Text = "EJECUTAR"; $btnExecute.Dock = "Bottom"; $btnExecute.Height = 50; $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $PanelContent.Controls.Add($btnExecute)
 $btnExecute.Add_Click({
    $visibleChecks = $CurrentCheckboxes.Values | Where-Object { $_.Checked }
    if (-not $visibleChecks.Count) { Write-Log "No hay opciones marcadas." "Yellow"; return }
    
    $sync.IsRunning = $true; $sync.MaxProgress = $visibleChecks.Count; $sync.CurrentProgress = 0
    $btnExecute.Text = "PROCESANDO..."; $btnExecute.Enabled = $false; $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(80, 50, 140); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(100, 60, 160); $btnExecute.Invalidate()
    
    $job = {
        param($items, $mod, $syncHash)
        foreach ($item in $items) {
            $name = $item.Text; $tag = $item.Tag
            if ($mod -eq "Apps") {
                $syncHash.LogQueue.Enqueue(@{ Text="Instalando $name (ID: $tag) vía Winget..."; Color="Cyan" })
                try {
                    $proc = Start-Process winget -ArgumentList "install --id $tag -e --accept-package-agreements --accept-source-agreements -h" -Wait -PassThru -NoNewWindow
                    if ($proc.ExitCode -eq 0) { $syncHash.LogQueue.Enqueue(@{ Text="$name instalado correctamente."; Color="MediumPurple" }) }
                    else { $syncHash.LogQueue.Enqueue(@{ Text="Error instalando $name (Código: $($proc.ExitCode))."; Color="Red" }) }
                } catch { $syncHash.LogQueue.Enqueue(@{ Text="Excepción al instalar $name."; Color="Red" }) }
            } elseif ($mod -eq "Tweaks") {
                $syncHash.LogQueue.Enqueue(@{ Text="Aplicando Tweak: $name"; Color="Cyan" })
                try {
                    $sb = [ScriptBlock]::Create($tag.ToString())
                    & $sb
                    $syncHash.LogQueue.Enqueue(@{ Text="OK: $name aplicado."; Color="MediumPurple" })
                } catch { $syncHash.LogQueue.Enqueue(@{ Text="Error en: $name -> $($_.Exception.Message)"; Color="Red" }) }
            }
            $syncHash.CurrentProgress++
        }
        $syncHash.LogQueue.Enqueue(@{ Text="--- PROCESO FINALIZADO ---"; Color="Plum" })
        $syncHash.IsRunning = $false
    }
    $runspace = [runspacefactory]::CreateRunspace(); $runspace.Open(); $ps = [powershell]::Create(); $ps.Runspace = $runspace; $ps.AddScript($job).AddArgument($visibleChecks).AddArgument($CurrentModule).AddArgument($sync) | Out-Null; $ps.BeginInvoke() | Out-Null
})

# --- ANIMACIÓN DEL MENÚ LATERAL ---
 $IsSidebarExpanded = $true
 $AnimState = @{ Target = 220; Current = 220 }
 $AnimTimer = New-Object System.Windows.Forms.Timer; $AnimTimer.Interval = 15
 $AnimTimer.Add_Tick({
    if ($AnimState.Current -lt $AnimState.Target) { $AnimState.Current += 15; if ($AnimState.Current -gt $AnimState.Target) { $AnimState.Current = $AnimState.Target } }
    elseif ($AnimState.Current -gt $AnimState.Target) { $AnimState.Current -= 15; if ($AnimState.Current -lt $AnimState.Target) { $AnimState.Current = $AnimState.Target } }
    else { $AnimTimer.Stop() }
    $SplitCont.SplitterDistance = $AnimState.Current
    if ($AnimState.Current -lt 100) { $btnModApps.Width = 50; $btnModTweaks.Width = 50; $btnModDrivers.Width = 50; $btnSettings.Width = 50 } else { $btnModApps.Width = 220; $btnModTweaks.Width = 220; $btnModDrivers.Width = 220; $btnSettings.Width = 220 }
})
 $btnHamburger.Add_Click({ if ($script:IsSidebarExpanded) { $AnimState.Target = 50; $script:IsSidebarExpanded = $false } else { $AnimState.Target = 220; $script:IsSidebarExpanded = $true }; $AnimTimer.Start() })

# --- INIT ---
 $UITimer.Add_Tick({
    while ($script:sync.LogQueue.Count -gt 0) { $msg = $script:sync.LogQueue.Dequeue(); Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $($msg.Text)" -ForegroundColor $msg.Color }
    if (-not $script:sync.IsRunning -and $btnExecute.Text -ne "EJECUTAR") { $btnExecute.Text = "EJECUTAR"; $btnExecute.Enabled = $true; $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $btnExecute.Invalidate() }
})
 $UITimer.Start()
 $btnModApps.PerformClick()
 $Form.ShowDialog() | Out-Null
