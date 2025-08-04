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
    printf "Creating micromamba path compatibility links...\n"
    
    # Create workspace directories if they don't exist
    mkdir -p /workspace/environments/stable-diffusion-webui/micromamba/envs
    
    # Check if actual micromamba envs exist and create symlinks
    if [[ -d /opt/micromamba/envs/webui ]]; then
        # Remove existing symlink if it exists
        rm -f /workspace/environments/stable-diffusion-webui/micromamba/envs/webui
        # Create symlink to actual environment
        ln -sf /opt/micromamba/envs/webui /workspace/environments/stable-diffusion-webui/micromamba/envs/webui
        printf "Created symlink: /workspace/environments/stable-diffusion-webui/micromamba/envs/webui -> /opt/micromamba/envs/webui\n"
    elif [[ -d "${MAMBA_ROOT_PREFIX}/envs/webui" && "${MAMBA_ROOT_PREFIX}" != "/workspace/environments/stable-diffusion-webui/micromamba" ]]; then
        # Remove existing symlink if it exists
        rm -f /workspace/environments/stable-diffusion-webui/micromamba/envs/webui
        # Create symlink to environment in MAMBA_ROOT_PREFIX
        ln -sf "${MAMBA_ROOT_PREFIX}/envs/webui" /workspace/environments/stable-diffusion-webui/micromamba/envs/webui
        printf "Created symlink: /workspace/environments/stable-diffusion-webui/micromamba/envs/webui -> ${MAMBA_ROOT_PREFIX}/envs/webui\n"
    fi
    
    # Also create a symlink for the root prefix if needed
    if [[ -d /opt/micromamba && ! -L /workspace/environments/stable-diffusion-webui/micromamba && ! -d /workspace/environments/stable-diffusion-webui/micromamba ]]; then
        rm -rf /workspace/environments/stable-diffusion-webui/micromamba
        ln -sf /opt/micromamba /workspace/environments/stable-diffusion-webui/micromamba
        printf "Created symlink: /workspace/environments/stable-diffusion-webui/micromamba -> /opt/micromamba\n"
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