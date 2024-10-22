
# Setup and Manage Custom GNU Radio Module

This script (`setup_custom_module.sh`) allows you to easily create, update, or reinstall a custom GNU Radio Out-Of-Tree (OOT) module. It automatically installs dependencies, copies Python and YAML block files, builds the module, and installs it for use in GNU Radio Companion (GRC).

## Directory Structure

Ensure the following files are present in the same directory:


```
/path/to/your/module/
├── setup_custom_module.sh  # Bash script
├── custom_file_writer.py    # Your Python block file
└── custom_file_writer.block.yml # Your GRC block YAML file
```
## How to Run the Script

Run the Script:

First, make the script executable:
```
chmod +x /path/to/your/module/setup_custom_module.sh
```

To create or update the default module:

```
./setup_custom_module.sh
```

To create or update a module with a custom name:


``` 
./setup_custom_module.sh myNewModule
```

This will create or update the module myNewModule instead of the default customModule.

## Steps the Script Automates

1. Install Dependencies: Ensures that GNU Radio CMake, and Boost are installed.
2. Create or Backup the Module: Creates a new OOT module or backs up an existing one.
3. Add the Custom Block: Adds the block (e.g., custom_file_writer) to the OOT module.
4. Copy the Python and YAML Files: Copies custom_file_writer.py and custom_file_writer.block.yml into the module.
5. Build and Install: Compiles and installs the module for use in GNU Radio.


## Customization

* Python File: You can modify the custom_file_writer.py file as needed.
* YAML File: Update the custom_file_writer.block.yml file to change the block’s properties in GRC.

After running the script, the custom block will be available in GNU Radio Companion under the Custom category.