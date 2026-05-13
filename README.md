# Go Todo REST API

A secure, full-stack REST API built with Go, Gin, PostgreSQL, and JWT authentication. This project demonstrates the implementation of a complete todo management system with user authentication, password hashing, and protected routes.

## Features

- **User Authentication**: Secure registration and login with JWT tokens
- **Password Security**: bcrypt hashing for secure password storage
- **Protected Routes**: Middleware-based route protection
- **User-Specific Todos**: Each user has their own private todo collection
- **CRUD Operations**: Create, read, update, and delete todos
- **Database Migrations**: Version-controlled database schema changes
- **Hot Reloading**: Air integration for development

## Prerequisites

Before you begin, ensure you have the following installed:

- **Go** (v1.21 or higher)
- **PostgreSQL** (v14 or higher)
- **golang-migrate** - [Installation Guide](https://github.com/golang-migrate/migrate)
- **Air** - [Installation Guide](https://github.com/air-verse/air)

## Getting Started

### 1. Download/Clone the Repository

### 2. Install Dependencies

```bash
go mod download
```

### 3. Set Up PostgreSQL Database

Create a new database in PostgreSQL:

```sql
CREATE DATABASE todo_api;
```

### 4. Configure Environment Variables

Create a `.env` file in the root directory:

```env
DATABASE_URL=postgres://username:password@localhost:5432/todo_api?sslmode=disable
PORT=3000
JWT_SECRET=your-secure-jwt-secret-key
```

### 5. Run Database Migrations

Using the migrate CLI:

```bash
migrate -path migrations -database "your_database_url" up
```

Or using the provided migration scripts:

**PowerShell (Windows):**
```powershell
.\scripts\migrate.ps1 up
```

**Bash (Linux/macOS):**
```bash
./scripts/migrate.sh up
```

#### Migration Script Usage

Both scripts provide the same functionality:

- `migrate.ps1 up` or `migrate.sh up` - Apply all pending migrations
- `migrate.ps1 down [count]` or `migrate.sh down [count]` - Rollback the last [count] migrations (default: 1)
- `migrate.ps1 create <name>` or `migrate.sh create <name>` - Create new migration files

The scripts include automatic dirty database detection and recovery, environment variable parsing, and user confirmation prompts for safety.

### 6. Start the Server

```bash
go run ./cmd/api
```

Or with Air for hot reloading:

```bash
air
```

The API will be available at `http://localhost:3000`

## Project Structure

```
Go-Gin-Postgres-Todo-REST-API/
├── cmd/
│   └── api/
│       └── main.go              # Application entry point
├── internal/
│   ├── config/
│   │   └── config.go            # Environment configuration
│   ├── database/
│   │   └── postgres.go          # Database connection
│   ├── handlers/
│   │   ├── todo_handler.go      # Todo route handlers
│   │   └── user_handler.go      # Auth route handlers
│   ├── middleware/
│   │   └── auth_middleware.go   # JWT authentication middleware
│   ├── models/
│   │   ├── todo.go              # Todo model
│   │   └── user.go              # User model
│   └── repository/
│       ├── todo_repository.go   # Todo database operations
│       └── user_repository.go   # User database operations
├── migrations/
│   ├── 000001_create_todos_api_table.up.sql
│   ├── 000001_create_todos_api_table.down.sql
│   ├── 000002_create_users_api_table.up.sql
│   ├── 000002_create_users_api_table.down.sql
│   ├── 000003_add_user_id_to_todos_table.up.sql
│   └── 000003_add_user_id_to_todos_table.down.sql
├── scripts/
│   └── migrate.ps1              # Migration helper script
├── .air.toml                    # Air configuration
├── .env                         # Environment variables (create this)
├── go.mod                       # Go module definition
└── go.sum                       # Go dependencies checksum
```

## API Endpoints

### Public Routes

| Method | Endpoint         | Description         |
| ------ | ---------------- | ------------------- |
| GET    | `/`              | Health check        |
| POST   | `/auth/register` | Register a new user |
| POST   | `/auth/login`    | Login and get token |

### Protected Routes (Require JWT)

| Method | Endpoint     | Description          |
| ------ | ------------ | -------------------- |
| POST   | `/todos`     | Create a new todo    |
| GET    | `/todos`     | Get all user's todos |
| GET    | `/todos/:id` | Get a specific todo  |
| PUT    | `/todos/:id` | Update a todo        |
| DELETE | `/todos/:id` | Delete a todo        |

## Request-Response Flow

```mermaid
%%{init: {'themeVariables': {'edgeLabelBackground':'transparent', 'clusterBkg':'transparent'}}}%%

flowchart TB
    Client("🌐 CLIENT<br/>Postman / Browser<br/>HTTP + JSON")

    subgraph GinFramework["⚡ GIN FRAMEWORK"]
        Router("🔀 ROUTER<br/>Route Management")
        Auth("🔐 AUTH MIDDLEWARE<br/>JWT Validation")
    end

    subgraph Routes["📍 ENDPOINTS"]
        PublicRoutes("🔓 PUBLIC<br/>POST /auth/register<br/>POST /auth/login")
        ProtectedRoutes("🔒 PROTECTED<br/>POST /todos<br/>GET /todos<br/>GET /todos/:id<br/>PUT /todos/:id<br/>DELETE /todos/:id<br/>User Context Required")
    end


   Handlers("⚙️ HANDLERS<br/>━━━━━━━━━━━━━━━━━━━━<br/>▼ REQUEST HANDLING ▼<br/>Parse Request<br/>Validate Input<br/>Business Logic Processing<br/>━━━━━━━━━━━━━━━━━━━━<br/>▼ RESPONSE HANDLING ▼<br/>Format Response<br/>Status Codes<br/>━━━━━━━━━━━━━━━━━━━━")

Repository("📊 REPOSITORY<br/>━━━━━━━━━━━━━<br/>▼ REQUEST HANDLING ▼<br/>Execute SQL Queries<br/>━━━━━━━━━━━━━━━━━━━━<br/>▼ RESPONSE HANDLING ▼<br/>Return Data/Errors<br/>━━━━━━━━━━━━━")

    subgraph Database["🗄️ POSTGRESQL"]
        Users[("👤 USERS<br/>id: UUID<br/>email: unique<br/>password: bcrypt<br/>created_at: TIMESTAMP<br/>updated_at: TIMESTAMP")]
        Todos[("📝 TODOS<br/>id: SERIAL<br/>title: VARCHAR(255)<br/>completed: BOOLEAN<br/>created_at: TIMESTAMP<br/>updated_at: TIMESTAMP<br/>user_id: UUID")]
    end

    %% REQUEST FLOW - with proper spacing
    Client ===>|"1. HTTP Request"| Router
    Router --->|"2. Route"| PublicRoutes
    Router --->|"2. Check Auth"| Auth
    Auth --->|"3. Authorized"| ProtectedRoutes

    PublicRoutes ===>|"4. Process"| Handlers
    ProtectedRoutes ===>|"4. Process"| Handlers

    Handlers ===>|"5. Query"| Repository

    Repository ===>|"6. SQL"| Users
    Repository ===>|"6. SQL"| Todos

    %% RESPONSE FLOW - with proper spacing
    Users -.->|"7. Data/Error"| Repository
    Todos -.->|"7. Data/Error"| Repository

    Repository -.->|"8. Entity/Error"| Handlers

    Handlers -.->|"9. JSON Response"| ProtectedRoutes
    Handlers -.->|"9. JSON Response"| PublicRoutes

    ProtectedRoutes -.->|"10. Pass Through"| Auth
    PublicRoutes -.->|"10. Pass Through"| Router
    Auth -.->|"11. Pass Through"| Router

    Router -.->|"12. HTTP Response"| Client

    %% Foreign Key Relationship
    Users -.->|"Foreign Key"| Todos

    style Client fill:#412B6B,stroke:#5C3E94,stroke-width:1px,color:#FFD700
    style Router fill:#412B6B,stroke:#5C3E94,stroke-width:1px,color:#FFD700
    style Auth fill:#412B6B,stroke:#5C3E94,stroke-width:1px,color:#FFD700
    style PublicRoutes fill:#0a0a0a,stroke:#90EE90,stroke-width:1px,color:#90EE90
    style ProtectedRoutes fill:#0a0a0a,stroke:#FF6B6B,stroke-width:1px,color:#FF6B6B
    style Handlers fill:#412B6B,stroke:#5C3E94,stroke-width:1px,color:#FFD700
    style Repository fill:#412B6B,stroke:#5C3E94,stroke-width:1px,color:#FFD700
    style Users fill:#412B6B,stroke:#5C3E94,stroke-width:1px,color:#FFD700
    style Todos fill:#412B6B,stroke:#5C3E94,stroke-width:1px,color:#FFD700
    style GinFramework fill:#09122C,stroke:transparent,stroke-width:1px,color:#FFD700
    style Routes fill:#09122C,stroke:transparent,stroke-width:1px,color:#FFD700
    style Database fill:#09122C,stroke:transparent,stroke-width:1px,color:#FFD700

    %% Link styling for blue borders on labels
    linkStyle 0 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 1 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 2 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 3 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 4 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 5 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 6 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 7 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 8 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 9 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 10 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 11 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 12 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 13 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 14 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 15 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 16 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 17 stroke:#4169E1,stroke-width:1px,fill:none
    linkStyle 18 stroke:#4169E1,stroke-width:1px,fill:none
```

## Testing with Postman

### User Requests

| Request        | Method | URL                                    | Body                                                          |
| -------------- | ------ | -------------------------------------- | ------------------------------------------------------------- |
| User Register  | POST   | `http://localhost:3000/auth/register`  | `{"email": "user@example.com", "password": "securepassword"}` |
| User Login     | POST   | `http://localhost:3000/auth/login`     | `{"email": "user@example.com", "password": "securepassword"}` |
| Protected Test | GET    | `http://localhost:3000/protected-test` | -                                                             |

### Todo Requests (Protected)

| Request          | Method | URL                               | Body                                        |
| ---------------- | ------ | --------------------------------- | ------------------------------------------- |
| Create To Do     | POST   | `http://localhost:3000/todos`     | `{"title": "Learn Go", "completed": false}` |
| Get All To Dos   | GET    | `http://localhost:3000/todos`     | -                                           |
| Get Single To Do | GET    | `http://localhost:3000/todos/:id` | -                                           |
| Update To Do     | PUT    | `http://localhost:3000/todos/:id` | `{"title": "Updated", "completed": true}`   |
| Delete To Do     | DELETE | `http://localhost:3000/todos/:id` | -                                           |
| Home Route       | GET    | `http://localhost:3000/`          | -                                           |

### Authorization Setup

For protected routes, add the JWT token in Postman:

1. Go to the **Authorization** tab
2. Select **Bearer Token** from the dropdown
3. Paste your token from the login response

## Database Schema

### Users Table

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### Todos Table

```sql
CREATE TABLE todos (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE
);
```

## Technologies Used

- **Go 1.21+**: Backend programming language
- **Gin**: HTTP web framework
- **PostgreSQL**: Relational database
- **pgx/v5**: PostgreSQL driver and connection pool
- **JWT**: JSON Web Tokens for authentication
- **bcrypt**: Password hashing
- **golang-migrate**: Database migrations
- **Air**: Hot reloading for development
- **godotenv**: Environment variable management

## License

This project is licensed under the MIT License.

---

Happy Coding and Learning! 🙂