$items = Get-ChildItem questions/*.md | ForEach-Object {
    $fn = $_.Name
    $raw = Get-Content $_.FullName -Raw -Encoding utf8
    
    # 1. 抓取 YAML Front Matter 區塊 (--- ... ---)
    $yamlContent = ""
    if ($raw -match '(?s)^---\r?\n(.*?)\r?\n---') {
        $yamlContent = $matches[1]
    } else {
        $yamlContent = $raw
    }

    $tags = @()

    # 2. 解析 YAML 中的 tags / source 欄位
    $lines = $yamlContent -split "\r?\n"
    $inTagSection = $false

    foreach ($line in $lines) {
        # 當遇到 tags: 或 source: 開頭
        if ($line -match '(?i)^\s*(tags|source)\s*:\s*(.*)$') {
            $value = $matches[2].Trim()
            
            # 情況 A: 同行陣列 [tag1, tag2]
            if ($value -match '^\[(.*)\]$') {
                $tags += $matches[1] -split ','
                $inTagSection = $false
            } 
            # 情況 B: 同行單一值 (tags: tag1)
            elseif ($value -ne "") {
                $tags += $value
                $inTagSection = $false
            } 
            # 情況 C: 多行列表 (tags: 換行後的 - tag1)
            else {
                $inTagSection = $true
            }
            continue
        }

        # 如果在多行列表狀態下
        if ($inTagSection) {
            # 遇到縮排的 - tag 項目
            if ($line -match '^\s*-\s*(.*)$') {
                $tags += $matches[1].Trim()
            } 
            # 如果遇到其他新屬性 (如 title: / date:) 就結束標籤區塊
            elseif ($line -match '^\s*\w+\s*:') {
                $inTagSection = $false
            }
        }
    }

    # 3. 清理字串 (移除引號、橫線、空格) 並進行去重
    $cleanTags = $tags | ForEach-Object { 
        $_ -replace '["'']', '' 
    } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" -and $_ -ne "---" } | Select-Object -Unique

    $tagStr = ($cleanTags | ForEach-Object { "`"$($_)`"" }) -join ', '
    "{ file: `"questions/$fn`", tags: [$tagStr] }"
}

$jsonBlock = "const questionBank = [`n  " + ($items -join ",`n  ") + "`n];"

# 4. 讀寫 index.html (避免 File Lock)
$htmlPath = "$PSScriptRoot/index.html"
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$updatedHtml = $html -replace 'const questionBank = \[[\s\S]*?\];', $jsonBlock
[System.IO.File]::WriteAllText($htmlPath, $updatedHtml, [System.Text.Encoding]::UTF8)

Write-Host "✅ 已成功抓取所有多重標籤並同步至 index.html！" -ForegroundColor Green