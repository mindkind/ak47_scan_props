# ak47_scan_props

A FiveM resource that removes invalid props that cause players to crash with the error:

```
Server->client connection timed out. Pending commands: 52.
Command list: ak47_housing:loadfurnitures (294143 B, 17734 msec ago)
ak47_housing:loadfurnitures (294143 B, 17734 msec ago)
```

This resource scans and manages furniture props in a housing system, checks for invalid props in a predefined furniture configuration, analyzes their usage in a housing database, and provides tools to remove invalid props from houses.

## Features
- **Client-Side Prop Scanning**: Validates props in `Furniture.Objects` (defined in `config.lua`) using FiveM natives (`IsModelInCdimage`, `IsModelValid`) to identify invalid props.
- **Server-Side Housing Analysis**: Analyzes the `ak47_housing` database table to track prop usage, detect invalid props in houses, and identify props missing from the config.
- **Log Overwriting**: Overwrites log files (`scan_results.log` and `invalid_props.log`) with each scan to keep only the latest results.
- **Invalid Prop Removal**: Provides a command to remove invalid props from the `furnitures` JSON in the `ak47_housing` table and update the database.
- **Console Feedback**: Displays red-colored messages in the server console for scan start, invalid props to remove, and completion, with a prompt to fix invalid props if detected.

## Files
- **`fxmanifest.lua`**: Resource manifest defining client and server scripts and dependencies.
- **`config.lua`**: Configuration file defining `Furniture.Objects`, a table of furniture props with categories, objects, prices, and names.
- **`client.lua`**: Client-side script that scans `Furniture.Objects` for invalid props and sends results to the server.
- **`server.lua`**: Server-side script that handles scan results, analyzes housing data, and provides the removal command.
- **`scan_results.log`**: Log file (overwritten per scan) containing detailed scan and housing analysis results.
- **`invalid_props.log`**: Log file (overwritten per scan) listing invalid props detected by the client.

## Installation
1. **Download the Resource**:
   - Clone or download this repository into your FiveM server’s `resources` folder.

2. **Rename the Folder** (if needed):
   - Ensure the folder is named `ak47_scan_props`.

3. **Update `config.lua`**:
   - Retrieve the `config.lua` file from `ak47_housing/modules/furniture/config.lua` and place it into the resource folder.
   - Remove the `Config.` prefix from the file to ensure proper functionality.

4. **Start the Resource**:
   - Run `refresh` and `ensure ak47_scan_props` in your server console.

## Usage
### **Commands**
#### **Client-Side Command: `scanprops`**
- **Description**: Initiates a scan of `Furniture.Objects` on the client to check for invalid props.
- **Output**:
  - **Client console (F8)**: Scan progress and results.
  - **Server console**: Red messages for start, props to remove, completion, and a prompt if invalid props are found.
  - **Logs**: `scan_results.log` (full analysis) and `invalid_props.log` (invalid props list).
- **Example**:
  ```
  scanprops
  ```

#### **Server-Side Command: `remove_invalid_props`**
- **Description**: Reads `invalid_props.log`, scans `ak47_housing` for houses using these props, removes them from `furnitures` JSON, and updates the database.
- **Output**: Red console messages for start, each removal, and completion with the number of updated houses.
- **Example**:
  ```
  remove_invalid_props
  ```

## **Workflow**
1. **Run a Scan**:
   - Execute `scanprops` in-game to scan `Furniture.Objects`.
   - Check the server console for invalid props and the prompt:
     ```
     ^1[SCAN] Invalid props detected. Run 'remove_invalid_props' to remove them from houses.^7
     ```
2. **Remove Invalid Props**:
   - If invalid props are detected, run `remove_invalid_props` in the server console to remove them from all houses in `ak47_housing`.
3. **Verify Results**:
   - Check `scan_results.log` for the full analysis, including housing prop usage and missing props.
   - Check the database to confirm invalid props are removed from `furnitures`.

## **Log Files**
- **`scan_results.log`**:
  - Overwritten per scan.
  - Contains:
    - Client scan results (invalid props).
    - Housing analysis (global prop usage, per-house usage, invalid props in houses, missing props from config).
- **`invalid_props.log`**:
  - Overwritten per scan.
  - Lists invalid props detected by the client in the format:
    ```
    [timestamp] Invalid Prop: Category=X, Object=Y, Name=Z
    ```

## **Troubleshooting**
- **"ERROR: Furniture.Objects not loaded"**:
  - Ensure `config.lua` defines `Furniture.Objects` correctly and is listed in both `client_scripts` and `server_scripts` in `fxmanifest.lua`.
- **"ERROR: oxmysql not found"**:
  - Verify `oxmysql` is installed and started in `server.cfg`.
- **File Write Errors**:
  - Check write permissions for `resources/ak47_scan_props` (Linux: `chmod -R 775`, Windows: run as admin).
- **No Invalid Props Removed**:
  - Ensure `invalid_props.log` exists and contains valid entries from a prior scan.

## **Contributing**
Feel free to submit issues or pull requests on GitHub to improve this resource!
