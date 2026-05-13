package config

import (
	"log"
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DatabaseURL  string
	Port         string
	JWTSecretKey string
}

func Load() (*Config, error) {
	if err := godotenv.Load(); err != nil {
		log.Println("Warning: .env file not found, useing  environment variables")
	}

	var config *Config = &Config{
		DatabaseURL:  os.Getenv("DATABASE_URL"),
		Port:         os.Getenv("PORT"),
		JWTSecretKey: os.Getenv("JWT_SECRET_KEY"),
	}

	return config, nil
}
