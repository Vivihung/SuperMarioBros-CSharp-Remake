# Motivation: Fiddler can inspect traffic in powershell terminals, but not WSL.
# Issue list
#     1. IO: aider's model responses are not displayed in console.
#     2. IO: Ctrl-C doens't pass through to aider.
#     3. Env: Somehow running test.ps1 will reset the oh-my-posh theme under user folder. It renamed the theme file to *.bak.

# Check for required tools
$requiredCommands = @("dotnet", "upgrade-assistant", "aider")
foreach ($cmd in $requiredCommands) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Error "Error: $cmd is required but not installed"
        exit 1
    }
}

# Verify dotnet SDK version
if (-not (dotnet --list-sdks | Select-String -Pattern '9\.0')) {
    Write-Error "Error: .NET 9.0 SDK is required"
    exit 1
}

$envfile = Resolve-Path ../.env
$rootfolder = Get-Location

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned -Force

# Find all .csproj files in the repository and run upgrade analysis
Get-ChildItem -Recurse -Filter *.csproj | ForEach-Object {
    $dir = $_.DirectoryName
    $csfileloc = Resolve-Path $_.FullName
    Write-Host "Analyzing $dir"
    upgrade-assistant analyze --non-interactive `
        -f net9.0 `
        -r "$dir/report.json" `
        --serializer JSON `
        --code `
        --binaries `
        --privacyMode Unrestricted `
        "$csfileloc"
    
    Set-Location $dir
    $env:dir = $dir

    # Hardcoded input filename
    $input_file = "report.json"

    # Delete the temp folder if it exists
    $temp_folder = "temp_chunks"
    if (Test-Path $temp_folder) {
        Remove-Item -Recurse -Force $temp_folder
    }

    # Create a temporary folder for chunked files
    New-Item -ItemType Directory -Path $temp_folder | Out-Null

    # Step 1: Read the JSON file
    $json = Get-Content $input_file | ConvertFrom-Json

    # Step 2: Filter the rules to only keep severity=="Mandatory"
    $mandatory_rules = $json.rules.PSObject.Properties | Where-Object { $_.Value.severity -eq "Mandatory" } | ForEach-Object { $_.Name }

    # Step 3: For each item under projects, filter its ruleInstances where ruleId are in the set from #1
    # Assign a unique number ID (starting from 0) to each filtered ruleInstance and place it inside the ruleInstance object
    $filtered_rule_instances = $json.projects | ForEach-Object {
        $_.ruleInstances | Where-Object { $mandatory_rules -contains $_.ruleId } | ForEach-Object -Begin { $id = 0 } -Process {
            $_ | Add-Member -NotePropertyName "id" -NotePropertyValue $id
            $id++
            $_
        }
    }

    # Hack: Just take the first 200 for demo (to avoid long process time)
    $filtered_rule_instances = $filtered_rule_instances | Select-Object -First 200

    # Step 4: Split the filtered ruleInstances into chunks of 50 elements each
    $chunkSize = 50
    $chunks = for ($i = 0; $i -lt $filtered_rule_instances.Count; $i += $chunkSize) {
        , @($filtered_rule_instances[$i..($i + $chunkSize - 1)])
    }

    # Step 5: Save each chunk to a separate file
    $chunkIndex = 0
    foreach ($chunk in $chunks) {
        $chunk_file = "$temp_folder/chunk_$chunkIndex.json"
        $chunk | ConvertTo-Json -Depth 10 | Set-Content $chunk_file
        Write-Host "Created chunk file: $chunk_file"
        $chunkIndex++
    }
    Write-Host "Filtered ruleInstances have been split into chunks and saved in the '$temp_folder' folder."

    # Step 6: For each chunk, run the command
    $chunk_file = Get-ChildItem $temp_folder -Filter *.json | Select-Object -First 1
    Write-Host "Processing $($chunk_file.FullName)"
    $env:temp_folder = $temp_folder
    Copy-Item $chunk_file.FullName -Destination currentchunk.json
    Remove-Item $chunk_file.FullName


    # Isolate aider's IO from the script's pipeline
    # Build the argument list for aider
    $aiderArgs = @(
        "--gitignore",
        "--architect",
        "--no-show-model-warnings",
        "--no-check-update",
        "--no-show-release-notes",
        "--yes-always",
        "--no-suggest-shell-commands",
        "--auto-test",
        "--test-cmd", "$rootfolder/test.ps1",
        "--env-file=$envfile",
        "--file", "`"$csfileloc`"",
        "--edit-format", "diff",
        "--read", "currentchunk.json"
    )

    # DEBUG
    Write-Host "Running command with a new process: aider $aiderArgs"

    try {
        # Start aider as a separate process to allow key interrupts pass through
        $aiderProcess = Start-Process -FilePath "aider" -ArgumentList $aiderArgs -NoNewWindow -PassThru

        # Wait for the process to finish
        $aiderProcess.WaitForExit()

        # Run aider directly in the current PowerShell session
        # & "aider" $aiderArgs

        
    }
    catch {
        Write-Host "Aider was interrupted by Ctrl+C."
    
        # Forcefully terminate the aider process
        if ($aiderProcess -and -not $aiderProcess.HasExited) {
            Stop-Process -Id $aiderProcess.Id -Force
        }
        exit 1
    }

    # Check the exit code
    if ($aiderProcess.ExitCode -ne 0) {
        Write-Host "Aider failed with exit code $($aiderProcess.ExitCode)"
    }

    # Write-Host "Running command: aider --gitignore --architect --no-show-model-warnings --no-check-update --no-show-release-notes --yes-always --no-suggest-shell-commands --auto-test --test-cmd `"$rootfolder/test.ps1`" --env-file=$envfile --file `"$csfileloc`" --edit-format diff --read currentchunk.json"
    # aider --gitignore --architect --no-show-model-warnings --no-check-update --no-show-release-notes --yes-always --no-suggest-shell-commands --auto-test --test-cmd "& $rootfolder/test.ps1" --env-file=$envfile --file "$csfileloc" --edit-format diff --read currentchunk.json

    # Clean up the temporary folder
    Remove-Item -Recurse -Force $temp_folder
    Remove-Item Env:\temp_folder
    Remove-Item Env:\dir
    Set-Location $rootfolder
}