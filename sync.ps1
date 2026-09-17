$items = Get-ChildItem Questions/*.md | ForEach-Object {
    $fn = $_.Name
    $raw = Get-Content $_.FullName -Raw -Encoding utf8
    
    # 精準擷取 YAML 前言
    $yamlContent = ""
    if ($raw -match '(?s)^(?:---\r?\n)?(.*?)\r?\n---') {
        $yamlContent = $matches[1]
    } else {
        $yamlContent = $raw
    }

    $difficulty = "未標示"
    $categories = @()
    $concepts = @()
    $lines = $yamlContent -split "\r?\n"
    $currentKey = $null

    foreach ($line in $lines) {
        # 1. 抓取 difficulty
        if ($line -match '(?i)^\s*difficulty\s*:\s*(.*)$') {
            $val = $matches[1].Trim() -replace '["'']', ''
            if ($val) { $difficulty = $val }
            continue
        }

        # 2. 抓取 source (映射為 categories)
        if ($line -match '(?i)^\s*source\s*:\s*(.*)$') {
            $val = $matches[1].Trim() -replace '["'']', ''
            if ($val) { $categories += $val }
            continue
        }

        # 3. 抓取 tags 或 concepts (映射為 concepts)
        if ($line -match '(?i)^\s*(tags|concepts)\s*:\s*(.*)$') {
            $currentKey = "concepts"
            $value = $matches[2].Trim()
            if ($value -match '^\[(.*)\]$') {
                $concepts += $matches[1] -split ',' | ForEach-Object { $_.Trim() }
                $currentKey = $null
            } elseif ($value -ne "") {
                $concepts += $value
                $currentKey = $null
            }
            continue
        }

        # 多行列表模式解析 (- tag)
        if ($currentKey -eq "concepts") {
            if ($line -match '^\s*-\s*([^$]+)$') {
                $val = $matches[1].Trim()
                $concepts += $val
            } elseif ($line -match '^\s*\w+\s*:' -or $line -match '^\s*#' -or $line.Trim() -eq "") {
                $currentKey = $null
            }
        }
    }

    # 清理與去重
    $cleanCats = $categories | ForEach-Object { $_ -replace '["'']', '' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique
    $cleanCons = $concepts | ForEach-Object { $_ -replace '["'']', '' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique

    $catStr = ($cleanCats | ForEach-Object { "`"$($_)`"" }) -join ', '
    $conStr = ($cleanCons | ForEach-Object { "`"$($_)`"" }) -join ', '

    "{ file: `"Questions/$fn`", difficulty: `"$difficulty`", categories: [$catStr], concepts: [$conStr] }"
}

$jsonBlock = "const questionBank = [`n  " + ($items -join ",`n  ") + "`n];"

# 使用 ReadAllText / WriteAllText 避免檔案鎖定衝突
$htmlPath = "$PSScriptRoot/index.html"
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$updatedHtml = $html -replace 'const questionBank = \[[\s\S]*?\];', $jsonBlock
[System.IO.File]::WriteAllText($htmlPath, $updatedHtml, [System.Text.Encoding]::UTF8)

Write-Host "✅ 已成功按「取題來源 (source)」、「難易度 (difficulty)」與「試題內容 (tags)」完成同步！" -ForegroundColor Green