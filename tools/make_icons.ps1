# Draws the sidebar icons in the same sizes and style as the vanilla sidebar
# icons (media/ui/Sidebar/<size>/*_<size>.png): black outline, grey gradient
# when off, colour gradient when on.
#   Skills   (F08): a rising bar chart
#   Wishlist (F06): a star
#   Players  (F09): two people
# Output: mod\...\42\media\ui\SurvivorComforts\<Name>_{On,Off}_<size>.png
# Only needs to be re-run when the icon design changes.

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

$outDir = Join-Path $PSScriptRoot "..\mod\SurvivorComforts\Contents\mods\SurvivorComforts\42\media\ui\SurvivorComforts"
New-Item -ItemType Directory -Force $outDir | Out-Null

# Drawn at 4x of the 128x96 icon, then scaled down to every size.
$W = 512; $H = 384
$BaseY = 344

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

# Each shape draws itself with the given fill brush and outline pen.
function Draw-Skills($g, $brush, $pen) {
    $bars = @(@(100, 120), @(212, 200), @(324, 280))   # x, height
    $barW = 88
    foreach ($b in $bars) {
        $path = New-RoundedRect $b[0] ($BaseY - $b[1]) $barW $b[1] 16
        $g.FillPath($brush, $path)
        $g.DrawPath($pen, $path)
    }
    # Base line under the bars
    $pen.StartCap = "Round"; $pen.EndCap = "Round"
    $g.DrawLine($pen, 72, $BaseY + 4, 440, $BaseY + 4)
}

function Draw-Wishlist($g, $brush, $pen) {
    $cx = 256; $cy = 200; $outer = 170; $inner = 70
    $points = New-Object System.Drawing.PointF[] 10
    for ($i = 0; $i -lt 10; $i++) {
        $r = if ($i % 2 -eq 0) { $outer } else { $inner }
        $a = -[Math]::PI / 2 + $i * [Math]::PI / 5
        $points[$i] = [System.Drawing.PointF]::new($cx + $r * [Math]::Cos($a), $cy + $r * [Math]::Sin($a))
    }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddPolygon($points)
    $g.FillPath($brush, $path)
    $g.DrawPath($pen, $path)
}

function Draw-Players($g, $brush, $pen) {
    # The one behind first, so the front one is drawn over it.
    foreach ($p in @(@(350, 112, 50, 280, 430, 196), @(214, 128, 62, 108, 320, 212))) {   # head x, y, r, body left, right, top
        $head = New-Object System.Drawing.Drawing2D.GraphicsPath
        $head.AddEllipse($p[0] - $p[2], $p[1] - $p[2], $p[2] * 2, $p[2] * 2)
        $body = New-RoundedRect $p[3] $p[5] ($p[4] - $p[3]) ($BaseY - $p[5]) 60
        foreach ($path in $body, $head) {
            $g.FillPath($brush, $path)
            $g.DrawPath($pen, $path)
        }
    }
}

function Draw-Icon($shape, $top, $bottom) {
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "AntiAlias"
    $g.Clear([System.Drawing.Color]::Transparent)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::Black), 18
    $pen.LineJoin = "Round"
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 40), (New-Object System.Drawing.Point 0, $BaseY), $top, $bottom
    & $shape $g $brush $pen
    $g.Dispose()
    return $bmp
}

$offTop = [System.Drawing.Color]::FromArgb(235, 235, 235)
$offBottom = [System.Drawing.Color]::FromArgb(90, 90, 90)
$onTop = [System.Drawing.Color]::FromArgb(255, 222, 130)
$onBottom = [System.Drawing.Color]::FromArgb(176, 112, 28)

foreach ($icon in "Skills", "Wishlist", "Players") {
    $shape = Get-Command "Draw-$icon"
    $variants = @{
        Off = Draw-Icon $shape $offTop $offBottom
        On  = Draw-Icon $shape $onTop $onBottom
    }
    foreach ($size in 48, 64, 80, 96, 128) {
        $outH = [int]($size * 0.75)
        foreach ($name in $variants.Keys) {
            $out = New-Object System.Drawing.Bitmap $size, $outH
            $g = [System.Drawing.Graphics]::FromImage($out)
            $g.InterpolationMode = "HighQualityBicubic"
            $g.PixelOffsetMode = "HighQuality"
            $g.DrawImage($variants[$name], 0, 0, $size, $outH)
            $g.Dispose()
            $file = Join-Path $outDir "${icon}_${name}_$size.png"
            $out.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
            $out.Dispose()
        }
    }
}
Write-Host "Icons written to $outDir"
