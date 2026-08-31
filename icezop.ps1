[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- INYECCIÓN C# (Controles Modernos y Panel Transparente) ---
if (-not ([System.Management.Automation.PSTypeName]'GradientButton').Type) {
    $CSharpCode = @"
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class GradientButton : Button {
    public Color Color1 { get; set; } public Color Color2 { get; set; } public int CornerRadius { get; set; }
    public GradientButton() { this.Color1 = Color.FromArgb(139, 92, 246); this.Color2 = Color.FromArgb(165, 120, 255); this.CornerRadius = 8; this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; this.Cursor = Cursors.Hand; this.Font = new Font("Segoe UI Variable Text", 10, FontStyle.Bold); this.Padding = new Padding(30, 12, 30, 12); }
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
    public ModernCheckBox() { this.CheckColor = Color.FromArgb(139, 92, 246); this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; }
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
    public Label Header { get; set; } public FlowLayoutPanel Inner { get; set; }
    public CategoryCard() {
        this.BackColor = Color.FromArgb(30, 30, 36); this.Size = new Size(350, 45); this.Margin = new Padding(0, 0, 0, 15); this.Cursor = Cursors.Hand;
        Header = new Label(); Header.Dock = DockStyle.Fill; Header.TextAlign = ContentAlignment.MiddleLeft; Header.Padding = new Padding(20, 0, 0, 0);
        Header.Font = new Font("Segoe UI Variable Text", 10, FontStyle.Bold); Header.ForeColor = Color.White; Header.BackColor = Color.FromArgb(40, 40, 48); Controls.Add(Header);
        Header.MouseEnter += (s, e) => { this.BackColor = Color.FromArgb(45, 45, 52); Header.BackColor = Color.FromArgb(50, 50, 60); };
        Header.MouseLeave += (s, e) => { this.BackColor = Color.FromArgb(30, 30, 36); Header.BackColor = Color.FromArgb(40, 40, 48); };
    }
}

public class DriverCard : Panel {
    public ModernCheckBox Check { get; set; } public Label LblName { get; set; } public Label LblStatus { get; set; }
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
    public bool IsClose { get; set; } public int IconType { get; set; }
    public WinButton() { this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics; g.Clear(this.BackColor);
        if (IsClose && this.ClientRectangle.Contains(this.PointToClient(Cursor.Position))) { g.FillRectangle(new SolidBrush(Color.FromArgb(232, 24, 24)), this.ClientRectangle); using (Pen p = new Pen(Color.White, 2)) { g.DrawLine(p, 16, 10, 26, 20); g.DrawLine(p, 26, 10, 16, 20); } }
        else { using (Pen p = new Pen(this.ForeColor, 2)) { if (IsClose) { g.DrawLine(p, 16, 10, 26, 20); g.DrawLine(p, 26, 10, 16, 20); } else if (IconType == 3) { g.DrawLine(p, 15, 12, 27, 12); g.DrawLine(p, 15, 16, 27, 16); g.DrawLine(p, 15, 20, 27, 20); } else if (IconType == 4) { g.DrawEllipse(p, 19, 11, 10, 10); g.DrawLine(p, 24, 8, 24, 11); g.DrawLine(p, 24, 21, 24, 24); g.DrawLine(p, 16, 16, 19, 16); g.DrawLine(p, 29, 16, 32, 16); } else { g.DrawLine(p, 15, 15, 27, 15); } } }
    }
}

public class NavButton : Button {
    public bool IsActive { get; set; } public int IconType { get; set; }
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

// Panel Transparente para el efecto Overlay/Blur
public class TransparentPanel : Panel {
    public TransparentPanel() { this.DoubleBuffered = true; }
    protected override CreateParams CreateParams { get { CreateParams cp = base.CreateParams; cp.ExStyle |= 0x20; return cp; } }
    protected override void OnPaint(PaintEventArgs e) {
        using (SolidBrush b = new SolidBrush(Color.FromArgb(180, 0, 0, 0))) { e.Graphics.FillRectangle(b, this.ClientRectangle); }
    }
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

# --- FORMULARIO BASE ---
 $Form = New-Object System.Windows.Forms.Form; $Form.Text = "icezOP"; $Form.Size = New-Object System.Drawing.Size(1100, 750); $Form.StartPosition = "CenterScreen"; $Form.BackColor = $C_BgBase; $Form.FormBorderStyle = "None"
 $Radius = 15; $FormPath = New-Object System.Drawing.Drawing2D.GraphicsPath
 $FormPath.AddArc(0, 0, $Radius, $Radius, 180, 90); $FormPath.AddArc($Form.Width - $Radius, 0, $Radius, $Radius, 270, 90); $FormPath.AddArc($Form.Width - $Radius, $Form.Height - $Radius, $Radius, $Radius, 0, 90); $FormPath.AddArc(0, $Form.Height - $Radius, $Radius, $Radius, 90, 90); $FormPath.CloseFigure(); $Form.Region = New-Object System.Drawing.Region($FormPath)

 $DragInfo = @{ Dragging = $false; X = 0; Y = 0 }

# --- ESTRUCTURA RAIZ (Header Arriba, Split Abajo) ---
 $RootLayout = New-Object System.Windows.Forms.TableLayoutPanel; $RootLayout.Dock = "Fill"; $RootLayout.ColumnCount = 1; $RootLayout.RowCount = 2
 $RootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70))) | Out-Null
 $RootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
 $Form.Controls.Add($RootLayout)

# 1. HEADER CENTRAL (icezOP)
 $PanelHeader = New-Object System.Windows.Forms.Panel; $PanelHeader.Dock = "Fill"; $PanelHeader.BackColor = $C_BgBase; $RootLayout.Controls.Add($PanelHeader, 0, 0)
 $PanelHeader.Add_MouseDown({ if($_.Button -eq 'Left'){ $script:DragInfo.Dragging = $true; $script:DragInfo.X = $_.X; $script:DragInfo.Y = $_.Y } })
 $PanelHeader.Add_MouseMove({ if($script:DragInfo.Dragging){ $Form.Left += $_.X - $script:DragInfo.X; $Form.Top += $_.Y - $script:DragInfo.Y } })
 $PanelHeader.Add_MouseUp({ $script:DragInfo.Dragging = $false })

 $LblTitle = New-Object System.Windows.Forms.Label; $LblTitle.Text = "icezOP"; $LblTitle.Font = New-Object System.Drawing.Font("Segoe Script", 26, [System.Drawing.FontStyle]::Bold); $LblTitle.ForeColor = $C_Accent; $LblTitle.Dock = "Fill"; $LblTitle.TextAlign = "MiddleCenter"; $LblTitle.AutoSize = $false; $PanelHeader.Controls.Add($LblTitle)

 $btnClose = New-Object WinButton; $btnClose.IsClose = $true; $btnClose.Location = New-Object System.Drawing.Point(1030, 10); $btnClose.Size = New-Object System.Drawing.Size(45, 32); $btnClose.BackColor = $C_BgBase; $btnClose.ForeColor = $C_TextSec; $btnClose.Cursor = "Hand"; $PanelHeader.Controls.Add($btnClose)
 $btnClose.Add_Click({ $Form.Close() })
 $btnMin = New-Object WinButton; $btnMin.Location = New-Object System.Drawing.Point(985, 10); $btnMin.Size = New-Object System.Drawing.Size(45, 32); $btnMin.BackColor = $C_BgBase; $btnMin.ForeColor = $C_TextSec; $btnMin.Cursor = "Hand"; $PanelHeader.Controls.Add($btnMin)
 $btnMin.Add_Click({ $Form.WindowState = "Minimized" })

# Separador de 1px
 $SepLine = New-Object System.Windows.Forms.Panel; $SepLine.Dock = "Bottom"; $SepLine.Height = 1; $SepLine.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50); $PanelHeader.Controls.Add($SepLine)

# 2. SPLIT CONTAINER (Sidebar | Content)
 $SplitCont = New-Object System.Windows.Forms.SplitContainer; $SplitCont.Dock = "Fill"; $SplitCont.SplitterWidth = 0; $SplitCont.SplitterDistance = 220; $SplitCont.BackColor = $C_BgBase; $RootLayout.Controls.Add($SplitCont, 0, 1)

# 2a. SIDEBAR
 $Sidebar = New-Object System.Windows.Forms.Panel; $Sidebar.Dock = "Fill"; $Sidebar.BackColor = $C_BgLayer; $SplitCont.Panel1.Controls.Add($Sidebar)
 $btnModApps = New-Object NavButton; $btnModApps.Text = "Aplicaciones"; $btnModApps.IconType = 0; $btnModApps.IsActive = $true; $btnModApps.Location = New-Object System.Drawing.Point(0, 20); $btnModApps.Size = New-Object System.Drawing.Size(220, 40); $btnModApps.BackColor = $C_BgLayer; $btnModApps.ForeColor = $C_TextMain; $btnModApps.Font = $FontGlobal; $Sidebar.Controls.Add($btnModApps)
 $btnModTweaks = New-Object NavButton; $btnModTweaks.Text = "Tweaks"; $btnModTweaks.IconType = 1; $btnModTweaks.Location = New-Object System.Drawing.Point(0, 60); $btnModTweaks.Size = New-Object System.Drawing.Size(220, 40); $btnModTweaks.BackColor = $C_BgLayer; $btnModTweaks.ForeColor = $C_TextSec; $btnModTweaks.Font = $FontGlobal; $Sidebar.Controls.Add($btnModTweaks)
 $btnModDrivers = New-Object NavButton; $btnModDrivers.Text = "Drivers"; $btnModDrivers.IconType = 2; $btnModDrivers.Location = New-Object System.Drawing.Point(0, 100); $btnModDrivers.Size = New-Object System.Drawing.Size(220, 40); $btnModDrivers.BackColor = $C_BgLayer; $btnModDrivers.ForeColor = $C_TextSec; $btnModDrivers.Font = $FontGlobal; $Sidebar.Controls.Add($btnModDrivers)
 $btnSettings = New-Object NavButton; $btnSettings.Text = "Configuración"; $btnSettings.IconType = 4; $btnSettings.Location = New-Object System.Drawing.Point(0, 620); $btnSettings.Size = New-Object System.Drawing.Size(220, 40); $btnSettings.BackColor = $C_BgLayer; $btnSettings.ForeColor = $C_TextSec; $btnSettings.Font = $FontGlobal; $Sidebar.Controls.Add($btnSettings)

# 2b. CONTENT AREA
 $PanelContent = New-Object System.Windows.Forms.Panel; $PanelContent.Dock = "Fill"; $PanelContent.BackColor = $C_BgBase; $SplitCont.Panel2.Controls.Add($PanelContent)

# --- CONTENEDORES DINÁMICOS ---
 $DynPanel = New-Object System.Windows.Forms.Panel; $DynPanel.Dock = "Fill"; $DynPanel.BackColor = $C_BgBase; $DynPanel.AutoScroll = $true; $DynPanel.Padding = New-Object System.Windows.Forms.Padding(20); $PanelContent.Controls.Add($DynPanel)

# --- PANEL DRIVERS (CON LISTA UNIFICADA Y MOCK DATA) ---
 $PanelDrivers = New-Object System.Windows.Forms.Panel; $PanelDrivers.Dock = "Fill"; $PanelDrivers.BackColor = $C_BgBase; $PanelDrivers.Visible = $false; $PanelContent.Controls.Add($PanelDrivers)

 $LblDriverTitle = New-Object System.Windows.Forms.Label; $LblDriverTitle.Text = "GESTOR DE DRIVERS"; $LblDriverTitle.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 20, [System.Drawing.FontStyle]::Bold); $LblDriverTitle.ForeColor = $C_TextMain; $LblDriverTitle.Location = New-Object System.Drawing.Point(250, 20); $LblDriverTitle.AutoSize = $true; $PanelDrivers.Controls.Add($LblDriverTitle)

 $DriverListPanel = New-Object System.Windows.Forms.Panel; $DriverListPanel.Location = New-Object System.Drawing.Point(150, 80); $DriverListPanel.Size = New-Object System.Drawing.Size(760, 450); $DriverListPanel.BackColor = $C_BgBase; $DriverListPanel.AutoScroll = $true; $PanelDrivers.Controls.Add($DriverListPanel)

 $PanelDriverFooter = New-Object System.Windows.Forms.Panel; $PanelDriverFooter.Dock = "Bottom"; $PanelDriverFooter.BackColor = $C_BgBase; $PanelDriverFooter.Height = 60; $PanelDrivers.Controls.Add($PanelDriverFooter)
 $btnUpdateSelected = New-Object GradientButton; $btnUpdateSelected.Text = "Actualizar Seleccionados"; $btnUpdateSelected.Location = New-Object System.Drawing.Point(400, 10); $btnUpdateSelected.Size = New-Object System.Drawing.Size(220, 40); $btnUpdateSelected.Color1 = [System.Drawing.Color]::FromArgb(60, 60, 70); $btnUpdateSelected.Color2 = [System.Drawing.Color]::FromArgb(80, 80, 90); $btnUpdateSelected.Visible = $false; $PanelDriverFooter.Controls.Add($btnUpdateSelected)
 $btnUpdateAll = New-Object GradientButton; $btnUpdateAll.Text = "Actualizar Todos"; $btnUpdateAll.Location = New-Object System.Drawing.Point(650, 10); $btnUpdateAll.Size = New-Object System.Drawing.Size(200, 40); $btnUpdateAll.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnUpdateAll.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $PanelDriverFooter.Controls.Add($btnUpdateAll)

# --- OVERLAY Y MODAL HOST ---
 $Overlay = New-Object TransparentPanel; $Overlay.Dock = "Fill"; $Overlay.Visible = $false; $Overlay.BackColor = [System.Drawing.Color]::FromArgb(180, 0, 0, 0); $Form.Controls.Add($Overlay); $Overlay.BringToFront()
 $Overlay.Add_Click({ Hide-Modal })

 $ModalHost = New-Object System.Windows.Forms.Panel; $ModalHost.Size = New-Object System.Drawing.Size(600, 500); $ModalHost.Visible = $false; $ModalHost.BackColor = $C_Card; $Overlay.Controls.Add($ModalHost)
# Radio Borde Modal
 $ModalRadius = 15; $ModalPath = New-Object System.Drawing.Drawing2D.GraphicsPath
 $ModalPath.AddArc(0, 0, $ModalRadius, $ModalRadius, 180, 90); $ModalPath.AddArc($ModalHost.Width - $ModalRadius, 0, $ModalRadius, $ModalRadius, 270, 90); $ModalPath.AddArc($ModalHost.Width - $ModalRadius, $ModalHost.Height - $ModalRadius, $ModalRadius, $ModalRadius, 0, 90); $ModalPath.AddArc(0, $ModalHost.Height - $ModalRadius, $ModalRadius, $ModalRadius, 90, 90); $ModalPath.CloseFigure(); $ModalHost.Region = New-Object System.Drawing.Region($ModalPath)

function Show-Modal($TitleText, $ContentControl) {
    $ModalHost.Controls.Clear()
    $LblModalTitle = New-Object System.Windows.Forms.Label; $LblModalTitle.Text = $TitleText; $LblModalTitle.Font = New-Object System.Drawing.Font("Segoe UI Variable Text", 14, [System.Drawing.FontStyle]::Bold); $LblModalTitle.ForeColor = $C_Accent; $LblModalTitle.Location = New-Object System.Drawing.Point(20, 15); $LblModalTitle.AutoSize = $true; $ModalHost.Controls.Add($LblModalTitle)
    
    $BtnCloseModal = New-Object WinButton; $BtnCloseModal.IsClose = $true; $BtnCloseModal.Location = New-Object System.Drawing.Point(550, 10); $BtnCloseModal.Size = New-Object System.Drawing.Size(40, 32); $BtnCloseModal.BackColor = $C_Card; $BtnCloseModal.ForeColor = $C_TextSec; $BtnCloseModal.Cursor = "Hand"; $ModalHost.Controls.Add($BtnCloseModal)
    $BtnCloseModal.Add_Click({ Hide-Modal })

    $ContentControl.Location = New-Object System.Drawing.Point(20, 60); $ContentControl.Size = New-Object System.Drawing.Size(560, 420); $ModalHost.Controls.Add($ContentControl)
    
    $Overlay.Visible = $true; $ModalHost.Visible = $true
    $ModalHost.Location = New-Object System.Drawing.Point(($Overlay.Width - $ModalHost.Width)/2, ($Overlay.Height - $ModalHost.Height)/2)
}

function Hide-Modal { $Overlay.Visible = $false; $ModalHost.Visible = $false }

# --- LÓGICA DE MODALES (APPS, TWEAKS, SETTINGS) ---
 $CurrentCheckboxes = @{}
function Set-ModuleActive { param($ActiveBtn); $btnModApps.IsActive = $false; $btnModApps.ForeColor = $C_TextSec; $btnModApps.Invalidate(); $btnModTweaks.IsActive = $false; $btnModTweaks.ForeColor = $C_TextSec; $btnModTweaks.Invalidate(); $btnModDrivers.IsActive = $false; $btnModDrivers.ForeColor = $C_TextSec; $btnModDrivers.Invalidate(); $ActiveBtn.IsActive = $true; $ActiveBtn.ForeColor = $C_TextMain; $ActiveBtn.Invalidate() }

 $AppsJson = '[ { "Name": "Chrome", "ID": "Google.Chrome", "Cat": "Navegadores" }, { "Name": "Firefox", "ID": "Mozilla.Firefox", "Cat": "Navegadores" }, { "Name": "Discord", "ID": "Discord.Discord", "Cat": "Comunicacion" } ]' | ConvertFrom-Json
 $TweaksJson = '[ { "Name": "Desactivar Telemetría", "Script": "echo 1", "Cat": "Privacidad" }, { "Name": "Desactivar Cortana", "Script": "echo 2", "Cat": "Privacidad" } ]' | ConvertFrom-Json

function Open-CategoryModal($CatName, $Items, $IsTweak=$false) {
    $ModalContent = New-Object System.Windows.Forms.Panel; $ModalContent.BackColor = $C_Card; $ModalContent.AutoScroll = $true
    $InnerFlow = New-Object System.Windows.Forms.FlowLayoutPanel; $InnerFlow.Dock = "Fill"; $InnerFlow.FlowDirection = "TopDown"; $InnerFlow.WrapContents = $false; $InnerFlow.BackColor = $C_Card; $InnerFlow.Padding = "10,10,10,10"
    $script:CurrentCheckboxes = @{} # Limpiar para el modal actual

    foreach ($item in $Items) {
        $cb = New-Object ModernCheckBox; $cb.Text = $item.Name; $cb.Tag = if($IsTweak){$item.Script}else{$item.ID}; $cb.Size = New-Object System.Drawing.Size(500, 30); $cb.ForeColor = $C_TextMain; $cb.BackColor = $C_Card; $cb.Font = $FontGlobal; $cb.Margin = "0,5,0,5"
        $InnerFlow.Controls.Add($cb); $script:CurrentCheckboxes[$item.Name] = $cb
    }
    $ModalContent.Controls.Add($InnerFlow)
    Show-Modal $CatName.ToUpper() $ModalContent
}

 $btnModApps.Add_Click({ Set-ModuleActive $btnModApps; $DynPanel.Visible = $true; $PanelDrivers.Visible = $false; $btnExecute.Visible = $true; $DynPanel.Controls.Clear(); $script:CurrentCheckboxes = @{}
    $Cats = $AppsJson | ForEach-Object { $_.Cat } | Select-Object -Unique
    foreach ($cat in $Cats) {
        $Card = New-Object CategoryCard; $Card.Width = $DynPanel.Width - 60
        $Card.Header.Text = "  $($cat.ToUpper())"
        $Card.Add_Click({ Open-CategoryModal $cat ($AppsJson | Where-Object { $_.Cat -eq $cat }) }.GetNewClosure())
        $DynPanel.Controls.Add($Card)
    }
})

 $btnModTweaks.Add_Click({ Set-ModuleActive $btnModTweaks; $DynPanel.Visible = $true; $PanelDrivers.Visible = $false; $btnExecute.Visible = $true; $DynPanel.Controls.Clear(); $script:CurrentCheckboxes = @{}
    $Cats = $TweaksJson | ForEach-Object { $_.Cat } | Select-Object -Unique
    foreach ($cat in $Cats) {
        $Card = New-Object CategoryCard; $Card.Width = $DynPanel.Width - 60
        $Card.Header.Text = "  $($cat.ToUpper())"
        $Card.Add_Click({ Open-CategoryModal $cat ($TweaksJson | Where-Object { $_.Cat -eq $cat }) $true }.GetNewClosure())
        $DynPanel.Controls.Add($Card)
    }
})

# --- MODAL CONFIGURACIÓN ---
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

# --- PANEL DRIVERS LÓGICA Y MOCK DATA ---
 $btnModDrivers.Add_Click({
    Set-ModuleActive $btnModDrivers; $DynPanel.Visible = $false; $PanelDrivers.Visible = $true; $btnExecute.Visible = $false
    $DriverListPanel.Controls.Clear()
    
    # Mock Data Pendientes
    $drv1 = New-Object DriverCard($true); $drv1.LblName.Text = "NVIDIA GeForce RTX 4090"; $drv1.LblStatus.Text = "[Pendiente]"; $drv1.LblStatus.ForeColor = [System.Drawing.Color]::FromArgb(250, 204, 21); $DriverListPanel.Controls.Add($drv1)
    $drv2 = New-Object DriverCard($true); $drv2.LblName.Text = "Realtek Audio Controller"; $drv2.LblStatus.Text = "[Pendiente]"; $drv2.LblStatus.ForeColor = [System.Drawing.Color]::FromArgb(250, 204, 21); $DriverListPanel.Controls.Add($drv2)
    
    # Mock Data Actualizados
    $drv3 = New-Object DriverCard($false); $drv3.LblName.Text = "Intel Core i9 Processor"; $drv3.LblStatus.Text = "[Actualizado]"; $drv3.LblStatus.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100); $DriverListPanel.Controls.Add($drv3)
    $drv4 = New-Object DriverCard($false); $drv4.LblName.Text = "Samsung NVMe SSD Driver"; $drv4.LblStatus.Text = "[Actualizado]"; $drv4.LblStatus.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100); $DriverListPanel.Controls.Add($drv4)

    # Lógica dinámica de visibilidad del botón
    foreach($ctrl in $DriverListPanel.Controls) { if($ctrl.Check) { $ctrl.Check.Add_CheckedChanged({ $anyChecked = $false; foreach($c in $DriverListPanel.Controls) { if($c.Check -and $c.Check.Checked) { $anyChecked = $true; break } }; $btnUpdateSelected.Visible = $anyChecked }) } }
})

 $btnUpdateAll.Add_Click({ foreach($card in $DriverListPanel.Controls) { if($card.Check) { $card.Check.Checked = $true } }; $btnUpdateSelected.PerformClick() })

# --- BOTÓN EJECUTAR ---
 $btnExecute = New-Object GradientButton; $btnExecute.Text = "EJECUTAR"; $btnExecute.Dock = "Bottom"; $btnExecute.Height = 50; $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $PanelContent.Controls.Add($btnExecute)
 $btnExecute.Add_Click({
    $visibleChecks = $CurrentCheckboxes.Values | Where-Object { $_.Checked }
    if (-not $visibleChecks.Count) { Write-Log "No hay opciones marcadas." "Yellow"; return }
    $sync.IsRunning = $true; $sync.MaxProgress = $visibleChecks.Count; $sync.CurrentProgress = 0
    $btnExecute.Text = "PROCESANDO..."; $btnExecute.Enabled = $false; $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(80, 50, 140); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(100, 60, 160); $btnExecute.Invalidate()
    $job = {
        param($items, $syncHash)
        foreach ($item in $items) {
            $name = $item.Text; $tag = $item.Tag
            $syncHash.LogQueue.Enqueue(@{ Text="Procesando: $name"; Color="Cyan" })
            Start-Sleep -Seconds 1 # Simulación
            $syncHash.LogQueue.Enqueue(@{ Text="OK: $name"; Color="MediumPurple" })
            $syncHash.CurrentProgress++
        }
        $syncHash.LogQueue.Enqueue(@{ Text="Finalizado."; Color="Plum" }); $syncHash.IsRunning = $false
    }
    $runspace = [runspacefactory]::CreateRunspace(); $runspace.Open(); $ps = [powershell]::Create(); $ps.Runspace = $runspace; $ps.AddScript($job).AddArgument($visibleChecks).AddArgument($sync) | Out-Null; $ps.BeginInvoke() | Out-Null
})

# --- INIT ---
 $UITimer.Add_Tick({
    while ($script:sync.LogQueue.Count -gt 0) { $msg = $script:sync.LogQueue.Dequeue(); Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $($msg.Text)" -ForegroundColor $msg.Color }
    if (-not $script:sync.IsRunning -and $btnExecute.Text -ne "EJECUTAR") { $btnExecute.Text = "EJECUTAR"; $btnExecute.Enabled = $true; $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $btnExecute.Invalidate() }
})
 $UITimer.Start()
 $btnModApps.PerformClick() # Cargar vista inicial
 $Form.ShowDialog() | Out-Null
