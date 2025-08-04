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
    # Debug environment variables first
    printf "DEBUG: Checking RunPod environment variables...\n"
    printf "  RUNPOD_EXPECTED_MAMBA_ROOT='%s'\n" "${RUNPOD_EXPECTED_MAMBA_ROOT:-[not set]}"
    printf "  RUNPOD_EXPECTED_CONDA_PREFIX='%s'\n" "${RUNPOD_EXPECTED_CONDA_PREFIX:-[not set]}"
    
    # Only create RunPod compatibility links if we're likely on RunPod
    if [[ -n "${RUNPOD_EXPECTED_MAMBA_ROOT:-}" && -n "${RUNPOD_EXPECTED_CONDA_PREFIX:-}" ]]; then
        printf "=== RunPod Micromamba Compatibility Setup ===\n"
        
        # Debug: Show what we're looking for
        printf "Expected paths:\n"
        printf "  MAMBA_ROOT: ${RUNPOD_EXPECTED_MAMBA_ROOT}\n"
        printf "  CONDA_PREFIX: ${RUNPOD_EXPECTED_CONDA_PREFIX}\n"
        
        # Debug: Check micromamba command and environments
        if command -v micromamba >/dev/null 2>&1; then
            printf "DEBUG: micromamba found at: $(which micromamba)\n"
            printf "DEBUG: Current environments:\n"
            micromamba env list 2>/dev/null || printf "  Could not list environments\n"
            
            # Get micromamba info to find actual root
            if MAMBA_INFO=$(micromamba info 2>/dev/null); then
                printf "DEBUG: micromamba info:\n"
                echo "$MAMBA_INFO" | head -10
                
                ACTUAL_ROOT=$(echo "$MAMBA_INFO" | grep -E "base environment" | head -1 | awk '{print $NF}')
                if [[ -n "$ACTUAL_ROOT" && -d "$ACTUAL_ROOT" ]]; then
                    printf "DEBUG: Detected actual mamba root: $ACTUAL_ROOT\n"
                fi
            fi
        else
            printf "DEBUG: micromamba command not found\n"
        fi
        
        # Search for environments with detailed logging
        ACTUAL_WEBUI_ENV=""
        ACTUAL_JUPYTER_ENV=""
        ACTUAL_MAMBA_ROOT=""
        
        printf "DEBUG: Searching for environments...\n"
        
        # Search in standard locations first (where real environments are)
        printf "DEBUG: Searching for actual working environments...\n"
        for search_path in "/opt/micromamba/envs/webui" "/usr/local/micromamba/envs/webui" "/opt/conda/envs/webui"; do
            printf "  Checking: $search_path\n"
            if [[ -d "$search_path" ]]; then
                printf "    Directory exists\n"
                # Check if it's a valid environment
                if [[ -d "$search_path/conda-meta" ]] || [[ -f "$search_path/pyvenv.cfg" ]] || [[ -f "$search_path/bin/python" ]] || [[ -f "$search_path/bin/python3" ]]; then
                    ACTUAL_WEBUI_ENV="$search_path"
                    ACTUAL_MAMBA_ROOT="$(dirname $(dirname $search_path))"
                    printf "    ✓ Found working webui environment: $ACTUAL_WEBUI_ENV\n"
                    break
                else
                    printf "    Directory exists but no Python/conda-meta found\n"
                    ls -la "$search_path/" 2>/dev/null | head -3 || printf "    Cannot list directory\n"
                fi
            else
                printf "    Directory does not exist\n"
            fi
        done
        
        # Try micromamba env list as backup
        if [[ -z "$ACTUAL_WEBUI_ENV" ]] && command -v micromamba >/dev/null 2>&1; then
            printf "DEBUG: Trying micromamba env list as backup...\n"
            ENV_LIST=$(micromamba env list 2>/dev/null | grep -E "^\s*webui\s+" | awk '{print $NF}')
            if [[ -n "$ENV_LIST" ]] && [[ -d "$ENV_LIST" ]]; then
                if [[ -d "$ENV_LIST/conda-meta" ]] || [[ -f "$ENV_LIST/pyvenv.cfg" ]] || [[ -f "$ENV_LIST/bin/python" ]] || [[ -f "$ENV_LIST/bin/python3" ]]; then
                    ACTUAL_WEBUI_ENV="$ENV_LIST"
                    ACTUAL_MAMBA_ROOT="$(dirname $(dirname $ENV_LIST))"
                    printf "    ✓ Found webui environment via micromamba: $ACTUAL_WEBUI_ENV\n"
                fi
            fi
        fi
        
        # Search for jupyter environment in standard locations
        printf "DEBUG: Searching for jupyter environment...\n"
        for search_path in "/opt/micromamba/envs/jupyter" "/usr/local/micromamba/envs/jupyter" "/opt/conda/envs/jupyter"; do
            printf "  Checking: $search_path\n"
            if [[ -d "$search_path" ]]; then
                printf "    Directory exists\n"
                # Check for valid environment
                if [[ -f "$search_path/bin/jupyter" ]] || [[ -d "$search_path/conda-meta" ]]; then
                    ACTUAL_JUPYTER_ENV="$search_path"
                    printf "    ✓ Found working jupyter environment: $ACTUAL_JUPYTER_ENV\n"
                    break
                else
                    printf "    Directory exists but no jupyter binary or conda-meta found\n"
                fi
            else
                printf "    Directory does not exist\n"
            fi
        done
        
        # Try micromamba env list as backup
        if [[ -z "$ACTUAL_JUPYTER_ENV" ]] && command -v micromamba >/dev/null 2>&1; then
            printf "DEBUG: Trying micromamba for jupyter as backup...\n"
            JUPYTER_ENV_LIST=$(micromamba env list 2>/dev/null | grep -E "^\s*jupyter\s+" | awk '{print $NF}')
            if [[ -n "$JUPYTER_ENV_LIST" ]] && [[ -d "$JUPYTER_ENV_LIST" ]]; then
                if [[ -f "$JUPYTER_ENV_LIST/bin/jupyter" ]] || [[ -d "$JUPYTER_ENV_LIST/conda-meta" ]]; then
                    ACTUAL_JUPYTER_ENV="$JUPYTER_ENV_LIST"
                    printf "    ✓ Found jupyter environment via micromamba: $ACTUAL_JUPYTER_ENV\n"
                fi
            fi
        fi
        
        # Create directory structure for expected paths
        printf "Creating target directory structure...\n"
        mkdir -p "$(dirname ${RUNPOD_EXPECTED_MAMBA_ROOT})"
        
        # Create symlinks
        if [[ -n "$ACTUAL_MAMBA_ROOT" && -d "$ACTUAL_MAMBA_ROOT" ]]; then
            if [[ ! -e "${RUNPOD_EXPECTED_MAMBA_ROOT}" ]]; then
                ln -sf "$ACTUAL_MAMBA_ROOT" "${RUNPOD_EXPECTED_MAMBA_ROOT}"
                printf "✓ Created root symlink: ${RUNPOD_EXPECTED_MAMBA_ROOT} -> $ACTUAL_MAMBA_ROOT\n"
            else
                printf "Root symlink already exists\n"
            fi
        else
            printf "⚠ No suitable mamba root found\n"
        fi
        
        if [[ -n "$ACTUAL_WEBUI_ENV" ]]; then
            mkdir -p "$(dirname ${RUNPOD_EXPECTED_CONDA_PREFIX})"
            if [[ ! -e "${RUNPOD_EXPECTED_CONDA_PREFIX}" ]]; then
                ln -sf "$ACTUAL_WEBUI_ENV" "${RUNPOD_EXPECTED_CONDA_PREFIX}"
                printf "✓ Created webui symlink: ${RUNPOD_EXPECTED_CONDA_PREFIX} -> $ACTUAL_WEBUI_ENV\n"
            else
                printf "Webui symlink already exists\n"
            fi
        else
            printf "⚠ No webui environment with Python found\n"
        fi
        
        if [[ -n "$ACTUAL_JUPYTER_ENV" ]]; then
            JUPYTER_EXPECTED="${RUNPOD_EXPECTED_MAMBA_ROOT}/envs/jupyter"
            mkdir -p "$(dirname ${JUPYTER_EXPECTED})"
            if [[ ! -e "${JUPYTER_EXPECTED}" ]]; then
                ln -sf "$ACTUAL_JUPYTER_ENV" "${JUPYTER_EXPECTED}"
                printf "✓ Created jupyter symlink: ${JUPYTER_EXPECTED} -> $ACTUAL_JUPYTER_ENV\n"
            fi
        fi
        
        # Final verification
        printf "=== Verification ===\n"
        
        # Check if symlink was created and points to valid environment
        if [[ -L "${RUNPOD_EXPECTED_CONDA_PREFIX}" ]] && [[ -d "${RUNPOD_EXPECTED_CONDA_PREFIX}" ]]; then
            printf "✓ Symlink created and points to valid directory\n"
            printf "  Link: ${RUNPOD_EXPECTED_CONDA_PREFIX} -> $(readlink ${RUNPOD_EXPECTED_CONDA_PREFIX})\n"
            
            # Try multiple python executable locations
            PYTHON_FOUND=false
            for python_path in "${RUNPOD_EXPECTED_CONDA_PREFIX}/bin/python" "${RUNPOD_EXPECTED_CONDA_PREFIX}/bin/python3"; do
                if [[ -f "$python_path" ]]; then
                    PYTHON_VERSION=$("$python_path" --version 2>&1)
                    printf "✓ SUCCESS: Python found at $python_path - $PYTHON_VERSION\n"
                    PYTHON_FOUND=true
                    break
                fi
            done
            
            if [[ "$PYTHON_FOUND" == "false" ]]; then
                printf "⚠ WARNING: No Python executable found in expected locations\n"
                printf "  Contents of bin directory:\n"
                ls -la "${RUNPOD_EXPECTED_CONDA_PREFIX}/bin/" 2>/dev/null | head -10 || printf "  Cannot list bin directory\n"
            fi
            
            # Test micromamba run command
            if micromamba run -n webui python --version >/dev/null 2>&1; then
                printf "✓ SUCCESS: micromamba run -n webui works\n"
            else
                printf "⚠ WARNING: micromamba run -n webui failed\n"
                # Try alternative test
                if micromamba run -n webui python3 --version >/dev/null 2>&1; then
                    printf "✓ SUCCESS: micromamba run -n webui python3 works\n"
                fi
            fi
        elif [[ -d "${RUNPOD_EXPECTED_CONDA_PREFIX}" ]]; then
            printf "✓ Directory exists at expected path\n"
        else
            printf "❌ FAILURE: Expected environment not found\n"
            printf "Expected: ${RUNPOD_EXPECTED_CONDA_PREFIX}\n"
        fi
        printf "===========================================\n"
    else
        printf "⚠ Skipping RunPod micromamba setup - required environment variables not set\n"
        printf "  This is normal if not running on RunPod\n"
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