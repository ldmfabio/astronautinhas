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

    $header = [regex]::Match($Text, '\A(?:\uFEFF)?---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|\z)')
    if (-not $header.Success) {
        return $null
    }

    $scope = $header.Groups[1].Value
    $prefix = '(?m)^'
    if ($Name -in @('projeto','titulo_conversa','autor_prompt','prompt_arquivo','status_importacao','prompt_original_importado','texto_original_importado','imagem_original_importada') -and $scope -match '(?m)^fonte:[ \t]*\r?$') {
        $source = [regex]::Match($scope, '(?m)^fonte:[ \t]*\r?\n((?:[ \t]+[^\r\n]*(?:\r?\n|\z))+)')
        if (-not $source.Success) {
            return $null
        }
        $scope = $source.Groups[1].Value
        $prefix = '(?m)^[ ]{2}'
    }
    $pattern = $prefix + [regex]::Escape($Name) + ':[ \t]*(?:"([^"\r\n]+)"|''([^''\r\n]+)''|([^#\r\n]+?))[ \t]*(?:#[^\r\n]*)?\r?$'
    $match = [regex]::Match($scope, $pattern)
    if (-not $match.Success) {
        return $null
    }

    foreach ($index in 1..3) {
        if ($match.Groups[$index].Success) {
            return $match.Groups[$index].Value.Trim()
        }
    }
    return $null
}

function Assert-Frontmatter {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$FileName
    )

    if (-not $Text.StartsWith("---")) {
        throw "$FileName deve comecar com frontmatter YAML delimitado por ---."
    }

    $parts = $Text -split '(?m)^---\s*$'
    if ($parts.Count -lt 3) {
        throw "$FileName possui frontmatter YAML invalido ou sem fechamento ---."
    }
}

try {
    foreach ($command in @('git', 'gh', 'python', 'npm')) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "$command nao encontrado no PATH."
        }
    }

    $packagePath = (Resolve-Path $Pacote).Path
    if ([System.IO.Path]::GetExtension($packagePath).ToLowerInvariant() -ne '.zip') {
        throw 'O pacote deve ser um arquivo .zip.'
    }

    $insideRepo = git rev-parse --is-inside-work-tree
    if ($LASTEXITCODE -ne 0 -or $insideRepo.Trim() -ne 'true') {
        throw 'Execute o script dentro do repositorio Astronautinhas.'
    }

    $changes = git status --porcelain
    if ($LASTEXITCODE -ne 0) {
        throw 'Nao foi possivel verificar o estado do repositorio.'
    }
    if ($changes) {
        throw 'Ha alteracoes locais nao commitadas. Faca commit ou stash antes de importar uma historia.'
    }

    Write-Host 'Verificando autenticacao do GitHub CLI...'
    Invoke-Checked -Command 'gh' -Arguments @('auth', 'status')

    $currentBranch = (git branch --show-current).Trim()
    if ($currentBranch -eq 'gh-pages') {
        throw 'Importacao bloqueada na branch gh-pages.'
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
                throw "Pacote incompleto. Item obrigatorio ausente: $required"
            }
        }

        $storyText = Get-Content -LiteralPath $storySource -Raw -Encoding UTF8
        $promptText = Get-Content -LiteralPath $promptSource -Raw -Encoding UTF8

        Assert-Frontmatter -Text $storyText -FileName 'historia.md'
        Assert-Frontmatter -Text $promptText -FileName 'prompt.md'

        $requiredStoryFields = @(
            'id',
            'numero',
            'titulo',
            'planeta',
            'slug',
            'categoria',
            'data',
            'imagem',
            'draft',
            'prompt_arquivo',
            'status_importacao',
            'prompt_original_importado',
            'texto_original_importado',
            'imagem_original_importada'
        )

        $missingStoryFields = @()
        foreach ($fieldName in $requiredStoryFields) {
            if (-not (Get-FrontmatterField -Text $storyText -Name $fieldName)) {
                $missingStoryFields += $fieldName
            }
        }

        if ($missingStoryFields.Count -gt 0) {
            throw "historia.md esta sem campos obrigatorios no frontmatter: $($missingStoryFields -join ', ')"
        }

        if ($storyText -notmatch '(?m)^publicacao:\s*$') {
            throw 'historia.md precisa conter o bloco publicacao no frontmatter.'
        }

        if ($storyText -notmatch '(?m)^fonte:\s*$') {
            throw 'historia.md precisa conter o bloco fonte no frontmatter.'
        }

        $requiredPromptFields = @(
            'historia_id',
            'slug',
            'data',
            'titulo_conversa',
            'autor_prompt',
            'projeto',
            'estado_registro'
        )

        $missingPromptFields = @()
        foreach ($fieldName in $requiredPromptFields) {
            if (-not (Get-FrontmatterField -Text $promptText -Name $fieldName)) {
                $missingPromptFields += $fieldName
            }
        }

        if ($missingPromptFields.Count -gt 0) {
            throw "prompt.md esta sem campos obrigatorios no frontmatter: $($missingPromptFields -join ', ')"
        }

        $number = Get-FrontmatterField -Text $storyText -Name 'numero'
        $slug = Get-FrontmatterField -Text $storyText -Name 'slug'
        $title = Get-FrontmatterField -Text $storyText -Name 'titulo'
        $image = Get-FrontmatterField -Text $storyText -Name 'imagem'
        $storyId = Get-FrontmatterField -Text $storyText -Name 'id'
        $promptStoryId = Get-FrontmatterField -Text $promptText -Name 'historia_id'
        $promptSlug = Get-FrontmatterField -Text $promptText -Name 'slug'

        if ($number -notmatch '^\d+$') {
            throw "Numero de historia invalido: $number"
        }

        if ($slug -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
            throw "Slug invalido: $slug"
        }

        $id = '{0:D3}' -f [int]$number
        $folder = "$id-$slug"

        if ($storyId -ne $id) {
            throw "O campo id de historia.md deve ser '$id', mas veio '$storyId'."
        }

        if ($promptStoryId -ne $id) {
            throw "O campo historia_id de prompt.md deve ser '$id', mas veio '$promptStoryId'."
        }

        if ($promptSlug -ne $slug) {
            throw "O slug de prompt.md deve ser '$slug', mas veio '$promptSlug'."
        }

        $expectedImage = "../../assets/historias/$folder/ilustracao.png"
        if ($image -ne $expectedImage) {
            throw "O campo imagem deve ser '$expectedImage', mas veio '$image'."
        }

        $expectedPromptPath = "../../archive/prompts/$folder.md"
        $promptPath = Get-FrontmatterField -Text $storyText -Name 'prompt_arquivo'
        if ($promptPath -ne $expectedPromptPath) {
            throw "O campo prompt_arquivo deve ser '$expectedPromptPath', mas veio '$promptPath'."
        }

        $comicPngs = @(Get-ChildItem -LiteralPath $comicsSource -File -Filter '*.png' | Sort-Object Name)
        $bookPngs = @(Get-ChildItem -LiteralPath $bookSource -File -Filter '*.png' | Sort-Object Name)

        if ($comicPngs.Count -ne 1 -or $comicPngs[0].Name -ne 'pagina-01.png') {
            throw 'O pacote deve conter exatamente quadrinhos/pagina-01.png.'
        }

        $expectedBookNames = @(1..6 | ForEach-Object { 'pagina-{0:D2}.png' -f $_ })
        $actualBookNames = @($bookPngs | ForEach-Object { $_.Name })

        if ($actualBookNames.Count -ne 6) {
            throw 'O livrinho deve conter exatamente 6 paginas PNG.'
        }

        for ($i = 0; $i -lt 6; $i++) {
            if ($actualBookNames[$i] -ne $expectedBookNames[$i]) {
                throw "Pagina de livrinho ausente ou fora do padrao: $($expectedBookNames[$i])"
            }
        }

        $bookHashes = @(
            $bookPngs | ForEach-Object {
                (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
            }
        )

        if (($bookHashes | Select-Object -Unique).Count -ne 6) {
            throw 'As 6 paginas do livrinho precisam ser arquivos diferentes. Foram detectadas imagens repetidas.'
        }

        $mainImageHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $imageSource).Hash
        $comicHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $comicPngs[0].FullName).Hash

        if ($bookHashes -contains $mainImageHash) {
            throw 'Uma pagina do livrinho e identica a ilustracao principal. O livrinho precisa ter cenas proprias.'
        }

        if ($comicHash -eq $mainImageHash) {
            throw 'A pagina de quadrinhos e identica a ilustracao principal. Os quadrinhos precisam ter composicao propria.'
        }

        if ($bookHashes -contains $comicHash) {
            throw 'Uma pagina do livrinho e identica a pagina de quadrinhos.'
        }

        $storyDestination = Join-Path $RootDir "content\historias\$folder.md"
        $promptDestination = Join-Path $RootDir "archive\prompts\$folder.md"
        $assetsDestination = Join-Path $RootDir "assets\historias\$folder"

        if (Test-Path $storyDestination) {
            throw "Ja existe uma historia com este numero/slug: content/historias/$folder.md"
        }

        if (Test-Path $promptDestination) {
            throw "Ja existe registro de prompt para esta historia: archive/prompts/$folder.md"
        }

        if (Test-Path $assetsDestination) {
            throw "Ja existe pasta de assets para esta historia: assets/historias/$folder"
        }

        $existingByNumber = @(
            Get-ChildItem -LiteralPath (Join-Path $RootDir 'content\historias') -Filter '*.md' |
            Where-Object { $_.Name -match "^$id-" }
        )

        if ($existingByNumber.Count -gt 0) {
            throw "O numero $number ja esta em uso por $($existingByNumber[0].Name)."
        }

        $slugPattern = '(?m)^slug:\s*["'']?' + [regex]::Escape($slug) + '["'']?\s*$'
        $existingBySlug = @(
            Get-ChildItem -LiteralPath (Join-Path $RootDir 'content\historias') -Filter '*.md' |
            Where-Object {
                [regex]::IsMatch(
                    (Get-Content $_.FullName -Raw -Encoding UTF8),
                    $slugPattern
                )
            }
        )

        if ($existingBySlug.Count -gt 0) {
            throw "O slug '$slug' ja esta em uso por $($existingBySlug[0].Name)."
        }

        $branchName = "feature/historia-$folder"

        git show-ref --verify --quiet "refs/heads/$branchName"
        if ($LASTEXITCODE -eq 0) {
            throw "A branch local '$branchName' ja existe."
        }

        git ls-remote --exit-code --heads origin $branchName *> $null
        if ($LASTEXITCODE -eq 0) {
            throw "A branch remota '$branchName' ja existe."
        }

        Write-Host "Criando branch $branchName..."
        Invoke-Checked -Command 'git' -Arguments @('checkout', '-b', $branchName)

        New-Item -ItemType Directory -Path (Split-Path $storyDestination -Parent) -Force | Out-Null
        New-Item -ItemType Directory -Path (Split-Path $promptDestination -Parent) -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $assetsDestination 'quadrinhos\livrinho') -Force | Out-Null

        Copy-Item -LiteralPath $storySource -Destination $storyDestination
        Copy-Item -LiteralPath $promptSource -Destination $promptDestination
        Copy-Item -LiteralPath $imageSource -Destination (Join-Path $assetsDestination 'ilustracao.png')

        Copy-Item -LiteralPath $comicPngs[0].FullName -Destination (Join-Path $assetsDestination 'quadrinhos\pagina-01.png')

        foreach ($file in $bookPngs) {
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $assetsDestination ('quadrinhos\livrinho\' + $file.Name))
        }

        Write-Host 'Validando conteudo...'
        Invoke-Checked -Command 'python' -Arguments @('scripts/validate_content.py')

        Write-Host 'Executando build do site...'
        Invoke-Checked -Command 'npm' -Arguments @('--prefix', 'site', 'run', 'build')

        $changesAfterBuild = git status --porcelain
        if (-not $changesAfterBuild) {
            throw 'Nenhuma alteracao foi detectada apos a importacao.'
        }

        Write-Host 'Criando commit...'
        Invoke-Checked -Command 'git' -Arguments @(
            'add',
            "content/historias/$folder.md",
            "archive/prompts/$folder.md",
            "assets/historias/$folder"
        )

        Invoke-Checked -Command 'git' -Arguments @(
            'commit',
            '-m',
            "feat: adicionar historia $id - $title"
        )

        Write-Host 'Enviando branch para o GitHub...'
        Invoke-Checked -Command 'git' -Arguments @(
            'push',
            '-u',
            'origin',
            $branchName
        )

        $prTitle = "Adicionar historia $id - $title"
        $prBodyLines = @(
            "Adiciona a historia $id - $title ao acervo dos Astronautinhas.",
            "",
            "Inclui:",
            "- texto e metadados da historia;",
            "- registro do prompt original;",
            "- ilustracao principal;",
            "- pagina de quadrinhos com 6 cenas;",
            "- 6 paginas do Livrinho.",
            "",
            "Validacoes executadas automaticamente:",
            "- scripts/validate_content.py;",
            "- npm --prefix site run build.",
            "",
            "A PR foi criada pelo fluxo automatizado de importacao.",
            "O merge continua manual."
        )

        $prBody = $prBodyLines -join [Environment]::NewLine

        Write-Host 'Abrindo Pull Request...'
        Invoke-Checked -Command 'gh' -Arguments @(
            'pr',
            'create',
            '--base',
            'main',
            '--head',
            $branchName,
            '--title',
            $prTitle,
            '--body',
            $prBody
        )

        Write-Host ''
        Write-Host "Importacao concluida: $id - $title"
        Write-Host "Branch: $branchName"
        Write-Host 'A PR foi aberta para revisao. Nenhum merge foi realizado.'
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
