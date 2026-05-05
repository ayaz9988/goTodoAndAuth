# goTodoAndAuth

## a simple todo backend with authentication for learning porposes

### there are scripts for migrations
#### how to use them

Make sure the bash script is executable once:
```bash
chmod +x scripts/migrate.sh
```

Then, from **anywhere** in your terminal (as long as you are inside the project directory structure), you can run:

**Create a migration:**
```bash
./scripts/migrate.sh create create_todo_table
# or Powershell: .\scripts\migrate.ps1 create create_todo_table
```

**Run migrations up:**
```bash
./scripts/migrate.sh up
```

**Rollback 1 migration:**
```bash
./scripts/migrate.sh down
```

**Rollback 3 migrations:**
```bash
./scripts/migrate.sh down 3
```