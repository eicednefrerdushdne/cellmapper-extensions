# cellmapper-extensions
Some stuff to make mapping towers faster and easier.

## Theory of operation ##
Triangulation is a much faster and more precise method of locating towers than relying solely on signal strength.

This website extension requests your own Cellmapper data from a tiny web server that runs on your computer. It then displays that data directly on the Cellmapper website.


## Prerequisites ##
 - Windows computer
 - Google Chrome
 - [Tampermonkey Chrome extension](https://chrome.google.com/webstore/detail/tampermonkey/dhdgffkkebhmkfjojejmpbldmpobfkfo)
 - USB cable or rooted phone
 - General troubleshooting ability
 - Experience in PowerShell, Javascript, and SQLite will help significantly.

## Computer Setup ##
1. Clone this Github repo
2. Install the Tampermonkey script into your web browser (`CellMapperExtensions.user.js`)
3. Install SQLite so it's available in the default path. Chocolatey makes this installation really easy.

## Basic Workflow ##
1. Record data on your phone
2. Copy raw cellmapper data from your phone to computer (
3. Import that raw data into the local computer database (sqlite)
    - Use the `Import-CellmapperDB.ps1` script to do this.
    - `Import-CellmapperDB.ps1` searches a list of folders. You can customize this list by modifying the script.
4. Run the `Start-PointServer.ps1` script and then open the Cellmapper website
5. Click on a tower, and the extension will display any data that you've recorded.

## Basic Usage ##
Click on a tower to display the LTE Timing Advance circles to quickly locate a tower.
Here's a screenshot of this in action.
![image](https://user-images.githubusercontent.com/98231591/150722696-c1c673e5-08a9-4949-a44e-fa6b4190d77c.png)
