$rootPath = Get-Location
$jsFile = Join-Path $rootPath "js\problems.js"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

Write-Host "Scanning for problems in: $rootPath"

# Initialize entries array
$catalog = @()

# Get all directories in the root (Categories)
# Exclude known system/app dirs
$excludeDirs = @("js", ".git", ".agent", ".vscode", "node_modules")
$categories = Get-ChildItem -Path $rootPath -Directory | Where-Object { $excludeDirs -notcontains $_.Name }

foreach ($categoryDir in $categories) {
    Write-Host "Found Category: $($categoryDir.Name)"
    
    $categoryObj = @{
        categoryName  = $categoryDir.Name
        subCategories = @()
    }

    # Get subdirectories (SubCategories)
    $subDirs = Get-ChildItem -Path $categoryDir.FullName -Directory

    foreach ($subDir in $subDirs) {
        $indexFile = Join-Path $subDir.FullName "index.html"
        $shouldInclude = $false
        
        # 1. Check if index.html exists
        if (Test-Path $indexFile) {
            $shouldInclude = $true
        } 
        # 2. If not, try to generate it from existing HTML files
        else {
            $htmlFiles = Get-ChildItem -Path $subDir.FullName -Filter "*.html"
            
            if ($htmlFiles.Count -gt 0) {
                Write-Host "  [AUTO-GEN] Generating index.html for $($subDir.Name)..."
                
                # Build HTML list items
                $listItems = ""
                foreach ($file in $htmlFiles) {
                    $fileName = $file.Name
                    $displayName = $file.BaseName
                    
                    # Skip if it is somehow index.html (though logic prevents this usually)
                    if ($fileName -eq "index.html") { continue }

                    $listItems += @"
            <a href="$fileName" class="block bg-white rounded-lg shadow hover:shadow-md transition-all duration-200 p-4 border-l-4 border-indigo-400">
                <p class="text-xs font-bold text-indigo-400 mb-1">FILE</p>
                <p class="text-base text-slate-700 font-medium">$displayName</p>
            </a>
"@
                }

                # HTML Template
                $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$($subDir.Name)</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;700&family=Noto+Sans+JP:wght@400;700&display=swap" rel="stylesheet">
    <style>body { font-family: 'Inter', 'Noto Sans JP', sans-serif; }</style>
</head>
<body class="bg-slate-50">
    <div class="max-w-4xl mx-auto p-6 md:p-10 min-h-screen">
        <header class="mb-10 pt-8 border-b pb-4">
            <a href="../../index.html" class="text-blue-500 hover:text-blue-700 text-sm flex items-center mb-3">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="mr-1"><path d="M3 12h18M12 5l-7 7 7 7"></path></svg>
                問題選択に戻る (トップ)
            </a>
            <h1 class="text-3xl font-extrabold text-slate-800 tracking-tight">
                $($subDir.Name)
            </h1>
            <p class="text-base text-slate-500 mt-1">
                ファイルを選択して学習を開始してください (自動生成)
            </p>
        </header>

        <div class="space-y-4">
$listItems
        </div>
    </div>
</body>
</html>
"@
                try {
                    [System.IO.File]::WriteAllText($indexFile, $htmlContent, $utf8NoBom)
                    Write-Host "    -> Created $indexFile"
                    $shouldInclude = $true
                }
                catch {
                    Write-Error "    Failed to write index.html: $_"
                }
            }
        }

        if ($shouldInclude) {
            Write-Host "  Found Item: $($subDir.Name)"
            
            # Extract title from HTML
            $title = $subDir.Name
            try {
                $content = Get-Content -Path $indexFile -Raw -Encoding UTF8
                if ($content -match '<title>(.*?)</title>') {
                    $title = $matches[1]
                }
            }
            catch {
                Write-Warning "    Could not read $($indexFile)"
            }

            # Create relative path ensuring forward slashes
            $relativePath = "$($categoryDir.Name)/$($subDir.Name)/index.html"
            
            $subCatObj = @{
                name  = $subDir.Name
                items = @(
                    @{
                        title = $title
                        path  = $relativePath
                        note  = ""
                    }
                )
            }
            $categoryObj.subCategories += $subCatObj
        }
    }
    
    if ($categoryObj.subCategories.Count -gt 0) {
        $catalog += $categoryObj
    }
}

# Convert to JSON
# Handle PowerShell 5.1 JSON array quirk
$json = $catalog | ConvertTo-Json -Depth 10

if ($catalog.Count -eq 1) {
    if (-not ($json.Trim().StartsWith("["))) {
        $json = "[$json]"
    }
}
if (-not $json) {
    $json = "[]"
}

# Javascript content
$jsContent = "window.PROBLEM_CATALOG = $json;"

# Write to file with UTF8 encoding
[System.IO.File]::WriteAllText($jsFile, $jsContent, $utf8NoBom)

Write-Host "Done. Updated $($jsFile)"
