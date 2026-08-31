[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- INYECCIÓN DE CONTROLES C# PREMIUM ---
if (-not ([System.Management.Automation.PSTypeName]'GradientButton').Type) {
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
        Rectangle shadowRect = new Rectangle(0, 4, this.Width - 1, this.Height - 3);
        using (GraphicsPath shadowPath = new GraphicsPath()) {
            shadowPath.AddArc(shadowRect.X, shadowRect.Y, CornerRadius, CornerRadius, 180, 90);
            shadowPath.AddArc(shadowRect.Right - CornerRadius, shadowRect.Y, CornerRadius, CornerRadius, 270, 90);
            shadowPath.AddArc(shadowRect.Right - CornerRadius, shadowRect.Bottom - CornerRadius, CornerRadius, CornerRadius, 0, 90);
            shadowPath.AddArc(shadowRect.X, shadowRect.Bottom - CornerRadius, CornerRadius, CornerRadius, 90, 90);
            shadowPath.CloseFigure();
            using (SolidBrush sb = new SolidBrush(Color.FromArgb(40, 0, 0, 0))) { g.FillPath(sb, shadowPath); }
        }
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

public class SecondaryButton : Button {
    public SecondaryButton() {
        this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 1; this.FlatAppearance.BorderColor = Color.FromArgb(60, 60, 70);
        this.BackColor = Color.FromArgb(30, 30, 36); this.ForeColor = Color.White; this.Font = new Font("Segoe UI", 9, FontStyle.Bold); this.Cursor = Cursors.Hand; this.Height = 35;
    }
}

public class AccentButton : Button {
    public AccentButton() {
        this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 1; this.FlatAppearance.BorderColor = Color.FromArgb(139, 92, 246);
        this.BackColor = Color.FromArgb(20, 20, 25); this.ForeColor = Color.FromArgb(165, 120, 255); this.Font = new Font("Segoe UI", 8, FontStyle.Bold); this.Cursor = Cursors.Hand; this.Height = 25;
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
    public bool IsExpanded { get; set; }
    public CategoryCard() {
        this.BackColor = Color.FromArgb(30, 30, 36); this.Size = new Size(350, 45); this.Margin = new Padding(0, 0, 15, 15);
        
        Header = new Label(); Header.Size = new Size(350, 45); Header.TextAlign = ContentAlignment.MiddleLeft; Header.Padding = new Padding(20, 0, 0, 0);
        Header.Font = new Font("Segoe UI", 10, FontStyle.Bold); Header.ForeColor = Color.White; Header.Cursor = Cursors.Hand; Header.BackColor = Color.FromArgb(40, 40, 48); Controls.Add(Header);

        Inner = new FlowLayoutPanel(); Inner.AutoSize = true; Inner.AutoSizeMode = AutoSizeMode.GrowAndShrink; Inner.Location = new Point(0, 45);
        Inner.Size = new Size(350, 0); Inner.FlowDirection = FlowDirection.TopDown; Inner.WrapContents = false; Inner.Visible = false; Inner.Padding = new Padding(20, 15,20, 15); Controls.Add(Inner);
        Header.Click += (s, e) => { IsExpanded = !IsExpanded; Inner.Visible = IsExpanded; if (IsExpanded) { this.Height = 45 + Inner.PreferredSize.Height; } else { this.Height = 45; } };
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
        LblName = new Label(); LblName.Location = new Point(x, 15); LblName.Font = new Font("Segoe UI", 9, FontStyle.Bold); LblName.ForeColor = Color.White; LblName.AutoSize = true; Controls.Add(LblName);
        LblStatus = new Label(); LblStatus.Location = new Point(630, 17); LblStatus.Font = new Font("Segoe UI", 8, FontStyle.Bold); LblStatus.AutoSize = true; Controls.Add(LblStatus);
    }
}

public class CircularProgress : Control {
    public Color ProgressColor { get; set; }
    private Timer timer; private float angle = 0;
    public CircularProgress() { 
        this.ProgressColor = Color.FromArgb(139, 92, 246);
        this.DoubleBuffered = true; this.Size = new Size(60, 60); timer = new Timer(); timer.Interval = 20; timer.Tick += (s, e) => { angle = (angle + 5) % 360; this.Invalidate(); }; timer.Start(); 
    }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.Clear(this.BackColor);
        using (Pen p = new Pen(ProgressColor, 4)) { p.StartCap = LineCap.Round; p.EndCap = LineCap.Round; Rectangle rect = new Rectangle(2, 2, this.Width - 6, this.Height - 6); g.DrawArc(p, rect, angle, 120); }
    }
}

public class WinButton : Button {
    public bool IsClose { get; set; } public int IconType { get; set; }
    public WinButton() { this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics; g.Clear(this.BackColor);
        if (IsClose && this.ClientRectangle.Contains(this.PointToClient(Cursor.Position))) {
            g.FillRectangle(new SolidBrush(Color.FromArgb(232, 24, 24)), this.ClientRectangle);
            using (Pen p = new Pen(Color.White, 2)) { g.DrawLine(p, 16, 10, 26, 20); g.DrawLine(p, 26, 10, 16, 20); }
        } else {
            using (Pen p = new Pen(this.ForeColor, 2)) {
                if (IsClose) { g.DrawLine(p, 16, 10, 26, 20); g.DrawLine(p, 26,10, 16, 20); }
                else if (IconType == 3) { g.DrawLine(p, 15, 12, 27, 12); g.DrawLine(p, 15, 16, 27,16); g.DrawLine(p, 15, 20, 27, 20); } // Hamburguer
                else { g.DrawLine(p, 15, 15, 27, 15); } // Minimize
            }
        }
    }
}

public class NavButton : Button {
    public bool IsActive { get; set; } public int IconType { get; set; }
    public NavButton() { this.FlatStyle = FlatStyle.Flat; this.FlatAppearance.BorderSize = 0; this.DoubleBuffered = true; }
    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.Clear(this.BackColor);
        if (IsActive) { g.FillRectangle(new SolidBrush(Color.FromArgb(35, 35, 42)), this.ClientRectangle); g.FillRectangle(new SolidBrush(Color.FromArgb(139, 92, 246)), new Rectangle(0, 5, 4, this.Height - 10)); }
        int iconX = 15; int iconY = this.Height / 2 - 8; Color iconColor = this.IsActive ? Color.FromArgb(165, 120, 255) : Color.FromArgb(140, 140, 150);
        using (Pen p = new Pen(iconColor, 2)) {
            if (IconType == 0) { g.DrawRectangle(p, iconX, iconY, 6, 6); g.DrawRectangle(p, iconX+10, iconY, 6, 6); g.DrawRectangle(p, iconX, iconY+10, 6, 6); g.DrawRectangle(p, iconX+10, iconY+10, 6, 6); }
            else if (IconType == 1) { g.DrawEllipse(p, iconX+2, iconY+2, 12, 12); g.DrawEllipse(p, iconX+6, iconY+6, 4, 4); }
            else if (IconType == 2) { g.DrawRectangle(p, iconX+2, iconY, 12, 16); g.DrawLine(p, iconX, iconY+4, iconX+2, iconY+4); g.DrawLine(p, iconX+14, iconY+4, iconX+16, iconY+4); }
        }
        if (this.Width > 100) { TextRenderer.DrawText(g, this.Text, this.Font, new Rectangle(40, 0, this.Width-40, this.Height), this.ForeColor, TextFormatFlags.Left | TextFormatFlags.VerticalCenter); }
    }
}

public class DarkScrollPanel : FlowLayoutPanel {
    [DllImport("uxtheme.dll", ExactSpelling = true, CharSet = CharSet.Unicode)]
    private static extern int SetWindowTheme(IntPtr hWnd, string pszSubAppName, string pszSubIdList);
    public DarkScrollPanel() { this.HandleCreated += (s, e) => { try { SetWindowTheme(this.Handle, "DarkMode_Explorer", null); } catch { } }; }
}
"@
    Add-Type -TypeDefinition $CSharpCode -ReferencedAssemblies System.Windows.Forms, System.Drawing
}

# --- MOTOR ASÍNCRONO Y PROGRESO ---
 $sync = [Hashtable]::Synchronized(@{ LogQueue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new()); DriverQueue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new()); IsRunning = $false; MaxProgress = 0; CurrentProgress = 0; IsScanning = $false })
 $UITimer = New-Object System.Windows.Forms.Timer; $UITimer.Interval = 150

 $UITimer.Add_Tick({
    while ($script:sync.LogQueue.Count -gt 0) { $msg = $script:sync.LogQueue.Dequeue(); $script:LblLog.Text = "[$(Get-Date -Format 'HH:mm:ss')] $($msg.Text)"; $script:LblLog.ForeColor = $msg.Color }
    while ($script:sync.DriverQueue.Count -gt 0) {
        $drv = $script:sync.DriverQueue.Dequeue()
        if ($drv.Clear) { $script:CardPending.Inner.Controls.Clear(); $script:CardUpdated.Inner.Controls.Clear() }
        else {
            $dCard = New-Object DriverCard($drv.Cat -eq "Pending")
            $dCard.LblName.Text = $drv.Name; $dCard.LblStatus.Text = $drv.Status; $dCard.LblStatus.ForeColor = $drv.Color
            if ($drv.Cat -eq "Pending") { $script:CardPending.Inner.Controls.Add($dCard) } else { $script:CardUpdated.Inner.Controls.Add($dCard) }
        }
    }
    if ($script:sync.IsScanning -eq $false -and $script:PanelLoading.Visible -eq $true) {
        $script:PanelLoading.Visible = $false; $script:DriverListPanel.Visible = $true; $script:PanelDriverFooter.Visible = $true; $script:btnScanDrivers.Visible = $false
    }
})

function Write-Log($texto, $color = "White") { $sync.LogQueue.Enqueue(@{ Text = $texto; Color = $color }) }

# --- TEMA ICEZOP ---
 $C_BgBase = [System.Drawing.Color]::FromArgb(15, 15, 18); $C_BgLayer = [System.Drawing.Color]::FromArgb(25, 25, 30); $C_Card = [System.Drawing.Color]::FromArgb(30, 30, 36)
 $C_Accent = [System.Drawing.Color]::FromArgb(139, 92, 246); $C_TextMain = [System.Drawing.Color]::FromArgb(245, 245, 250); $C_TextSec = [System.Drawing.Color]::FromArgb(140, 140, 150)
 $FontGlobal = New-Object System.Drawing.Font("Segoe UI", 10)

# --- FORMULARIO BORDERLESS ---
 $Form = New-Object System.Windows.Forms.Form; $Form.Text = "icezOP"; $Form.Size = New-Object System.Drawing.Size(1100, 750); $Form.StartPosition = "CenterScreen"; $Form.BackColor = $C_BgBase; $Form.FormBorderStyle = "None"
 $Radius = 15; $FormPath = New-Object System.Drawing.Drawing2D.GraphicsPath
 $FormPath.AddArc(0, 0, $Radius, $Radius, 180, 90); $FormPath.AddArc($Form.Width - $Radius, 0, $Radius, $Radius, 270, 90); $FormPath.AddArc($Form.Width - $Radius, $Form.Height - $Radius, $Radius, $Radius, 0, 90); $FormPath.AddArc(0, $Form.Height - $Radius, $Radius, $Radius, 90, 90); $FormPath.CloseFigure(); $Form.Region = New-Object System.Drawing.Region($FormPath)

 $DragInfo = @{ Dragging = $false; X = 0; Y = 0 }
 $RootLayout = New-Object System.Windows.Forms.TableLayoutPanel; $RootLayout.Dock = "Fill"; $RootLayout.ColumnCount = 2; $RootLayout.RowCount = 1
 $RootLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 220))) | Out-Null
 $RootLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
 $RootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
 $Form.Controls.Add($RootLayout)

# 1. SIDEBAR
 $Sidebar = New-Object System.Windows.Forms.Panel; $Sidebar.Dock = "Fill"; $Sidebar.BackColor = $C_BgLayer; $RootLayout.Controls.Add($Sidebar, 0, 0)
 $TitleBar = New-Object System.Windows.Forms.Panel; $TitleBar.Location = New-Object System.Drawing.Point(0, 0); $TitleBar.Size = New-Object System.Drawing.Size(220, 40); $TitleBar.BackColor = $C_BgLayer; $Sidebar.Controls.Add($TitleBar)

 $btnHamburger = New-Object WinButton; $btnHamburger.IconType = 3; $btnHamburger.Location = New-Object System.Drawing.Point(0, 0); $btnHamburger.Size = New-Object System.Drawing.Size(45, 32); $btnHamburger.BackColor = $C_BgLayer; $btnHamburger.ForeColor = $C_TextSec; $btnHamburger.Cursor = "Hand"; $TitleBar.Controls.Add($btnHamburger)
 $btnHamburger.Add_MouseEnter({ $btnHamburger.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 52) })
 $btnHamburger.Add_MouseLeave({ $btnHamburger.BackColor = $C_BgLayer })

 $LblLogo = New-Object System.Windows.Forms.Label; $LblLogo.Text = "icezOP"; $LblLogo.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold); $LblLogo.ForeColor = $C_Accent; $LblLogo.Location = New-Object System.Drawing.Point(50, 10); $LblLogo.AutoSize = $true; $TitleBar.Controls.Add($LblLogo)
 $TitleBar.Add_MouseDown({ if($_.Button -eq 'Left'){ $script:DragInfo.Dragging = $true; $script:DragInfo.X = $_.X; $script:DragInfo.Y = $_.Y } })
 $TitleBar.Add_MouseMove({ if($script:DragInfo.Dragging){ $Form.Left += $_.X - $script:DragInfo.X; $Form.Top += $_.Y - $script:DragInfo.Y } })
 $TitleBar.Add_MouseUp({ $script:DragInfo.Dragging = $false })

 $btnModApps = New-Object NavButton; $btnModApps.Text = "Aplicaciones"; $btnModApps.IconType = 0; $btnModApps.IsActive = $true; $btnModApps.Location = New-Object System.Drawing.Point(0, 60); $btnModApps.Size = New-Object System.Drawing.Size(220, 40); $btnModApps.BackColor = $C_BgLayer; $btnModApps.ForeColor = $C_TextMain; $btnModApps.Font = $FontGlobal; $btnModApps.Cursor = "Hand"; $Sidebar.Controls.Add($btnModApps)
 $btnModTweaks = New-Object NavButton; $btnModTweaks.Text = "Tweaks"; $btnModTweaks.IconType = 1; $btnModTweaks.Location = New-Object System.Drawing.Point(0, 100); $btnModTweaks.Size = New-Object System.Drawing.Size(220, 40); $btnModTweaks.BackColor = $C_BgLayer; $btnModTweaks.ForeColor = $C_TextSec; $btnModTweaks.Font = $FontGlobal; $btnModTweaks.Cursor = "Hand"; $Sidebar.Controls.Add($btnModTweaks)
 $btnModDrivers = New-Object NavButton; $btnModDrivers.Text = "Drivers"; $btnModDrivers.IconType = 2; $btnModDrivers.Location = New-Object System.Drawing.Point(0, 140); $btnModDrivers.Size = New-Object System.Drawing.Size(220, 40); $btnModDrivers.BackColor = $C_BgLayer; $btnModDrivers.ForeColor = $C_TextSec; $btnModDrivers.Font = $FontGlobal; $btnModDrivers.Cursor = "Hand"; $Sidebar.Controls.Add($btnModDrivers)

 $PanelSpecs = New-Object System.Windows.Forms.Panel; $PanelSpecs.Location = New-Object System.Drawing.Point(15, 490); $PanelSpecs.Size = New-Object System.Drawing.Size(190, 150); $PanelSpecs.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 25); $Sidebar.Controls.Add($PanelSpecs)
 $LblSpecsTitle = New-Object System.Windows.Forms.Label; $LblSpecsTitle.Text = "ESPECIFICACIONES PC"; $LblSpecsTitle.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold); $LblSpecsTitle.ForeColor = $C_Accent; $LblSpecsTitle.Location = New-Object System.Drawing.Point(10, 5); $LblSpecsTitle.AutoSize = $true; $PanelSpecs.Controls.Add($LblSpecsTitle)
 $OSInfo = (Get-CimInstance Win32_OperatingSystem).Caption; $CPUInfo = (Get-CimInstance Win32_Processor).Name; $GPUInfo = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name; $RAMInfo = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
 $LblOS = New-Object System.Windows.Forms.Label; $LblOS.Text = "OS: $OSInfo"; $LblOS.Font = New-Object System.Drawing.Font("Segoe UI", 9); $LblOS.ForeColor = $C_TextMain; $LblOS.Location = New-Object System.Drawing.Point(10, 30); $LblOS.AutoSize = $true
 $LblCPU = New-Object System.Windows.Forms.Label; $LblCPU.Text = "CPU: $CPUInfo"; $LblCPU.Font = New-Object System.Drawing.Font("Segoe UI", 9); $LblCPU.ForeColor = $C_TextMain; $LblCPU.Location = New-Object System.Drawing.Point(10, 60); $LblCPU.AutoSize = $true
 $LblGPU = New-Object System.Windows.Forms.Label; $LblGPU.Text = "GPU: $GPUInfo"; $LblGPU.Font = New-Object System.Drawing.Font("Segoe UI", 9); $LblGPU.ForeColor = $C_TextMain; $LblGPU.Location = New-Object System.Drawing.Point(10, 90); $LblGPU.AutoSize = $true
 $LblRAM = New-Object System.Windows.Forms.Label; $LblRAM.Text = "RAM: $RAMInfo GB"; $LblRAM.Font = New-Object System.Drawing.Font("Segoe UI", 9); $LblRAM.ForeColor = $C_TextMain; $LblRAM.Location = New-Object System.Drawing.Point(10, 120); $LblRAM.AutoSize = $true
if($LblOS.Width -gt 170){ $LblOS.Text = "OS: Windows 11 Pro" }; if($LblCPU.Width -gt 170){ $LblCPU.Text = $LblCPU.Text.Substring(0, 25) + "..." }; if($LblGPU.Width -gt 170){ $LblGPU.Text = $LblGPU.Text.Substring(0, 25) + "..." }
 $PanelSpecs.Controls.Add($LblOS); $PanelSpecs.Controls.Add($LblCPU); $PanelSpecs.Controls.Add($LblGPU); $PanelSpecs.Controls.Add($LblRAM)

# 2. MAIN AREA
 $MainContent = New-Object System.Windows.Forms.Panel; $MainContent.Dock = "Fill"; $MainContent.BackColor = $C_BgBase; $MainContent.Padding = New-Object System.Windows.Forms.Padding(25); $RootLayout.Controls.Add($MainContent, 1, 0)
 $TableLayout = New-Object System.Windows.Forms.TableLayoutPanel; $TableLayout.Dock = "Fill"; $TableLayout.RowCount = 3
 $TableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 90))) | Out-Null
 $TableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
 $TableLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 60))) | Out-Null
 $TableLayout.ColumnCount = 1; $MainContent.Controls.Add($TableLayout)

 $PanelHeader = New-Object System.Windows.Forms.Panel; $PanelHeader.Dock = "Fill"; $PanelHeader.BackColor = $C_BgBase; $TableLayout.Controls.Add($PanelHeader, 0, 0)
 $btnMin = New-Object WinButton; $btnMin.Location = New-Object System.Drawing.Point(730, 0); $btnMin.Size = New-Object System.Drawing.Size(45, 32); $btnMin.BackColor = $C_BgBase; $btnMin.ForeColor = $C_TextSec; $btnMin.Cursor = "Hand"; $PanelHeader.Controls.Add($btnMin)
 $btnMin.Add_Click({ $Form.WindowState = "Minimized" }); $btnMin.Add_MouseEnter({ $btnMin.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 52); $btnMin.Invalidate() }); $btnMin.Add_MouseLeave({ $btnMin.BackColor = $C_BgBase; $btnMin.Invalidate() })
 $btnClose = New-Object WinButton; $btnClose.IsClose = $true; $btnClose.Location = New-Object System.Drawing.Point(775, 0); $btnClose.Size = New-Object System.Drawing.Size(45, 32); $btnClose.BackColor = $C_BgBase; $btnClose.ForeColor = $C_TextSec; $btnClose.Cursor = "Hand"; $PanelHeader.Controls.Add($btnClose)
 $btnClose.Add_Click({ $Form.Close() }); $btnClose.Add_MouseEnter({ $btnClose.Invalidate() }); $btnClose.Add_MouseLeave({ $btnClose.Invalidate() })

 $LblHeader = New-Object System.Windows.Forms.Label; $LblHeader.Text = "Aplicaciones"; $LblHeader.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold); $LblHeader.ForeColor = $C_TextMain; $LblHeader.Location = New-Object System.Drawing.Point(0, 35); $LblHeader.AutoSize = $true; $PanelHeader.Controls.Add($LblHeader)
 $PanelSearch = New-Object System.Windows.Forms.Panel; $PanelSearch.Location = New-Object System.Drawing.Point(350, 40); $PanelSearch.Size = New-Object System.Drawing.Size(350, 35); $PanelSearch.BackColor = $C_Card; $PanelHeader.Controls.Add($PanelSearch)
 $txtSearch = New-Object System.Windows.Forms.TextBox; $txtSearch.Location = New-Object System.Drawing.Point(10, 8); $txtSearch.Size = New-Object System.Drawing.Size(220, 20); $txtSearch.BorderStyle = "None"; $txtSearch.BackColor = $C_Card; $txtSearch.ForeColor = $C_TextMain; $txtSearch.Font = $FontGlobal; $txtSearch.Text = "Buscar..."; $PanelSearch.Controls.Add($txtSearch)
 $btnRec = New-Object AccentButton; $btnRec.Text = "Recomendados"; $btnRec.Location = New-Object System.Drawing.Point(240, 5); $btnRec.Size = New-Object System.Drawing.Size(105, 25); $PanelSearch.Controls.Add($btnRec)

 $PanelContent = New-Object System.Windows.Forms.Panel; $PanelContent.Dock = "Fill"; $PanelContent.BackColor = $C_BgBase; $TableLayout.Controls.Add($PanelContent, 0, 1)
 $DynPanel = New-Object DarkScrollPanel; $DynPanel.Dock = "Fill"; $DynPanel.BackColor = $C_BgBase; $DynPanel.AutoScroll = $true; $DynPanel.WrapContents = $true; $PanelContent.Controls.Add($DynPanel)

# PANEL DRIVERS REDISEÑADO
 $PanelDrivers = New-Object System.Windows.Forms.Panel; $PanelDrivers.Dock = "Fill"; $PanelDrivers.BackColor = $C_BgBase; $PanelDrivers.Visible = $false; $PanelContent.Controls.Add($PanelDrivers)

 $btnScanDrivers = New-Object GradientButton; $btnScanDrivers.Text = "ANALIZAR DRIVERS"; $btnScanDrivers.Size = New-Object System.Drawing.Size(300, 50); $btnScanDrivers.Location = New-Object System.Drawing.Point(260, 20); $btnScanDrivers.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnScanDrivers.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $btnScanDrivers.ForeColor = [System.Drawing.Color]::White; $btnScanDrivers.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold); $btnScanDrivers.Cursor = "Hand"; $btnScanDrivers.CornerRadius = 8; $PanelDrivers.Controls.Add($btnScanDrivers)

 $PanelLoading = New-Object System.Windows.Forms.Panel; $PanelLoading.Dock = "Fill"; $PanelLoading.BackColor = $C_BgBase; $PanelLoading.Visible = $false; $PanelDrivers.Controls.Add($PanelLoading)
 $ProgressRing = New-Object CircularProgress; $ProgressRing.Location = New-Object System.Drawing.Point(380, 150); $ProgressRing.Size = New-Object System.Drawing.Size(60, 60); $PanelLoading.Controls.Add($ProgressRing)
 $LblLoading = New-Object System.Windows.Forms.Label; $LblLoading.Text = "Buscando controladores y librerías..."; $LblLoading.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold); $LblLoading.ForeColor = $C_TextMain; $LblLoading.Location = New-Object System.Drawing.Point(280, 220); $LblLoading.AutoSize = $true; $PanelLoading.Controls.Add($LblLoading)

 $DriverListPanel = New-Object DarkScrollPanel; $DriverListPanel.Dock = "Fill"; $DriverListPanel.BackColor = $C_BgBase; $DriverListPanel.AutoScroll = $true; $DriverListPanel.Visible = $false; $PanelDrivers.Controls.Add($DriverListPanel)
 $CardPending = New-Object CategoryCard; $CardPending.Header.Text = "  ACTUALIZACIONES PENDIENTES"; $CardPending.Inner.BackColor = $C_Card; $DriverListPanel.Controls.Add($CardPending)
 $CardUpdated = New-Object CategoryCard; $CardUpdated.Header.Text = "  CONTROLADORES ACTUALIZADOS"; $CardUpdated.Inner.BackColor = $C_Card; $DriverListPanel.Controls.Add($CardUpdated)

 $PanelDriverFooter = New-Object System.Windows.Forms.Panel; $PanelDriverFooter.Dock = "Bottom"; $PanelDriverFooter.BackColor = $C_BgBase; $PanelDriverFooter.Visible = $false; $PanelDrivers.Controls.Add($PanelDriverFooter)
 $btnUpdateSelected = New-Object SecondaryButton; $btnUpdateSelected.Text = "Actualizar Seleccionados"; $btnUpdateSelected.Location = New-Object System.Drawing.Point(400, 10); $btnUpdateSelected.Size = New-Object System.Drawing.Size(180, 40); $PanelDriverFooter.Controls.Add($btnUpdateSelected)
 $btnUpdateAll = New-Object GradientButton; $btnUpdateAll.Text = "Actualizar Todos"; $btnUpdateAll.Location = New-Object System.Drawing.Point(600, 10); $btnUpdateAll.Size = New-Object System.Drawing.Size(180, 40); $btnUpdateAll.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnUpdateAll.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $btnUpdateAll.ForeColor = [System.Drawing.Color]::White; $btnUpdateAll.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold); $btnUpdateAll.Cursor = "Hand"; $btnUpdateAll.CornerRadius = 8; $PanelDriverFooter.Controls.Add($btnUpdateAll)

# FOOTER GLOBAL
 $PanelFooter = New-Object System.Windows.Forms.Panel; $PanelFooter.Dock = "Fill"; $PanelFooter.BackColor = $C_BgBase; $TableLayout.Controls.Add($PanelFooter, 0, 2)
 $LblStatus = New-Object System.Windows.Forms.Label; $LblStatus.Text = "ESTADO: LISTO"; $LblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold); $LblStatus.ForeColor = $C_Accent; $LblStatus.Location = New-Object System.Drawing.Point(0, 20); $LblStatus.AutoSize = $true; $PanelFooter.Controls.Add($LblStatus)
 $LblLog = New-Object System.Windows.Forms.Label; $LblLog.Text = "icezOP iniciado."; $LblLog.Font = New-Object System.Drawing.Font("Segoe UI", 8); $LblLog.ForeColor = $C_TextSec; $LblLog.Location = New-Object System.Drawing.Point(120, 22); $LblLog.AutoSize = $true; $PanelFooter.Controls.Add($LblLog)
 $ProgressBar = New-Object System.Windows.Forms.ProgressBar; $ProgressBar.Location = New-Object System.Drawing.Point(0, 45); $ProgressBar.Size = New-Object System.Drawing.Size(580, 4); $ProgressBar.Style = "Continuous"; $ProgressBar.ForeColor = $C_Accent; $ProgressBar.BackColor = $C_Card; $PanelFooter.Controls.Add($ProgressBar)
 $btnExecute = New-Object GradientButton; $btnExecute.Text = "EJECUTAR"; $btnExecute.Location = New-Object System.Drawing.Point(600, 10); $btnExecute.Size = New-Object System.Drawing.Size(220, 40); $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(139, 92, 246); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(165, 120, 255); $btnExecute.ForeColor = [System.Drawing.Color]::White; $btnExecute.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold); $btnExecute.Cursor = "Hand"; $btnExecute.CornerRadius = 8; $PanelFooter.Controls.Add($btnExecute)

 # --- CATÁLOGOS JSON INTEGRADOS ---
 $AppsJson = @"
[
  { "Name": "Google Chrome", "ID": "Google.Chrome", "Cat": "Navegadores", "Rec": true },
  { "Name": "Mozilla Firefox", "ID": "Mozilla.Firefox", "Cat": "Navegadores", "Rec": true },
  { "Name": "Brave", "ID": "Brave.Brave", "Cat": "Navegadores", "Rec": false },
  { "Name": "Opera GX", "ID": "Opera.OperaGX", "Cat": "Navegadores", "Rec": false },
  { "Name": "Discord", "ID": "Discord.Discord", "Cat": "Comunicacion", "Rec": true },
  { "Name": "WhatsApp", "ID": "WhatsApp.WhatsApp", "Cat": "Comunicacion", "Rec": true },
  { "Name": "Telegram", "ID": "Telegram.TelegramDesktop", "Cat": "Comunicacion", "Rec": false },
  { "Name": "Visual Studio Code", "ID": "Microsoft.VisualStudioCode", "Cat": "Programacion", "Rec": true },
  { "Name": "Git", "ID": "Git.Git", "Cat": "Programacion", "Rec": true },
  { "Name": "Windows Terminal", "ID": "Microsoft.WindowsTerminal", "Cat": "Programacion", "Rec": true },
  { "Name": "Steam", "ID": "Valve.Steam", "Cat": "Juegos", "Rec": true },
  { "Name": "Epic Games Launcher", "ID": "EpicGames.EpicGamesLauncher", "Cat": "Juegos", "Rec": false },
  { "Name": "VLC Media Player", "ID": "VideoLAN.VLC", "Cat": "Video", "Rec": true },
  { "Name": "OBS Studio", "ID": "OBSProject.OBSStudio", "Cat": "Video", "Rec": true },
  { "Name": "Spotify", "ID": "Spotify.Spotify", "Cat": "Audio", "Rec": true },
  { "Name": "7-Zip", "ID": "7zip.7zip", "Cat": "Utilidades", "Rec": true },
  { "Name": "Everything", "ID": "voidtools.Everything", "Cat": "Utilidades", "Rec": true },
  { "Name": "Microsoft PowerToys", "ID": "Microsoft.PowerToys", "Cat": "Utilidades", "Rec": true },
  { "Name": "Bitwarden", "ID": "Bitwarden.Bitwarden", "Cat": "Seguridad", "Rec": true },
  { "Name": "qBittorrent", "ID": "qBittorrent.qBittorrent", "Cat": "Downloads", "Rec": true }
]
"@
 $TweaksJson = @"
[
  { "Cat": "Privacidad y Telemetría", "Name": "Desactivar Telemetría y Diagnósticos", "Script": "Set-ItemProperty 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection' -Name 'AllowTelemetry' -Value 0 -Type DWord -Force" },
  { "Cat": "Privacidad y Telemetría", "Name": "Desactivar Advertising ID", "Script": "Set-ItemProperty 'HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\AdvertisingInfo' -Name 'Enabled' -Value 0 -Type DWord -Force" },
  { "Cat": "Interfaz y Explorador", "Name": "Mostrar Extensiones de Archivos", "Script": "Set-ItemProperty 'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced' -Name 'HideFileExt' -Value 0 -Type DWord -Force" },
  { "Cat": "Interfaz y Explorador", "Name": "Restaurar Menú Contextual Clásico (Win10)", "Script": "Set-ItemProperty 'HKCU:\\Software\\Classes\\CLSID\\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\\InprocServer32' -Name '(Default)' -Value '' -Type String -Force" },
  { "Cat": "Rendimiento", "Name": "Desactivar Hibernación (Libera Disco)", "Script": "powercfg -h off" },
  { "Cat": "Rendimiento", "Name": "Activar Plan de Energía Ultimate", "Script": "powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null" },
  { "Cat": "Gaming", "Name": "Desactivar Xbox Game DVR (Más FPS)", "Script": "Set-ItemProperty 'HKCU:\\System\\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -Type DWord -Force" },
  { "Cat": "Red y Ping", "Name": "Limpiar Caché DNS", "Script": "ipconfig /flushdns" }
"@
try { $AppCatalog = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/icezggg/icezOP/main/apps.json" -ErrorAction Stop } catch { $AppCatalog = $AppsJson | ConvertFrom-Json }
try { $TweakCatalog = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/icezggg/icezOP/main/tweaks.json" -ErrorAction Stop } catch { $TweakCatalog = $TweaksJson | ConvertFrom-Json }

# --- LÓGICA DE MÓDULOS ---
 $CurrentModule = "Apps"; $CurrentCheckboxes = @{}
function Clear-DynamicPanel { $DynPanel.Controls.Clear(); $script:CurrentCheckboxes = @{} }
function Set-ModuleActive {
    param($ActiveBtn)
    $btnModApps.IsActive = $false; $btnModApps.ForeColor = $C_TextSec; $btnModApps.Invalidate()
    $btnModTweaks.IsActive = $false; $btnModTweaks.ForeColor = $C_TextSec; $btnModTweaks.Invalidate()
    $btnModDrivers.IsActive = $false; $btnModDrivers.ForeColor = $C_TextSec; $btnModDrivers.Invalidate()
    $ActiveBtn.IsActive = $true; $ActiveBtn.ForeColor = $C_TextMain; $ActiveBtn.Invalidate()
}

function Set-AppModule {
    Set-ModuleActive $btnModApps; $script:CurrentModule = "Apps"
    $DynPanel.Visible = $true; $PanelDrivers.Visible = $false; $PanelSearch.Visible = $true; $btnExecute.Visible = $true
    $LblHeader.Text = "Aplicaciones"; Clear-DynamicPanel; $txtSearch.Text = "Buscar..."; $txtSearch.ForeColor = $C_TextSec
    $Categories = $AppCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    foreach ($cat in $Categories) {
        $Card = New-Object CategoryCard; $appsInCat = @($AppCatalog | Where-Object { $_.Cat -eq $cat }); $totalApps = $appsInCat.Count
        $Card.Header.Text = "  $($cat.ToUpper())  [0/$totalApps]"; $Card.Inner.BackColor = $C_Card
        foreach ($app in $appsInCat) {
            $cb = New-Object ModernCheckBox; $cb.Text = $app.Name; $cb.Tag = $app.ID; $cb.Size = New-Object System.Drawing.Size(310, 25); $cb.ForeColor = $C_TextMain; $cb.BackColor = $C_Card; $cb.Font = $FontGlobal; $cb.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
            $Card.Inner.Controls.Add($cb); $script:CurrentCheckboxes[$app.Name] = $cb
            $cb.Add_CheckedChanged({ $checked = 0; foreach($c in $Card.Inner.Controls) { if($c.Checked) { $checked++ } }; $Card.Header.Text = "  $($cat.ToUpper())  [$checked/$totalApps]" })
        }
        $DynPanel.Controls.Add($Card)
    }
}

function Set-TweaksModule {
    Set-ModuleActive $btnModTweaks; $script:CurrentModule = "Tweaks"
    $DynPanel.Visible = $true; $PanelDrivers.Visible = $false; $PanelSearch.Visible = $false; $btnExecute.Visible = $true
    $LblHeader.Text = "Tweaks"; Clear-DynamicPanel
    $Categories = $TweakCatalog | ForEach-Object { $_.Cat } | Select-Object -Unique
    foreach ($cat in $Categories) {
        $Card = New-Object CategoryCard; $tweaksInCat = @($TweakCatalog | Where-Object { $_.Cat -eq $cat }); $totalTweaks = $tweaksInCat.Count
        $Card.Header.Text = "  $($cat.ToUpper())  [0/$totalTweaks]"; $Card.Inner.BackColor = $C_Card
        foreach ($tweak in $tweaksInCat) {
            $cb = New-Object ModernCheckBox; $cb.Text = $tweak.Name; $cb.Tag = $tweak.Script; $cb.Size = New-Object System.Drawing.Size(310, 25); $cb.ForeColor = $C_TextMain; $cb.BackColor = $C_Card; $cb.Font = $FontGlobal; $cb.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
            $Card.Inner.Controls.Add($cb); $script:CurrentCheckboxes[$tweak.Name] = $cb
            $cb.Add_CheckedChanged({ $checked = 0; foreach($c in $Card.Inner.Controls) { if($c.Checked) { $checked++ } }; $Card.Header.Text = "  $($cat.ToUpper())  [$checked/$totalTweaks]" })
        }
        $DynPanel.Controls.Add($Card)
    }
}

function Set-DriversModule { Set-ModuleActive $btnModDrivers; $script:CurrentModule = "Drivers"; $DynPanel.Visible = $false; $PanelDrivers.Visible = $true; $PanelSearch.Visible = $false; $btnExecute.Visible = $false; $LblHeader.Text = "Gestor de Drivers" }

 $btnModApps.Add_Click({ Set-AppModule })
 $btnModTweaks.Add_Click({ Set-TweaksModule })
 $btnModDrivers.Add_Click({ Set-DriversModule })
 $btnRec.Add_Click({ foreach($app in $AppCatalog) { $CurrentCheckboxes[$app.Name].Checked = $app.Rec } })

 $txtSearch.Add_GotFocus({ if ($txtSearch.Text -eq "Buscar...") { $txtSearch.Text = ""; $txtSearch.ForeColor = $C_TextMain } })
 $txtSearch.Add_LostFocus({ if ($txtSearch.Text -eq "") { $txtSearch.Text = "Buscar..."; $txtSearch.ForeColor = $C_TextSec } })
 $txtSearch.Add_TextChanged({
    $searchText = $txtSearch.Text.ToLower(); if ($txtSearch.Text -eq "Buscar...") { $searchText = "" }
    foreach($card in $DynPanel.Controls) {
        $cardVisible = $false
        foreach($ctrl in $card.Controls) {
            if($ctrl -is [System.Windows.Forms.FlowLayoutPanel]) { foreach($cb in $ctrl.Controls) { if($cb.Text.ToLower() -match $searchText) { $cb.Visible = $true; $cardVisible = $true } else { $cb.Visible = $false } } }
        }
        $card.Visible = $cardVisible
    }
})

# --- MENÚ HAMBURGUESA ---
 $IsSidebarExpanded = $true
 $btnHamburger.Add_Click({
    if ($script:IsSidebarExpanded) {
        $RootLayout.ColumnStyles[0].Width = 50
        $script:IsSidebarExpanded = $false
        $PanelSpecs.Visible = $false
        $LblLogo.Visible = $false
    } else {
        $RootLayout.ColumnStyles[0].Width = 220
        $script:IsSidebarExpanded = $true
        $PanelSpecs.Visible = $true
        $LblLogo.Visible = $true
    }
    $btnModApps.Invalidate(); $btnModTweaks.Invalidate(); $btnModDrivers.Invalidate()
})

# --- ESCANEO REAL DE DRIVERS (HARDWARE Y LIBRERÍAS) ---
 $btnScanDrivers.Add_Click({
    $sync.IsScanning = $true
    $btnScanDrivers.Visible = $false
    $PanelLoading.Visible = $true
    $DriverListPanel.Visible = $false
    $PanelDriverFooter.Visible = $false
    $sync.DriverQueue.Enqueue(@{ Clear = $true })
    
    $job = {
        param($syncHash)
        try {
            # 1. Escanear Hardware y Drivers PnP
            $pnpDrivers = Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.DeviceName }
            foreach($drv in $pnpDrivers) {
                $isOld = $false
                if ($drv.DriverDate) {
                    $age = (Get-Date) - $drv.DriverDate
                    if ($age.Days -gt 730) { $isOld = $true } # Mayor a 2 años
                }
                
                $cat = if ($isOld) { "Pending" } else { "Updated" }
                $status = if ($isOld) { "[Antiguo]" } else { "[OK]" }
                $color = if ($isOld) { [System.Drawing.Color]::FromArgb(250, 204, 21) } else { [System.Drawing.Color]::FromArgb(34, 197, 94) }
                
                $syncHash.DriverQueue.Enqueue(@{ Cat=$cat; Name=$drv.DeviceName; Status=$status; Color=$color })
            }
            
            # 2. Escanear Librerías Lógicas (Visual C++ Redistributables)
            $vcPaths = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
            $vcApps = Get-ItemProperty $vcPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "Visual C\+\+ \d{4}" } | Select-Object DisplayName, DisplayVersion
            
            if ($vcApps) {
                foreach($app in $vcApps) {
                    $syncHash.DriverQueue.Enqueue(@{ Cat="Pending"; Name="$($app.DisplayName) (v$($app.DisplayVersion))"; Status="[Librería]"; Color=[System.Drawing.Color]::FromArgb(139, 92, 246) })
                }
            } else {
                $syncHash.DriverQueue.Enqueue(@{ Cat="Updated"; Name="Librerías C++ no detectadas o actualizadas"; Status="[OK]"; Color=[System.Drawing.Color]::FromArgb(34, 197, 94) })
            }
            
            # 3. DirectX
            $dxPath = "HKLM:\SOFTWARE\Microsoft\DirectX"
            if (Test-Path $dxPath) {
                $dxVer = (Get-ItemProperty $dxPath -Name "Version" -ErrorAction SilentlyContinue).Version
                if ($dxVer) {
                    $syncHash.DriverQueue.Enqueue(@{ Cat="Updated"; Name="DirectX Runtime (v$dxVer)"; Status="[OK]"; Color=[System.Drawing.Color]::FromArgb(34, 197, 94) })
                }
            }
            
        } catch {
            $syncHash.DriverQueue.Enqueue(@{ Cat="Pending"; Name="Error durante el escaneo: $($_.Exception.Message)"; Status="[ERROR]"; Color=[System.Drawing.Color]::FromArgb(239, 68, 68) })
        }
        $syncHash.IsScanning = $false
    }
    $runspace = [runspacefactory]::CreateRunspace(); $runspace.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $runspace
    $ps.AddScript($job).AddArgument($sync) | Out-Null
    $ps.BeginInvoke() | Out-Null
})

# --- ACCIÓN ACTUALIZAR TODOS Y SELECCIONADOS ---
 $btnUpdateAll.Add_Click({
    foreach($card in $CardPending.Inner.Controls) { if($card.Check) { $card.Check.Checked = $true } }
    $btnUpdateSelected.PerformClick()
})

 $btnUpdateSelected.Add_Click({
    $sync.IsRunning = $true
    $LblStatus.Text = "ESTADO: ACTUALIZANDO"; $LblStatus.ForeColor = [System.Drawing.Color]::FromArgb(250, 150, 50)
    $job = {
        param($syncHash)
        $syncHash.LogQueue.Enqueue(@{ Text="Iniciando actualización de drivers nativos..."; Color="Cyan" })
        Start-Process pnputil -ArgumentList "/scan-devices" -Wait -NoNewWindow
        $syncHash.LogQueue.Enqueue(@{ Text="Buscando actualizaciones de software vía Winget..."; Color="Cyan" })
        Start-Process winget -ArgumentList "upgrade --all --accept-package-agreements --accept-source-agreements -h" -Wait -NoNewWindow
        $syncHash.LogQueue.Enqueue(@{ Text="Proceso de actualización finalizado."; Color="Plum" })
        $syncHash.IsRunning = $false
    }
    $runspace = [runspacefactory]::CreateRunspace(); $runspace.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $runspace
    $ps.AddScript($job).AddArgument($sync) | Out-Null
    $ps.BeginInvoke() | Out-Null
})

# Lógica Ejecutar (Apps y Tweaks)
 $btnExecute.Add_Click({
    $visibleChecks = $CurrentCheckboxes.Values | Where-Object { $_.Checked -and $_.Visible }
    if (-not $visibleChecks.Count) { Write-Log "No hay opciones marcadas." "Yellow"; return }
    $sync.IsRunning = $true; $sync.MaxProgress = $visibleChecks.Count; $sync.CurrentProgress = 0
    $btnExecute.Text = "PROCESANDO..."; $btnExecute.Enabled = $false; $btnExecute.Color1 = [System.Drawing.Color]::FromArgb(80, 50, 140); $btnExecute.Color2 = [System.Drawing.Color]::FromArgb(100, 60, 160); $btnExecute.Invalidate()
    $LblStatus.Text = "ESTADO: TRABAJANDO"; $LblStatus.ForeColor = [System.Drawing.Color]::FromArgb(250, 150, 50)
    $job = {
        param($items, $mod, $syncHash)
        foreach ($item in $items) {
            $name = $item.Text; $tag = $item.Tag
            if ($mod -eq "Apps") {
                $syncHash.LogQueue.Enqueue(@{ Text="Instalando $name..."; Color="Cyan" })
                try { $proc = Start-Process winget -ArgumentList "install --id $tag -e --accept-package-agreements --accept-source-agreements -h" -Wait -PassThru -NoNewWindow; if ($proc.ExitCode -eq 0) { $syncHash.LogQueue.Enqueue(@{ Text="$name instalado."; Color="MediumPurple" }) } else { $syncHash.LogQueue.Enqueue(@{ Text="Error en $name."; Color="Red" }) } } catch { $syncHash.LogQueue.Enqueue(@{ Text="Excepción: $name."; Color="Red" }) }
            } elseif ($mod -eq "Tweaks") {
                $syncHash.LogQueue.Enqueue(@{ Text="Aplicando: $name"; Color="Cyan" })
                try { $sb = [ScriptBlock]::Create($tag.ToString()); & $sb; $syncHash.LogQueue.Enqueue(@{ Text="OK: $name"; Color="MediumPurple" }) } catch { $syncHash.LogQueue.Enqueue(@{ Text="Error: $name"; Color="Red" }) }
            }
            $syncHash.CurrentProgress++
        }
        $syncHash.LogQueue.Enqueue(@{ Text="Finalizado."; Color="Plum" }); $syncHash.IsRunning = $false
    }
    $runspace = [runspacefactory]::CreateRunspace(); $runspace.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $runspace
    $ps.AddScript($job).AddArgument($visibleChecks).AddArgument($CurrentModule).AddArgument($sync) | Out-Null
    $ps.BeginInvoke() | Out-Null
})

# Inicializar
 $UITimer.Start()
Set-AppModule
 $Form.ShowDialog() | Out-Null
