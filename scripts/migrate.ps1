# ==============================================================================
# Database Migration Manager
# ==============================================================================

# Determine the directory where this script lives
 $ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path } # Fallback for older PS versions

 $ProjectRoot = Join-Path $ScriptDir ".."

# Paths relative to the script's location
 $EnvFile = Join-Path $ProjectRoot ".env"
 $MigrationsPath = Join-Path $ProjectRoot "migrations"

# ==============================================================================
# Logging Functions
# ==============================================================================

function Write-Info {
    param ([string]$Message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$([char]0x1b)[34mINFO$([char]0x1b)[0m] $Message"
}

function Write-Success {
    param ([string]$Message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$([char]0x1b)[32mSUCCESS$([char]0x1b)[0m] $Message"
}

function Write-Warn {
    param ([string]$Message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$([char]0x1b)[33mWARNING$([char]0x1b)[0m] $Message"
}

function Write-Err {
    param ([string]$Message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$([char]0x1b)[31mERROR$([char]0x1b)[0m] $Message"
}

# ==============================================================================
# Pre-flight Checks
# ==============================================================================

if (-not (Get-Command migrate -ErrorAction SilentlyContinue)) {
    Write-Err "The 'migrate' command could not be found. Please install golang-migrate."
    exit 1
}

if (-not (Test-Path $EnvFile)) {
    Write-Err "Environment file not found at $EnvFile"
    exit 1
}

# Parse the .env file to get DATABASE_URL
 $DbUrl = $null
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*DATABASE_URL\s*=\s*(.+)$') {
        # Strip quotes from the value
        $DbUrl = $Matches[1].Trim('"', "'")
    }
}

if ([string]::IsNullOrWhiteSpace($DbUrl)) {
    Write-Err "DATABASE_URL is empty or not found in $EnvFile"
    exit 1
}

# ==============================================================================
# Command Functions
# ==============================================================================

function Invoke-Up {
    Write-Info "Starting database UP migration..."
    Write-Host "$([char]0x1b)[33mApplying all pending migrations to the database.$([char]0x1b)[0m"
    $confirm = Read-Host "Do you want to continue? (y/N)"
    if ($confirm -notmatch '^[yY]$') {
        Write-Warn "Migration cancelled by user."
        exit 0
    }

    migrate -path $MigrationsPath -database $DbUrl up
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Database migrated up successfully!"
    } else {
        Write-Err "UP migration failed!"
        exit 1
    }
}

function Invoke-Down {
    param ([int]$Count = 1)
    Write-Info "Starting database DOWN migration..."
    Write-Host "$([char]0x1b)[31m⚠ WARNING: This will rollback the last $Count migration(s)!$([char]0x1b)[0m"
    Write-Host "$([char]0x1b)[31mThis action may result in DATA LOSS.$([char]0x1b)[0m"
    $confirm = Read-Host "Are you absolutely sure? (Type 'yes' to confirm)"

    if ($confirm -ne "yes") {
        Write-Warn "Down migration aborted by user."
        exit 0
    }

    migrate -path $MigrationsPath -database $DbUrl down $Count
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Database rolled back $Count step(s) successfully!"
    } else {
        Write-Err "DOWN migration failed!"
        exit 1
    }
}

function Invoke-Create {
    param ([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-Err "Migration name is required. Usage: .\db.ps1 create <name>"
        exit 1
    }

    Write-Info "Creating new migration files with sequence..."
    migrate create -ext sql -dir $MigrationsPath -seq $Name
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Migration files created successfully! Don't forget to write your UP and DOWN SQL."
    } else {
        Write-Err "Failed to create migration files."
        exit 1
    }
}

# ==============================================================================
# Main Router
# ==============================================================================

switch ($args[0]) {
    "up" { Invoke-Up }
    "down" { Invoke-Down -Count $args[1] }
    "create" { Invoke-Create -Name $args[1] }
    default {
        Write-Err "Invalid command: $($args[0])"
        Write-Host ""
        Write-Host "Usage:"
        Write-Host "  .\migrate.ps1 up                          Run all pending migrations"
        Write-Host "  .\migrate.ps1 down [count]                Rollback [count] migrations (default: 1)"
        Write-Host "  .\migrate.ps1 create <migration_name>     Create new migration files"
        exit 1
    }
}