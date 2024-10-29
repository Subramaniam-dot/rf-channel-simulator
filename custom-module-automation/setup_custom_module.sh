#!/bin/bash

# Get the current working directory (where the script, Python, and YAML files are located)
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Get module name from user input or default to 'customModule'
MODULE_NAME=${1:-customModule}
BLOCK_NAME="custom_file_writer"

# Function to detect GNU Radio installation paths
detect_gnuradio_paths() {
    echo "Detecting GNU Radio installation paths..."
    
    # Try to get paths using gnuradio-config-info
    if command -v gnuradio-config-info >/dev/null 2>&1; then
        PREFIX=$(gnuradio-config-info --prefix)
        USERDIR=$(gnuradio-config-info --userdir)
        PREFS=$(gnuradio-config-info --prefs)
        echo "Found GNU Radio paths:"
        echo "Prefix: $PREFIX"
        echo "User directory: $USERDIR"
        echo "Preferences: $PREFS"
    else
        echo "gnuradio-config-info not found. Searching for installation..."
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
            echo "Found GNU Radio directory at: $path"
            PARENT_DIR="$path"
            break
        fi
    done
    
    # If no directory found, use default
    if [ -z "$PARENT_DIR" ]; then
        echo "Warning: Could not find GNU Radio directory. Using default path."
        PARENT_DIR="/usr/local/share/gnuradio"
    fi
    
    # Check for existing blocks to confirm correct directory
    if [ -d "$PARENT_DIR/grc/blocks" ] || [ -d "$PARENT_DIR/blocks" ]; then
        echo "Confirmed GNU Radio blocks directory exists at: $PARENT_DIR"
    else
        echo "Warning: Selected directory may not be correct GNU Radio path"
    fi
    
    # Set derived paths
    MODULE_DIR="$PARENT_DIR/gr-$MODULE_NAME"
    GRC_PATH="$MODULE_DIR/grc"
    PYTHON_PATH="$MODULE_DIR/python/$MODULE_NAME"
    
    # Print final paths
    echo "Using the following paths:"
    echo "Parent Directory: $PARENT_DIR"
    echo "Module Directory: $MODULE_DIR"
    echo "GRC Path: $GRC_PATH"
    echo "Python Path: $PYTHON_PATH"
    
    # Ask for confirmation
    read -p "Are these paths correct? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled. Please specify correct path manually."
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install dependencies
install_dependencies() {
    echo "Checking and installing dependencies..."

    # Check GNU Radio
    if ! command_exists gnuradio-companion; then
        echo "GNU Radio not found. Please install GNU Radio before running this script."
        exit 1
    else
        echo "GNU Radio is already installed."
    fi

    # Check CMake
    if ! command_exists cmake; then
        echo "CMake not found. Installing..."
        sudo apt install -y cmake
    else
        echo "CMake is already installed."
    fi

    # Check Boost (assuming that GNU Radio installation provides Boost)
    if ! command_exists gr_modtool; then
        echo "gr_modtool not found. Please ensure GNU Radio is properly installed."
        exit 1
    else
        echo "gr_modtool is available."
    fi
}

# Function to create or backup the OOT module
create_or_backup_module() {
    if [ -d "$MODULE_DIR" ]; then
        echo "Existing module directory found at $MODULE_DIR."
        echo "Creating backup..."
        BACKUP_DIR="$HOME/backup_gr_${MODULE_NAME}_$(date +%Y%m%d_%H%M%S)"
        cp -r "$MODULE_DIR" "$BACKUP_DIR"
        echo "Backup created at $BACKUP_DIR"
    else
        echo "Creating new OOT module..."
        # Ensure parent directory exists and is writable
        sudo mkdir -p "$PARENT_DIR"
        sudo chown $USER:$USER "$PARENT_DIR"
        
        # Try different methods to create the module
        if ! gr_modtool newmod "$MODULE_NAME" --directory="$PARENT_DIR"; then
            echo "Trying alternative method..."
            if ! gr_modtool newmod "$MODULE_NAME" --srcdir="$PARENT_DIR"; then
                if ! gr_modtool newmod "$MODULE_NAME"; then
                    echo "Error: Failed to create module. Make sure GNU Radio and gr_modtool are properly installed."
                    exit 1
                fi
                # Move the module to the correct location if created in current directory
                sudo mv "gr-$MODULE_NAME" "$PARENT_DIR/" 2>/dev/null || true
            fi
        fi
    fi
    cd "$MODULE_DIR" || exit
}

# Function to add custom block
add_custom_block() {
    if [ ! -f "$PYTHON_PATH/$BLOCK_NAME.py" ]; then
        echo "Adding custom block..."
        gr_modtool add "$BLOCK_NAME" --block-type=sink --lang=python
        if [ $? -ne 0 ]; then
            echo "Error: Failed to add custom block."
            exit 1
        fi
    else
        echo "Custom block already exists."
    fi
}

# Function to copy custom Python block code
copy_python_block() {
    if [ -f "$SCRIPT_DIR/$BLOCK_NAME.py" ]; then
        echo "Copying custom Python block from $SCRIPT_DIR..."
        sudo cp "$SCRIPT_DIR/$BLOCK_NAME.py" "$PYTHON_PATH/$BLOCK_NAME.py"
        # Ensure proper permissions
        sudo chown $USER:$USER "$PYTHON_PATH/$BLOCK_NAME.py"
    else
        echo "Error: Python file not found. Ensure $BLOCK_NAME.py exists in the script directory."
        exit 1
    fi
}

# Function to copy the GRC block YAML file
copy_grc_yaml() {
    if [ -f "$SCRIPT_DIR/$BLOCK_NAME.block.yml" ]; then
        echo "Copying GRC YAML block description from $SCRIPT_DIR..."
        sudo cp "$SCRIPT_DIR/$BLOCK_NAME.block.yml" "$GRC_PATH/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
        # Ensure proper permissions
        sudo chown $USER:$USER "$GRC_PATH/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
    else
        echo "Error: YAML file not found. Ensure $BLOCK_NAME.block.yml exists in the script directory."
        exit 1
    fi
}

build_and_install() {
    echo "Building and installing the module..."

    # Remove the build directory if it exists to avoid permission issues
    if [ -d "$MODULE_DIR/build" ]; then
        sudo rm -rf "$MODULE_DIR/build"
    fi

    mkdir -p "$MODULE_DIR/build"
    cd "$MODULE_DIR/build" || exit

    # Use the Python executable from the current environment
    PYTHON_EXECUTABLE=$(which python3)

    # Set the installation prefix to the GNU Radio installation path
    CMAKE_PREFIX=$PREFIX
    if [ -z "$CMAKE_PREFIX" ]; then
        CMAKE_PREFIX="/usr/local"
    fi

    cmake .. -DCMAKE_INSTALL_PREFIX="$CMAKE_PREFIX" -DPYTHON_EXECUTABLE="$PYTHON_EXECUTABLE"
    make
    sudo make install
    sudo ldconfig

    echo "Updating GRC block cache..."
    if command_exists grcc; then
        grcc --force
    fi
}

# Function to verify installation
verify_installation() {
    echo "Verifying installation..."
    
    # Check if module directory exists
    if [ ! -d "$MODULE_DIR" ]; then
        echo "Warning: Module directory not found at $MODULE_DIR"
        return 1
    fi
    
    # Check if Python file exists
    if [ ! -f "$PYTHON_PATH/$BLOCK_NAME.py" ]; then
        echo "Warning: Python block file not found at $PYTHON_PATH/$BLOCK_NAME.py"
        return 1
    fi
    
    # Check if YAML file exists
    if [ ! -f "$GRC_PATH/${MODULE_NAME}_${BLOCK_NAME}.block.yml" ]; then
        echo "Warning: YAML block file not found at $GRC_PATH/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
        return 1
    fi
    
    echo "Installation verified successfully!"
    return 0
}

# Execute functions in order
detect_gnuradio_paths
install_dependencies
create_or_backup_module
add_custom_block
copy_python_block
copy_grc_yaml
build_and_install
verify_installation

if [ $? -eq 0 ]; then
    echo "Custom module setup completed successfully!"
    echo "You can now use the custom block in GNU Radio Companion."
    echo "Location: $MODULE_DIR"
else
    echo "Installation completed with warnings. Please check the messages above."
fi