# Set strict mode for better scripting practices
Set-StrictMode -Version Latest

# Define variables
$GpoName    = "ClassInsights"
$GpoComment = "Dies ist die Standardgruppenrichtlinie für ClassInsights"
$ApiUrl     = "[API_URL]"
$ApiToken   = "[API_TOKEN]"
$regKey     = "HKLM\SOFTWARE\ClassInsights"


# Function to log errors
function Log-Error {
    param (
        [string]$Message
    )
    Write-Error "$(Get-Date -Format o) - $Message"
}

# Import the GroupPolicy module with error handling
try {
    Import-Module GroupPolicy -ErrorAction Stop
    Write-Host "GroupPolicy module imported successfully."
} catch {
    Log-Error "Failed to import GroupPolicy module. $_"
    exit 1
}

# Check if the GPO already exists
try {
    $existingGpo = Get-GPO -Name $GpoName -ErrorAction SilentlyContinue
    if ($existingGpo) {
        Write-Warning "GPO '$GpoName' already exists. Exiting script."
        exit 0
    }
} catch {
    Log-Error "Error checking existence of GPO '$GpoName'. $_"
    exit 1
}

# Create the new GPO
try {
    $gpo = New-GPO -Name $GpoName -Comment $GpoComment -ErrorAction Stop
    Write-Host "GPO '$GpoName' created successfully."
} catch {
    Log-Error "Error creating GPO '$GpoName'. $_"
    exit 1
}

# Set the registry values with error handling
try {
    Set-GPRegistryValue -Name $gpo.DisplayName -Key $regKey -ValueName "ApiUrl" -Type String -Value $ApiUrl -ErrorAction Stop
    Write-Host "Registry value 'ApiUrl' set to '$ApiUrl'."
} catch {
    Log-Error "Error setting registry value 'ApiUrl'. $_"
    exit 1
}

try {
    Set-GPRegistryValue -Name $gpo.DisplayName -Key $regKey -ValueName "ApiToken" -Type String -Value $ApiToken -ErrorAction Stop
    Write-Host "Registry value 'ApiToken' set to '$ApiToken'."
} catch {
    Log-Error "Error setting registry value 'ApiToken'. $_"
    exit 1
}

Write-Host "GPO '$GpoName' was created and configured successfully."
