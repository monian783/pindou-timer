Add-Type -AssemblyName System.Drawing

$outDir = 'E:\pindou_timer\assets\icon'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function New-RoundRect([int]$x, [int]$y, [int]$w, [int]$h, [int]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function New-Canvas([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    return @($bmp, $g)
}

# 表盘（白色环 + 指针 + 绿色圆心），按 scale 缩放画在 size 画布中央
function Draw-Clock($g, [int]$size, [double]$scale) {
    $c = $size / 2.0
    $r = $c * 0.585 * $scale
    $ringW = [float]($c * 0.115 * $scale)
    $handW = [float]($c * 0.105 * $scale)

    $white = New-Object System.Drawing.Pen([System.Drawing.Color]::White, $ringW)
    $g.DrawEllipse($white, [float]($c - $r), [float]($c - $r), [float]($r * 2), [float]($r * 2))

    $hand = New-Object System.Drawing.Pen([System.Drawing.Color]::White, $handW)
    $hand.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $hand.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    # 分针朝上
    $g.DrawLine($hand, [float]$c, [float]$c, [float]$c, [float]($c - $r * 0.62))
    # 时针朝右
    $g.DrawLine($hand, [float]$c, [float]$c, [float]($c + $r * 0.45), [float]$c)

    $dot = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 53, 196, 107))
    $dr = [float]($c * 0.10 * $scale)
    $g.FillEllipse($dot, [float]($c - $dr), [float]($c - $dr), [float]($dr * 2), [float]($dr * 2))
}

# ---- 1) 完整图标：圆角蓝底 + 表盘 ----
$size = 1024
$pair = New-Canvas $size
$bmp = $pair[0]; $g = $pair[1]
$bg = New-RoundRect 0 0 $size $size 232
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0, 0)),
    (New-Object System.Drawing.Point(0, $size)),
    [System.Drawing.Color]::FromArgb(255, 62, 125, 240),
    [System.Drawing.Color]::FromArgb(255, 30, 92, 204))
$g.FillPath($grad, $bg)
Draw-Clock $g $size 1.0
$g.Dispose()
$bmp.Save("$outDir\app_icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
'寫 app_icon.png'

# ---- 2) 自适应图标前景：透明底 + 缩小的表盘（安卓安全区） ----
$pair2 = New-Canvas $size
$bmp2 = $pair2[0]; $g2 = $pair2[1]
$g2.Clear([System.Drawing.Color]::Transparent)
Draw-Clock $g2 $size 0.66
$g2.Dispose()
$bmp2.Save("$outDir\app_icon_foreground.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp2.Dispose()
'寫 app_icon_foreground.png'

Get-ChildItem $outDir | Select-Object Name, @{n = 'KB'; e = { [math]::Round($_.Length / 1KB, 1) } } | Format-Table -AutoSize | Out-String
