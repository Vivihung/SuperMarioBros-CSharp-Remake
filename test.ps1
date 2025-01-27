Write-Host "Validation script started"

# Set the directory
Set-Location -Path $dir

# Find the first JSON file in the temp folder
$SOURCE_JSON = Get-ChildItem -Path $temp_folder -Filter *.json -File | Select-Object -First 1

if ($SOURCE_JSON) {
    # Copy the JSON file to currentchunk.json and remove the original
    Copy-Item -Path $SOURCE_JSON.FullName -Destination "currentchunk.json"
    Remove-Item -Path $SOURCE_JSON.FullName
} else {
    Write-Host "No JSON file found in temp_folder"

    # HACK: Assume the process ended successfully
    if (Test-Path "currentchunk.json") {
        Remove-Item -Path "currentchunk.json"
    }

    # Attempt to build the .NET project
    dotnet build

    if (-not $?) {
        Write-Host "Error: Dotnet build failed"
        exit 1
    } else {
        # Find all .csproj files in the current directory
        $csproj_files = Get-ChildItem -Path . -Filter *.csproj -Recurse -File

        if (-not $csproj_files) {
            Write-Host "Error: No .csproj files found in the current directory"
            exit 1
        }

        # Check if more than one .csproj file is found
        if ($csproj_files.Count -gt 1) {
            Write-Host "Error: More than one .csproj file found. Only one is allowed."
            exit 1
        }

        # Take the first .csproj file
        $csproj = $csproj_files[0]
        Write-Host "Running analysis for $($csproj.FullName)"

        # Run the upgrade-assistant analyze command
        upgrade-assistant analyze --non-interactive `
            -f net9.0 `
            -r "$dir/report.json" `
            --serializer JSON `
            --code `
            --binaries `
            --privacyMode Unrestricted `
            $csproj.FullName
    }
}

exit 0