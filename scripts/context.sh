#!/bin/bash

set -e

output_file="$(pwd)/context.txt"
recursive=false
verbose=false
strip_comments=false
extensions=()

logInfo() {
    local message="$@"
    echo "$message"
}

logVerbose() {
    local message="$@"
    if [ "$verbose" = true ]; then
        echo "$message"
    fi
}

logError() {
    local message="$@"
    echo "$message" >&2
}

add_separator() {
    local base_dir="$1"
    local file="$2"
    echo -e "\n\n=== file: ${base_dir}/${file} ===\n\n" >> "$output_file"
}

strip_comments_from_file() {
    local file="$1"
    sed -E 's://.*$::g; /\/\*/,/\*\//d; s:/\*.*\*/::g' "$file"
}

process_file() {
    local file="$1"
    local base_dir="$2"
    local relative_path="${file#$base_dir/}"
    add_separator "$base_dir" "$relative_path"
    if [ "$strip_comments" = true ]; then
        strip_comments_from_file "$file" >> "$output_file"
    else
        cat "$file" >> "$output_file"
    fi
    logVerbose "Processed file: ${base_dir}/${relative_path}"
    logInfo "Processed file: ${relative_path}"
}

process_directory() {
    local directory="$1"
    local base_dir="$2"

    logVerbose "Processing directory: $directory"
    logVerbose "Base directory: $base_dir"

    if [ ! -d "$directory" ]; then
        logError "Warning: Directory '$directory' does not exist. Skipping."
        return
    fi

    if [ "$recursive" = true ]; then
        if [ ${#extensions[@]} -eq 0 ]; then
            logVerbose "Finding all files in directory: $directory"
            find "$directory" -type f -print | while IFS= read -r file; do
                logVerbose "Found file: $file"
                process_file "$file" "$base_dir"
            done
        else
            logVerbose "Finding files with extensions: ${extensions[@]} in directory: $directory"
            find_command="find \"$directory\" -type f \\("
            for ext in "${extensions[@]}"; do
                find_command+=" -iname \"*.$ext\" -o"
            done
            find_command="${find_command% -o} \\) -print"
            logVerbose "Executing: $find_command"
            eval $find_command | while IFS= read -r file; do
                logVerbose "Found file: $file"
                process_file "$file" "$base_dir"
            done
        fi
    else
        for file in "$directory"/*; do
            if [ -f "$file" ]; then
                logVerbose "Found file: $file"
                process_file "$file" "$base_dir"
            fi
        done
    fi
}

open_output_file() {
    if command -v xdg-open &> /dev/null; then
        xdg-open "$1"
    elif command -v open &> /dev/null; then
        open "$1"
    else
        logError "Unable to open the file automatically. Please open it manually: $1"
    fi
}

main() {
    local directories=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--recursive)
                recursive=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -e|--extensions)
                extensions+=("${2#.}") # Remove leading dot if present
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -s|--strip-comments)
                strip_comments=true
                shift
                ;;
            *)
                directories+=("$1")
                shift
                ;;
        esac
    done

    if [ ${#directories[@]} -eq 0 ]; then
        logError "Usage: $0 [-r|--recursive] [-v|--verbose] [-e|--extensions ext1 ext2 ...] [-o|--output filename] [--strip-comments] <directory_or_file1> [directory_or_file2] [directory_or_file3] ..."
        exit 1
    fi

    logVerbose "Configured extensions: ${extensions[@]}"
    logVerbose "Recursive mode: $recursive"
    logVerbose "Strip comments: $strip_comments"
    logVerbose "Output file: $output_file"
    logVerbose "Directories or files to process: ${directories[@]}"

    > "$output_file"

    for item in "${directories[@]}"; do
        if [ -d "$item" ]; then
            base_dir="$(cd "$item" && pwd)"
            process_directory "$base_dir" "$base_dir"
        elif [ -f "$item" ]; then
            base_dir="$(dirname "$(cd "$(dirname "$item")" && pwd)")"
            process_file "$item" "$base_dir"
        else
            logError "Warning: '$item' is not a valid file or directory. Skipping."
        fi
    done

    logInfo "Concatenation complete. Output file: $output_file"
    open_output_file "$output_file"
}

main "$@"
