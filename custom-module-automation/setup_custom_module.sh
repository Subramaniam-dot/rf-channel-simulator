#!/bin/bash

# Get the current timestamp for log file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="gnuradio_module_setup_$TIMESTAMP.log"

# Function to log messages
log_message() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$message" | tee -a "$LOG_FILE"
}

# Start logging
log_message "Starting GNU Radio module setup and verification process"
log_message "Log file created at: $LOG_FILE"

# Get the current working directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
log_message "Script directory: $SCRIPT_DIR"

# Get module name from user input or default to 'customModule'
MODULE_NAME=${1:-customModule}
BLOCK_NAME="custom_file_writer"
log_message "Module name: $MODULE_NAME"
log_message "Block name: $BLOCK_NAME"

# Function to detect GNU Radio installation paths
detect_gnuradio_paths() {
    log_message "Detecting GNU Radio installation paths..."
    
    if command -v gnuradio-config-info >/dev/null 2>&1; then
        PREFIX=$(gnuradio-config-info --prefix)
        USERDIR=$(gnuradio-config-info --userdir)
        PREFS=$(gnuradio-config-info --prefs)
        BLOCKS_PATH=$(gnuradio-config-info --prefix)/share/gnuradio/grc/blocks
        
        log_message "Found GNU Radio paths:"
        log_message "Prefix: $PREFIX"
        log_message "User directory: $USERDIR"
        log_message "Blocks Path: $BLOCKS_PATH"
        
        # Print Python path
        log_message "Python path:"
        python3 -c "import sys; print('\n'.join(sys.path))" 2>&1 | tee -a "$LOG_FILE"
    else
        log_message "ERROR: gnuradio-config-info not found. Is GNU Radio properly installed?"
        exit 1
    fi
    
    # Search common installation locations
    potential_paths=(
        "/usr/local/share/gnuradio"
        "/usr/share/gnuradio"
        "$HOME/.local/share/gnuradio"
        "$HOME/.gnuradio"
        "/opt/gnuradio"
        "$PREFIX/share/gnuradio"
    )
    
    # Find first existing directory that contains gnuradio
    for path in "${potential_paths[@]}"; do
        if [ -d "$path" ]; then
            log_message "Found GNU Radio directory at: $path"
            PARENT_DIR="$path"
            break
        fi
    done
    
    if [ -z "$PARENT_DIR" ]; then
        log_message "WARNING: Could not find GNU Radio directory. Using default path."
        PARENT_DIR="/usr/local/share/gnuradio"
    fi
    
    # Set derived paths
    MODULE_DIR="$PARENT_DIR/gr-$MODULE_NAME"
    GRC_PATH="$MODULE_DIR/grc"
    PYTHON_PATH="$MODULE_DIR/python/$MODULE_NAME"
    
    log_message "Using paths:"
    log_message "Parent Directory: $PARENT_DIR"
    log_message "Module Directory: $MODULE_DIR"
    log_message "GRC Path: $GRC_PATH"
    log_message "Python Path: $PYTHON_PATH"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install dependencies
install_dependencies() {
    log_message "Checking and installing dependencies..."

    # Check GNU Radio
    if ! command_exists gnuradio-companion; then
        log_message "ERROR: GNU Radio not found. Please install GNU Radio first."
        exit 1
    else
        log_message "GNU Radio is installed."
        log_message "GNU Radio version: $(gnuradio-config-info --version)"
    fi

    # Check CMake
    if ! command_exists cmake; then
        log_message "Installing CMake..."
        sudo apt install -y cmake 2>&1 | tee -a "$LOG_FILE"
    else
        log_message "CMake is installed."
        log_message "CMake version: $(cmake --version | head -n1)"
    fi

    if ! command_exists gr_modtool; then
        log_message "ERROR: gr_modtool not found. Please ensure GNU Radio is properly installed."
        exit 1
    else
        log_message "gr_modtool is available."
    fi
}

# Function to create or backup module
create_or_backup_module() {
    log_message "Creating or backing up module..."
    
    if [ -d "$MODULE_DIR" ]; then
        log_message "Existing module found at $MODULE_DIR"
        BACKUP_DIR="$HOME/backup_gr_${MODULE_NAME}_$TIMESTAMP"
        log_message "Creating backup at $BACKUP_DIR"
        cp -r "$MODULE_DIR" "$BACKUP_DIR" 2>&1 | tee -a "$LOG_FILE"
    else
        log_message "Creating new OOT module..."
        sudo mkdir -p "$PARENT_DIR"
        sudo chown $USER:$USER "$PARENT_DIR"
        
        # Try different module creation methods
        if ! gr_modtool newmod "$MODULE_NAME" --directory="$PARENT_DIR" 2>&1 | tee -a "$LOG_FILE"; then
            log_message "Trying alternative module creation method..."
            if ! gr_modtool newmod "$MODULE_NAME" --srcdir="$PARENT_DIR" 2>&1 | tee -a "$LOG_FILE"; then
                if ! gr_modtool newmod "$MODULE_NAME" 2>&1 | tee -a "$LOG_FILE"; then
                    log_message "ERROR: Failed to create module"
                    exit 1
                fi
                sudo mv "gr-$MODULE_NAME" "$PARENT_DIR/" 2>/dev/null || true
            fi
        fi
    fi
    cd "$MODULE_DIR" || exit
}

# Function to add and configure custom block
add_custom_block() {
    log_message "Adding custom block..."
    if [ ! -f "$PYTHON_PATH/$BLOCK_NAME.py" ]; then
        gr_modtool add "$BLOCK_NAME" --block-type=sink --lang=python 2>&1 | tee -a "$LOG_FILE"
    else
        log_message "Custom block already exists."
    fi
}

# Function to copy block files
copy_block_files() {
    log_message "Copying block files..."
    
    # Copy Python file
    if [ -f "$SCRIPT_DIR/$BLOCK_NAME.py" ]; then
        sudo cp "$SCRIPT_DIR/$BLOCK_NAME.py" "$PYTHON_PATH/$BLOCK_NAME.py"
        sudo chown $USER:$USER "$PYTHON_PATH/$BLOCK_NAME.py"
        log_message "Copied Python block file"
    else
        log_message "ERROR: Python file not found at $SCRIPT_DIR/$BLOCK_NAME.py"
        exit 1
    fi
    
    # Copy YAML file
    if [ -f "$SCRIPT_DIR/$BLOCK_NAME.block.yml" ]; then
        sudo cp "$SCRIPT_DIR/$BLOCK_NAME.block.yml" "$GRC_PATH/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
        sudo chown $USER:$USER "$GRC_PATH/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
        log_message "Copied YAML block file"
    else
        log_message "ERROR: YAML file not found at $SCRIPT_DIR/$BLOCK_NAME.block.yml"
        exit 1
    fi
}

# Function to build and install
build_and_install() {
    log_message "Building and installing module..."
    
    # Clean build directory
    if [ -d "$MODULE_DIR/build" ]; then
        sudo rm -rf "$MODULE_DIR/build"
    fi
    mkdir -p "$MODULE_DIR/build"
    cd "$MODULE_DIR/build" || exit
    
    PYTHON_EXECUTABLE=$(which python3)
    CMAKE_PREFIX=${PREFIX:-"/usr/local"}
    
    # Configure and build
    log_message "Running CMake..."
    cmake .. -DCMAKE_INSTALL_PREFIX="$CMAKE_PREFIX" -DPYTHON_EXECUTABLE="$PYTHON_EXECUTABLE" 2>&1 | tee -a "$LOG_FILE"
    
    log_message "Building..."
    make 2>&1 | tee -a "$LOG_FILE"
    
    log_message "Installing..."
    sudo make install 2>&1 | tee -a "$LOG_FILE"
    sudo ldconfig
    
    # Update block cache
    if command_exists grcc; then
        log_message "Updating GRC block cache..."
        grcc --force 2>&1 | tee -a "$LOG_FILE"
    fi
}

# Function to verify installation
verify_installation() {
    log_message "Verifying installation..."
    
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
    
    # Check all locations
    for path in "${potential_paths[@]}"; do
        if [ -f "$path/${MODULE_NAME}_${BLOCK_NAME}.block.yml" ]; then
            log_message "Found block YAML at: $path/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
            cat "$path/${MODULE_NAME}_${BLOCK_NAME}.block.yml" >> "$LOG_FILE"
        fi
    done
    
    # Verify Python module
    if python3 -c "import $MODULE_NAME" 2>/dev/null; then
        log_message "Python module '$MODULE_NAME' is importable"
    else
        log_message "WARNING: Python module '$MODULE_NAME' is not importable"
    fi
}

# Function to fix common issues
fix_common_issues() {
    log_message "Attempting to fix common issues..."
    
    # Update Python path
    PYTHON_SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
    echo "export PYTHONPATH=$PYTHONPATH:$PYTHON_SITE_PACKAGES" >> ~/.bashrc
    source ~/.bashrc
    
    # Fix permissions
    sudo chmod -R 755 /usr/local/share/gnuradio
    sudo chown -R $USER:$USER ~/.gnuradio
    
    # Clear and rebuild cache
    rm -rf ~/.gnuradio/grc-cache/*
    rm -rf ~/.cache/gnuradio/*
    grcc --force
    grcc --clean
    
    log_message "Common fixes applied"
}

# Main execution
{
    detect_gnuradio_paths
    install_dependencies
    create_or_backup_module
    add_custom_block
    copy_block_files
    build_and_install
    verify_installation
    fix_common_issues
    
    log_message "Installation and verification completed"
    log_message "Log file: $LOG_FILE"
    
    # Print final instructions
    log_message "Next steps:"
    log_message "1. Run: gnuradio-companion"
    log_message "2. Click 'Tools' -> 'Reload Blocks'"
    log_message "3. Search for '$BLOCK_NAME' in the blocks list"
    log_message "4. Check log file for details: $LOG_FILE"
} 2>&1 | tee -a "$LOG_FILE"

log_message "Script completed. Check $LOG_FILE for details."