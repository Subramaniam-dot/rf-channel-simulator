#!/bin/bash

# Get module name from user input or default to 'customModule'
MODULE_NAME=${1:-customModule}
BLOCK_NAME="custom_file_writer"

# Function to detect GNU Radio installation paths
detect_gnuradio_paths() {
    echo "Detecting GNU Radio paths..."
    
    if command -v gnuradio-config-info >/dev/null 2>&1; then
        PREFIX=$(gnuradio-config-info --prefix)
        USERDIR=$(gnuradio-config-info --userdir)
        PREFS=$(gnuradio-config-info --prefs)
        BLOCKS_PATH=$(gnuradio-config-info --prefix)/share/gnuradio/grc/blocks
        echo "Found GNU Radio paths:"
        echo "Prefix: $PREFIX"
        echo "User directory: $USERDIR"
        echo "Blocks Path: $BLOCKS_PATH"
    else
        echo "Error: gnuradio-config-info not found. Is GNU Radio properly installed?"
        exit 1
    fi
}

# Function to check custom block installation
verify_custom_block() {
    echo "Verifying custom block installation..."
    
    # List of potential block locations
    potential_paths=(
        "/usr/local/share/gnuradio/grc/blocks"
        "/usr/share/gnuradio/grc/blocks"
        "$HOME/.local/share/gnuradio/blocks"
        "$HOME/.gnuradio/blocks"
        "$PREFIX/share/gnuradio/grc/blocks"
        "$USERDIR/blocks"
    )
    
    BLOCK_FOUND=false
    
    # Check for block file in all potential locations
    for path in "${potential_paths[@]}"; do
        if [ -f "$path/${MODULE_NAME}_${BLOCK_NAME}.block.yml" ]; then
            echo "Found block file at: $path/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
            BLOCK_FOUND=true
            break
        fi
    done
    
    # Check Python module installation
    python3 -c "import $MODULE_NAME" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "Python module '$MODULE_NAME' is installed and importable"
    else
        echo "Warning: Python module '$MODULE_NAME' is not importable"
    fi
    
    if [ "$BLOCK_FOUND" = false ]; then
        echo "Warning: Custom block YAML file not found in standard locations"
    fi
}

# Function to rebuild block cache
rebuild_block_cache() {
    echo "Rebuilding GNU Radio Companion block cache..."
    
    # Try different cache rebuild commands
    if command -v grcc >/dev/null 2>&1; then
        echo "Using grcc to rebuild cache..."
        grcc --force
    fi
    
    # Refresh user's GRC config
    if [ -f "$HOME/.gnuradio/config.conf" ]; then
        echo "Updating GRC config..."
        touch "$HOME/.gnuradio/config.conf"
    fi
    
    # Clear any existing GRC cache
    if [ -d "$HOME/.gnuradio/grc-cache" ]; then
        echo "Clearing GRC cache..."
        rm -rf "$HOME/.gnuradio/grc-cache"
    fi
}

# Function to launch GNU Radio Companion
launch_grc() {
    echo "Launching GNU Radio Companion..."
    
    # Check if GRC is available
    if ! command -v gnuradio-companion >/dev/null 2>&1; then
        echo "Error: GNU Radio Companion not found"
        exit 1
    fi
    
    # Create a test flowgraph to verify block
    TEST_DIR="/tmp/grc_test_${MODULE_NAME}"
    mkdir -p "$TEST_DIR"
    
    cat > "$TEST_DIR/test_${MODULE_NAME}.grc" << EOL
{
  "metadata": {
    "version": "3.10.7.0",
    "file_format": 1
  },
  "options": {
    "parameters": {
      "author": "",
      "catch_exceptions": "True",
      "category": "[GRC Hier Blocks]",
      "cmake_opt": "",
      "comment": "",
      "copyright": "",
      "description": "",
      "gen_cmake": "On",
      "gen_linking": "dynamic",
      "generate_options": "qt_gui",
      "hier_block_src_path": ".:",
      "id": "test_${MODULE_NAME}",
      "max_nouts": "0",
      "output_language": "python",
      "placement": [
        "0",
        "0"
      ],
      "qt_qss_theme": "",
      "realtime_scheduling": "",
      "run": "True",
      "run_command": "{python} -u {filename}",
      "run_options": "prompt",
      "sizing_mode": "fixed",
      "thread_safe_setters": "",
      "title": "Test ${MODULE_NAME}"
    },
    "states": {
      "bus_sink": false,
      "bus_source": false,
      "bus_structure": null,
      "coordinate": [
        8,
        8
      ],
      "rotation": 0,
      "state": "enabled"
    }
  }
}
EOL

    echo "Created test flowgraph at: $TEST_DIR/test_${MODULE_NAME}.grc"
    echo "Launching GNU Radio Companion..."
    
    # Launch GRC with the test flowgraph
    gnuradio-companion "$TEST_DIR/test_${MODULE_NAME}.grc" &
    
    echo "Tips for verifying the custom block:"
    echo "1. Look for '$MODULE_NAME' in the block list (right side panel)"
    echo "2. Search for '$BLOCK_NAME' in the search box"
    echo "3. The block should appear under the custom category"
    echo "4. If the block is not visible:"
    echo "   - Click 'Reload Blocks' in the GRC menu"
    echo "   - Check the console output for any errors"
    echo "   - Verify the module installation path"
}

# Main execution
echo "Verifying and launching GNU Radio Companion with custom block..."
detect_gnuradio_paths
verify_custom_block
rebuild_block_cache
launch_grc

echo "Script completed. Check GNU Radio Companion window for the custom block."
echo "If the block is not visible, try these commands manually:"
echo "1. sudo ldconfig"
echo "2. grcc --force"
echo "3. restart gnuradio-companion"