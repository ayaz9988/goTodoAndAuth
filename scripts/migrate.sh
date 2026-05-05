#!/usr/bin/env bash

# ==============================================================================
# Database Migration Manager
# ==============================================================================

# Determine the directory where this script lives
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Paths relative to the script's location
ENV_FILE="$PROJECT_ROOT/.env"
MIGRATIONS_PATH="$PROJECT_ROOT/migrations"

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Logging Functions
# ==============================================================================

log_info() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $1"; }

# ==============================================================================
# Core Execution Logic (Handles Dirty DB Recovery)
# ==============================================================================

execute_migrate() {
    local cmd_args=("$@")
    
    # Run the migrate command and capture output/errors
    local output
    output=$(migrate -path "$MIGRATIONS_PATH" -database "$DB_URL" "${cmd_args[@]}" 2>&1)
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        if echo "$output" | grep -iq "dirty database"; then
            # Extract the dirty version number safely
            local dirty_ver=$(echo "$output" | grep -oE 'Dirty database version [0-9]+' | grep -oE '[0-9]+')
            
            if [ -z "$dirty_ver" ]; then
                log_error "Dirty database detected, but could not parse version number from output:"
                echo "$output"
                exit 1
            fi
            
            local force_ver=$((dirty_ver - 1))
            
            log_error "Database is dirty at version $dirty_ver."
            echo -e "${RED}golang-migrate has locked the database to prevent corruption.${NC}"
            echo -e "${YELLOW}Please ensure you have manually fixed the database schema in your DB client.${NC}"
            
            read -p "Have you fixed the schema? (Type 'yes' to force to v$force_ver and retry, or 'no' to abort): " confirm
            
            if [ "$confirm" = "yes" ]; then
                log_info "Forcing database to clean state (version $force_ver)..."
                local force_output
                force_output=$(migrate -path "$MIGRATIONS_PATH" -database "$DB_URL" force "$force_ver" 2>&1)
                
                if [ $? -ne 0 ]; then
                    log_error "Failed to force database version!"
                    echo "$force_output"
                    exit 1
                fi
                
                log_success "Database forced to version $force_ver successfully."
                log_info "Retrying original command: migrate ${cmd_args[*]}..."
                echo "--------------------------------------------------"
                
                # Recursive call to retry the original command
                execute_migrate "${cmd_args[@]}"
            else
                log_warn "Aborted by user. Please fix the database manually and run the force command yourself."
                exit 0
            fi
        else
            # Not a dirty database error, just a normal failure
            log_error "Migration failed!"
            echo "$output"
            exit 1
        fi
    fi
    # If exit_code is 0, we silently return to the calling function
}

# ==============================================================================
# Pre-flight Checks
# ==============================================================================

if ! command -v migrate &> /dev/null; then
    log_error "The 'migrate' command could not be found. Please install golang-migrate."
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    log_error "Environment file not found at $ENV_FILE"
    exit 1
fi

# Safely parse the .env file to get DATABASE_URL (strips quotes)
DB_URL=$(grep -E '^\s*DATABASE_URL\s*=' "$ENV_FILE" | head -n 1 | cut -d '=' -f 2- | tr -d '"' | tr -d "'" | xargs)

if [ -z "$DB_URL" ]; then
    log_error "DATABASE_URL is empty or not found in $ENV_FILE"
    exit 1
fi

# ==============================================================================
# Command Functions
# ==============================================================================

run_up() {
    log_info "Starting database UP migration..."
    echo -e "${YELLOW}Applying all pending migrations to the database.${NC}"
    read -p "Do you want to continue? (y/N): " confirm
    if [[ "$confirm" != [yY] ]]; then
        log_warn "Migration cancelled by user."
        exit 0
    fi

    # Call the unified executor
    execute_migrate up
    
    # If execute_migrate didn't exit, it succeeded
    log_success "Database migrated up successfully!"
}

run_down() {
    local count=${1:-1}
    log_info "Starting database DOWN migration..."
    echo -e "${RED}⚠ WARNING: This will rollback the last $count migration(s)!${NC}"
    echo -e "${RED}This action may result in DATA LOSS.${NC}"
    read -p "Are you absolutely sure? (Type 'yes' to confirm): " confirm

    if [ "$confirm" != "yes" ]; then
        log_warn "Down migration aborted by user."
        exit 0
    fi

    # Call the unified executor
    execute_migrate down "$count"
    
    # If execute_migrate didn't exit, it succeeded
    log_success "Database rolled back $count step(s) successfully!"
}

run_create() {
    local name=$1
    if [ -z "$name" ]; then
        log_error "Migration name is required. Usage: $0 create <name>"
        exit 1
    fi

    log_info "Creating new migration files with sequence..."
    local output
    output=$(migrate create -ext sql -dir "$MIGRATIONS_PATH" -seq "$name" 2>&1)
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create migration files!"
        echo "$output"
        exit 1
    fi
    
    log_success "Migration files created successfully! Don't forget to write your UP and DOWN SQL."
}

# ==============================================================================
# Main Router
# ==============================================================================

case "$1" in
    up)
        run_up
        ;;
    down)
        run_down "$2"
        ;;
    create)
        run_create "$2"
        ;;
    *)
        log_error "Invalid command: $1"
        echo ""
        echo "Usage:"
        echo "  $0 up                          Run all pending migrations"
        echo "  $0 down [count]                Rollback [count] migrations (default: 1)"
        echo "  $0 create <migration_name>     Create new migration files"
        exit 1
        ;;
esac