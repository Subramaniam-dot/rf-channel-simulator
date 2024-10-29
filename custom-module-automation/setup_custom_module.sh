#!/bin/bash

# Get the current timestamp for log file
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="gnuradio_module_setup_$TIMESTAMP.log"
BACKUP_DIR="$HOME/gnuradio_backup_$TIMESTAMP"

# Text formatting
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to log messages
log_message() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$message" | tee -a "$LOG_FILE"
}

# Function to log success messages
log_success() {
    echo -e "${GREEN}${BOLD}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to log warning messages
log_warning() {
    echo -e "${YELLOW}${BOLD}[!]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    echo -e "${RED}${BOLD}[✗] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    echo "Check $LOG_FILE for details"
    exit 1
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        handle_error "Please do not run this script as root or with sudo"
    fi
}

# Start logging
log_message "Starting GNU Radio module setup and verification process"
log_message "Log file created at: $LOG_FILE"
mkdir -p "$BACKUP_DIR"

# Get the current working directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
log_message "Script directory: $SCRIPT_DIR"

# Get module name from user input or default to 'customModule'
MODULE_NAME=${1:-customModule}
BLOCK_NAME=${2:-custom_file_writer}
log_message "Module name: $MODULE_NAME"
log_message "Block name: $BLOCK_NAME"

# Define paths
PREFIX="/usr/local"
PARENT_DIR="$PREFIX/share/gnuradio"
MODULE_DIR="$PARENT_DIR/gr-$MODULE_NAME"
PYTHON_DIR="$MODULE_DIR/python/$MODULE_NAME"
GRC_DIR="$MODULE_DIR/grc"
BUILD_DIR="$MODULE_DIR/build"

# Function to check system requirements
check_system_requirements() {
    log_message "Checking system requirements..."
    
    # Check Ubuntu/Debian
    if ! command -v apt-get >/dev/null 2>&1; then
        handle_error "This script requires Ubuntu/Debian"
    fi
    
    # Check Python version
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    if [[ $(echo "$PYTHON_VERSION" | cut -d. -f1) -lt 3 ]]; then
        handle_error "Python 3.x is required"
    fi
    log_success "Python version: $PYTHON_VERSION"
    
    # Check system memory
    local mem_total=$(free -m | awk '/^Mem:/{print $2}')
    if [[ $mem_total -lt 2048 ]]; then
        log_warning "Low memory detected: ${mem_total}MB (recommended: 2048MB)"
    else
        log_success "Available system memory: ${mem_total}MB"
    fi
    
    # Check disk space
    local disk_space=$(df -m / | awk 'NR==2 {print $4}')
    if [[ $disk_space -lt 5120 ]]; then
        log_warning "Low disk space: ${disk_space}MB (recommended: 5120MB)"
    else
        log_success "Available disk space: ${disk_space}MB"
    fi
}

# Update just the packages list in the install_dependencies function:

    install_dependencies() {
        log_message "Installing and verifying dependencies..."
        
        # Update package list
        sudo apt-get update || handle_error "Failed to update package list"
        
        # Required packages - Updated VOLK package name
        local packages=(
            cmake
            build-essential
            libboost-all-dev
            libgmp-dev
            swig
            python3-numpy
            python3-mako
            python3-sphinx
            python3-lxml
            python3-yaml
            python3-click
            python3-click-plugins
            python3-zmq
            python3-scipy
            python3-gi
            python3-gi-cairo
            gir1.2-gtk-3.0
            libvolk-dev        # Changed from libvolk2-dev to libvolk-dev
            libfftw3-dev
            libgsl-dev
            libcppunit-dev
            doxygen
            pkg-config
        )
        
        # Install packages
        for package in "${packages[@]}"; do
            if ! dpkg -l | grep -q "^ii  $package"; then
                log_message "Installing $package..."
                sudo apt-get install -y "$package" || handle_error "Failed to install $package"
            fi
        done
        
        # After installing VOLK, ensure ldconfig is run
        sudo ldconfig
        
        # Verify GNU Radio installation
        if ! command -v gnuradio-companion >/dev/null 2>&1; then
            log_message "Installing GNU Radio..."
            sudo apt-get install -y gnuradio || handle_error "Failed to install GNU Radio"
        fi
        
        # Verify gr_modtool
        if ! command -v gr_modtool >/dev/null 2>&1; then
            handle_error "gr_modtool not found after installing GNU Radio"
        fi
        
        log_success "All dependencies installed successfully"
        
        # Verify VOLK installation
        if ldconfig -p | grep -q libvolk; then
            log_success "VOLK library installed successfully"
        else
            handle_error "VOLK library installation failed"
        fi
    }

# Function to set up Python environment
setup_python_environment() {
    log_message "Setting up Python environment..."
    
    # Install pip if not present
    if ! command -v pip3 >/dev/null 2>&1; then
        sudo apt-get install -y python3-pip || handle_error "Failed to install pip3"
    fi
    
    # Install required Python packages
    pip3 install --user --upgrade pip setuptools wheel || handle_error "Failed to upgrade pip"
    pip3 install --user numpy mako six || handle_error "Failed to install Python requirements"
    
    # Set up PYTHONPATH
    local site_packages=$(python3 -c "import site; print(site.USER_SITE)")
    mkdir -p "$site_packages"
    
    # Add Python path to bashrc if not already present
    if ! grep -q "PYTHONPATH.*$PYTHON_DIR" ~/.bashrc; then
        echo "export PYTHONPATH=$PYTHON_DIR:\$PYTHONPATH" >> ~/.bashrc
        log_success "Added PYTHONPATH to ~/.bashrc"
    fi
    
    # Create symbolic link for development
    if [ ! -L "$site_packages/$MODULE_NAME" ]; then
        ln -sf "$PYTHON_DIR" "$site_packages/$MODULE_NAME"
        log_success "Created symbolic link for module development"
    fi
}

# Function to create or backup module
create_or_backup_module() {
    log_message "Creating or backing up module..."
    
    if [ -d "$MODULE_DIR" ]; then
        log_message "Existing module found at $MODULE_DIR"
        cp -r "$MODULE_DIR" "$BACKUP_DIR/gr-$MODULE_NAME" || handle_error "Failed to create backup"
        log_success "Backup created at $BACKUP_DIR/gr-$MODULE_NAME"
        
        # Clean existing installation
        sudo rm -rf "$MODULE_DIR"
        log_success "Cleaned existing module directory"
    fi
    
    # Create new module
    log_message "Creating new OOT module..."
    sudo mkdir -p "$PARENT_DIR"
    sudo chown $USER:$USER "$PARENT_DIR"
    
    cd "$PARENT_DIR" || handle_error "Failed to change to parent directory"
    gr_modtool newmod "$MODULE_NAME" || handle_error "Failed to create new module"
    
    # Set up directory structure
    mkdir -p "$PYTHON_DIR" "$GRC_DIR" || handle_error "Failed to create module directories"
}

# Function to add block to module
add_block() {
    log_message "Adding block to module..."
    
    cd "$MODULE_DIR" || handle_error "Failed to change to module directory"
    
    # Add block using gr_modtool
    gr_modtool add -t sync -l python "$BLOCK_NAME" || handle_error "Failed to add block"
}

# Function to copy block files
copy_block_files() {
    log_message "Copying block files..."
    
    # Verify source files
    local required_files=(
        "$SCRIPT_DIR/$BLOCK_NAME.py"
        "$SCRIPT_DIR/$BLOCK_NAME.block.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            handle_error "Required file not found: $file"
        fi
    done
    
    # Copy Python implementation
    cp "$SCRIPT_DIR/$BLOCK_NAME.py" "$PYTHON_DIR/$BLOCK_NAME.py" || \
        handle_error "Failed to copy Python implementation"
    
    # Copy YAML block definition
    cp "$SCRIPT_DIR/$BLOCK_NAME.block.yml" "$GRC_DIR/${MODULE_NAME}_${BLOCK_NAME}.block.yml" || \
        handle_error "Failed to copy YAML definition"
    
    # Set permissions
    chmod 644 "$PYTHON_DIR/$BLOCK_NAME.py"
    chmod 644 "$GRC_DIR/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
    
    log_success "Block files copied successfully"
}

# Function to build and install module
build_and_install() {
    log_message "Building and installing module..."
    
    # Create and enter build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR" || handle_error "Failed to change to build directory"
    
    # Configure build
    cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" \
          -DPYTHON_EXECUTABLE=$(which python3) \
          -DENABLE_TESTING=OFF \
          .. || handle_error "CMake configuration failed"
    
    # Build
    make -j$(nproc) || handle_error "Build failed"
    
    # Install
    sudo make install || handle_error "Installation failed"
    sudo ldconfig
    
    log_success "Module built and installed successfully"
}

# Function to verify installation
verify_installation() {
    log_message "Verifying installation..."
    
    # Check Python module
    if python3 -c "import $MODULE_NAME" 2>/dev/null; then
        log_success "Python module '$MODULE_NAME' is importable"
    else
        log_warning "Python module '$MODULE_NAME' is not importable"
        fix_python_import
    fi
    
    # Verify files
    local check_files=(
        "$PYTHON_DIR/$BLOCK_NAME.py"
        "$GRC_DIR/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
        "$PREFIX/lib/cmake/gnuradio-$MODULE_NAME/gnuradio-${MODULE_NAME}Config.cmake"
    )
    
    for file in "${check_files[@]}"; do
        if [ -f "$file" ]; then
            log_success "Verified: $file"
        else
            log_warning "Missing: $file"
        fi
    done
}

# Function to fix Python import issues
fix_python_import() {
    log_message "Fixing Python import issues..."
    
    # Update Python path
    local site_packages=$(python3 -c "import site; print(site.getsitepackages()[0])")
    
    # Create .pth file
    echo "$PYTHON_DIR" | sudo tee "$site_packages/${MODULE_NAME}.pth" > /dev/null
    
    # Rebuild Python cache
    sudo python3 -m compileall "$PYTHON_DIR"
    
    log_success "Python import fixes applied"
}

# Function to update GRC
update_grc() {
    log_message "Updating GNU Radio Companion..."
    
    # Clear GRC cache
    rm -rf ~/.gnuradio/grc-cache/*
    rm -rf ~/.cache/gnuradio/*
    
    # Update GRC block path configuration
    mkdir -p ~/.gnuradio
    if ! grep -q "$GRC_DIR" ~/.gnuradio/config.conf 2>/dev/null; then
        cat >> ~/.gnuradio/config.conf << EOF
[grc]
local_blocks_path = $GRC_DIR
EOF
    fi
    
    # Reload blocks if GRC is installed
    if command -v grcc >/dev/null 2>&1; then
        if [ -f "$GRC_DIR/${MODULE_NAME}_${BLOCK_NAME}.block.yml" ]; then
            grcc "$GRC_DIR/${MODULE_NAME}_${BLOCK_NAME}.block.yml"
        fi
    fi
    
    log_success "GRC configuration updated"
}

# Main execution
main() {
    # Trap errors
    trap 'handle_error "Script failed at line $LINENO"' ERR
    
    # Run all steps
    check_root
    check_system_requirements
    # install_dependencies
    setup_python_environment
    create_or_backup_module
    add_block
    copy_block_files
    build_and_install
    verify_installation
    update_grc
    
    # Print success message and next steps
    cat << EOF | tee -a "$LOG_FILE"

${GREEN}${BOLD}Installation Completed Successfully${NC}

Next Steps:
1. Close and reopen your terminal or run:
   source ~/.bashrc

2. Start GNU Radio Companion:
   gnuradio-companion

3. Click Tools -> Reload Blocks

4. Search for '$BLOCK_NAME' in the blocks list

Installation Details:
- Module Name: $MODULE_NAME
- Block Name: $BLOCK_NAME
- Install Location: $MODULE_DIR
- Log File: $LOG_FILE
- Backup Location: $BACKUP_DIR

If you experience any issues:
- Check the log file: $LOG_FILE
- Try running: python3 -c "import $MODULE_NAME"
- Check GRC blocks path in: ~/.gnuradio/config.conf

EOF
}

# Run main function
main "$@" 2>&1 | tee -a "$LOG_FILE"