#!/bin/bash

cd $dir

SOURCE_JSON=$(find "$temp_folder" -maxdepth 1 -type f -name '*.json' -print -quit)
if [ -n "$SOURCE_JSON" ]; then
    cp "$SOURCE_JSON" currentchunk.json
    rm "$SOURCE_JSON"
else
    echo "Error: No json found in temp_folder"
    # HACK: Assume the process ended successfully
    if [ -f "currentchunk.json" ]; then
        rm currentchunk.json
    fi

    # Attempt to build the .NET project
    dotnet build

    if [ $? -eq 1 ]; then
        echo "Error: Dotnet build failed"
        exit 1
    else
        # Run the analysis again
        # Find all .csproj files in the current directory
        csproj_files=$(find . -type f -name '*.csproj')

        if [ -z "$csproj_files" ]; then
            echo "Error: No .csproj files found in the current directory"
            exit 1
        fi

        # Check if more than one .csproj file is found
        csproj_count=$(echo "$csproj_files" | wc -l)
        if [ "$csproj_count" -gt 1 ]; then
            echo "Error: More than one .csproj file found. Only one is allowed."
            exit 1
        fi

        # Take the first .csproj file
        csproj=$(echo "$csproj_files" | head -n 1)
        echo "Running analysis for $csproj"
        upgrade-assistant analyze --non-interactive \
            -f net9.0 \
            -r "$dir/report.json" \
            --serializer JSON \
            --code \
            --binaries \
            --privacyMode Unrestricted \
            "$csproj"
    fi
fi

exit 0