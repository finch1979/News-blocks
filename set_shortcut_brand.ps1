param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath,

    [string]$ShortcutName = "New Block 025",

    [string]$Title = "New Block",

    [string]$Badge = "025",

    [double]$ThumbnailScale = 0.66
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$desktopPath = [Environment]::GetFolderPath("Desktop")
$repoRoot = $PSScriptRoot
$brandingDir = Join-Path $repoRoot "branding"
$pngPath = Join-Path $brandingDir "desktop-logo.png"
$icoPath = Join-Path $brandingDir "desktop-logo.ico"
$shortcutNameFile = Join-Path $brandingDir "shortcut-name.txt"
$targetShortcutPath = Join-Path $desktopPath ("{0}.lnk" -f $ShortcutName)
$legacyShortcutPaths = @(
    (Join-Path $desktopPath "News Blocks.lnk"),
    (Join-Path $desktopPath "New Block 025.lnk")
)

function New-RoundedRectanglePath {
    param(
        [System.Drawing.RectangleF]$Rect,
        [float]$Radius
    )

    $diameter = $Radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($Rect.X, $Rect.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Rect.Right - $diameter, $Rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Save-BitmapAsIcon {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path
    )

    $iconHandle = $Bitmap.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
    try {
        $stream = [System.IO.File]::Create($Path)
        try {
            $icon.Save($stream)
        } finally {
            $stream.Dispose()
        }
    } finally {
        $icon.Dispose()
        $null = [System.Runtime.InteropServices.Marshal]::Release($iconHandle)
    }
}

if (-not (Test-Path $ImagePath)) {
    throw "Image file was not found: $ImagePath"
}

if ($ThumbnailScale -le 0 -or $ThumbnailScale -gt 1) {
    throw "ThumbnailScale must be greater than 0 and less than or equal to 1."
}

New-Item -ItemType Directory -Path $brandingDir -Force | Out-Null
Set-Content -Path $shortcutNameFile -Value $ShortcutName -Encoding UTF8

$size = 256
$canvas = New-Object System.Drawing.Bitmap($size, $size)
$graphics = [System.Drawing.Graphics]::FromImage($canvas)

try {
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::FromArgb(245, 122, 14))

    $sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path $ImagePath))
    try {
        $targetImageSize = [int]($size * $ThumbnailScale)
        $scale = [Math]::Min($targetImageSize / $sourceImage.Width, $targetImageSize / $sourceImage.Height)
        $drawWidth = [int][Math]::Ceiling($sourceImage.Width * $scale)
        $drawHeight = [int][Math]::Ceiling($sourceImage.Height * $scale)
        $offsetX = [int](($size - $drawWidth) / 2)
        $offsetY = [int](18 + (($targetImageSize - $drawHeight) / 2))

        $graphics.DrawImage($sourceImage, (New-Object System.Drawing.Rectangle($offsetX, $offsetY, $drawWidth, $drawHeight)))
    } finally {
        $sourceImage.Dispose()
    }

    $overlayRect = New-Object System.Drawing.Rectangle(0, 112, $size, 144)
    $overlayBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $overlayRect,
        [System.Drawing.Color]::FromArgb(0, 17, 17, 17),
        [System.Drawing.Color]::FromArgb(220, 15, 15, 15),
        [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    try {
        $graphics.FillRectangle($overlayBrush, $overlayRect)
    } finally {
        $overlayBrush.Dispose()
    }

    $badgePath = New-RoundedRectanglePath -Rect (New-Object System.Drawing.RectangleF(18, 20, 92, 40)) -Radius 14
    $badgeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(228, 255, 246, 235))
    $badgeTextBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 109, 52, 22))
    $badgeFont = New-Object System.Drawing.Font("Segoe UI Semibold", 14, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    try {
        $graphics.FillPath($badgeBrush, $badgePath)
        $graphics.DrawString("NEWS", $badgeFont, $badgeTextBrush, 31, 28)
    } finally {
        $badgePath.Dispose()
        $badgeBrush.Dispose()
        $badgeTextBrush.Dispose()
        $badgeFont.Dispose()
    }

    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(140, 0, 0, 0))
    $titleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $subtitleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 214, 170))
    $titleFont = New-Object System.Drawing.Font("Segoe UI Semibold", 28, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $badgeNumberFont = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    try {
        $graphics.DrawString($Title, $titleFont, $shadowBrush, 22, 168)
        $graphics.DrawString($Title, $titleFont, $titleBrush, 20, 166)
        $graphics.DrawString($Badge, $badgeNumberFont, $shadowBrush, 24, 208)
        $graphics.DrawString($Badge, $badgeNumberFont, $subtitleBrush, 22, 206)
    } finally {
        $shadowBrush.Dispose()
        $titleBrush.Dispose()
        $subtitleBrush.Dispose()
        $titleFont.Dispose()
        $badgeNumberFont.Dispose()
    }

    $canvas.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Save-BitmapAsIcon -Bitmap $canvas -Path $icoPath
} finally {
    $graphics.Dispose()
    $canvas.Dispose()
}

$sourceShortcutPath = $legacyShortcutPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $sourceShortcutPath) {
    throw "Desktop shortcut was not found. Run install_autostart.ps1 first."
}

if ($sourceShortcutPath -ne $targetShortcutPath) {
    Rename-Item -Path $sourceShortcutPath -NewName ([System.IO.Path]::GetFileName($targetShortcutPath)) -Force
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($targetShortcutPath)
$shortcut.IconLocation = "$icoPath,0"
$shortcut.Description = "$ShortcutName launcher"
$shortcut.Save()

Write-Host "Shortcut updated: $targetShortcutPath" -ForegroundColor Green
Write-Host "Icon generated: $icoPath" -ForegroundColor Cyan