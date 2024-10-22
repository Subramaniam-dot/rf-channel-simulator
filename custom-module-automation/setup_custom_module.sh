#!/bin/bash

# Get the current working directory (where the script, Python, and YAML files are located)
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Get module name from user input or default to 'customModule'
MODULE_NAME=${1:-customModule}
BLOCK_NAME="custom_file_writer"

# Define the parent directory for modules
PARENT_DIR="$HOME/gnuradio_modules"
MODULE_DIR="$PARENT_DIR/gr-$MODULE_NAME"
GRC_PATH="$MODULE_DIR/grc"
PYTHON_PATH="$MODULE_DIR/python/$MODULE_NAME"
BACKUP_DIR="$HOME/backup_gr_$MODULE_NAME_$(date +%Y%m%d_%H%M%S)"

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
        if [ "$(uname)" == "Darwin" ]; then
            brew install cmake
        else
            sudo apt install -y cmake
        fi
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
        echo "Skipping module creation since it already exists."
    else
        echo "Creating new OOT module..."
        mkdir -p "$PARENT_DIR"
        gr_modtool newmod "$MODULE_NAME" --destdir="$PARENT_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create module. Make sure GNU Radio and gr_modtool are properly installed."
            exit 1
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
        cp "$SCRIPT_DIR/$BLOCK_NAME.py" "$PYTHON_PATH/$BLOCK_NAME.py"
    else
        echo "Error: Python file not found. Ensure $BLOCK_NAME.py exists in the script directory."
        exit 1
    fi
}

# Function to copy the GRC block YAML file
copy_grc_yaml() {
    if [ -f "$SCRIPT_DIR/$BLOCK_NAME.block.yml" ]; then
        echo "Copying GRC YAML block description from $SCRIPT_DIR..."
        cp "$SCRIPT_DIR/$BLOCK_NAME.block.yml" "$GRC_PATH/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
    else
        echo "Error: YAML file not found. Ensure $BLOCK_NAME.block.yml exists in the script directory."
        exit 1
    fi
}

build_and_install() {
    echo "Building and installing the module..."

    # Remove the build directory if it exists to avoid permission issues
    if [ -d "$MODULE_DIR/build" ]; then
        rm -rf "$MODULE_DIR/build"
    fi

    mkdir -p "$MODULE_DIR/build"
    cd "$MODULE_DIR/build" || exit

    # Use the Python executable from the current environment
    PYTHON_EXECUTABLE=$(which python)

    # If using a virtual environment like radioconda, set the installation prefix
    if [ -n "$CONDA_PREFIX" ]; then
        INSTALL_PREFIX="$CONDA_PREFIX"
    else
        INSTALL_PREFIX="/usr/local"
    fi

    cmake .. -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" -DPYTHON_EXECUTABLE="$PYTHON_EXECUTABLE"
    make
    make install

    # Update shared library cache on Linux systems
    if [ "$(uname)" != "Darwin" ]; then
        sudo ldconfig
    fi
}


# Execute functions in order
install_dependencies
create_or_backup_module
add_custom_block
copy_python_block
copy_grc_yaml
build_and_install

echo "Custom module setup or update completed successfully!"
