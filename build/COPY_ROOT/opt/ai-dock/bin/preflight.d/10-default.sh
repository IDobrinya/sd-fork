#!/bin/false
# This file will be sourced in init.sh

function preflight_main() {
    preflight_fix_micromamba_paths
    preflight_copy_notebook
    preflight_update_webui
    printf "%s" "${WEBUI_FLAGS}" > /etc/a1111_webui_flags.conf
}

function preflight_copy_notebook() {
    if micromamba env list | grep 'jupyter' > /dev/null 2>&1;  then
        if [[ ! -f "${WORKSPACE}webui.ipynb" ]]; then
            cp /usr/local/share/ai-dock/webui.ipynb ${WORKSPACE}
        fi
    fi
}

function preflight_fix_micromamba_paths() {
    printf "DEBUG: Starting micromamba path compatibility fix...\n"
    
    # Debug: Print current environment variables
    printf "DEBUG: MAMBA_ROOT_PREFIX=${MAMBA_ROOT_PREFIX:-not set}\n"
    printf "DEBUG: CONDA_PREFIX=${CONDA_PREFIX:-not set}\n"
    printf "DEBUG: MAMBA_DEFAULT_ENV=${MAMBA_DEFAULT_ENV:-not set}\n"
    
    # Find where micromamba actually is
    printf "DEBUG: Searching for micromamba installations...\n"
    if command -v micromamba >/dev/null 2>&1; then
        printf "DEBUG: micromamba command found at: $(which micromamba)\n"
        
        # Try to get micromamba info and extract root prefix
        printf "DEBUG: Trying to get micromamba info...\n"
        if MAMBA_INFO=$(micromamba info 2>/dev/null); then
            printf "DEBUG: micromamba info output:\n$MAMBA_INFO\n"
            
            # Extract root prefix from micromamba info
            ACTUAL_ROOT_PREFIX=$(echo "$MAMBA_INFO" | grep -E "^\s*(base environment|root environment|prefix)" | head -1 | sed 's/.*: *//' | sed 's/ .*//')
            if [[ -n "$ACTUAL_ROOT_PREFIX" && -d "$ACTUAL_ROOT_PREFIX" ]]; then
                printf "DEBUG: Detected actual micromamba root prefix: $ACTUAL_ROOT_PREFIX\n"
                
                # Update environment variables to actual paths
                export MAMBA_ROOT_PREFIX="$ACTUAL_ROOT_PREFIX"
                printf "DEBUG: Updated MAMBA_ROOT_PREFIX to: $MAMBA_ROOT_PREFIX\n"
            fi
        fi
        
        # List existing environments
        printf "DEBUG: Listing micromamba environments...\n"
        micromamba env list 2>&1 || true
    else
        printf "DEBUG: micromamba command not found\n"
    fi
    
    # Search for potential micromamba directories
    printf "DEBUG: Searching for micromamba directories...\n"
    find /opt -name "*micromamba*" -type d 2>/dev/null || true
    find /usr -name "*micromamba*" -type d 2>/dev/null || true
    find /root -name "*micromamba*" -type d 2>/dev/null || true
    
    # Search for webui environments specifically
    printf "DEBUG: Searching for 'webui' environments...\n"
    find / -path "*/envs/webui" -type d 2>/dev/null | head -5 || true
    find / -path "*/envs/jupyter" -type d 2>/dev/null | head -5 || true
    
    # Create target directories
    printf "DEBUG: Creating target directory structure...\n"
    mkdir -p /workspace/environments/stable-diffusion-webui/micromamba/envs
    printf "DEBUG: Created /workspace/environments/stable-diffusion-webui/micromamba/envs\n"
    
    # Try to find and link actual environments
    FOUND_WEBUI=false
    FOUND_JUPYTER=false
    
    # Check common locations for webui environment, including detected root prefix
    SEARCH_PATHS=(
        "/opt/micromamba/envs/webui"
        "/usr/local/micromamba/envs/webui"
        "/root/micromamba/envs/webui"
        "/opt/conda/envs/webui"
        "/usr/local/conda/envs/webui"
    )
    
    # Add detected root prefix if available
    if [[ -n "$MAMBA_ROOT_PREFIX" && "$MAMBA_ROOT_PREFIX" != "/workspace/environments/stable-diffusion-webui/micromamba" ]]; then
        SEARCH_PATHS+=("${MAMBA_ROOT_PREFIX}/envs/webui")
    fi
    
    for potential_path in "${SEARCH_PATHS[@]}"
    do
        if [[ -d "$potential_path" ]]; then
            printf "DEBUG: Found webui environment at: $potential_path\n"
            rm -f /workspace/environments/stable-diffusion-webui/micromamba/envs/webui
            ln -sf "$potential_path" /workspace/environments/stable-diffusion-webui/micromamba/envs/webui
            printf "Created symlink: /workspace/environments/stable-diffusion-webui/micromamba/envs/webui -> $potential_path\n"
            FOUND_WEBUI=true
            break
        fi
    done
    
    # Check common locations for jupyter environment, including detected root prefix
    JUPYTER_SEARCH_PATHS=(
        "/opt/micromamba/envs/jupyter"
        "/usr/local/micromamba/envs/jupyter"
        "/root/micromamba/envs/jupyter"
        "/opt/conda/envs/jupyter"
        "/usr/local/conda/envs/jupyter"
    )
    
    # Add detected root prefix if available
    if [[ -n "$MAMBA_ROOT_PREFIX" && "$MAMBA_ROOT_PREFIX" != "/workspace/environments/stable-diffusion-webui/micromamba" ]]; then
        JUPYTER_SEARCH_PATHS+=("${MAMBA_ROOT_PREFIX}/envs/jupyter")
    fi
    
    for potential_path in "${JUPYTER_SEARCH_PATHS[@]}"
    do
        if [[ -d "$potential_path" ]]; then
            printf "DEBUG: Found jupyter environment at: $potential_path\n"
            rm -f /workspace/environments/stable-diffusion-webui/micromamba/envs/jupyter
            ln -sf "$potential_path" /workspace/environments/stable-diffusion-webui/micromamba/envs/jupyter
            printf "Created symlink: /workspace/environments/stable-diffusion-webui/micromamba/envs/jupyter -> $potential_path\n"
            FOUND_JUPYTER=true
            break
        fi
    done
    
    # If environments not found, but they should exist in the expected location, don't create dummies
    if [[ "$FOUND_WEBUI" == "false" ]]; then
        if [[ -d "/workspace/environments/stable-diffusion-webui/micromamba/envs/webui" && -f "/workspace/environments/stable-diffusion-webui/micromamba/envs/webui/bin/python" ]]; then
            printf "DEBUG: webui environment directory already exists at expected location with Python\n"
        elif [[ -d "/workspace/environments/stable-diffusion-webui/micromamba/envs/webui" ]]; then
            printf "WARNING: webui environment exists but Python not found - this is expected if environment is being built\n"
        else
            printf "WARNING: webui environment not found, creating dummy directory\n"
            mkdir -p /workspace/environments/stable-diffusion-webui/micromamba/envs/webui
        fi
    fi
    
    if [[ "$FOUND_JUPYTER" == "false" ]]; then
        if [[ -d "/workspace/environments/stable-diffusion-webui/micromamba/envs/jupyter" ]]; then
            printf "DEBUG: jupyter environment directory already exists at expected location\n"
        else
            printf "WARNING: jupyter environment not found, creating dummy directory\n"
            mkdir -p /workspace/environments/stable-diffusion-webui/micromamba/envs/jupyter
        fi
    fi
    
    # Create root micromamba symlink if needed
    for potential_root in \
        "/opt/micromamba" \
        "/usr/local/micromamba" \
        "/root/micromamba" \
        "/opt/conda" \
        "/usr/local/conda"
    do
        if [[ -d "$potential_root" && ! -L /workspace/environments/stable-diffusion-webui/micromamba && ! -d /workspace/environments/stable-diffusion-webui/micromamba ]]; then
            printf "DEBUG: Found micromamba root at: $potential_root\n"
            rm -rf /workspace/environments/stable-diffusion-webui/micromamba
            ln -sf "$potential_root" /workspace/environments/stable-diffusion-webui/micromamba
            printf "Created root symlink: /workspace/environments/stable-diffusion-webui/micromamba -> $potential_root\n"
            break
        fi
    done
    
    # Final verification and testing
    printf "DEBUG: Final verification of created paths:\n"
    if [[ -d /workspace/environments/stable-diffusion-webui/micromamba/envs ]]; then
        ls -la /workspace/environments/stable-diffusion-webui/micromamba/envs/ 2>/dev/null || printf "DEBUG: envs directory not accessible\n"
        
        # Test if the webui environment is accessible
        if [[ -d /workspace/environments/stable-diffusion-webui/micromamba/envs/webui ]]; then
            printf "DEBUG: webui environment directory exists\n"
            if [[ -L /workspace/environments/stable-diffusion-webui/micromamba/envs/webui ]]; then
                LINK_TARGET=$(readlink /workspace/environments/stable-diffusion-webui/micromamba/envs/webui)
                printf "DEBUG: webui is a symlink pointing to: $LINK_TARGET\n"
                if [[ -d "$LINK_TARGET" ]]; then
                    printf "DEBUG: symlink target is valid\n"
                else
                    printf "WARNING: symlink target does not exist!\n"
                fi
            fi
        fi
        
        # Test if the jupyter environment is accessible  
        if [[ -d /workspace/environments/stable-diffusion-webui/micromamba/envs/jupyter ]]; then
            printf "DEBUG: jupyter environment directory exists\n"
            if [[ -L /workspace/environments/stable-diffusion-webui/micromamba/envs/jupyter ]]; then
                LINK_TARGET=$(readlink /workspace/environments/stable-diffusion-webui/micromamba/envs/jupyter)
                printf "DEBUG: jupyter is a symlink pointing to: $LINK_TARGET\n"
                if [[ -d "$LINK_TARGET" ]]; then
                    printf "DEBUG: symlink target is valid\n"
                else
                    printf "WARNING: symlink target does not exist!\n"
                fi
            fi
        fi
    else
        printf "DEBUG: envs directory was not created\n"
    fi
    
    # Test micromamba command with the environment
    printf "DEBUG: Testing micromamba access to webui environment...\n"
    if command -v micromamba >/dev/null 2>&1; then
        if micromamba run -n webui python --version 2>/dev/null; then
            printf "DEBUG: micromamba run -n webui works!\n"
        else
            printf "WARNING: micromamba run -n webui failed!\n"
        fi
    fi
    
    printf "DEBUG: Micromamba path compatibility fix completed\n"
}

function preflight_update_webui() {
    if [[ ${AUTO_UPDATE,,} != "false" ]]; then
        /opt/ai-dock/bin/update-webui.sh
    else
        printf "Skipping auto update (AUTO_UPDATE=false)"
    fi
}

preflight_main "$@"