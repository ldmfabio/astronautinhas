$ErrorActionPreference = 'Stop'

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$DistDir = Join-Path $RootDir 'site\dist'
$Branch = 'gh-pages'
$Remote = 'origin'

Set-Location $RootDir

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @()
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Comando falhou: $Command $($Arguments -join ' ')"
    }
}

try {
    $workingTreeChanges = git status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw 'Não foi possível verificar o estado do repositório Git.'
    }
    if ($workingTreeChanges) {
        throw 'Há alterações locais não commitadas. Faça commit ou stash antes do deploy.'
    }

    Write-Host 'Validando conteúdo...'
    Invoke-CheckedCommand -Command 'python' -Arguments @('scripts/validate_content.py')

    Write-Host 'Instalando dependências do site...'
    Invoke-CheckedCommand -Command 'npm' -Arguments @('--prefix', 'site', 'install')

    Write-Host 'Gerando site para GitHub Pages...'
    $env:GITHUB_PAGES = 'true'
    try {
        Invoke-CheckedCommand -Command 'npm' -Arguments @('--prefix', 'site', 'run', 'build')
    }
    finally {
        Remove-Item Env:GITHUB_PAGES -ErrorAction SilentlyContinue
    }

    $IndexFile = Join-Path $DistDir 'index.html'
    if (-not (Test-Path $IndexFile)) {
        throw 'O build não gerou site\dist\index.html.'
    }

    Write-Host 'Verificando branch gh-pages remota...'
    git fetch $Remote $Branch 2>$null
    $remoteExists = ($LASTEXITCODE -eq 0)

    $TempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("astronautinhas-gh-pages-" + [guid]::NewGuid().ToString('N'))

    try {
        if ($remoteExists) {
            Invoke-CheckedCommand -Command 'git' -Arguments @('worktree', 'add', '--detach', $TempDir, "$Remote/$Branch")
        }
        else {
            Invoke-CheckedCommand -Command 'git' -Arguments @('worktree', 'add', '--detach', $TempDir, 'HEAD')
            Push-Location $TempDir
            try {
                Invoke-CheckedCommand -Command 'git' -Arguments @('checkout', '--orphan', $Branch)
                git rm -rf . 2>$null | Out-Null
            }
            finally {
                Pop-Location
            }
        }

        Get-ChildItem -LiteralPath $TempDir -Force | Where-Object { $_.Name -ne '.git' } | Remove-Item -Recurse -Force
        Copy-Item -Path (Join-Path $DistDir '*') -Destination $TempDir -Recurse -Force
        New-Item -ItemType File -Path (Join-Path $TempDir '.nojekyll') -Force | Out-Null

        Push-Location $TempDir
        try {
            Invoke-CheckedCommand -Command 'git' -Arguments @('add', '-A')
            git diff --cached --quiet
            if ($LASTEXITCODE -eq 0) {
                Write-Host 'Nenhuma alteração no site publicado.'
                return
            }

            Invoke-CheckedCommand -Command 'git' -Arguments @('commit', '-m', 'deploy: publish Astronautinhas site')
            Invoke-CheckedCommand -Command 'git' -Arguments @('push', $Remote, "HEAD:$Branch")
        }
        finally {
            Pop-Location
        }
    }
    finally {
        git worktree remove --force $TempDir 2>$null | Out-Null
        if (Test-Path $TempDir) {
            Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ''
    Write-Host 'Publicado em: https://ldmfabio.github.io/astronautinhas/'
}
finally {
    Set-Location $RootDir
}
