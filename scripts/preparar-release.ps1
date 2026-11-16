param([string]$Tag = 'v1.2.2')
$ErrorActionPreference = 'Stop'
$raizProjeto = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $raizProjeto
if ($Tag -notmatch '^v\d+\.\d+\.\d+$') { throw 'Use uma tag como v1.2.2.' }
if (git status --porcelain) { throw 'Confirme as alterações em commit antes de preparar a release.' }
$apk = Join-Path $raizProjeto 'build/app/outputs/flutter-apk/app-release.apk'
if (-not (Test-Path -LiteralPath $apk)) { throw 'Gere o APK de release primeiro.' }
$env:GIT_TERMINAL_PROMPT = '0'
$env:GCM_INTERACTIVE = 'never'
# A credencial permanece apenas em memória e nunca é exibida ou gravada.
$credencial = "protocol=https`nhost=github.com`n`n" | git credential fill 2>$null
$linhaToken = $credencial | Where-Object { $_.StartsWith('password=') }
if (-not $linhaToken) { throw 'Autentique o Git no GitHub antes de publicar.' }
$headers = @{Authorization = 'Bearer ' + $linhaToken.Substring(9); Accept='application/vnd.github+json'; 'X-GitHub-Api-Version'='2022-11-28'}
$repositorio = 'nandoalmeidam/gs-cpad-climasense'
$api = "https://api.github.com/repos/$repositorio"
$revisao = (git rev-parse HEAD).Trim()
$existente = Invoke-RestMethod "$api/releases" -Headers $headers
if ($existente | Where-Object tag_name -eq $Tag) { throw 'Essa release já existe; confira no GitHub antes de repetir.' }
$notas = [regex]::Match((Get-Content README.md -Raw), '(?ms)^## Notas da versão\r?\n(.*?)(?=^## |\z)').Groups[1].Value.Trim()
if (-not $notas) { throw 'Preencha a seção Notas da versão no README.' }
$corpo = @{tag_name=$Tag;target_commitish=$revisao;name="ClimaSense $Tag";body=$notas;draft=$true;prerelease=$false} | ConvertTo-Json
$release = Invoke-RestMethod "$api/releases" -Method Post -Headers $headers -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($corpo))
$nome = "climasense-$Tag.apk"
$upload = ($release.upload_url -split '\{')[0]
$arquivo = Invoke-RestMethod "$($upload)?name=$nome" -Method Post -Headers $headers -ContentType 'application/vnd.android.package-archive' -InFile $apk
if ($arquivo.size -ne (Get-Item -LiteralPath $apk).Length) { throw 'O tamanho do APK enviado não corresponde ao arquivo local.' }
$hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Output ([PSCustomObject]@{releaseId=$release.id;draft=$release.draft;commit=$revisao;asset=$arquivo.name;bytes=$arquivo.size;sha256=$hash;url=$release.html_url})
