<#
    Genera copias livianas (JPEG) de Imagenes/ y Planos/ para usar en la web.
    Los originales no se tocan. Salida: Imagenes/web/*.jpg y Planos/web/*.jpg
    Uso: powershell -File optimize-images.ps1
#>

Add-Type -AssemblyName System.Drawing

function Convert-ImageToJpeg {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [int]$MaxDim,
        [int]$Quality
    )

    $img = [System.Drawing.Image]::FromFile($SourcePath)
    try {
        $ratio = [Math]::Min(1.0, $MaxDim / [Math]::Max($img.Width, $img.Height))
        $newW = [int]([Math]::Round($img.Width * $ratio))
        $newH = [int]([Math]::Round($img.Height * $ratio))

        $bmp = New-Object System.Drawing.Bitmap $newW, $newH
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.DrawImage($img, 0, 0, $newW, $newH)

        $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $Quality)

        $bmp.Save($DestPath, $jpegCodec, $encParams)

        $g.Dispose()
        $bmp.Dispose()
    }
    finally {
        $img.Dispose()
    }
}

$root = $PSScriptRoot

$jobs = @(
    @{ Src = "Imagenes"; Dst = "Imagenes/web"; MaxDim = 2000; Quality = 80 },
    @{ Src = "Planos";   Dst = "Planos/web";   MaxDim = 1800; Quality = 88 }
)

foreach ($job in $jobs) {
    $srcDir = Join-Path $root $job.Src
    $dstDir = Join-Path $root $job.Dst
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null

    Get-ChildItem -Path $srcDir -File | Where-Object { $_.Extension -match '\.(png|jpe?g|tif?f)$' } | ForEach-Object {
        $destName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) + ".jpg"
        $destPath = Join-Path $dstDir $destName
        Write-Host "Convirtiendo $($_.Name) -> $($job.Dst)/$destName"
        Convert-ImageToJpeg -SourcePath $_.FullName -DestPath $destPath -MaxDim $job.MaxDim -Quality $job.Quality
    }
}

Write-Host "`nListo. Tamanos generados:"
Get-ChildItem -Path (Join-Path $root "Imagenes/web"), (Join-Path $root "Planos/web") -File |
    Select-Object Directory, Name, @{N='KB';E={[Math]::Round($_.Length/1KB,0)}} |
    Format-Table -AutoSize
