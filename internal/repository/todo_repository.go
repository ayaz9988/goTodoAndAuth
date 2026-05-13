package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/ayaz9988/goTodoAndAuth.git/internal/models"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrTodoNotFound = errors.New("todo not found")

func CreateTodo(pool *pgxpool.Pool, title string, completed bool, user_id string) (*models.Todo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		INSERT INTO goTodo (title, completed, user_id)
    		VALUES ($1, $2, $3)
    		RETURNING id, title, completed, created_at, updated_at, user_id
  	`
	todo := models.Todo{}

	if err := pool.QueryRow(ctx, query, title, completed, user_id).Scan(
		&todo.ID,
		&todo.Title,
		&todo.Completed,
		&todo.CreatedAt,
		&todo.UpdatedAt,
		&todo.UserID,
	); err != nil {
		return nil, err
	}

	return &todo, nil
}

func GetAllTodos(pool *pgxpool.Pool, user_id string) (*[]models.Todo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		SELECT id, title, completed, created_at, updated_at, user_id
	    	FROM goTodo
		WHERE user_id = $1
	    	ORDER BY created_at DESC
  	`

	rows, err := pool.Query(ctx, query, user_id)
	if err != nil {
		return nil, err
	}

	defer rows.Close()

	todos := []models.Todo{}

	for rows.Next() {
		var todo models.Todo
		err := rows.Scan(
			&todo.ID,
			&todo.Title,
			&todo.Completed,
			&todo.CreatedAt,
			&todo.UpdatedAt,
			&todo.UserID,
		)
		if err != nil {
			return nil, err
		}

		todos = append(todos, todo)
	}

	if err = rows.Err(); err != nil {
		return nil, err
	}

	return &todos, nil
}

func GetTodoByID(pool *pgxpool.Pool, id int, user_id string) (*models.Todo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		SELECT id, title, completed, created_at, updated_at, user_id
		FROM goTodo
		WHERE id = $1 and user_id = $2
		ORDER BY created_at DESC
  	`

	todo := models.Todo{}

	if err := pool.QueryRow(ctx, query, id, user_id).Scan(
		&todo.ID,
		&todo.Title,
		&todo.Completed,
		&todo.CreatedAt,
		&todo.UpdatedAt,
		&todo.UserID,
	); err != nil {
		return nil, err
	}

	return &todo, nil
}

func UpdateTodo(pool *pgxpool.Pool, id int, title string, completed bool, user_id string) (*models.Todo, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		UPDATE goTodo
		SET title = $1, completed = $2, updated_at = CURRENT_TIMESTAMP
		WHERE id = $3 AND user_id = $4
		RETURNING id, title, completed, created_at, updated_at, user_id
	`
	var todo models.Todo
	if err := pool.QueryRow(ctx, query, title, completed, user_id).Scan(
		&todo.ID,
		&todo.Title,
		&todo.Completed,
		&todo.CreatedAt,
		&todo.UpdatedAt,
		&todo.UserID,
	); err != nil {
		return nil, err
	}

	return &todo, nil
}

func DeleteTodo(pool *pgxpool.Pool, id int, user_id string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	query := `
		DELETE FROM goTodo
		WHERE id = $1 AND user_id = $2
	`
	commandTag, err := pool.Exec(ctx, query, id, user_id)
	if err != nil {
		return err
	}

	if commandTag.RowsAffected() == 0 {
		return fmt.Errorf("todo with id %d not found", id)
	}

	return nil
}
