#!/bin/bash

# Check for required tools
required_commands=("jq" "dotnet" "upgrade-assistant" "aider")
for cmd in "${required_commands[@]}"; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is required but not installed"
        exit 1
    fi
done

# Verify dotnet SDK version
if ! dotnet --list-sdks | grep -q '9\.0'; then
    echo "Error: .NET 9.0 SDK is required"
    exit 1
fi

envfile=$(readlink -f ../.env)
rootfolder=$PWD

chmod +x test.sh

# Find all .csproj files in the repository and run upgrade analysis
find . -type f -name "*.csproj" -print0 | while IFS= read -r -d '' csproj; do
    dir=$(dirname "$csproj")
    csfileloc=$(readlink -f "$csproj")
    echo "Analyzing $dir"
    upgrade-assistant analyze --non-interactive \
        -f net9.0 \
        -r "$dir/report.json" \
        --serializer JSON \
        --code \
        --binaries \
        --privacyMode Unrestricted \
        "$csfileloc"
    
    cd $dir
    export dir
    # Filter the data to incidents whose severity is Mandatory
    # Hardcoded input filename
    input_file="report.json"

    # Delete the temp folder if it exists
    temp_folder="temp_chunks"
    if [ -d "$temp_folder" ]; then
        rm -rf "$temp_folder"
    fi

    # Create a temporary folder for chunked files
    mkdir -p "$temp_folder"

    # Print the mandatory incident count from the report
    mandatory_count=$(jq -r '.stats.charts.severity.Mandatory' "$input_file")
    echo "Found $mandatory_count mandatory incidents."

    # Step 1: Filter the rules to only keep severity=="Mandatory"
    mandatory_rules=$(jq -r '.rules | to_entries[] | select(.value.severity == "Mandatory") | .key' $input_file)

    # Convert the mandatory_rules to a JSON array
    mandatory_rules_array=$(echo "$mandatory_rules" | jq -R -s -c 'split("\n")[:-1]')

    # Print the mandatory_rules_array
    # echo "Mandatory rules: $mandatory_rules_array"

    # Step 2: For each item under projects, filter its ruleInstances where ruleId are in the set from #1
    # Assign a unique number ID (starting from 0) to each filtered ruleInstance and place it inside the ruleInstance object
    filtered_rule_instances=$(jq --argjson mandatory_rules "$mandatory_rules_array" '
    .projects[] | .ruleInstances | map(select(.ruleId as $ruleId | $mandatory_rules | index($ruleId) != null)) | to_entries | map(.value + {id: .key | tonumber})
    ' $input_file)

    # Hack: Just take the first 200 for demo (to avoid long process time)
    filtered_rule_instances=$(echo "$filtered_rule_instances" | jq '.[:200]')

    # Step 3: Split the filtered ruleInstances into chunks of 50 elements each
    echo "$filtered_rule_instances" | jq -c '[_nwise(50)]' | jq -c '.[]' | while IFS= read -r chunk; do
        # Generate a unique filename for each chunk
        chunk_file="$temp_folder/chunk_$(date +%s%N).json"
        echo "$chunk" | jq '.' > "$chunk_file"
        echo "Created chunk file: $chunk_file"
    done
    echo "Filtered ruleInstances have been split into chunks and saved in the '$temp_folder' folder."

    # Step 4: For each chunk, run the command
    chunk_file=$(find "$temp_folder" -maxdepth 1 -type f -name '*.json' -print -quit)
    echo "Processing $chunk_file"
    export temp_folder
    cp $chunk_file currentchunk.json
    rm $chunk_file
    # Isolate aider's IO from the script's pipeline
    set -x  # Show command being executed
    aider --gitignore --architect --no-show-model-warnings --no-check-update --no-show-release-notes --yes-always --no-suggest-shell-commands --auto-test --test-cmd "$rootfolder/test.sh" --env-file=$envfile --file "$csfileloc" --edit-format diff --read currentchunk.json </dev/tty >/dev/tty
    set +x
    
    # # Print the command (for debugging purposes)
    # echo "Running command: $cmd"

    # # Execute the command
    # eval $cmd

    # Clean up the temporary folder
    rm -rf "$temp_folder"
    unset temp_folder
    unset dir
    cd $rootfolder
done