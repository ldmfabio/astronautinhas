param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Pacote
)

$ErrorActionPreference = 'Stop'
$RootDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $RootDir

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @()
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Comando falhou: $Command $($Arguments -join ' ')"
    }
}

function Get-FrontmatterField {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $pattern = "(?m)^" + [regex]::Escape($Name) + ":\s*[""']?([^""'\r\n]+)"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return $null
    }
    return $match.Groups[1].Value.Trim()
}

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git não encontrado no PATH.'
    }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'GitHub CLI (gh) não encontrado no PATH.'
    }
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        throw 'Python não encontrado no PATH.'
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw 'npm não encontrado no PATH.'
    }

    $packagePath = (Resolve-Path $Pacote).Path
    if ([System.IO.Path]::GetExtension($packagePath).ToLowerInvariant() -ne '.zip') {
        throw 'O pacote deve ser um arquivo .zip.'
    }

    $insideRepo = git rev-parse --is-inside-work-tree
    if ($LASTEXITCODE -ne 0 -or $insideRepo.Trim() -ne 'true') {
        throw 'Execute o script dentro do repositório Astronautinhas.'
    }

    $changes = git status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw 'Não foi possível verificar o estado do repositório.'
    }
    if ($changes) {
        throw 'Há alterações locais não commitadas. Faça commit ou stash antes de importar uma história.'
    }

    Write-Host 'Verificando autenticação do GitHub CLI...'
    Invoke-Checked -Command 'gh' -Arguments @('auth', 'status')

    $currentBranch = (git branch --show-current).Trim()
    if ($currentBranch -eq 'gh-pages') {
        throw 'Importação bloqueada na branch gh-pages.'
    }

    Write-Host 'Atualizando main...'
    Invoke-Checked -Command 'git' -Arguments @('checkout', 'main')
    Invoke-Checked -Command 'git' -Arguments @('pull', '--ff-only', 'origin', 'main')

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("astronautinhas-import-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        Expand-Archive -LiteralPath $packagePath -DestinationPath $tempDir -Force

        $packageRoot = $tempDir
        if (-not (Test-Path (Join-Path $packageRoot 'historia.md'))) {
            $directories = @(Get-ChildItem -LiteralPath $tempDir -Directory)
            $filesAtRoot = @(Get-ChildItem -LiteralPath $tempDir -File)
            if ($directories.Count -eq 1 -and $filesAtRoot.Count -eq 0) {
                $packageRoot = $directories[0].FullName
            }
        }

        $storySource = Join-Path $packageRoot 'historia.md'
        $promptSource = Join-Path $packageRoot 'prompt.md'
        $imageSource = Join-Path $packageRoot 'ilustracao.png'
        $comicsSource = Join-Path $packageRoot 'quadrinhos'
        $bookSource = Join-Path $packageRoot 'livrinho'

        foreach ($required in @($storySource, $promptSource, $imageSource, $comicsSource, $bookSource)) {
            if (-not (Test-Path $required)) {
                throw "Pacote incompleto. Item obrigatório ausente: $required"
            }
        }

        $comicPngs = @(Get-ChildItem -LiteralPath $comicsSource -File -Filter '*.png')
        $bookPngs = @(Get-ChildItem -LiteralPath $bookSource -File -Filter '*.png')
        if ($comicPngs.Count -lt 1) {
            throw 'O pacote precisa conter ao menos um PNG em quadrinhos/.'
        }
        if ($bookPngs.Count -lt 1) {
            throw 'O pacote precisa conter ao menos um PNG em livrinho/.'
        }

        $storyText = Get-Content -LiteralPath $storySource -Raw -Encoding UTF8
        $number = Get-FrontmatterField -Text $storyText -Name 'numero'
        $slug = Get-FrontmatterField -Text $storyText -Name 'slug'
        $title = Get-FrontmatterField -Text $storyText -Name 'titulo'
        $image = Get-FrontmatterField -Text $storyText -Name 'imagem'

        if (-not $number -or -not $slug -or -not $title -or -not $image) {
            throw 'historia.md precisa conter numero, slug, titulo e imagem no frontmatter.'
        }
        if ($number -notmatch '^\d+$') {
            throw "Número de história inválido: $number"
        }
        if ($slug -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
            throw "Slug inválido: $slug"
        }

        $id = '{0:D3}' -f [int]$number
        $folder = "$id-$slug"
        $expectedImage = "../../assets/historias/$folder/ilustracao.png"
        if ($image -ne $expectedImage) {
            throw "O campo imagem deve ser '$expectedImage', mas veio '$image'."
        }

        $storyDestination = Join-Path $RootDir "content\historias\$folder.md"
        $promptDestination = Join-Path $RootDir "archive\prompts\$folder.md"
        $assetsDestination = Join-Path $RootDir "assets\historias\$folder"

        if (Test-Path $storyDestination) {
            throw "Já existe uma história com este número/slug: content/historias/$folder.md"
        }
        if (Test-Path $promptDestination) {
            throw "Já existe registro de prompt para esta história: archive/prompts/$folder.md"
        }
        if (Test-Path $assetsDestination) {
            throw "Já existe pasta de assets para esta história: assets/historias/$folder"
        }

        $existingByNumber = Get-ChildItem -LiteralPath (Join-Path $RootDir 'content\historias') -Filter '*.md' |
            Where-Object { $_.Name -match "^$id-" }
        if ($existingByNumber) {
            throw "O número $number já está em uso por $($existingByNumber[0].Name)."
        }

        $slugPattern = "(?m)^slug:\s*[""']?" + [regex]::Escape($slug) + "[""']?\s*$"
        $existingBySlug = Get-ChildItem -LiteralPath (Join-Path $RootDir 'content\historias') -Filter '*.md' |
            Where-Object { [regex]::IsMatch((Get-Content $_.FullName -Raw -Encoding UTF8), $slugPattern) }
        if ($existingBySlug) {
            throw "O slug '$slug' já está em uso por $($existingBySlug[0].Name)."
        }

        $branchName = "feature/historia-$folder"
        git show-ref --verify --quiet "refs/heads/$branchName"
        if ($LASTEXITCODE -eq 0) {
            throw "A branch local '$branchName' já existe."
        }

        git ls-remote --exit-code --heads origin $branchName *> $null
        if ($LASTEXITCODE -eq 0) {
            throw "A branch remota '$branchName' já existe."
        }

        Write-Host "Criando branch $branchName..."
        Invoke-Checked -Command 'git' -Arguments @('checkout', '-b', $branchName)

        New-Item -ItemType Directory -Path (Split-Path $storyDestination -Parent) -Force | Out-Null
        New-Item -ItemType Directory -Path (Split-Path $promptDestination -Parent) -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $assetsDestination 'quadrinhos\livrinho') -Force | Out-Null

        Copy-Item -LiteralPath $storySource -Destination $storyDestination
        Copy-Item -LiteralPath $promptSource -Destination $promptDestination
        Copy-Item -LiteralPath $imageSource -Destination (Join-Path $assetsDestination 'ilustracao.png')

        foreach ($file in $comicPngs) {
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $assetsDestination ('quadrinhos\' + $file.Name))
        }
        foreach ($file in $bookPngs) {
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $assetsDestination ('quadrinhos\livrinho\' + $file.Name))
        }

        Write-Host 'Validando conteúdo...'
        Invoke-Checked -Command 'python' -Arguments @('scripts/validate_content.py')

        Write-Host 'Executando build do site...'
        Invoke-Checked -Command 'npm' -Arguments @('--prefix', 'site', 'run', 'build')

        $changesAfterBuild = git status --porcelain
        if (-not $changesAfterBuild) {
            throw 'Nenhuma alteração foi detectada após a importação.'
        }

        Write-Host 'Criando commit...'
        Invoke-Checked -Command 'git' -Arguments @(
            'add',
            "content/historias/$folder.md",
            "archive/prompts/$folder.md",
            "assets/historias/$folder"
        )
        Invoke-Checked -Command 'git' -Arguments @('commit', '-m', "feat: adicionar história $id - $title")

        Write-Host 'Enviando branch para o GitHub...'
        Invoke-Checked -Command 'git' -Arguments @('push', '-u', 'origin', $branchName)

        $prTitle = "Adicionar história $id — $title"
        $prBody = @"
Adiciona a história $id — $title ao acervo dos Astronautinhas.

Inclui:
- texto e metadados da história;
- registro do prompt original;
- ilustração principal;
- página(s) de quadrinhos;
- páginas do Livrinho.

Validações executadas automaticamente:
- scripts/validate_content.py;
- npm --prefix site run build.

A PR foi criada pelo fluxo automatizado de importação. O merge continua manual.
"@

        Write-Host 'Abrindo Pull Request...'
        Invoke-Checked -Command 'gh' -Arguments @(
            'pr', 'create',
            '--base', 'main',
            '--head', $branchName,
            '--title', $prTitle,
            '--body', $prBody
        )

        Write-Host ''
        Write-Host "Importação concluída: $id — $title"
        Write-Host "Branch: $branchName"
        Write-Host 'A PR foi aberta para revisão. Nenhum merge foi realizado.'
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
finally {
    Set-Location $RootDir
}
