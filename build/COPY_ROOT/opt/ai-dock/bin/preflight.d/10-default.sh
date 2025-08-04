#!/bin/false
# This file will be sourced in init.sh

function preflight_main() {
    preflight_fix_runpod_micromamba_paths
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

function preflight_fix_runpod_micromamba_paths() {
    # Only create RunPod compatibility links if we're likely on RunPod
    if [[ -n "$RUNPOD_EXPECTED_MAMBA_ROOT" && -n "$RUNPOD_EXPECTED_CONDA_PREFIX" ]]; then
        printf "Setting up RunPod micromamba compatibility...\n"
        
        # Find where micromamba actually created the environments
        ACTUAL_WEBUI_ENV=""
        ACTUAL_JUPYTER_ENV=""
        ACTUAL_MAMBA_ROOT=""
        
        # Search for webui environment in common locations
        for search_path in "/opt/micromamba/envs/webui" "/usr/local/micromamba/envs/webui" "/opt/conda/envs/webui"; do
            if [[ -d "$search_path" && -f "$search_path/bin/python" ]]; then
                ACTUAL_WEBUI_ENV="$search_path"
                ACTUAL_MAMBA_ROOT="$(dirname $(dirname $search_path))"
                printf "Found webui environment at: $ACTUAL_WEBUI_ENV\n"
                break
            fi
        done
        
        # Search for jupyter environment
        for search_path in "/opt/micromamba/envs/jupyter" "/usr/local/micromamba/envs/jupyter" "/opt/conda/envs/jupyter"; do
            if [[ -d "$search_path" && -f "$search_path/bin/jupyter" ]]; then
                ACTUAL_JUPYTER_ENV="$search_path"
                printf "Found jupyter environment at: $ACTUAL_JUPYTER_ENV\n"
                break
            fi
        done
        
        # Create directory structure for expected paths
        mkdir -p "$(dirname $RUNPOD_EXPECTED_MAMBA_ROOT)"
        
        # Create symlink for root micromamba directory
        if [[ -n "$ACTUAL_MAMBA_ROOT" && -d "$ACTUAL_MAMBA_ROOT" ]]; then
            if [[ ! -e "$RUNPOD_EXPECTED_MAMBA_ROOT" ]]; then
                ln -sf "$ACTUAL_MAMBA_ROOT" "$RUNPOD_EXPECTED_MAMBA_ROOT"
                printf "Created symlink: $RUNPOD_EXPECTED_MAMBA_ROOT -> $ACTUAL_MAMBA_ROOT\n"
            fi
        fi
        
        # Create individual environment symlinks if needed
        if [[ -n "$ACTUAL_WEBUI_ENV" ]]; then
            mkdir -p "$(dirname $RUNPOD_EXPECTED_CONDA_PREFIX)"
            if [[ ! -e "$RUNPOD_EXPECTED_CONDA_PREFIX" ]]; then
                ln -sf "$ACTUAL_WEBUI_ENV" "$RUNPOD_EXPECTED_CONDA_PREFIX"
                printf "Created webui symlink: $RUNPOD_EXPECTED_CONDA_PREFIX -> $ACTUAL_WEBUI_ENV\n"
            fi
        fi
        
        if [[ -n "$ACTUAL_JUPYTER_ENV" ]]; then
            JUPYTER_EXPECTED="${RUNPOD_EXPECTED_MAMBA_ROOT}/envs/jupyter"
            mkdir -p "$(dirname $JUPYTER_EXPECTED)"
            if [[ ! -e "$JUPYTER_EXPECTED" ]]; then
                ln -sf "$ACTUAL_JUPYTER_ENV" "$JUPYTER_EXPECTED"
                printf "Created jupyter symlink: $JUPYTER_EXPECTED -> $ACTUAL_JUPYTER_ENV\n"
            fi
        fi
        
        # Verify the fix worked
        if [[ -f "$RUNPOD_EXPECTED_CONDA_PREFIX/bin/python" ]]; then
            printf "✓ RunPod micromamba compatibility setup successful\n"
        else
            printf "⚠ Warning: RunPod micromamba setup may not be complete\n"
        fi
    fi
}

function preflight_update_webui() {
    if [[ ${AUTO_UPDATE,,} != "false" ]]; then
        /opt/ai-dock/bin/update-webui.sh
    else
        printf "Skipping auto update (AUTO_UPDATE=false)"
    fi
}

preflight_main "$@"