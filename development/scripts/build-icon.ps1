$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$source = Join-Path $root 'development/artwork/timer-bars-concept-v2.png'
$destination = Join-Path $root 'DoTBarsForever/Media/TimerBars.tga'
New-Item -ItemType Directory -Force (Split-Path -Parent $destination) | Out-Null
$image = [System.Drawing.Image]::FromFile($source)
$bitmap = New-Object System.Drawing.Bitmap 256, 256
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
try {
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($image, 0, 0, 256, 256)
    # Uncompressed true-color TGA, BGRA pixels, top-left origin, 8 alpha bits.
    $header = New-Object byte[] 18
    $header[2] = 2
    $header[13] = 1
    $header[15] = 1
    $header[16] = 32
    $header[17] = 40
    $stream = [System.IO.File]::Create($destination)
    $writer = New-Object System.IO.BinaryWriter $stream
    try {
        $writer.Write($header)
        for ($y = 0; $y -lt 256; $y++) {
            for ($x = 0; $x -lt 256; $x++) {
                $pixel = $bitmap.GetPixel($x, $y)
                $writer.Write([byte]$pixel.B)
                $writer.Write([byte]$pixel.G)
                $writer.Write([byte]$pixel.R)
                $writer.Write([byte]$pixel.A)
            }
        }
    } finally { $writer.Dispose() }
} finally {
    $graphics.Dispose()
    $bitmap.Dispose()
    $image.Dispose()
}
Write-Output $destination
