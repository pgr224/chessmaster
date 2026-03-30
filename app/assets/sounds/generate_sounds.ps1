param()

function New-WavFile {
    param(
        [string]$Path,
        [int]$Frequency,
        [int]$DurationMs,
        [double]$Volume = 0.5
    )
    $sampleRate = 44100
    $numSamples = [int]($sampleRate * $DurationMs / 1000)
    $dataSize = $numSamples * 2
    
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    
    # RIFF header
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([int]($dataSize + 36))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    
    # fmt chunk
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([int]16)
    $bw.Write([int16]1)
    $bw.Write([int16]1)
    $bw.Write([int]$sampleRate)
    $bw.Write([int]($sampleRate * 2))
    $bw.Write([int16]2)
    $bw.Write([int16]16)
    
    # data chunk
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([int]$dataSize)
    
    for ($i = 0; $i -lt $numSamples; $i++) {
        $t = $i / $sampleRate
        $env = [Math]::Max(0.0, 1.0 - ($t * 1000.0 / $DurationMs))
        $sample = [int16]([Math]::Sin(2.0 * [Math]::PI * $Frequency * $t) * 32767.0 * $Volume * $env)
        $bw.Write($sample)
    }
    
    [System.IO.File]::WriteAllBytes($Path, $ms.ToArray())
    $bw.Close()
    $ms.Close()
    Write-Host "Created: $Path"
}

$base = "d:\PP942920DRIVE\PROJECTS\chess\app\assets\sounds"

New-WavFile -Path "$base\move_self.wav" -Frequency 600 -DurationMs 80 -Volume 0.4
New-WavFile -Path "$base\move_opponent.wav" -Frequency 500 -DurationMs 80 -Volume 0.35
New-WavFile -Path "$base\capture.wav" -Frequency 800 -DurationMs 120 -Volume 0.5
New-WavFile -Path "$base\check.wav" -Frequency 1000 -DurationMs 200 -Volume 0.6
New-WavFile -Path "$base\castle.wav" -Frequency 400 -DurationMs 150 -Volume 0.4
New-WavFile -Path "$base\promote.wav" -Frequency 1200 -DurationMs 250 -Volume 0.5
New-WavFile -Path "$base\game_start.wav" -Frequency 700 -DurationMs 300 -Volume 0.45
New-WavFile -Path "$base\game_end.wav" -Frequency 500 -DurationMs 400 -Volume 0.5
New-WavFile -Path "$base\illegal.wav" -Frequency 200 -DurationMs 200 -Volume 0.5
New-WavFile -Path "$base\low_time.wav" -Frequency 900 -DurationMs 100 -Volume 0.6

Write-Host "All sound files generated!"
