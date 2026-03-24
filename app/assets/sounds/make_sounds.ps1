function Write-Wave ($file, $freqs, $durationMs) {
    $sampleRate = 44100
    $numSamples = [int]($sampleRate * $durationMs / 1000)
    $fileStream = [System.IO.File]::Create($file)
    $writer = New-Object System.IO.BinaryWriter($fileStream)

    # RIFF header
    $writer.Write([char[]]"RIFF")
    $writer.Write([int]($numSamples * 2 + 36))
    $writer.Write([char[]]"WAVE")

    # fmt subchunk
    $writer.Write([char[]]"fmt ")
    $writer.Write([int]16)
    $writer.Write([Int16]1) # PCM
    $writer.Write([Int16]1) # Mono
    $writer.Write([int]$sampleRate)
    $writer.Write([int]($sampleRate * 2)) # ByteRate
    $writer.Write([Int16]2) # BlockAlign
    $writer.Write([Int16]16) # BitsPerSample

    # data subchunk
    $writer.Write([char[]]"data")
    $writer.Write([int]($numSamples * 2))

    $pi = [math]::PI
    for ($i = 0; $i -lt $numSamples; $i++) {
        $t = $i / $sampleRate
        if ($freqs -is [array]) {
            $idx = [int]([math]::Floor($t / ($durationMs / 1000 / $freqs.Length)))
            if ($idx -ge $freqs.Length) { $idx = $freqs.Length - 1 }
            $f = $freqs[$idx]
            
            # Simple envelope to make arpeggio clear
            $envT = $t - ($idx * ($durationMs / 1000 / $freqs.Length))
            $val = [Int16]([math]::Round([math]::Sin(2 * $pi * $f * $t) * 16383 * [math]::Exp(-5 * $envT)))
        } else {
            # Exponential decay envelope
            $val = [Int16]([math]::Round([math]::Sin(2 * $pi * $freqs * $t) * 16383 * [math]::Exp(-20 * $t)))
        }
        $writer.Write([Int16]$val)
    }

    $writer.Close()
    $fileStream.Close()
}

New-Item -ItemType Directory -Force -Path "d:\PP942920DRIVE\PROJECTS\chess\app\assets\sounds"

# Move: subtle short "thud/click" tone
Write-Wave -file "d:\PP942920DRIVE\PROJECTS\chess\app\assets\sounds\move.wav" -freqs 300 -durationMs 100

# Warning / Check: higher pitch alert tone
Write-Wave -file "d:\PP942920DRIVE\PROJECTS\chess\app\assets\sounds\warning.wav" -freqs 800 -durationMs 300

# Win: Arpeggio up C major chord (C4, E4, G4, C5)
Write-Wave -file "d:\PP942920DRIVE\PROJECTS\chess\app\assets\sounds\win.wav" -freqs @(261.63, 329.63, 392.00, 523.25) -durationMs 800

Write-Output "Successfully generated move.wav, warning.wav, win.wav"
