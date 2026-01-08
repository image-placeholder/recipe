#!/usr/bin/env sh

set -e
# --- Jekyll Config Utility ---

# Load Jekyll YAML into prefixed shell variables
load_jekyll_config() {
    local config_file="${1:-_config.yml}"
    local prefix="_jekyll_"
    
    if [ ! -f "$config_file" ]; then
        printf "[\033[31mERROR\033[0m] %s not found.\n" "$config_file" >&2
        return 1
    fi

    if ! command -v yq >/dev/null 2>&1; then
        printf "[\033[31mERROR\033[0m] 'yq' (Mike Farah version) is required.\n" >&2
        return 1
    fi

    # Parse, prefix, and load
    eval "$(yq -o=shell "$config_file" | sed "s/^/${prefix}/")"
    printf "[\033[32mSUCCESS\033[0m] Variables loaded with prefix: %s\n" "$prefix"
}

# Remove all loaded Jekyll variables from memory
cleanup_jekyll_config() {
    local prefix="_jekyll_"
    
    # Get a list of all variable names starting with the prefix and unset them
    # 'set' lists variables; 'cut' gets the name before the '='
    for var in $(set | grep "^${prefix}" | cut -d'=' -f1); do
        unset "$var"
    done
    
    printf "[\033[34mCLEANUP\033[0m] All %s* variables have been unset.\n" "$prefix"
}
