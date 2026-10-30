# Draws the Workshop preview image and the in-game mod list poster.
#   mod\SurvivorComforts\preview.png                                  (Workshop, exactly 256x256, under 1000 KB)
#   mod\SurvivorComforts\Contents\mods\SurvivorComforts\42\poster.png (mod list, set by poster= in mod.info)
#   mod\SurvivorComforts\Contents\mods\SurvivorComforts\42\icon.png   (mod list icon, set by icon= in mod.info, 64x64)
# Only needs to be re-run when the design changes.

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

$root = Join-Path $PSScriptRoot "..\mod\SurvivorComforts"
$S = 1024   # drawn at 4x, then scaled down to 256
$Size = 256

function Color($r, $g, $b, $a = 255) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

function New-RoundedRect($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function New-Star($cx, $cy, $outer, $inner) {
    $points = New-Object System.Drawing.PointF[] 10
    for ($i = 0; $i -lt 10; $i++) {
        $r = if ($i % 2 -eq 0) { $outer } else { $inner }
        $a = -[Math]::PI / 2 + $i * [Math]::PI / 5
        $points[$i] = [System.Drawing.PointF]::new($cx + $r * [Math]::Cos($a), $cy + $r * [Math]::Sin($a))
    }
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddPolygon($points)
    return $p
}

$bmp = New-Object System.Drawing.Bitmap $S, $S
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = "AntiAlias"
$g.TextRenderingHint = "AntiAliasGridFit"

# Background: dark green-grey, lighter at the top.
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point 0, $S), (Color 58 66 56), (Color 24 28 26)
$g.FillRectangle($bg, 0, 0, $S, $S)

# Warm glow behind the icons.
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(212, 70, 600, 460)
$glowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
$glowBrush.CenterColor = Color 255 190 90 90
$glowBrush.SurroundColors = @(Color 255 190 90 0)
$g.FillPath($glowBrush, $glow)

$outline = New-Object System.Drawing.Pen (Color 20 20 20), 22
$outline.LineJoin = "Round"
$amber = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 120), (New-Object System.Drawing.Point 0, 520), (Color 255 222 130), (Color 196 120 30)
$blue = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 200), (New-Object System.Drawing.Point 0, 520), (Color 150 220 255), (Color 50 130 190)

# Bar chart (skills) on the left, star (wishlist) on the right.
$baseY = 500
foreach ($bar in @(@(200, 130), @(300, 220), @(400, 310))) {
    $path = New-RoundedRect $bar[0] ($baseY - $bar[1]) 80 $bar[1] 14
    $g.FillPath($blue, $path)
    $g.DrawPath($outline, $path)
}
$star = New-Star 650 330 190 80
$g.FillPath($amber, $star)
$g.DrawPath($outline, $star)

# Title
$format = New-Object System.Drawing.StringFormat
$format.Alignment = "Center"
$titleFont = New-Object System.Drawing.Font "Segoe UI", 118, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$subFont = New-Object System.Drawing.Font "Segoe UI", 56, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$shadow = New-Object System.Drawing.SolidBrush (Color 0 0 0 160)
$white = New-Object System.Drawing.SolidBrush (Color 245 240 228)
$muted = New-Object System.Drawing.SolidBrush (Color 200 196 180)
foreach ($line in @(@("Survivor", 590), @("Comforts", 720))) {
    $rect = New-Object System.Drawing.RectangleF 0, ($line[1] + 6), $S, 160
    $g.DrawString($line[0], $titleFont, $shadow, $rect, $format)
    $rect = New-Object System.Drawing.RectangleF 0, $line[1], $S, 160
    $g.DrawString($line[0], $titleFont, $white, $rect, $format)
}
$g.DrawString("Quality of life for B42", $subFont, $muted, (New-Object System.Drawing.RectangleF 0, 880, $S, 80), $format)
$g.Dispose()

$out = New-Object System.Drawing.Bitmap $Size, $Size
$g = [System.Drawing.Graphics]::FromImage($out)
$g.InterpolationMode = "HighQualityBicubic"
$g.PixelOffsetMode = "HighQuality"
$g.DrawImage($bmp, 0, 0, $Size, $Size)
$g.Dispose()

foreach ($file in @((Join-Path $root "preview.png"), (Join-Path $root "Contents\mods\SurvivorComforts\42\poster.png"))) {
    $out.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Written $file ($((Get-Item $file).Length) bytes)"
}
$out.Dispose()
$bmp.Dispose()

# Mod list icon (icon= in mod.info): the preview without the title - bar
# chart and star with the warm glow, on a rounded square. The mod list draws
# it at about 28-40 px, so the shapes are larger and the outlines thicker.
$IconSize = 64
$ibmp = New-Object System.Drawing.Bitmap $S, $S
$g = [System.Drawing.Graphics]::FromImage($ibmp)
$g.SmoothingMode = "AntiAlias"
$g.Clear([System.Drawing.Color]::Transparent)
$box = New-RoundedRect 16 16 992 992 170
$boxBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point 0, $S), (Color 58 66 56), (Color 24 28 26)
$g.FillPath($boxBrush, $box)
$g.SetClip($box)
$iconGlow = New-Object System.Drawing.Drawing2D.GraphicsPath
$iconGlow.AddEllipse(120, 140, 820, 700)
$iconGlowBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush $iconGlow
$iconGlowBrush.CenterColor = Color 255 190 90 110
$iconGlowBrush.SurroundColors = @(Color 255 190 90 0)
$g.FillPath($iconGlowBrush, $iconGlow)
$g.ResetClip()

$iconOutline = New-Object System.Drawing.Pen (Color 20 20 20), 34
$iconOutline.LineJoin = "Round"
$iconBlue = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 300), (New-Object System.Drawing.Point 0, 860), (Color 150 220 255), (Color 50 130 190)
$iconAmber = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 180), (New-Object System.Drawing.Point 0, 780), (Color 255 222 130), (Color 196 120 30)
$iconBase = 860
foreach ($bar in @(@(110, 220), @(250, 360), @(390, 500))) {   # x, height
    $path = New-RoundedRect $bar[0] ($iconBase - $bar[1]) 115 $bar[1] 22
    $g.FillPath($iconBlue, $path)
    $g.DrawPath($iconOutline, $path)
}
$iconStar = New-Star 705 480 290 122
$g.FillPath($iconAmber, $iconStar)
$g.DrawPath($iconOutline, $iconStar)
$g.Dispose()

$iout = New-Object System.Drawing.Bitmap $IconSize, $IconSize
$g = [System.Drawing.Graphics]::FromImage($iout)
$g.InterpolationMode = "HighQualityBicubic"
$g.PixelOffsetMode = "HighQuality"
$g.DrawImage($ibmp, 0, 0, $IconSize, $IconSize)
$g.Dispose()
$file = Join-Path $root "Contents\mods\SurvivorComforts\42\icon.png"
$iout.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Written $file ($((Get-Item $file).Length) bytes)"
$iout.Dispose()
$ibmp.Dispose()
