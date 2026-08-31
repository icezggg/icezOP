<#
    ═══════════════════════════════════════════════════════════════
     icezOP v0.2.0 — Post-instalacion y optimizacion para Windows 11
    ═══════════════════════════════════════════════════════════════
     Motor:    PowerShell 5.1 + WinForms (C# inyectado)
     Apps:     Winget        |  Tweaks: Registro/Servicios/PowerCFG
     Drivers:  Motor propio (Win32_PnPSignedDriver + drivers.json)
     Archivos: apps.json, tweaks.json, drivers.json (local o repo)
               config.json se crea en %APPDATA%\icezOP
     Ejecutar: powershell -ExecutionPolicy Bypass -File .\icezOP.ps1
              o:  iex (irm 'https://raw.githubusercontent.com/icezggg/icezOP/main/icezop.ps1')
    ═══════════════════════════════════════════════════════════════
#>

# ════════════════════ 0. ARRANQUE, PERMISOS Y MODO ════════════════════
 $Script:Version  = '0.2.0'
 $Script:RepoBase = 'https://raw.githubusercontent.com/icezggg/icezOP/main'
 $Script:SelfPath = $PSCommandPath

 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
 $isSta   = ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA)

# Elevar a administrador (auto-relanzamiento con UAC)
if (-not $isAdmin) {
    try {
        if ($Script:SelfPath) {
            Start-Process 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',('"{0}"' -f $Script:SelfPath))
        } else {
            $cmd = "iex (irm '$Script:RepoBase/icezop.ps1')"
            Start-Process 'powershell.exe' -Verb RunAs -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-Command',$cmd)
        }
    } catch {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [void][System.Windows.Forms.MessageBox]::Show('icezOP necesita permisos de administrador para funcionar.', 'icezOP', 'OK', 'Warning')
        } catch {}
    }
    return
}

# WinForms necesita STA
if (-not $isSta) {
    if ($Script:SelfPath) {
        Start-Process 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',('"{0}"' -f $Script:SelfPath))
    } else {
        $cmd = "iex (irm '$Script:RepoBase/icezop.ps1')"
        Start-Process 'powershell.exe' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-Command',$cmd)
    }
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
 $null = [System.Drawing.Color]::Empty

# DPI awareness + esquinas redondeadas nativas (Win11)
if (-not ('Icez.Win32' -as [type])) {
    Add-Type -Namespace Icez -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
'@
}
[Icez.Win32]::SetProcessDPIAware() | Out-Null

# ════════════════════ 1. CATALOGOS (JSON) + CONFIG ════════════════════
if ($Script:SelfPath) {
    $Script:Root = Split-Path -Parent $Script:SelfPath
} else {
    $Script:Root = $PWD.Path
}

 $Script:ConfigDir  = Join-Path $env:APPDATA 'icezOP'
 $Script:ConfigFile = Join-Path $Script:ConfigDir 'config.json'

function ConvertTo-IcezArray {
    param($Data)
    if ($null -eq $Data) { return @() }
    if ($Data -is [System.Management.Automation.PSCustomObject]) {
        $prop = @($Data.PSObject.Properties | Where-Object { $_.Value -is [System.Array] }) | Select-Object -First 1
        if ($prop) { return @($prop.Value) }
        return @()
    }
    return @($Data)
}

function Import-IcezJson {
    param([string]$Name)
    $local = Join-Path $Script:Root $Name
    if (Test-Path -LiteralPath $local) {
        try {
            return ConvertTo-IcezArray (Get-Content -LiteralPath $local -Raw -Encoding UTF8 | ConvertFrom-Json)
        } catch {}
    }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        return ConvertTo-IcezArray (Invoke-RestMethod -Uri ($Script:RepoBase + '/' + $Name) -UseBasicParsing)
    } catch {}
    return @()
}

function Load-Config {
    $cfg = @{
        Theme         = 'Dark Mode (Por defecto)'
        RestorePoint  = $true
        UpdateSources = $true
        AutoWinget    = $false
        OnFinish      = 'none'
        Retries       = 1
    }
    if (Test-Path -LiteralPath $Script:ConfigFile) {
        try {
            $j = Get-Content -LiteralPath $Script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $j.PSObject.Properties) {
                if ($cfg.ContainsKey($p.Name)) { $cfg[$p.Name] = $p.Value }
            }
        } catch {}
    }
    return $cfg
}

function Save-Config {
    try {
        if (-not (Test-Path -LiteralPath $Script:ConfigDir)) {
            New-Item -ItemType Directory -Path $Script:ConfigDir -Force | Out-Null
        }
        $o = @{}
        foreach ($k in $Script:Settings.Keys) { $o[$k] = $Script:Settings[$k] }
        ConvertTo-Json $o | Set-Content -LiteralPath $Script:ConfigFile -Encoding UTF8
    } catch {}
}

 $Script:Apps    = @(Import-IcezJson 'apps.json'    | Where-Object { $_.Name -and $_.ID -and $_.Cat })
 $Script:Tweaks  = @(Import-IcezJson 'tweaks.json'  | Where-Object { $_.Name -and $_.Script -and $_.Cat })
 $Script:Drivers = @(Import-IcezJson 'drivers.json' | Where-Object { $_.Match -and $_.Latest })

 $Script:Settings = Load-Config

if ($Script:Apps.Count -eq 0 -and $Script:Tweaks.Count -eq 0) {
    [void][System.Windows.Forms.MessageBox]::Show(
        "No se pudieron cargar apps.json ni tweaks.json.`r`n`r`nSe busco en: $Script:Root`r`ny en el repositorio: $Script:RepoBase",
        'icezOP', 'OK', 'Warning')
}

 $Script:AppCats = New-Object System.Collections.ArrayList
foreach ($a in $Script:Apps) {
    if (-not $Script:AppCats.Contains([string]$a.Cat)) { [void]$Script:AppCats.Add([string]$a.Cat) }
}
 $Script:TweakCats = New-Object System.Collections.ArrayList
foreach ($t in $Script:Tweaks) {
    if (-not $Script:TweakCats.Contains([string]$t.Cat)) { [void]$Script:TweakCats.Add([string]$t.Cat) }
}

# ════════════════════ 2. TEMAS ════════════════════
# Definiciones RGB por tema (strings "R,G,B" para evitar problemas de evaluacion)
 $Script:Themes = @{
    'Dark Mode (Por defecto)' = @{
        Bg = '14,14,19';     BgAlt = '19,19,25';   Card = '26,26,34';    Border = '42,42,53'
        Text = '236,236,244'; Sub = '142,142,160'
        Acc = '139,92,246';  AccL = '167,139,250'; AccD = '91,33,182'
        Ok = '52,211,153';   Err = '248,113,113';  Warn = '251,191,36'
        Dim = '90,90,104';   Dim2 = '110,110,124'; LogBg = '11,11,16'; LogFg = '169,169,188'; OvBg = '8,8,12'
    }
    'Midnight Blue' = @{
        Bg = '10,14,24';     BgAlt = '14,19,32';   Card = '20,26,42';    Border = '38,48,72'
        Text = '230,238,250'; Sub = '136,152,178'
        Acc = '59,130,246';  AccL = '96,165,250';  AccD = '30,64,175'
        Ok = '52,211,153';   Err = '248,113,113';  Warn = '251,191,36'
        Dim = '84,98,122';   Dim2 = '104,118,142'; LogBg = '7,10,18';  LogFg = '160,175,200'; OvBg = '5,7,14'
    }
    'High Contrast' = @{
        Bg = '0,0,0';        BgAlt = '12,12,12';   Card = '24,24,24';    Border = '90,90,90'
        Text = '255,255,255'; Sub = '180,180,180'
        Acc = '0,200,255';   AccL = '80,220,255';  AccD = '0,120,160'
        Ok = '0,255,140';    Err = '255,90,90';    Warn = '255,220,0'
        Dim = '110,110,110'; Dim2 = '140,140,140'; LogBg = '0,0,0';    LogFg = '200,200,200'; OvBg = '0,0,0'
    }
}

# Aplica un tema: materializa los colores en $Script:Theme y en la clase C# IcezOP.Theme
function Apply-Theme([string]$Name) {
    if (-not $Script:Themes.ContainsKey($Name)) { $Name = 'Dark Mode (Por defecto)' }
    $Script:ThemeName = $Name
    $t = $Script:Themes[$Name]
    $Script:Theme = @{}
    foreach ($k in $t.Keys) {
        $rgb = [int[]]($t[$k] -split ',')
        $Script:Theme[$k] = [System.Drawing.Color]::FromArgb($rgb[0], $rgb[1], $rgb[2])
    }
    if ('IcezOP.Theme' -as [type]) {
        [IcezOP.Theme]::Acc    = $Script:Theme['Acc']
        [IcezOP.Theme]::AccL   = $Script:Theme['AccL']
        [IcezOP.Theme]::AccD   = $Script:Theme['AccD']
        [IcezOP.Theme]::Card   = $Script:Theme['Card']
        [IcezOP.Theme]::Border = $Script:Theme['Border']
    }
}

function icezCol([string]$N) {
    if ($Script:Theme -and $Script:Theme.ContainsKey($N)) { return $Script:Theme[$N] }
    return [System.Drawing.Color]::White
}

function icezG([string]$N) {
    switch ($N) {
        'Menu' { [string][char]0xE700 }
        'Home' { [string][char]0xE80F }
        'Apps' { [string][char]0xE71D }
        'Fix'  { [string][char]0xE90F }
        'Drv'  { [string][char]0xE721 }
        'Gear' { [string][char]0xE713 }
        'Play' { [string][char]0xE768 }
        'X'    { [string][char]0xE8BB }
        'Min'  { [string][char]0xE921 }
        default { '' }
    }
}

 $Script:GlyphFont = 'Segoe MDL2 Assets'
try {
    $ff = New-Object System.Drawing.FontFamily('Segoe Fluent Icons')
    $Script:GlyphFont = 'Segoe Fluent Icons'
    $ff.Dispose()
} catch {}

# ════════════════════ 3. ESTADO GLOBAL ════════════════════
 $Script:AppSel   = @{}
 $Script:TweakSel = @{}
 $Script:ModalBoxes      = $null
 $Script:ModalCounterLbl = $null
 $Script:ModalTotal      = 0
 $Script:DriverSel       = @{}
 $Script:DriverRendered  = $true
 $Script:RunActive       = $false
 $Script:RunPs = $null; $Script:RunRs = $null; $Script:RunHandle = $null
 $Script:DrvPs = $null; $Script:DrvRs = $null

 $sync = [hashtable]::Synchronized(@{})
 $sync.Log            = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
 $sync.Running        = $false
 $sync.Done           = $false
 $sync.Cancel         = $false
 $sync.Percent        = 0
 $sync.Status         = ''
 $sync.OkCount        = 0
 $sync.FailCount      = 0
 $sync.DriverPhase    = 'idle'
 $sync.DriverScan     = (New-Object System.Collections.ArrayList)
 $sync.DriverError    = ''
 $sync.Winget         = $null

# ════════════════════ 4. CONTROLES CUSTOM (C# INYECTADO) ════════════════════
 $cs = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Windows.Forms;

namespace IcezOP
{
    // Colores del tema, modificables desde PowerShell antes de crear controles
    public static class Theme
    {
        public static Color Acc    = Color.FromArgb(139, 92, 246);
        public static Color AccL   = Color.FromArgb(167, 139, 250);
        public static Color AccD   = Color.FromArgb(91, 33, 182);
        public static Color Card   = Color.FromArgb(26, 26, 34);
        public static Color Border = Color.FromArgb(42, 42, 53);
    }

    public static class Gfx
    {
        public static GraphicsPath Round(RectangleF r, float rad)
        {
            GraphicsPath p = new GraphicsPath();
            if (rad <= 0f) { p.AddRectangle(r); return p; }
            float d = rad * 2f;
            if (d > r.Width) d = r.Width;
            if (d > r.Height) d = r.Height;
            p.AddArc(r.X, r.Y, d, d, 180f, 90f);
            p.AddArc(r.Right - d, r.Y, d, d, 270f, 90f);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0f, 90f);
            p.AddArc(r.X, r.Bottom - d, d, d, 90f, 90f);
            p.CloseFigure();
            return p;
        }
    }

    public class CardPanel : Panel
    {
        private int radius;
        private Color fill;
        private Color border;
        public int Radius { get { return radius; } set { radius = value; Invalidate(); } }
        public Color FillColor { get { return fill; } set { fill = value; Invalidate(); } }
        public Color BorderColor { get { return border; } set { border = value; Invalidate(); } }
        public CardPanel()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            radius = 16;
            fill = Theme.Card;
            border = Theme.Border;
        }
        protected override void OnPaintBackground(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (GraphicsPath p = Gfx.Round(new RectangleF(0.5f, 0.5f, Width - 1f, Height - 1f), radius))
            {
                using (SolidBrush b = new SolidBrush(fill)) e.Graphics.FillPath(b, p);
                using (Pen pen = new Pen(border)) e.Graphics.DrawPath(pen, p);
            }
        }
    }

    public class IcezCheckBox : Control
    {
        private bool isChecked;
        private bool isHover;
        private bool star;
        public bool Checked
        {
            get { return isChecked; }
            set { if (isChecked != value) { isChecked = value; Invalidate(); if (CheckedChanged != null) CheckedChanged(this, EventArgs.Empty); } }
        }
        public bool Star { get { return star; } set { star = value; Invalidate(); } }
        public event EventHandler CheckedChanged;
        public IcezCheckBox()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Cursor = Cursors.Hand;
            Font = new Font("Segoe UI", 9.75F);
            Height = 30;
        }
        protected override void OnMouseEnter(EventArgs e) { isHover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { isHover = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnClick(EventArgs e) { Checked = !Checked; base.OnClick(e); }
        protected override bool IsInputKey(Keys k) { if (k == Keys.Space) return true; return base.IsInputKey(k); }
        protected override void OnKeyUp(KeyEventArgs e) { if (e.KeyCode == Keys.Space) Checked = !Checked; base.OnKeyUp(e); }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            int box = 17;
            int by = (Height - box) / 2;
            RectangleF br = new RectangleF(1f, by, box, box);
            using (GraphicsPath p = Gfx.Round(br, 5f))
            {
                if (isChecked)
                {
                    using (LinearGradientBrush lb = new LinearGradientBrush(br, Theme.AccL, Theme.AccD, LinearGradientMode.Vertical))
                        g.FillPath(lb, p);
                }
                else
                {
                    using (SolidBrush sb = new SolidBrush(Theme.Card))
                        g.FillPath(sb, p);
                }
                Color bc = isChecked ? Theme.AccL : (isHover ? Theme.Acc : Color.FromArgb(64, 64, 76));
                using (Pen pen = new Pen(bc, 1.5f)) g.DrawPath(pen, p);
            }
            if (isChecked)
            {
                using (Pen pen = new Pen(Color.White, 2f))
                {
                    pen.StartCap = LineCap.Round;
                    pen.EndCap = LineCap.Round;
                    g.DrawLine(pen, br.X + 4f, br.Y + 8.5f, br.X + 7f, br.Y + 12f);
                    g.DrawLine(pen, br.X + 7f, br.Y + 12f, br.X + 13.5f, br.Y + 4.5f);
                }
            }
            SizeF ts = g.MeasureString(Text, Font);
            int tx = (int)br.Right + 8;
            Color tc = isChecked ? Color.FromArgb(240, 240, 248) : Color.FromArgb(185, 185, 200);
            using (SolidBrush tb = new SolidBrush(tc))
                g.DrawString(Text, Font, tb, tx, (Height - ts.Height) / 2f);
            if (star)
            {
                using (Font sf = new Font("Segoe UI", 7.5F, FontStyle.Bold))
                using (SolidBrush sb2 = new SolidBrush(Theme.AccL))
                    g.DrawString("*", sf, sb2, tx + ts.Width + 5f, (Height - ts.Height) / 2f - 1f);
            }
        }
    }

    public class GradientButton : Control
    {
        private bool isHover;
        private bool isDown;
        private Color cTop;
        private Color cBottom;
        private string glyph;
        private string gfont;
        private int radius;
        public Color TopColor { get { return cTop; } set { cTop = value; Invalidate(); } }
        public Color BottomColor { get { return cBottom; } set { cBottom = value; Invalidate(); } }
        public string Glyph { get { return glyph; } set { glyph = value; Invalidate(); } }
        public string GlyphFont { get { return gfont; } set { gfont = value; Invalidate(); } }
        public GradientButton()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Cursor = Cursors.Hand;
            cTop = Theme.Acc;
            cBottom = Theme.AccD;
            Font = new Font("Segoe UI Semibold", 10F);
            ForeColor = Color.White;
            gfont = "Segoe MDL2 Assets";
            radius = 10;
        }
        protected override void OnMouseEnter(EventArgs e) { isHover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { isHover = false; isDown = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { isDown = true; Invalidate(); base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { isDown = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            RectangleF r = new RectangleF(0f, 0f, Width - 1f, Height - 3f);
            using (GraphicsPath p = Gfx.Round(r, radius))
            {
                if (Enabled)
                {
                    using (GraphicsPath sp = Gfx.Round(new RectangleF(1f, 3f, Width - 2f, Height - 3f), radius))
                    using (SolidBrush sb = new SolidBrush(Color.FromArgb(isDown ? 40 : 90, 20, 12, 40)))
                        g.FillPath(sb, sp);
                    using (LinearGradientBrush lb = new LinearGradientBrush(r, cTop, cBottom, LinearGradientMode.Vertical))
                        g.FillPath(lb, p);
                    if (isHover && !isDown)
                    {
                        using (SolidBrush hb = new SolidBrush(Color.FromArgb(28, 255, 255, 255)))
                            g.FillPath(hb, p);
                    }
                    if (isDown)
                    {
                        using (SolidBrush db = new SolidBrush(Color.FromArgb(45, 0, 0, 0)))
                            g.FillPath(db, p);
                    }
                }
                else
                {
                    using (SolidBrush nb = new SolidBrush(Color.FromArgb(56, 56, 70)))
                        g.FillPath(nb, p);
                }
            }
            Color txtC = Enabled ? ForeColor : Color.FromArgb(120, 120, 135);
            SizeF ts = g.MeasureString(Text, Font);
            float tx;
            if (!string.IsNullOrEmpty(glyph))
            {
                using (Font gf = new Font(gfont, 10F))
                {
                    SizeF gs = g.MeasureString(glyph, gf);
                    tx = (Width - (ts.Width + gs.Width + 6f)) / 2f;
                    using (SolidBrush tb = new SolidBrush(txtC))
                        g.DrawString(glyph, gf, tb, tx, (Height - 3f - gs.Height) / 2f);
                    tx += gs.Width + 6f;
                }
            }
            else
            {
                tx = (Width - ts.Width) / 2f;
            }
            using (SolidBrush tb2 = new SolidBrush(txtC))
                g.DrawString(Text, Font, tb2, tx, (Height - 3f - ts.Height) / 2f);
        }
    }

    public class GhostButton : Control
    {
        private bool isHover;
        public GhostButton()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Cursor = Cursors.Hand;
            Font = new Font("Segoe UI Semibold", 9F);
            ForeColor = Theme.AccL;
        }
        protected override void OnMouseEnter(EventArgs e) { isHover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { isHover = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            using (GraphicsPath p = Gfx.Round(new RectangleF(0.5f, 0.5f, Width - 1f, Height - 1f), 10f))
            {
                if (isHover)
                {
                    using (SolidBrush b = new SolidBrush(Color.FromArgb(26, Theme.Acc)))
                        g.FillPath(b, p);
                }
                using (Pen pen = new Pen(Enabled ? Color.FromArgb(160, ForeColor) : Color.FromArgb(90, 90, 105)))
                    g.DrawPath(pen, p);
            }
            Color tc = Enabled ? ForeColor : Color.FromArgb(120, 120, 135);
            SizeF ts = g.MeasureString(Text, Font);
            using (SolidBrush tb = new SolidBrush(tc))
                g.DrawString(Text, Font, tb, (Width - ts.Width) / 2f, (Height - ts.Height) / 2f);
        }
    }

    public class GlyphButton : Control
    {
        private bool isHover;
        private string glyph;
        private string gfont;
        private bool danger;
        public string Glyph { get { return glyph; } set { glyph = value; Invalidate(); } }
        public string GlyphFont { get { return gfont; } set { gfont = value; Invalidate(); } }
        public bool Danger { get { return danger; } set { danger = value; Invalidate(); } }
        public GlyphButton()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Cursor = Cursors.Hand;
            gfont = "Segoe MDL2 Assets";
            Size = new Size(34, 34);
        }
        protected override void OnMouseEnter(EventArgs e) { isHover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { isHover = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            if (isHover)
            {
                using (GraphicsPath p = Gfx.Round(new RectangleF(0.5f, 0.5f, Width - 1f, Height - 1f), 9f))
                using (SolidBrush b = new SolidBrush(danger ? Color.FromArgb(70, 248, 113, 113) : Color.FromArgb(26, 255, 255, 255)))
                    g.FillPath(b, p);
            }
            Color gc = isHover ? (danger ? Color.FromArgb(255, 205, 210) : Color.FromArgb(230, 230, 240)) : Color.FromArgb(160, 160, 175);
            using (Font gf = new Font(gfont, 10F))
            {
                SizeF gs = g.MeasureString(glyph, gf);
                using (SolidBrush b = new SolidBrush(gc))
                    g.DrawString(glyph, gf, b, (Width - gs.Width) / 2f, (Height - gs.Height) / 2f);
            }
        }
    }

    public class NavItem : Control
    {
        private bool act;
        private bool hov;
        private bool showTxt;
        private string glyph;
        private string gfont;
        public bool IsActive { get { return act; } set { act = value; Invalidate(); } }
        public bool ShowText { get { return showTxt; } set { showTxt = value; Invalidate(); } }
        public string Glyph { get { return glyph; } set { glyph = value; Invalidate(); } }
        public string GlyphFont { get { return gfont; } set { gfont = value; Invalidate(); } }
        public NavItem()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Cursor = Cursors.Hand;
            Font = new Font("Segoe UI", 9.75F);
            gfont = "Segoe MDL2 Assets";
            Height = 42;
        }
        protected override void OnMouseEnter(EventArgs e) { hov = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hov = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            if (act || hov)
            {
                using (GraphicsPath p = Gfx.Round(new RectangleF(8f, 3f, Width - 16f, Height - 6f), 10f))
                using (SolidBrush b = new SolidBrush(act ? Color.FromArgb(50, Theme.Acc) : Color.FromArgb(24, Theme.Acc)))
                    g.FillPath(b, p);
            }
            using (Font gf = new Font(gfont, 11.5F))
            {
                SizeF gs = g.MeasureString(glyph, gf);
                float gx = showTxt ? 20f : (Width - gs.Width) / 2f;
                using (SolidBrush b = new SolidBrush(act ? Theme.AccL : Color.FromArgb(150, 150, 165)))
                    g.DrawString(glyph, gf, b, gx, (Height - gs.Height) / 2f);
                if (showTxt)
                {
                    SizeF ts = g.MeasureString(Text, Font);
                    using (SolidBrush tb = new SolidBrush(act ? Color.FromArgb(238, 238, 246) : Color.FromArgb(178, 178, 192)))
                        g.DrawString(Text, Font, tb, 52f, (Height - ts.Height) / 2f);
                }
            }
            if (act && showTxt)
            {
                using (GraphicsPath p = Gfx.Round(new RectangleF(12f, Height / 2f - 8f, 3f, 16f), 1.5f))
                using (SolidBrush b = new SolidBrush(Theme.AccL))
                    g.FillPath(b, p);
            }
        }
    }

    public class CategoryTile : Control
    {
        private bool hov;
        private string title;
        private string sub;
        private string mono;
        private bool subAcc;
        public string Title { get { return title; } set { title = value; Invalidate(); } }
        public string Subtitle { get { return sub; } set { sub = value; Invalidate(); } }
        public string Monogram { get { return mono; } set { mono = value; Invalidate(); } }
        public bool SubAccent { get { return subAcc; } set { subAcc = value; Invalidate(); } }
        public CategoryTile()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Cursor = Cursors.Hand;
        }
        protected override void OnMouseEnter(EventArgs e) { hov = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hov = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            using (GraphicsPath p = Gfx.Round(new RectangleF(0.5f, 0.5f, Width - 1f, Height - 1f), 14f))
            {
                using (SolidBrush b = new SolidBrush(hov ? Color.FromArgb(35, 35, 49) : Color.FromArgb(27, 27, 35)))
                    g.FillPath(b, p);
                using (Pen pen = new Pen(hov ? Color.FromArgb(90, Theme.Acc) : Theme.Border, 1f))
                    g.DrawPath(pen, p);
            }
            float ms = 40f;
            RectangleF mr = new RectangleF(16f, (Height - ms) / 2f, ms, ms);
            using (GraphicsPath mp = Gfx.Round(mr, 12f))
            using (LinearGradientBrush lb = new LinearGradientBrush(mr, Theme.AccL, Theme.AccD, LinearGradientMode.Vertical))
                g.FillPath(lb, mp);
            using (Font mf = new Font("Segoe UI Semibold", 14F))
            {
                string s = string.IsNullOrEmpty(mono) ? "?" : mono;
                if (s.Length > 2) s = s.Substring(0, 2);
                SizeF msz = g.MeasureString(s, mf);
                using (SolidBrush b = new SolidBrush(Color.White))
                    g.DrawString(s, mf, b, mr.X + (ms - msz.Width) / 2f, mr.Y + (ms - msz.Height) / 2f);
            }
            Rectangle tr1 = new Rectangle(68, 0, Width - 82, Height / 2);
            Rectangle tr2 = new Rectangle(68, Height / 2, Width - 82, Height / 2 - 2);
            using (Font tf = new Font("Segoe UI Semibold", 9.75F))
                TextRenderer.DrawText(g, title, tf, tr1, Color.FromArgb(237, 237, 245), TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.HidePrefix);
            using (Font sf = new Font("Segoe UI", 8.25F))
                TextRenderer.DrawText(g, sub, sf, tr2, subAcc ? Theme.AccL : Color.FromArgb(140, 140, 156), TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        }
    }

    public class IcezProgressBar : Control
    {
        private double pct;
        public double Percent
        {
            get { return pct; }
            set { double v = value; if (v < 0) v = 0; if (v > 100) v = 100; pct = v; Invalidate(); }
        }
        public IcezProgressBar()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            Height = 10;
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
            using (GraphicsPath tp = Gfx.Round(new RectangleF(0f, 0f, Width, Height), Height / 2f))
            using (SolidBrush b = new SolidBrush(Color.FromArgb(30, 30, 38)))
                e.Graphics.FillPath(b, tp);
            if (pct > 0.5)
            {
                float w = (float)(Width * pct / 100.0);
                if (w > Height)
                {
                    RectangleF fr = new RectangleF(0f, 0f, w, Height);
                    using (GraphicsPath fp = Gfx.Round(fr, Height / 2f))
                    using (LinearGradientBrush lb = new LinearGradientBrush(fr, Theme.AccL, Theme.AccD, LinearGradientMode.Horizontal))
                        e.Graphics.FillPath(lb, fp);
                }
            }
        }
    }

    public class IcezSlider : Control
    {
        private int val;
        private int min;
        private int max;
        private bool drag;
        public event EventHandler ValueChanged;
        public int Value
        {
            get { return val; }
            set { int v = value; if (v < min) v = min; if (v > max) v = max; if (v != val) { val = v; Invalidate(); if (ValueChanged != null) ValueChanged(this, EventArgs.Empty); } }
        }
        public int Minimum { get { return min; } set { min = value; if (val < min) val = min; Invalidate(); } }
        public int Maximum { get { return max; } set { max = value; if (val > max) val = max; Invalidate(); } }
        public IcezSlider()
        {
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint | ControlStyles.SupportsTransparentBackColor, true);
            BackColor = Color.Transparent;
            min = 0; max = 10; val = 0; Height = 26; Cursor = Cursors.Hand;
        }
        private int PosToValue(int x)
        {
            int pad = 10;
            if (Width <= pad * 2) return min;
            double r = (double)(x - pad) / (double)(Width - pad * 2);
            if (r < 0) r = 0; if (r > 1) r = 1;
            return min + (int)Math.Round(r * (max - min));
        }
        private int ValueToPos()
        {
            int pad = 10;
            if (max == min) return pad;
            double r = (double)(val - min) / (double)(max - min);
            return pad + (int)Math.Round(r * (Width - pad * 2));
        }
        protected override void OnMouseDown(MouseEventArgs e) { drag = true; Value = PosToValue(e.X); base.OnMouseDown(e); }
        protected override void OnMouseMove(MouseEventArgs e) { if (drag) Value = PosToValue(e.X); base.OnMouseMove(e); }
        protected override void OnMouseUp(MouseEventArgs e) { drag = false; base.OnMouseUp(e); }
        protected override void OnMouseLeave(EventArgs e) { drag = false; base.OnMouseLeave(e); }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            int y = Height / 2;
            int pad = 10;
            using (GraphicsPath t = Gfx.Round(new RectangleF(pad, y - 2f, Width - pad * 2, 4f), 2f))
            using (SolidBrush b = new SolidBrush(Color.FromArgb(42, 42, 53)))
                g.FillPath(b, t);
            int px = ValueToPos();
            if (px > pad)
            {
                using (GraphicsPath f = Gfx.Round(new RectangleF(pad, y - 2f, px - pad, 4f), 2f))
                using (SolidBrush fb = new SolidBrush(Theme.Acc))
                    g.FillPath(fb, f);
            }
            using (SolidBrush tb = new SolidBrush(Theme.AccL))
                g.FillEllipse(tb, px - 7, y - 7, 14, 14);
            using (Pen pen = new Pen(Color.FromArgb(20, 20, 26), 2f))
                g.DrawEllipse(pen, px - 7, y - 7, 14, 14);
        }
    }
}
'@

if (-not ('IcezOP.IcezCheckBox' -as [type])) {
    Add-Type -TypeDefinition $cs -ReferencedAssemblies @('System.dll','System.Drawing.dll','System.Windows.Forms.dll')
}

# Aplicar el tema guardado ANTES de construir la interfaz
Apply-Theme ([string]$Script:Settings.Theme)

# ════════════════════ 5. HELPERS DE UI ════════════════════
function Pt([int]$x, [int]$y) { New-Object System.Drawing.Point($x, $y) }
function Sz([int]$w, [int]$h) { New-Object System.Drawing.Size($w, $h) }
function RectF([single]$x, [single]$y, [single]$w, [single]$h) { New-Object System.Drawing.RectangleF($x, $y, $w, $h) }

function New-Label {
    param(
        [string]$Text,
        [int]$X, [int]$Y, [int]$W, [int]$H,
        [single]$Size = 10,
        [string]$ColName = 'Text',
        [switch]$Bold,
        [string]$Family = 'Segoe UI'
    )
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = Pt $X $Y
    $l.Size = Sz $W $H
    $l.Font = New-Object System.Drawing.Font($Family, $Size, $(if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }))
    $l.ForeColor = (icezCol $ColName)
    $l.BackColor = [System.Drawing.Color]::Transparent
    return $l
}

function New-Card([int]$X, [int]$Y, [int]$W, [int]$H) {
    $c = New-Object IcezOP.CardPanel
    $c.Location = Pt $X $Y
    $c.Size = Sz $W $H
    return $c
}

# Esquinas redondeadas NATIVAS de Windows 11 (sin artefactos negros).
# Fallback a Region clasica si DWM no soporta el atributo (Win10).
function Set-FormRounded([System.Windows.Forms.Form]$f, [int]$Radius = 14) {
    $applied = $false
    try {
        $null = $f.Handle
        $pref = 2   # DWMWCP_ROUND
        $hr = [Icez.Win32]::DwmSetWindowAttribute($f.Handle, 33, [ref]$pref, 4)
        if ($hr -eq 0) { $applied = $true }
    } catch {}
    if (-not $applied) {
        try {
            $rg = [IcezOP.Gfx]::Round((RectF 0 0 $f.Width $f.Height), $Radius)
            $f.Region = New-Object System.Drawing.Region($rg)
        } catch {}
    }
}

# Overlay oscuro con fundido de entrada (efecto modal con blur simulado)
function Show-IcezOverlay {
    $ov = New-Object System.Windows.Forms.Form
    $ov.FormBorderStyle = 'None'
    $ov.ShowInTaskbar = $false
    $ov.StartPosition = 'Manual'
    $ov.Bounds = $Script:Form.Bounds
    $ov.BackColor = (icezCol 'OvBg')
    $ov.Opacity = 0
    $ov.Show($Script:Form)
    $t = New-Object System.Windows.Forms.Timer
    $t.Interval = 16
    $t.Add_Tick({
        if ($ov.Opacity -lt 0.62) { $ov.Opacity = [Math]::Min(0.62, $ov.Opacity + 0.07) }
        else { $this.Stop(); $this.Dispose() }
    }.GetNewClosure())
    $t.Start()
    return $ov
}

function Get-WingetPath {
    $wg = (Get-Command winget -ErrorAction SilentlyContinue).Source
    if (-not $wg) {
        $alt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
        if (Test-Path $alt) { $wg = $alt }
    }
    return $wg
}

function Update-ModalCounter {
    if ($Script:ModalCounterLbl -and $Script:ModalBoxes) {
        $n = 0
        foreach ($b in $Script:ModalBoxes) { if ($b.Checked) { $n++ } }
        $Script:ModalCounterLbl.Text = ('{0} de {1} seleccionados' -f $n, $Script:ModalTotal)
    }
}

function Update-DriverBtn {
    $n = @($Script:DriverSel.Keys | Where-Object { $Script:DriverSel[$_] }).Count
    if ($n -gt 0) {
        $Script:DrvUpdBtn.Visible = $true
        $Script:DrvUpdBtn.Text = ('ACTUALIZAR SELECCIONADOS ({0})' -f $n)
    } else {
        $Script:DrvUpdBtn.Visible = $false
    }
}

function Update-HomeUI {
    $a = 0
    $t = 0
    foreach ($k in $Script:AppSel.Keys)   { if ($Script:AppSel[$k])   { $a++ } }
    foreach ($k in $Script:TweakSel.Keys) { if ($Script:TweakSel[$k]) { $t++ } }
    $Script:HomeStatA.Text = [string]$a
    $Script:HomeStatT.Text = [string]$t
    $Script:HomeStatQ.Text = [string]($a + $t)
    $Script:ExecBtn.Enabled = (($a + $t) -gt 0)
    $Script:StatusLbl.Text  = ('En cola: {0} apps - {1} tweaks' -f $a, $t)
    foreach ($cat in $Script:AppTiles.Keys) {
        $tot = @($Script:Apps | Where-Object { $_.Cat -eq $cat }).Count
        $sel = @($Script:Apps | Where-Object { $_.Cat -eq $cat -and [bool]$Script:AppSel[$_.ID] }).Count
        $tile = $Script:AppTiles[$cat]
        $tile.Subtitle = ('{0} apps - {1} marcadas' -f $tot, $sel)
        $tile.SubAccent = ($sel -gt 0)
    }
    foreach ($cat in $Script:TweakTiles.Keys) {
        $tot = @($Script:Tweaks | Where-Object { $_.Cat -eq $cat }).Count
        $sel = @($Script:Tweaks | Where-Object { $_.Cat -eq $cat -and [bool]$Script:TweakSel[($_.Cat + '|' + $_.Name)] }).Count
        $tile = $Script:TweakTiles[$cat]
        $tile.Subtitle = ('{0} tweaks - {1} marcados' -f $tot, $sel)
        $tile.SubAccent = ($sel -gt 0)
    }
}

# ════════════════════ 6. WORKERS (Runspaces) ════════════════════
 $Script:WorkerCode = @'
param($sync, $cfg)
function Log([string]$m) { $sync.Log.Enqueue($m) }

 $tasks = @($sync.Tasks)
 $total = $tasks.Count
 $sync.OkCount = 0
 $sync.FailCount = 0
 $sync.Percent = 0

for ($i = 0; $i -lt $total; $i++) {
    if ($sync.Cancel) { Log '  !  Cancelado por el usuario.'; break }
    $t = $tasks[$i]
    $sync.Percent = [math]::Round(($i / $total) * 100, 1)
    $sync.Status = ('[{0}/{1}]  {2}' -f ($i + 1), $total, $t.Label)
    Log ('> ' + $t.Label)
    $ok = $false
    try {
        switch ($t.Kind) {

            'restore' {
                try {
                    Enable-ComputerRestore -Drive ($env:SystemDrive + '\') -ErrorAction SilentlyContinue
                    New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -Name 'SystemRestorePointCreationFrequency' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
                    Checkpoint-Computer -Description 'icezOP - Pre-optimizacion' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop | Out-Null
                    Log '  OK  Punto de restauracion creado'
                    $ok = $true
                } catch { Log ('  !  No se pudo crear el punto: ' + $_.Exception.Message) }
            }

            'sources' {
                & $sync.Winget source update --disable-interactivity 2>&1 | Out-Null
                Log '  OK  Origenes de Winget actualizados'
                $ok = $true
            }

            'wingetboot' {
                try {
                    Log '  ..  Descargando App Installer (Winget)'
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $vc = Join-Path $env:TEMP 'icezOP-vclibs.appx'
                    $pk = Join-Path $env:TEMP 'icezOP-winget.msixbundle'
                    Invoke-WebRequest 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile $vc -UseBasicParsing
                    Invoke-WebRequest 'https://aka.ms/getwinget' -OutFile $pk -UseBasicParsing
                    Add-AppxPackage -Path $pk -DependencyPath $vc -ErrorAction Stop
                    $sync.Winget = (Get-Command winget -ErrorAction SilentlyContinue).Source
                    if (-not $sync.Winget) {
                        $alt = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
                        if (Test-Path $alt) { $sync.Winget = $alt }
                    }
                    if ($sync.Winget) { Log '  OK  Winget instalado'; $ok = $true }
                    else { Log '  X   Winget instalado pero no en PATH. Reinicia.' }
                } catch { Log ('  X   ' + $_.Exception.Message) }
            }

            'app' {
                if (-not $sync.Winget) { Log '  X   Winget no disponible'; break }
                $wg = $sync.Winget
                $maxTry = 1 + [int]$cfg.Retries
                for ($try = 1; $try -le $maxTry; $try++) {
                    if ($try -gt 1) { Log ('  ..  Reintento ' + $try); Start-Sleep -Seconds 2 }
                    & $wg install --id $t.Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
                    $code = $LASTEXITCODE
                    if ($code -eq 0) { Log '  OK  Instalado correctamente'; $ok = $true; break }
                    & $wg list --id $t.Id --exact --disable-interactivity 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) { Log '  OK  Ya estaba instalado'; $ok = $true; break }
                    if ($try -eq $maxTry) { Log ('  X   Fallo (codigo ' + $code + ')') }
                }
            }

            'tweak' {
                $err = $null
                $eapPrev = $ErrorActionPreference
                try {
                    $ErrorActionPreference = 'Stop'
                    $null = Invoke-Expression -Command $t.Script
                } catch { $err = $_ }
                finally { $ErrorActionPreference = $eapPrev }
                if ($err) { Log ('  X   ' + $err.Exception.Message) }
                else { Log '  OK  Aplicado'; $ok = $true }
            }

            'driver' {
                if ($t.Action -eq 'winget' -and $t.Id) {
                    if (-not $sync.Winget) { Log '  X   Winget no disponible'; break }
                    $wg = $sync.Winget
                    & $wg install --id $t.Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-Null
                    $code = $LASTEXITCODE
                    if ($code -eq 0) { Log '  OK  Instalador ejecutado correctamente'; $ok = $true }
                    else { Log ('  X   Fallo (codigo ' + $code + ')') }
                }
                elseif ($t.Action -eq 'url' -and $t.Url) {
                    Start-Process $t.Url
                    Log '  OK  Se abrio la pagina oficial de descarga en el navegador'
                    $ok = $true
                }
                else { Log '  !  Este driver no tiene accion definida en drivers.json' }
            }

            'openurl' {
                Start-Process $t.Url
                Log '  OK  Abierta en el navegador'
                $ok = $true
            }
        }
    } catch { Log ('  X   Error: ' + $_.Exception.Message) }
    if ($ok) { $sync.OkCount++ } else { $sync.FailCount++ }
}
 $sync.Percent = 100
 $sync.Status = 'Completado'
 $sync.Done = $true
'@

# Escaneo LOCAL de controladores (Win32_PnPSignedDriver) + analisis contra drivers.json
 $Script:DriverScanCode = @'
param($sync, $catalog)

function CmpVer([string]$x, [string]$y) {
    $ax = @()
    foreach ($p in ($x -split '\.')) { $v = 0; if ([int]::TryParse($p, [ref]$v)) { $ax += $v } else { $ax += 0 } }
    $ay = @()
    foreach ($p in ($y -split '\.')) { $v = 0; if ([int]::TryParse($p, [ref]$v)) { $ay += $v } else { $ay += 0 } }
    $n = [Math]::Max($ax.Count, $ay.Count)
    for ($i = 0; $i -lt $n; $i++) {
        $vx = 0; if ($i -lt $ax.Count) { $vx = $ax[$i] }
        $vy = 0; if ($i -lt $ay.Count) { $vy = $ay[$i] }
        if ($vx -lt $vy) { return -1 }
        if ($vx -gt $vy) { return 1 }
    }
    return 0
}

 $sync.DriverPhase = 'scanning'
try {
    $raw = @(Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.DeviceName })
    $seen = @{}
    $list = New-Object System.Collections.ArrayList
    foreach ($d in $raw) {
        $n = [string]$d.DeviceName
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        $key = $n.ToLower()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true

        $cur = [string]$d.DriverVersion
        $dateStr = ''
        if ($d.DriverDate) {
            $ds = [string]$d.DriverDate
            if ($ds.Length -ge 8) { $dateStr = $ds.Substring(0,4) + '-' + $ds.Substring(4,2) + '-' + $ds.Substring(6,2) }
        }

        $state = 'unknown'
        $latest = ''; $action = ''; $id = ''; $url = ''; $note = ''
        foreach ($c in $catalog) {
            if ($n -match [string]$c.Match) {
                $latest = [string]$c.Latest
                if ($c.Action) { $action = [string]$c.Action }
                if ($c.Id)     { $id = [string]$c.Id }
                if ($c.Url)    { $url = [string]$c.Url }
                if ($c.Note)   { $note = [string]$c.Note }
                if ($cur -and $latest) {
                    if ((CmpVer $cur $latest) -lt 0) { $state = 'update' } else { $state = 'current' }
                }
                break
            }
        }

        [void]$list.Add(@{
            Name    = $n
            Current = $cur
            Latest  = $latest
            Date    = $dateStr
            Mfr     = [string]$d.Manufacturer
            State   = $state
            Action  = $action
            Id      = $id
            Url     = $url
            Note    = $note
        })
    }
    $sync.DriverScan = $list
    $sync.DriverPhase = 'done'
} catch {
    $sync.DriverError = $_.Exception.Message
    $sync.DriverPhase = 'error'
}
'@

# ════════════════════ 7. CONSTRUCCION DE LA INTERFAZ ════════════════════
[System.Windows.Forms.Application]::EnableVisualStyles()

 $Script:Form = New-Object System.Windows.Forms.Form
 $Script:Form.Text = 'icezOP'
 $Script:Form.StartPosition = 'CenterScreen'
 $Script:Form.FormBorderStyle = 'None'
 $Script:Form.MaximizeBox = $false
 $Script:Form.Size = Sz 1160 720
 $Script:Form.BackColor = (icezCol 'Bg')
 $Script:Form.Font = New-Object System.Drawing.Font('Segoe UI', 9.75)

# Esquinas redondeadas nativas (Win11) - reemplaza al Region clasico
Set-FormRounded $Script:Form 16

# Borde exterior redondeado dibujado a mano (AntiAlias, color del tema)
 $Script:Form.Add_Paint({
    $g = $_.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $r = RectF 0.5 0.5 ($Script:Form.ClientSize.Width - 1) ($Script:Form.ClientSize.Height - 1)
    $p = [IcezOP.Gfx]::Round($r, 14)
    $pen = New-Object System.Drawing.Pen((icezCol 'Border'))
    $g.DrawPath($pen, $p)
    $pen.Dispose()
})

# Icono generado en runtime
try {
    $icoBmp = New-Object System.Drawing.Bitmap 32, 32
    $ig = [System.Drawing.Graphics]::FromImage($icoBmp)
    $ig.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $ip = [IcezOP.Gfx]::Round((RectF 0 0 32 32), 9)
    $ib = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, 32, 32)), (icezCol 'AccL'), (icezCol 'AccD'), 'Vertical')
    $ig.FillPath($ib, $ip)
    $if = New-Object System.Drawing.Font('Segoe Script', 16, ([System.Drawing.FontStyle]::Bold -bor [System.Drawing.FontStyle]::Italic))
    $is = $ig.MeasureString('i', $if)
    $ig.DrawString('i', $if, [System.Drawing.Brushes]::White, ((32 - $is.Width) / 2), ((32 - $is.Height) / 2))
    $Script:Form.Icon = [System.Drawing.Icon]::FromHandle($icoBmp.GetHicon())
    $ig.Dispose(); $ib.Dispose(); $if.Dispose()
} catch {}

# ── Header (Dock Top) ──────────────────────────────────────────────
 $header = New-Object System.Windows.Forms.Panel
 $header.Dock = 'Top'
 $header.Height = 72
 $header.BackColor = (icezCol 'Bg')

 $btnMenu = New-Object IcezOP.GlyphButton
 $btnMenu.Location = Pt 16 19
 $btnMenu.Size = Sz 40 40
 $btnMenu.Glyph = (icezG 'Menu')
 $btnMenu.GlyphFont = $Script:GlyphFont
 $btnMenu.Add_Click({ $Script:Collapsed = -not $Script:Collapsed; $animTimer.Start() })
 $header.Controls.Add($btnMenu)

 $gTmp = $Script:Form.CreateGraphics()
 $fLogo = New-Object System.Drawing.Font('Segoe Script', 22, ([System.Drawing.FontStyle]::Bold -bor [System.Drawing.FontStyle]::Italic))
 $w1 = [int]$gTmp.MeasureString('icez', $fLogo).Width
 $w2 = [int]$gTmp.MeasureString('OP', $fLogo).Width
 $gTmp.Dispose()
 $x0 = [int]((1160 - ($w1 + $w2)) / 2)
 $logo1 = New-Label 'icez' $x0 10 ($w1 + 10) 52 22 'Text' -Family 'Segoe Script'
 $logo1.Font = $fLogo
 $logo2 = New-Label 'OP' ($x0 + $w1) 10 ($w2 + 10) 52 22 'AccL' -Family 'Segoe Script'
 $logo2.Font = $fLogo
 $header.Controls.Add($logo1)
 $header.Controls.Add($logo2)

 $btnMin = New-Object IcezOP.GlyphButton
 $btnMin.Location = Pt 1064 19
 $btnMin.Glyph = (icezG 'Min')
 $btnMin.GlyphFont = $Script:GlyphFont
 $btnMin.Add_Click({ $Script:Form.WindowState = 'Minimized' })

 $btnClose = New-Object IcezOP.GlyphButton
 $btnClose.Location = Pt 1108 19
 $btnClose.Glyph = (icezG 'X')
 $btnClose.GlyphFont = $Script:GlyphFont
 $btnClose.Danger = $true
 $btnClose.Add_Click({ $Script:Form.Close() })

 $header.Controls.Add($btnMin)
 $header.Controls.Add($btnClose)

 $Script:DragInfo = @{ Down = $false; X = 0; Y = 0 }
function Enable-Drag($ctl) {
    $ctl.Add_MouseDown({ if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $Script:DragInfo.Down = $true; $Script:DragInfo.X = $_.X; $Script:DragInfo.Y = $_.Y } })
    $ctl.Add_MouseUp({ $Script:DragInfo.Down = $false })
    $ctl.Add_MouseMove({
        if ($Script:DragInfo.Down) {
            $Script:Form.Left += ($_.X - $Script:DragInfo.X)
            $Script:Form.Top  += ($_.Y - $Script:DragInfo.Y)
        }
    })
}
Enable-Drag $header
Enable-Drag $logo1
Enable-Drag $logo2

 $sep = New-Object System.Windows.Forms.Panel
 $sep.Dock = 'Top'
 $sep.Height = 1
 $sep.BackColor = (icezCol 'Border')

# ── Barra inferior (Dock Bottom) ───────────────────────────────────
 $bottom = New-Object System.Windows.Forms.Panel
 $bottom.Dock = 'Bottom'
 $bottom.Height = 64
 $bottom.BackColor = (icezCol 'BgAlt')

 $bline = New-Object System.Windows.Forms.Panel
 $bline.Dock = 'Top'
 $bline.Height = 1
 $bline.BackColor = (icezCol 'Border')
 $bottom.Controls.Add($bline)

 $Script:StatusLbl = New-Label 'En cola: 0 apps - 0 tweaks' 24 18 640 22 9.5 'Sub'
 $bottom.Controls.Add($Script:StatusLbl)

 $verLbl = New-Label ('icezOP v' + $Script:Version) 24 40 300 16 8 'Dim'
 $bottom.Controls.Add($verLbl)

 $Script:ExecBtn = New-Object IcezOP.GradientButton
 $Script:ExecBtn.Location = Pt 946 11
 $Script:ExecBtn.Size = Sz 190 42
 $Script:ExecBtn.Text = 'EJECUTAR'
 $Script:ExecBtn.Glyph = (icezG 'Play')
 $Script:ExecBtn.GlyphFont = $Script:GlyphFont
 $Script:ExecBtn.Enabled = $false
 $bottom.Controls.Add($Script:ExecBtn)

# ── Menu lateral (Dock Left, animable) ─────────────────────────────
 $sidebar = New-Object System.Windows.Forms.Panel
 $sidebar.Dock = 'Left'
 $sidebar.Width = 220
 $sidebar.BackColor = (icezCol 'BgAlt')

 $Script:NavList = @()
function New-NavItem([string]$Glyph, [string]$Text, [string]$Tag, [int]$Y) {
    $n = New-Object IcezOP.NavItem
    $n.Glyph = $Glyph
    $n.GlyphFont = $Script:GlyphFont
    $n.Text = $Text
    $n.Tag = $Tag
    $n.Location = Pt 10 $Y
    $n.Size = Sz 200 42
    $n.Add_Click({ Switch-Page ([string]$this.Tag) })
    $script:sidebar.Controls.Add($n)
    $Script:NavList += $n
}
New-NavItem (icezG 'Home') 'Inicio'        'home' 20
New-NavItem (icezG 'Apps') 'Aplicaciones'  'apps' 68
New-NavItem (icezG 'Fix')  'Tweaks'        'tweaks' 116
New-NavItem (icezG 'Drv')  'Controladores' 'drivers' 164
New-NavItem (icezG 'Gear') 'Ajustes'       'settings' 212

# ── Host de contenido (Dock Fill) ──────────────────────────────────
 $content = New-Object System.Windows.Forms.Panel
 $content.Dock = 'Fill'
 $content.BackColor = (icezCol 'Bg')
 $Script:Pages = @{}

function New-Page([string]$Tag) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = 'Fill'
    $p.BackColor = (icezCol 'Bg')
    $p.Visible = $false
    $content.Controls.Add($p)
    $Script:Pages[$Tag] = $p
    return $p
}

function Switch-Page {
    param([string]$Tag)
    foreach ($k in $Script:Pages.Keys) {
        $Script:Pages[$k].Visible = ($k -eq $Tag)
        if ($k -eq $Tag) { $Script:Pages[$k].BringToFront() }
    }
    foreach ($n in $Script:NavList) { $n.IsActive = ([string]$n.Tag -eq $Tag) }
}

# ═══════════ PAGINA: INICIO ═══════════
 $pHome = New-Page 'home'
 $pHome.Controls.Add((New-Label 'Inicio' 24 20 400 34 15 'Text' -Bold))
 $pHome.Controls.Add((New-Label 'El primer programa que ejecutas despues de formatear tu PC.' 24 52 600 22 9.5 'Sub'))

 $hero = New-Card 24 82 892 128
 $hero.Controls.Add((New-Label 'Bienvenido a icezOP' 24 16 400 28 13.5 'Text' -Bold))
 $hero.Controls.Add((New-Label 'Explora las categorias, marca lo que quieras y pulsa EJECUTAR.' 24 46 620 20 9 'Sub'))

 $btnRec = New-Object IcezOP.GradientButton
 $btnRec.Location = Pt 24 80
 $btnRec.Size = Sz 230 36
 $btnRec.Text = 'MARCAR RECOMENDADOS'
 $btnRec.Add_Click({
    foreach ($a in $Script:Apps) { if ($a.Rec) { $Script:AppSel[[string]$a.ID] = $true } }
    Update-HomeUI
})
 $hero.Controls.Add($btnRec)

 $btnClear = New-Object IcezOP.GhostButton
 $btnClear.Location = Pt 268 80
 $btnClear.Size = Sz 180 36
 $btnClear.Text = 'LIMPIAR SELECCION'
 $btnClear.Add_Click({ $Script:AppSel = @{}; $Script:TweakSel = @{}; Update-HomeUI })
 $hero.Controls.Add($btnClear)
 $pHome.Controls.Add($hero)

 $statRefs = @()
 $sx = 24
foreach ($s in @('Apps seleccionadas', 'Tweaks seleccionados', 'Tareas en cola')) {
    $c = New-Card $sx 226 289 88
    $num = New-Label '0' 20 10 120 40 20 'AccL' -Bold
    $cap = New-Label $s 20 52 240 20 8.75 'Sub'
    $c.Controls.Add($num)
    $c.Controls.Add($cap)
    $pHome.Controls.Add($c)
    $statRefs += $num
    $sx += 301
}
 $Script:HomeStatA = $statRefs[0]
 $Script:HomeStatT = $statRefs[1]
 $Script:HomeStatQ = $statRefs[2]

 $how = New-Card 24 330 892 104
 $how.Controls.Add((New-Label 'Como funciona?' 24 14 300 24 11 'Text' -Bold))
 $how.Controls.Add((New-Label '1 - Abri una categoria y marca apps (Winget) o tweaks (registro, servicios...).' 24 42 840 18 8.75 'Sub'))
 $how.Controls.Add((New-Label '2 - Revisa los controladores en Controladores (escaneo local contra drivers.json).' 24 62 840 18 8.75 'Sub'))
 $how.Controls.Add((New-Label '3 - Pulsa EJECUTAR. Todo se procesa en cola sin congelar la interfaz.' 24 82 840 18 8.75 'Sub'))
 $pHome.Controls.Add($how)

# ═══════════ PAGINA: APLICACIONES ═══════════
 $pApps = New-Page 'apps'
 $pApps.Controls.Add((New-Label 'Aplicaciones' 24 20 400 34 15 'Text' -Bold))
 $pApps.Controls.Add((New-Label 'Instalacion oficial y silenciosa con Winget.' 24 52 700 22 9.5 'Sub'))

 $appFlow = New-Object System.Windows.Forms.FlowLayoutPanel
 $appFlow.Location = Pt 24 82
 $appFlow.Size = Sz 892 490
 $appFlow.BackColor = (icezCol 'Bg')
 $appFlow.AutoScroll = $true
 $appFlow.WrapContents = $true
 $pApps.Controls.Add($appFlow)

 $Script:AppTiles = @{}
foreach ($cat in $Script:AppCats) {
    $tile = New-Object IcezOP.CategoryTile
    $tile.Size = Sz 284 86
    $tile.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 10)
    $tile.Title = [string]$cat
    $tile.Monogram = ([string]$cat).Substring(0, 1)
    $tile.Tag = [string]$cat
    $tile.Add_Click({ Show-CategoryModal -Category ([string]$this.Tag) -Type 'app' })
    $Script:AppTiles[[string]$cat] = $tile
    $appFlow.Controls.Add($tile)
}

# ═══════════ PAGINA: TWEAKS ═══════════
 $pTweaks = New-Page 'tweaks'
 $pTweaks.Controls.Add((New-Label 'Tweaks y Optimizacion' 24 20 500 34 15 'Text' -Bold))
 $pTweaks.Controls.Add((New-Label 'Ajustes de registro, servicios, energia, red y rendimiento.' 24 52 700 22 9.5 'Sub'))

 $tweakFlow = New-Object System.Windows.Forms.FlowLayoutPanel
 $tweakFlow.Location = Pt 24 82
 $tweakFlow.Size = Sz 892 490
 $tweakFlow.BackColor = (icezCol 'Bg')
 $tweakFlow.AutoScroll = $true
 $tweakFlow.WrapContents = $true
 $pTweaks.Controls.Add($tweakFlow)

 $Script:TweakTiles = @{}
foreach ($cat in $Script:TweakCats) {
    $tile = New-Object IcezOP.CategoryTile
    $tile.Size = Sz 284 86
    $tile.Margin = New-Object System.Windows.Forms.Padding(0, 0, 10, 10)
    $tile.Title = [string]$cat
    $tile.Monogram = ([string]$cat).Substring(0, 1)
    $tile.Tag = [string]$cat
    $tile.Add_Click({ Show-CategoryModal -Category ([string]$this.Tag) -Type 'tweak' })
    $Script:TweakTiles[[string]$cat] = $tile
    $tweakFlow.Controls.Add($tile)
}

# ═══════════ PAGINA: CONTROLADORES (motor propio) ═══════════
 $pDrv = New-Page 'drivers'
 $pDrv.Controls.Add((New-Label 'Controladores' 24 16 400 34 15 'Text' -Bold))
 $pDrv.Controls.Add((New-Label 'Escaneo local contra drivers.json - sin Windows Update. Los desactualizados aparecen arriba.' 24 48 760 22 9.5 'Sub'))

 $drvCard = New-Card 24 80 892 84
 $drvCard.Controls.Add((New-Label 'Escaneo de controladores' 20 12 400 24 10.5 'Text' -Bold))
 $Script:DriverStatusLbl = New-Label 'Nunca se ha escaneado. Pulsa ESCANEAR para analizar tu equipo.' 20 42 620 20 9 'Sub'
 $drvCard.Controls.Add($Script:DriverStatusLbl)

 $Script:DrvScanBtn = New-Object IcezOP.GradientButton
 $Script:DrvScanBtn.Location = Pt 692 22
 $Script:DrvScanBtn.Size = Sz 176 40
 $Script:DrvScanBtn.Text = 'ESCANEAR'
 $Script:DrvScanBtn.Glyph = (icezG 'Drv')
 $Script:DrvScanBtn.GlyphFont = $Script:GlyphFont
 $drvCard.Controls.Add($Script:DrvScanBtn)
 $pDrv.Controls.Add($drvCard)

 $Script:DrvPendTitle = New-Label 'Pendientes de actualizacion (0)' 24 178 500 24 11 'Text' -Bold
 $pDrv.Controls.Add($Script:DrvPendTitle)

 $Script:DriverUpdatesPanel = New-Object System.Windows.Forms.Panel
 $Script:DriverUpdatesPanel.Location = Pt 24 204
 $Script:DriverUpdatesPanel.Size = Sz 892 150
 $Script:DriverUpdatesPanel.BackColor = (icezCol 'Bg')
 $Script:DriverUpdatesPanel.AutoScroll = $true
 $pDrv.Controls.Add($Script:DriverUpdatesPanel)

 $Script:DrvInstTitle = New-Label 'Instalados (0)' 24 366 500 24 11 'Text' -Bold
 $pDrv.Controls.Add($Script:DrvInstTitle)

 $Script:DriverInstalledPanel = New-Object System.Windows.Forms.Panel
 $Script:DriverInstalledPanel.Location = Pt 24 392
 $Script:DriverInstalledPanel.Size = Sz 892 146
 $Script:DriverInstalledPanel.BackColor = (icezCol 'Bg')
 $Script:DriverInstalledPanel.AutoScroll = $true
 $pDrv.Controls.Add($Script:DriverInstalledPanel)

 $Script:DrvUpdBtn = New-Object IcezOP.GradientButton
 $Script:DrvUpdBtn.Location = Pt 24 548
 $Script:DrvUpdBtn.Size = Sz 300 42
 $Script:DrvUpdBtn.Text = 'ACTUALIZAR SELECCIONADOS'
 $Script:DrvUpdBtn.Visible = $false
 $pDrv.Controls.Add($Script:DrvUpdBtn)

 $Script:DrvScanBtn.Add_Click({
    if ($Script:DrvPs -and $Script:DrvPs.InvocationStateInfo.State -eq 'Running') { return }
    $sync.DriverPhase = 'scanning'
    $Script:DriverRendered = $false
    $Script:DriverStatusLbl.Text = 'Escaneando controladores instalados...'
    try { if ($Script:DrvPs) { $Script:DrvPs.Dispose(); $Script:DrvRs.Dispose() } } catch {}
    $Script:DrvRs = [runspacefactory]::CreateRunspace()
    $Script:DrvRs.ApartmentState = 'STA'
    $Script:DrvRs.ThreadOptions = 'ReuseThread'
    $Script:DrvRs.Open()
    $Script:DrvPs = [powershell]::Create()
    $Script:DrvPs.Runspace = $Script:DrvRs
    [void]$Script:DrvPs.AddScript($Script:DriverScanCode)
    [void]$Script:DrvPs.AddArgument($sync)
    [void]$Script:DrvPs.AddArgument($Script:Drivers)
    $null = $Script:DrvPs.BeginInvoke()
})

function Build-DriverCards {
    $scan = @($sync.DriverScan)
    $Script:DriverUpdatesPanel.Controls.Clear()
    $Script:DriverInstalledPanel.Controls.Clear()
    $Script:DriverSel = @{}

    $updates = @($scan | Where-Object { $_.State -eq 'update' })
    $rest    = @($scan | Where-Object { $_.State -ne 'update' })
    $currents = @($rest | Where-Object { $_.State -eq 'current' })

    $Script:DrvPendTitle.Text = ('Pendientes de actualizacion ({0})' -f $updates.Count)
    $Script:DrvInstTitle.Text = ('Instalados ({0})' -f $rest.Count)

    # ── Grupo 1: DESACTUALIZADOS (arriba, destacados, con accion) ──
    if ($updates.Count -gt 0) {
        $y = 0
        foreach ($u in $updates) {
            $c = New-Object IcezOP.CardPanel
            $c.Location = Pt 0 $y
            $c.Size = Sz 874 64
            $c.BorderColor = (icezCol 'Acc')

            $cb = New-Object IcezOP.IcezCheckBox
            $cb.Location = Pt 16 4
            $cb.Size = Sz 620 30
            $cb.Text = [string]$u.Name

            $sub = ''
            if ($u.Current) { $sub += ('v' + $u.Current) }
            if ($u.Latest)  { $sub += ('   ->   v' + $u.Latest) }
            if ($u.Date)    { $sub += ('   -   ' + $u.Date) }
            $c.Controls.Add((New-Label $sub 44 34 640 20 8.25 'AccL'))

            $btn = New-Object IcezOP.GhostButton
            $btn.Location = Pt 716 17
            $btn.Size = Sz 142 30
            $btn.Text = 'ANADIR A LA COLA'
            $btn.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 8)

            $k = [string]$u.Name
            $btn.Add_Click({ $cb.Checked = -not $cb.Checked }.GetNewClosure())
            $cb.Add_CheckedChanged({
                param($s, $e)
                $Script:DriverSel[$k] = $s.Checked
                if ($s.Checked) {
                    $btn.Text = 'EN COLA'
                    $btn.ForeColor = (icezCol 'Ok')
                } else {
                    $btn.Text = 'ANADIR A LA COLA'
                    $btn.ForeColor = (icezCol 'AccL')
                }
                Update-DriverBtn
            }.GetNewClosure())

            $c.Controls.Add($cb)
            $c.Controls.Add($btn)
            $Script:DriverUpdatesPanel.Controls.Add($c)
            $y += 72
        }
    } else {
        if ($Script:Drivers.Count -eq 0) {
            $Script:DriverUpdatesPanel.Controls.Add((New-Label 'drivers.json no encontrado o sin entradas: no se puede analizar que esta desactualizado.' 4 8 760 36 9 'Warn'))
        } else {
            $Script:DriverUpdatesPanel.Controls.Add((New-Label 'Sin controladores pendientes segun drivers.json.' 4 8 700 20 9 'Ok'))
        }
    }

    # ── Grupo 2: AL DIA / SIN DATOS (abajo, tenues, sin boton) ──
    if ($rest.Count -eq 0) {
        $Script:DriverInstalledPanel.Controls.Add((New-Label 'No se detectaron dispositivos.' 4 6 600 20 9 'Sub'))
    } else {
        $lim = 80
        $y = 0
        $i = 0
        foreach ($r in $rest) {
            if ($i -ge $lim) {
                $Script:DriverInstalledPanel.Controls.Add((New-Label ('... y ' + ($rest.Count - $lim) + ' dispositivos mas') 4 $y 600 20 9 'Sub'))
                break
            }
            $c = New-Object IcezOP.CardPanel
            $c.Location = Pt 0 $y
            $c.Size = Sz 874 44
            $c.FillColor = (icezCol 'BgAlt')
            $c.BorderColor = (icezCol 'BgAlt')

            $nameCol = 'Sub'
            $verText = ('v' + $r.Current)
            if ($r.State -eq 'unknown') {
                $nameCol = 'Dim2'
                if (-not $r.Current) { $verText = 'sin version' }
            }
            $c.Controls.Add((New-Label ([string]$r.Name) 16 11 640 20 9 $nameCol))
            $c.Controls.Add((New-Label $verText 660 13 195 18 8.25 'Dim2'))
            $Script:DriverInstalledPanel.Controls.Add($c)
            $y += 50
            $i++
        }
    }

    $Script:DriverStatusLbl.Text = ('{0} pendientes - {1} al dia - {2} dispositivos en total' -f $updates.Count, $currents.Count, $rest.Count)
    Update-DriverBtn
}

# Ejecutar drivers seleccionados
 $Script:DrvUpdBtn.Add_Click({
    $names = @($Script:DriverSel.Keys | Where-Object { $Script:DriverSel[$_] })
    if ($names.Count -eq 0) { return }
    $scan = @($sync.DriverScan)
    $sync.Winget = Get-WingetPath
    $tasks = New-Object System.Collections.ArrayList
    foreach ($nm in $names) {
        $it = @($scan | Where-Object { $_.Name -eq $nm }) | Select-Object -First 1
        if ($it) {
            [void]$tasks.Add(@{
                Kind   = 'driver'
                Label  = ('Driver: ' + $it.Name)
                Action = [string]$it.Action
                Id     = [string]$it.Id
                Url    = [string]$it.Url
            })
        }
    }
    if ($tasks.Count -gt 0) {
        Start-Run -Tasks $tasks -Title 'Actualizando controladores'
    }
})

# ═══════════ PAGINA: AJUSTES ═══════════
 $pSet = New-Page 'settings'
 $pSet.Controls.Add((New-Label 'Ajustes' 24 20 400 34 15 'Text' -Bold))
 $pSet.Controls.Add((New-Label 'Preferencias y apariencia de icezOP.' 24 52 600 22 9.5 'Sub'))

# ── Card: Apariencia (temas) ──
 $cardTheme = New-Card 24 82 892 110
 $cardTheme.Controls.Add((New-Label 'Apariencia' 20 12 300 24 11 'Text' -Bold))
 $cardTheme.Controls.Add((New-Label 'Tema de colores:' 20 42 140 22 9.5 'Sub'))

 $cbTheme = New-Object System.Windows.Forms.ComboBox
 $cbTheme.Location = Pt 160 38
 $cbTheme.Size = Sz 300 26
 $cbTheme.DropDownStyle = 'DropDownList'
 $cbTheme.FlatStyle = 'Flat'
 $cbTheme.DrawMode = 'OwnerDrawFixed'
 $cbTheme.ItemHeight = 20
 $cbTheme.BackColor = (icezCol 'Card')
 $cbTheme.ForeColor = (icezCol 'Text')
 $cbTheme.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
foreach ($tn in @('Dark Mode (Por defecto)', 'Midnight Blue', 'High Contrast')) {
    [void]$cbTheme.Items.Add($tn)
}
if ($cbTheme.Items.Contains([string]$Script:Settings.Theme)) {
    $cbTheme.SelectedIndex = $cbTheme.Items.IndexOf([string]$Script:Settings.Theme)
} else {
    $cbTheme.SelectedIndex = 0
}
 $cbTheme.Add_DrawItem({
    param($s, $e)
    if ($e.Index -lt 0) { return }
    $sel = (($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -ne 0)
    $bgc = if ($sel) { (icezCol 'Acc') } else { (icezCol 'Card') }
    $brush = New-Object System.Drawing.SolidBrush($bgc)
    $e.Graphics.FillRectangle($brush, $e.Bounds)
    $brush.Dispose()
    $r = New-Object System.Drawing.Rectangle(($e.Bounds.X + 10), $e.Bounds.Y, ($e.Bounds.Width - 10), $e.Bounds.Height)
    [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, [string]$s.Items[$e.Index], $s.Font, $r, (icezCol 'Text'), ([System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::Left))
})
 $cbTheme.Add_SelectedIndexChanged({
    $Script:Settings.Theme = [string]$this.SelectedItem
    Save-Config
    $Script:ThemeHint.Text = ('Tema guardado: {0}. Se aplicara al reiniciar icezOP.' -f $this.SelectedItem)
})
 $cardTheme.Controls.Add($cbTheme)

 $Script:ThemeHint = New-Label '' 20 80 700 20 8.5 'Sub'
 $cardTheme.Controls.Add($Script:ThemeHint)
 $pSet.Controls.Add($cardTheme)

# ── Card: Ejecucion ──
 $cardExec = New-Card 24 204 892 268
 $cardExec.Controls.Add((New-Label 'Ejecucion' 20 14 300 24 11 'Text' -Bold))

 $cbRestore = New-Object IcezOP.IcezCheckBox
 $cbRestore.Location = Pt 20 44
 $cbRestore.Size = Sz 840 30
 $cbRestore.Text = 'Crear punto de restauracion antes de aplicar tweaks'
 $cbRestore.Checked = [bool]$Script:Settings.RestorePoint
 $cbRestore.Add_CheckedChanged({ $Script:Settings.RestorePoint = $this.Checked })
 $cardExec.Controls.Add($cbRestore)

 $cbSources = New-Object IcezOP.IcezCheckBox
 $cbSources.Location = Pt 20 78
 $cbSources.Size = Sz 840 30
 $cbSources.Text = 'Actualizar origenes de Winget antes de instalar'
 $cbSources.Checked = [bool]$Script:Settings.UpdateSources
 $cbSources.Add_CheckedChanged({ $Script:Settings.UpdateSources = $this.Checked })
 $cardExec.Controls.Add($cbSources)

 $cbWg = New-Object IcezOP.IcezCheckBox
 $cbWg.Location = Pt 20 112
 $cbWg.Size = Sz 840 30
 $cbWg.Text = 'Instalar Winget automaticamente si falta'
 $cbWg.Checked = [bool]$Script:Settings.AutoWinget
 $cbWg.Add_CheckedChanged({ $Script:Settings.AutoWinget = $this.Checked })
 $cardExec.Controls.Add($cbWg)

 $cardExec.Controls.Add((New-Label 'Al finalizar:' 20 152 300 20 9.5 'Sub'))

 $cbFinish = New-Object System.Windows.Forms.ComboBox
 $cbFinish.Location = Pt 20 172
 $cbFinish.Size = Sz 300 26
 $cbFinish.DropDownStyle = 'DropDownList'
 $cbFinish.FlatStyle = 'Flat'
 $cbFinish.DrawMode = 'OwnerDrawFixed'
 $cbFinish.ItemHeight = 20
 $cbFinish.BackColor = (icezCol 'Card')
 $cbFinish.ForeColor = (icezCol 'Text')
 $cbFinish.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
[void]$cbFinish.Items.Add('No hacer nada')
[void]$cbFinish.Items.Add('Cerrar icezOP')
[void]$cbFinish.Items.Add('Reiniciar el equipo')
switch ([string]$Script:Settings.OnFinish) {
    'close'   { $cbFinish.SelectedIndex = 1 }
    'restart' { $cbFinish.SelectedIndex = 2 }
    default   { $cbFinish.SelectedIndex = 0 }
}
 $cbFinish.Add_DrawItem({
    param($s, $e)
    if ($e.Index -lt 0) { return }
    $sel = (($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -ne 0)
    $bgc = if ($sel) { (icezCol 'Acc') } else { (icezCol 'Card') }
    $brush = New-Object System.Drawing.SolidBrush($bgc)
    $e.Graphics.FillRectangle($brush, $e.Bounds)
    $brush.Dispose()
    $r = New-Object System.Drawing.Rectangle(($e.Bounds.X + 10), $e.Bounds.Y, ($e.Bounds.Width - 10), $e.Bounds.Height)
    [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics, [string]$s.Items[$e.Index], $s.Font, $r, (icezCol 'Text'), ([System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::Left))
})
 $cbFinish.Add_SelectedIndexChanged({
    switch ($this.SelectedIndex) {
        1 { $Script:Settings.OnFinish = 'close' }
        2 { $Script:Settings.OnFinish = 'restart' }
        default { $Script:Settings.OnFinish = 'none' }
    }
})
 $cardExec.Controls.Add($cbFinish)

 $Script:LblRetries = New-Label ('Reintentos de Winget al fallar: {0}' -f [int]$Script:Settings.Retries) 20 208 400 20 9.5 'Sub'
 $cardExec.Controls.Add($Script:LblRetries)

 $slider = New-Object IcezOP.IcezSlider
 $slider.Location = Pt 20 228
 $slider.Size = Sz 300 26
 $slider.Minimum = 0
 $slider.Maximum = 3
 $slider.Value = [int]$Script:Settings.Retries
 $slider.Add_ValueChanged({
    $Script:Settings.Retries = $this.Value
    $Script:LblRetries.Text = ('Reintentos de Winget al fallar: {0}' -f $this.Value)
})
 $cardExec.Controls.Add($slider)
 $pSet.Controls.Add($cardExec)

# ── Card: Acerca de ──
 $cardAbout = New-Card 24 484 892 100
 $cardAbout.Controls.Add((New-Label 'Acerca de' 20 12 300 24 11 'Text' -Bold))
 $cardAbout.Controls.Add((New-Label ('icezOP v' + $Script:Version + ' - Post-instalacion y optimizacion para Windows 11') 20 38 700 20 9 'Sub'))

 $linkGh = New-Object System.Windows.Forms.LinkLabel
 $linkGh.Location = Pt 20 58
 $linkGh.Size = Sz 400 20
 $linkGh.Text = 'github.com/icezggg/icezOP'
 $linkGh.LinkColor = (icezCol 'AccL')
 $linkGh.ActiveLinkColor = (icezCol 'AccL')
 $linkGh.Font = New-Object System.Drawing.Font('Segoe UI', 9)
 $linkGh.Add_Click({ Start-Process 'https://github.com/icezggg/icezOP' })
 $cardAbout.Controls.Add($linkGh)

 $cardAbout.Controls.Add((New-Label 'Motor: PowerShell + WinForms (C#) - Instalador: Winget - Sin garantias.' 20 80 840 18 8.25 'Dim2'))
 $pSet.Controls.Add($cardAbout)

# ── Ensamblado (el orden de Add controla el docking) ──────────────
 $Script:Form.Controls.Add($content)
 $Script:Form.Controls.Add($sidebar)
 $Script:Form.Controls.Add($bottom)
 $Script:Form.Controls.Add($sep)
 $Script:Form.Controls.Add($header)

# ════════════════════ 8. MODAL DE CATEGORIA (con overlay fade) ════════════════════
function Show-CategoryModal {
    param([string]$Category, [string]$Type)

    $items = @()
    if ($Type -eq 'app') { $items = @($Script:Apps | Where-Object { $_.Cat -eq $Category }) }
    else { $items = @($Script:Tweaks | Where-Object { $_.Cat -eq $Category }) }
    if ($items.Count -eq 0) { return }

    $mw = 660
    $needed = $items.Count * 38 + 24
    $listH = [Math]::Min($needed, 420)
    if ($needed -lt 120) { $listH = 120 }
    $mh = 64 + $listH + 68

    $modal = New-Object System.Windows.Forms.Form
    $modal.FormBorderStyle = 'None'
    $modal.ShowInTaskbar = $false
    $modal.StartPosition = 'Manual'
    $modal.Size = Sz $mw $mh
    $modal.Location = Pt ([int]($Script:Form.Left + ($Script:Form.Width - $mw) / 2)) ([int]($Script:Form.Top + ($Script:Form.Height - $mh) / 2))
    $modal.BackColor = (icezCol 'Bg')
    Set-FormRounded $modal 18

    $modal.Controls.Add((New-Label $Category 28 14 440 30 13 'Text' -Bold))
    $counter = New-Label '' ($mw - 250) 22 160 20 9 'Sub'
    $modal.Controls.Add($counter)

    if ($Category -match '(?i)riesgo|experimental') {
        $modal.Controls.Add((New-Label '! Categoria experimental: puede causar inestabilidad.' 28 40 520 18 8.5 'Err'))
    }

    $btnX = New-Object IcezOP.GlyphButton
    $btnX.Location = Pt ($mw - 46) 14
    $btnX.Glyph = (icezG 'X')
    $btnX.GlyphFont = $Script:GlyphFont
    $modal.Controls.Add($btnX)

    $list = New-Object System.Windows.Forms.Panel
    $list.Location = Pt 16 58
    $list.Size = Sz ($mw - 32) $listH
    $list.AutoScroll = $true
    $list.BackColor = (icezCol 'Bg')
    $modal.Controls.Add($list)

    $Script:ModalBoxes = New-Object System.Collections.ArrayList
    $Script:ModalCounterLbl = $counter
    $Script:ModalTotal = $items.Count

    $y = 6
    foreach ($it in $items) {
        $cb = New-Object IcezOP.IcezCheckBox
        $cb.Location = Pt 10 $y
        $cb.Size = Sz 560 30
        $cb.Text = [string]$it.Name
        if ($Type -eq 'app' -and $it.Rec) { $cb.Star = $true }
        if ($Type -eq 'app') { $key = [string]$it.ID; $hash = $Script:AppSel }
        else { $key = ($it.Cat + '|' + $it.Name); $hash = $Script:TweakSel }
        if ($hash.ContainsKey($key)) { $cb.Checked = [bool]$hash[$key] }
        $k = $key
        $cb.Add_CheckedChanged({
            param($s, $e)
            $hash[$k] = $s.Checked
            Update-ModalCounter
        }.GetNewClosure())
        [void]$Script:ModalBoxes.Add($cb)
        $list.Controls.Add($cb)
        $y += 38
    }
    Update-ModalCounter

    $btnAll = New-Object IcezOP.GhostButton
    $btnAll.Location = Pt 28 ($mh - 54)
    $btnAll.Size = Sz 180 38
    $btnAll.Text = 'SELECCIONAR TODO'
    $btnAll.Add_Click({
        $any = $false
        foreach ($b in $Script:ModalBoxes) { if ($b.Checked) { $any = $true; break } }
        foreach ($b in $Script:ModalBoxes) { $b.Checked = (-not $any) }
    })
    $modal.Controls.Add($btnAll)

    $btnOk = New-Object IcezOP.GradientButton
    $btnOk.Location = Pt ($mw - 190) ($mh - 56)
    $btnOk.Size = Sz 160 40
    $btnOk.Text = 'LISTO'
    $modal.Controls.Add($btnOk)

    $closeAction = { $modal.Close() }.GetNewClosure()
    $btnOk.Add_Click($closeAction)
    $btnX.Add_Click($closeAction)

    # Overlay oscuro con fade + dialogo modal
    $ov = Show-IcezOverlay
    [void]$modal.ShowDialog($ov)
    $ov.Close()
    $ov.Dispose()
    $Script:ModalCounterLbl = $null
    $Script:ModalBoxes = $null
    Update-HomeUI
}

# ════════════════════ 9. MOTOR DE EJECUCION + MODAL ════════════════════
function Start-Run {
    param([System.Collections.ArrayList]$Tasks, [string]$Title = 'Ejecutando seleccion')

    $sync.Running = $true
    $sync.Done = $false
    $sync.Cancel = $false
    $sync.Percent = 0
    $sync.Status = 'Preparando...'
    $sync.OkCount = 0
    $sync.FailCount = 0
    $sync.Log = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
    $sync.Tasks = $Tasks

    $mw = 680
    $mh = 540
    $modal = New-Object System.Windows.Forms.Form
    $modal.FormBorderStyle = 'None'
    $modal.ShowInTaskbar = $false
    $modal.StartPosition = 'Manual'
    $modal.Size = Sz $mw $mh
    $modal.Location = Pt ([int]($Script:Form.Left + ($Script:Form.Width - $mw) / 2)) ([int]($Script:Form.Top + ($Script:Form.Height - $mh) / 2))
    $modal.BackColor = (icezCol 'Bg')
    Set-FormRounded $modal 18

    $modal.Controls.Add((New-Label $Title 28 20 500 30 13.5 'Text' -Bold))
    $Script:RunStatusLbl = New-Label 'Preparando...' 28 62 620 22 9.75 'Sub'
    $modal.Controls.Add($Script:RunStatusLbl)

    $Script:RunProg = New-Object IcezOP.IcezProgressBar
    $Script:RunProg.Location = Pt 28 94
    $Script:RunProg.Size = Sz 624 10
    $modal.Controls.Add($Script:RunProg)

    $Script:RunLogBox = New-Object System.Windows.Forms.ListBox
    $Script:RunLogBox.Location = Pt 28 120
    $Script:RunLogBox.Size = Sz 624 296
    $Script:RunLogBox.BorderStyle = 'None'
    $Script:RunLogBox.BackColor = (icezCol 'LogBg')
    $Script:RunLogBox.ForeColor = (icezCol 'LogFg')
    $Script:RunLogBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $Script:RunLogBox.IntegralHeight = $false
    $Script:RunLogBox.HorizontalScrollbar = $true
    $modal.Controls.Add($Script:RunLogBox)

    $Script:RunCancel = New-Object IcezOP.GhostButton
    $Script:RunCancel.Location = Pt 28 436
    $Script:RunCancel.Size = Sz 160 42
    $Script:RunCancel.Text = 'CANCELAR'
    $Script:RunCancel.ForeColor = (icezCol 'Err')
    $Script:RunCancel.Add_Click({
        $sync.Cancel = $true
        $Script:RunCancel.Enabled = $false
        $Script:RunCancel.Text = 'CANCELANDO...'
    })
    $modal.Controls.Add($Script:RunCancel)

    $Script:RunSummary = New-Label '' 28 56 624 64 11 'Text' -Bold
    $Script:RunSummary.Visible = $false
    $modal.Controls.Add($Script:RunSummary)

    $Script:RunRestart = New-Object IcezOP.GradientButton
    $Script:RunRestart.Location = Pt 350 436
    $Script:RunRestart.Size = Sz 200 42
    $Script:RunRestart.Text = 'REINICIAR AHORA'
    $Script:RunRestart.Visible = $false
    $Script:RunRestart.Add_Click({
        Start-Process 'shutdown.exe' -ArgumentList @('/r', '/t', '5', '/c', 'icezOP')
        $Script:Form.Close()
    })
    $modal.Controls.Add($Script:RunRestart)

    $Script:RunFinish = New-Object IcezOP.GhostButton
    $Script:RunFinish.Location = Pt 562 436
    $Script:RunFinish.Size = Sz 90 42
    $Script:RunFinish.Text = 'FINALIZAR'
    $Script:RunFinish.Visible = $false
    $Script:RunFinish.Add_Click({
        switch ([string]$Script:Settings.OnFinish) {
            'close'   { $Script:Form.Close() }
            'restart' { Start-Process 'shutdown.exe' -ArgumentList @('/r', '/t', '5', '/c', 'icezOP'); $Script:Form.Close() }
            default   { $Script:RunModal.Close() }
        }
    })
    $modal.Controls.Add($Script:RunFinish)

    $modal.Add_FormClosed({
        $Script:RunActive = $false
        try { if ($Script:RunPs) { $Script:RunPs.Dispose() } } catch {}
        try { if ($Script:RunRs) { $Script:RunRs.Dispose() } } catch {}
    })

    $Script:RunModal = $modal

    try { if ($Script:RunPs) { $Script:RunPs.Dispose(); $Script:RunRs.Dispose() } } catch {}
    $Script:RunRs = [runspacefactory]::CreateRunspace()
    $Script:RunRs.ApartmentState = 'STA'
    $Script:RunRs.ThreadOptions = 'ReuseThread'
    $Script:RunRs.Open()
    $Script:RunPs = [powershell]::Create()
    $Script:RunPs.Runspace = $Script:RunRs
    [void]$Script:RunPs.AddScript($Script:WorkerCode)
    [void]$Script:RunPs.AddArgument($sync)
    [void]$Script:RunPs.AddArgument($Script:Settings)
    $Script:RunHandle = $Script:RunPs.BeginInvoke()

    $Script:RunActive = $true
    $ov = Show-IcezOverlay
    [void]$modal.ShowDialog($ov)
    $ov.Close()
    $ov.Dispose()
}

# Boton EJECUTAR principal
 $Script:ExecBtn.Add_Click({
    $appsSel = @($Script:Apps | Where-Object { [bool]$Script:AppSel[[string]$_.ID] })
    $twSel = @($Script:Tweaks | Where-Object { [bool]$Script:TweakSel[($_.Cat + '|' + $_.Name)] })
    if (($appsSel.Count + $twSel.Count) -eq 0) { return }

    $wg = Get-WingetPath
    $sync.Winget = $wg

    $tasks = New-Object System.Collections.ArrayList
    if ($appsSel.Count -gt 0 -and -not $wg) {
        if ([bool]$Script:Settings.AutoWinget) {
            [void]$tasks.Add(@{ Kind = 'wingetboot'; Label = 'Instalar Winget' })
        } else {
            [void][System.Windows.Forms.MessageBox]::Show($Script:Form, 'Winget no esta disponible. Activa la instalacion automatica en Ajustes.', 'icezOP', 'OK', 'Warning')
            return
        }
    }
    if ($twSel.Count -gt 0 -and [bool]$Script:Settings.RestorePoint) {
        [void]$tasks.Add(@{ Kind = 'restore'; Label = 'Crear punto de restauracion' })
    }
    if ($appsSel.Count -gt 0 -and $wg -and [bool]$Script:Settings.UpdateSources) {
        [void]$tasks.Add(@{ Kind = 'sources'; Label = 'Actualizar origenes de Winget' })
    }
    foreach ($a in $appsSel) { [void]$tasks.Add(@{ Kind = 'app'; Id = [string]$a.ID; Label = ('Instalar ' + $a.Name) }) }
    foreach ($t in $twSel)   { [void]$tasks.Add(@{ Kind = 'tweak'; Script = [string]$t.Script; Label = ('Tweak: ' + $t.Name) }) }

    Start-Run -Tasks $tasks -Title 'Ejecutando seleccion'
})

# ════════════════════ 10. TIMERS ════════════════════
 $uiTimer = New-Object System.Windows.Forms.Timer
 $uiTimer.Interval = 120
 $uiTimer.Add_Tick({
    if ($Script:RunActive) {
        while ($sync.Log.Count -gt 0) { [void]$Script:RunLogBox.Items.Add([string]$sync.Log.Dequeue()) }
        if ($Script:RunLogBox.Items.Count -gt 0) { $Script:RunLogBox.TopIndex = $Script:RunLogBox.Items.Count - 1 }
        $Script:RunStatusLbl.Text = [string]$sync.Status
        $Script:RunProg.Percent = [double]$sync.Percent

        if ($sync.Done) {
            $Script:RunActive = $false
            try {
                $null = $Script:RunPs.EndInvoke($Script:RunHandle)
                $Script:RunPs.Dispose()
                $Script:RunRs.Dispose()
            } catch {}
            $Script:RunStatusLbl.Visible = $false
            $Script:RunProg.Visible = $false
            $Script:RunCancel.Visible = $false
            $txt = ('OK  {0} tareas completadas' -f $sync.OkCount)
            if ($sync.FailCount -gt 0) { $txt += ('   -   X  {0} con errores' -f $sync.FailCount) }
            $txt += "`r`nReinicia para aplicar todos los cambios."
            $Script:RunSummary.Text = $txt
            $Script:RunSummary.Visible = $true
            $Script:RunRestart.Visible = $true
            $Script:RunFinish.Visible = $true
        }
    }
    switch ([string]$sync.DriverPhase) {
        'scanning' { if ($Script:DriverStatusLbl) { $Script:DriverStatusLbl.Text = 'Escaneando controladores instalados...' } }
        'done'     { if (-not $Script:DriverRendered) { $Script:DriverRendered = $true; Build-DriverCards; $sync.DriverPhase = 'idle' } }
        'error'    { if (-not $Script:DriverRendered) { $Script:DriverRendered = $true; $Script:DriverStatusLbl.Text = ('Error: ' + $sync.DriverError); $sync.DriverPhase = 'idle' } }
    }
})
 $uiTimer.Start()

 $Script:Collapsed = $false
 $animTimer = New-Object System.Windows.Forms.Timer
 $animTimer.Interval = 15
 $animTimer.Add_Tick({
    $target = 220
    if ($Script:Collapsed) { $target = 64 }
    $w = $sidebar.Width
    $w = $w + [int](($target - $w) * 0.3)
    if ([Math]::Abs($target - $w) -le 3) { $w = $target; $animTimer.Stop() }
    $sidebar.Width = $w
    $showTxt = ($w -gt 110)
    foreach ($n in $Script:NavList) {
        $n.ShowText = $showTxt
        if ($showTxt) { $n.Width = 200 } else { $n.Width = 44 }
        $n.Location = Pt 10 $n.Location.Y
    }
})

# Limpieza + guardar config al cerrar
 $Script:Form.Add_FormClosing({
    $uiTimer.Stop()
    $animTimer.Stop()
    try { if ($Script:RunPs) { $Script:RunPs.Stop(); $Script:RunPs.Dispose() } } catch {}
    try { if ($Script:RunRs) { $Script:RunRs.Dispose() } } catch {}
    try { if ($Script:DrvPs) { $Script:DrvPs.Stop(); $Script:DrvPs.Dispose() } } catch {}
    try { if ($Script:DrvRs) { $Script:DrvRs.Dispose() } } catch {}
    Save-Config
})

# ════════════════════ 11. ARRANQUE ════════════════════
Switch-Page 'home'
Update-HomeUI
[void]$Script:Form.ShowDialog()
 $Script:Form.Dispose()
