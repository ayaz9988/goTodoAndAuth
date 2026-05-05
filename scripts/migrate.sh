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

    # Capture both stdout and stderr to check for the "dirty" keyword
    MIGRATE_OUTPUT=$(migrate -path "$MIGRATIONS_PATH" -database "$DB_URL" up 2>&1)
    MIGRATE_EXIT_CODE=$?

    if [ $MIGRATE_EXIT_CODE -ne 0 ]; then
        if echo "$MIGRATE_OUTPUT" | grep -iq "dirty database"; then
            log_error "The database is DIRTY! A previous migration failed midway."
            echo -e "${RED}----------------------------------------------------------------------------------${NC}"
            echo -e "${RED}golang-migrate has locked the database to prevent corruption.${NC}"
            echo -e "${RED}1. Check your database client (DBeaver/pgAdmin) to see what partially executed.${NC}"
            echo -e "${RED}2. Manually undo the partial changes so your DB matches the state BEFORE the failed version.${NC}"
            echo -e "${RED}3. Run the force command below to unlock it:${NC}"
            
            # Extract the version number safely without perl-regex
            DIRTY_VER=$(echo "$MIGRATE_OUTPUT" | grep -o 'Dirty database version [0-9]*' | grep -o '[0-9]*')
            
            if [ -n "$DIRTY_VER" ]; then
                PREV_VER=$((DIRTY_VER - 1))
                echo -e "${YELLOW}   migrate -path \"$MIGRATIONS_PATH\" -database \"\$DB_URL\" force $PREV_VER${NC}"
            else
                echo -e "${YELLOW}   migrate -path \"$MIGRATIONS_PATH\" -database \"\$DB_URL\" force <version>${NC}"
            fi
            echo -e "${RED}----------------------------------------------------------------------------------${NC}"
        else
            log_error "UP migration failed!"
            echo "$MIGRATE_OUTPUT"
        fi
        exit 1
    else
        log_success "Database migrated up successfully!"
    fi
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

    MIGRATE_OUTPUT=$(migrate -path "$MIGRATIONS_PATH" -database "$DB_URL" down "$count" 2>&1)
    MIGRATE_EXIT_CODE=$?

    if [ $MIGRATE_EXIT_CODE -ne 0 ]; then
        if echo "$MIGRATE_OUTPUT" | grep -iq "dirty database"; then
            log_error "The database is DIRTY! A previous migration failed midway."
            echo -e "${RED}Run 'force' to unlock it, but ensure the DB schema is manually fixed first.${NC}"
        else
            log_error "DOWN migration failed!"
            echo "$MIGRATE_OUTPUT"
        fi
        exit 1
    else
        log_success "Database rolled back $count step(s) successfully!"
    fi
}

run_create() {
    local name=$1
    if [ -z "$name" ]; then
        log_error "Migration name is required. Usage: $0 create <name>"
        exit 1
    fi

    log_info "Creating new migration files with sequence..."
    if migrate create -ext sql -dir "$MIGRATIONS_PATH" -seq "$name"; then
        log_success "Migration files created successfully! Don't forget to write your UP and DOWN SQL."
    else
        log_error "Failed to create migration files."
        exit 1
    fi
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