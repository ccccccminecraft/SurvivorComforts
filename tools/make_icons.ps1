# Draws the F08 sidebar icons (a rising bar chart) in the same sizes and
# style as the vanilla sidebar icons (media/ui/Sidebar/<size>/*_<size>.png):
# black outline, grey gradient when off, colour gradient when on.
# Output: mod\...\42\media\ui\TeamUIPack\Skills_{On,Off}_<size>.png
# Only needs to be re-run when the icon design changes.

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

$outDir = Join-Path $PSScriptRoot "..\mod\TeamUIPack\Contents\mods\TeamUIPack\42\media\ui\TeamUIPack"
New-Item -ItemType Directory -Force $outDir | Out-Null

# Drawn at 4x of the 128x96 icon, then scaled down to every size.
$W = 512; $H = 384

function New-RoundedRect($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddLine($x + $w, $y + $d, $x + $w, $y + $h)
    $p.AddLine($x + $w, $y + $h, $x, $y + $h)
    $p.CloseFigure()
    return $p
}

function Draw-Icon($top, $bottom) {
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "AntiAlias"
    $g.Clear([System.Drawing.Color]::Transparent)

    $baseY = 344
    $bars = @(@(100, 120), @(212, 200), @(324, 280))   # x, height
    $barW = 88
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), 18
    $pen.LineJoin = "Round"
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 40), (New-Object System.Drawing.Point 0, $baseY), $top, $bottom
    foreach ($b in $bars) {
        $path = New-RoundedRect $b[0] ($baseY - $b[1]) $barW $b[1] 16
        $g.FillPath($brush, $path)
        $g.DrawPath($pen, $path)
    }
    # Base line under the bars
    $pen.StartCap = "Round"; $pen.EndCap = "Round"
    $g.DrawLine($pen, 72, $baseY + 4, 440, $baseY + 4)

    $g.Dispose()
    return $bmp
}

$variants = @{
    Off = Draw-Icon ([System.Drawing.Color]::FromArgb(235, 235, 235)) ([System.Drawing.Color]::FromArgb(90, 90, 90))
    On  = Draw-Icon ([System.Drawing.Color]::FromArgb(255, 222, 130)) ([System.Drawing.Color]::FromArgb(176, 112, 28))
}

foreach ($size in 48, 64, 80, 96, 128) {
    $h = [int]($size * 0.75)
    foreach ($name in $variants.Keys) {
        $out = New-Object System.Drawing.Bitmap $size, $h
        $g = [System.Drawing.Graphics]::FromImage($out)
        $g.InterpolationMode = "HighQualityBicubic"
        $g.PixelOffsetMode = "HighQuality"
        $g.DrawImage($variants[$name], 0, 0, $size, $h)
        $g.Dispose()
        $file = Join-Path $outDir "Skills_${name}_$size.png"
        $out.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
        $out.Dispose()
    }
}
Write-Host "Icons written to $outDir"
