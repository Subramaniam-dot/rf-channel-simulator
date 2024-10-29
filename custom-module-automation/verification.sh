#!/bin/bash

# Get module name from user input or default to 'customModule'
MODULE_NAME=${1:-customModule}
BLOCK_NAME="custom_file_writer"

# Function to detect GNU Radio installation paths and block locations
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
        
        # Print Python path
        echo "Python path:"
        python3 -c "import sys; print('\n'.join(sys.path))"
    else
        echo "Error: gnuradio-config-info not found. Is GNU Radio properly installed?"
        exit 1
    fi
}

# Function to check custom block installation thoroughly
verify_custom_block() {
    echo "Performing thorough block verification..."
    
    # List of potential block locations
    potential_paths=(
        "/usr/local/share/gnuradio/grc/blocks"
        "/usr/share/gnuradio/grc/blocks"
        "$HOME/.local/share/gnuradio/blocks"
        "$HOME/.gnuradio/blocks"
        "$PREFIX/share/gnuradio/grc/blocks"
        "$USERDIR/blocks"
        "/usr/local/lib/python3/dist-packages/gnuradio/grc/blocks"
        "/usr/lib/python3/dist-packages/gnuradio/grc/blocks"
    )
    
    BLOCK_FOUND=false
    
    echo "Searching for block files..."
    # Check for block file in all potential locations
    for path in "${potential_paths[@]}"; do
        if [ -f "$path/${MODULE_NAME}_${BLOCK_NAME}.block.yml" ]; then
            echo "Found block YAML at: $path/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
            echo "Content of block YAML:"
            cat "$path/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
            BLOCK_FOUND=true
        fi
    done
    
    # Check Python module installation
    echo "Checking Python module..."
    python3 -c "
import sys
print('Python path:')
print('\n'.join(sys.path))
print('\nTrying to import module:')
import $MODULE_NAME
print('Module found at:', $MODULE_NAME.__file__)
" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "Python module '$MODULE_NAME' is installed and importable"
    else
        echo "Warning: Python module '$MODULE_NAME' is not importable"
        echo "Trying to locate module files..."
        find /usr/local/lib/python3* -name "${MODULE_NAME}*" 2>/dev/null
        find /usr/lib/python3* -name "${MODULE_NAME}*" 2>/dev/null
    fi
    
    if [ "$BLOCK_FOUND" = false ]; then
        echo "Warning: Custom block YAML file not found in standard locations"
    fi
}

# Function to fix common issues
fix_common_issues() {
    echo "Attempting to fix common issues..."
    
    # Fix Python path
    PYTHON_SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
    echo "export PYTHONPATH=$PYTHONPATH:$PYTHON_SITE_PACKAGES" >> ~/.bashrc
    source ~/.bashrc
    
    # Fix permissions
    echo "Fixing permissions..."
    sudo chmod -R 755 /usr/local/share/gnuradio
    sudo chown -R $USER:$USER ~/.gnuradio
    
    # Rebuild GRC cache
    echo "Rebuilding GRC cache..."
    rm -rf ~/.gnuradio/grc-cache/*
    grcc --force
    
    # Update library cache
    echo "Updating library cache..."
    sudo ldconfig
    
    # Create symbolic links if needed
    if [ -d "/usr/local/share/gnuradio/grc/blocks" ]; then
        echo "Creating symbolic links..."
        sudo ln -sf /usr/local/share/gnuradio/grc/blocks/* /usr/share/gnuradio/grc/blocks/ 2>/dev/null
    fi
}

# Function to rebuild block cache
rebuild_block_cache() {
    echo "Rebuilding GNU Radio Companion block cache..."
    
    # Remove all GRC cache
    echo "Removing GRC cache..."
    rm -rf ~/.gnuradio/grc-cache/*
    rm -rf ~/.cache/gnuradio/*
    
    # Rebuild cache
    if command -v grcc >/dev/null 2>&1; then
        echo "Using grcc to rebuild cache..."
        grcc --force
        grcc --clean
    fi
    
    # Refresh user's GRC config
    if [ -f "$HOME/.gnuradio/config.conf" ]; then
        echo "Updating GRC config..."
        touch "$HOME/.gnuradio/config.conf"
    fi
}

# Main execution
echo "Starting thorough verification process..."
detect_gnuradio_paths
verify_custom_block

echo "Would you like to attempt fixing common issues? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    fix_common_issues
    rebuild_block_cache
fi

echo "Verification completed. Try these manual steps if block is still not visible:"
echo "1. Open a new terminal and run: 'gnuradio-companion'"
echo "2. In GNU Radio Companion:"
echo "   - Click 'Tools' -> 'Reload Blocks'"
echo "   - Check 'Help' -> 'Types' for your block"
echo "3. If still not visible, try these commands:"
echo "   sudo ldconfig"
echo "   grcc --force"
echo "   rm -rf ~/.gnuradio/grc-cache/*"
echo "4. Check these paths for your block:"
for path in "${potential_paths[@]}"; do
    echo "   $path"
done