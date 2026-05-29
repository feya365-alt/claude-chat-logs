# Автосохранение чата Claude в GitHub
$ErrorActionPreference = "Continue"

$env:PATH = $env:PATH + ";C:\Program Files\Git\bin;C:\Program Files\GitHub CLI"
$RepoPath = "c:\Users\Honor\Documents\Сергей Грибанов"
$ChatLogsPath = "$RepoPath\chat-logs"
$ProjectDir = "$env:USERPROFILE\.claude\projects\c--Users-Honor-Documents----------------"

# Найти самый свежий JSONL файл сессии
$LatestSession = Get-ChildItem "$ProjectDir\*.jsonl" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $LatestSession) {
    Write-Host "Нет файлов сессий"
    exit 0
}

$SessionId = $LatestSession.BaseName
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$OutputFile = "$ChatLogsPath\chat_$Timestamp.md"
Set-Location $RepoPath

# Парсим JSONL и строим markdown
$Lines = Get-Content $LatestSession.FullName -Encoding UTF8
$ChatContent = "# Чат Claude — $Timestamp`n`n"
$ChatContent += "Сессия: ``$SessionId```n`n---`n`n"

foreach ($Line in $Lines) {
    try {
        $Entry = $Line | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $Entry) { continue }

        if ($Entry.type -eq "user" -and $Entry.message.role -eq "user") {
            $Content = $Entry.message.content
            $Text = ""
            if ($Content -is [string]) {
                $Text = $Content
            } elseif ($Content -is [array]) {
                foreach ($Part in $Content) {
                    if ($Part.type -eq "text") { $Text += $Part.text }
                }
            }
            if ($Text -ne "") {
                $Time = if ($Entry.timestamp) { ([datetime]$Entry.timestamp).ToLocalTime().ToString("HH:mm:ss") } else { "" }
                $ChatContent += "### Пользователь [$Time]`n`n$Text`n`n"
            }
        }
        elseif ($Entry.type -eq "assistant" -and $Entry.message.role -eq "assistant") {
            $Content = $Entry.message.content
            $Text = ""
            if ($Content -is [string]) {
                $Text = $Content
            } elseif ($Content -is [array]) {
                foreach ($Part in $Content) {
                    if ($Part.type -eq "text") { $Text += $Part.text }
                }
            }
            if ($Text -ne "") {
                $Time = if ($Entry.timestamp) { ([datetime]$Entry.timestamp).ToLocalTime().ToString("HH:mm:ss") } else { "" }
                $ChatContent += "### Claude [$Time]`n`n$Text`n`n---`n`n"
            }
        }
    } catch {}
}

# Сохраняем файл
[System.IO.File]::WriteAllText($OutputFile, $ChatContent, [System.Text.Encoding]::UTF8)

# Git commit и push
& "C:\Program Files\Git\bin\git.exe" add "chat-logs/"
$Status = & "C:\Program Files\Git\bin\git.exe" status --porcelain
if ($Status) {
    & "C:\Program Files\Git\bin\git.exe" commit -m "auto: сохранение чата $Timestamp"
    & "C:\Program Files\Git\bin\git.exe" push origin main 2>&1
    Write-Host "Сохранено: chat_$Timestamp.md"
} else {
    Write-Host "Нет изменений для сохранения"
}
