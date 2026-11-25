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
        throw 'Nao foi possivel verificar o estado do repositorio Git.'
    }
    if ($workingTreeChanges) {
        throw 'Ha alteracoes locais nao commitadas. Faca commit ou stash antes do deploy.'
    }

    Write-Host 'Validando conteudo...'
    Invoke-CheckedCommand -Command 'python' -Arguments @('scripts/validate_content.py')

    Write-Host 'Instalando dependencias do site...'
    Invoke-CheckedCommand -Command 'npm' -Arguments @('--prefix', 'site', 'install')

    Write-Host 'Gerando site para astronautinhas.com.br...'
    Invoke-CheckedCommand -Command 'npm' -Arguments @('--prefix', 'site', 'run', 'build')

    $IndexFile = Join-Path $DistDir 'index.html'
    if (-not (Test-Path $IndexFile)) {
        throw 'O build nao gerou site\dist\index.html.'
    }

    Write-Host 'Verificando branch gh-pages remota...'
    # Git writes progress to stderr even when successful.
    # Avoid redirecting native stderr with Windows PowerShell ErrorAction Stop.
    $remoteRef = @(git ls-remote --exit-code --heads $Remote "refs/heads/$Branch")
    $remoteStatus = $LASTEXITCODE
    if ($remoteStatus -ne 0 -and $remoteStatus -ne 2) {
        throw "Falha ao consultar a branch remota (git exit $remoteStatus)."
    }
    $remoteExists = ($remoteStatus -eq 0)
    if ($remoteExists) {
        Invoke-CheckedCommand -Command 'git' -Arguments @(
            'fetch', '--quiet', $Remote, "refs/heads/$($Branch):refs/remotes/$Remote/$Branch"
        )
    }

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
                Invoke-CheckedCommand -Command 'git' -Arguments @('rm', '-rf', '--quiet', '.')
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
                Write-Host 'Nenhuma alteracao no site publicado.'
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
        if (Test-Path (Join-Path $TempDir '.git')) {
            git worktree remove --force $TempDir
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Nao foi possivel remover o worktree temporario: $TempDir"
            }
        }
        if ((Test-Path $TempDir) -and -not (Test-Path (Join-Path $TempDir '.git'))) {
            Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host ''
    Write-Host 'Publicado em: https://astronautinhas.com.br/'
}
finally {
    Set-Location $RootDir
}
