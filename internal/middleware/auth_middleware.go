package middleware

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/ayaz9988/goTodoAndAuth.git/internal/config"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

func AuthMiddleware(cfg *config.Config) gin.HandlerFunc {
  return func (c * gin.Context) {
    authHeader := c.GetHeader("Authorization")
    if authHeader == "" {
      c.JSON(http.StatusUnauthorized, gin.H{
        "error": "Authorization header required",
      })
      c.Abort()
      return
    }
    
    tokenString := strings.TrimPrefix(authHeader, "Bearer ")
    if tokenString == "" || tokenString == authHeader {
      c.JSON(http.StatusUnauthorized, gin.H{
        "error": "Invalid authorization header format",
      })
      c.Abort()
      return
    }
    
    token, err := jwt.Parse(tokenString, func(token *jwt.Token)(interface{}, error) {
      if token.Method.Alg() != jwt.SigningMethodHS256.Alg() {
        return nil, fmt.Errorf("Unexpected signing method: %v", token.Header["alg"])
      }
      return []byte(cfg.JWTSecretKey), nil
    })
    
    if err!= nil || !token.Valid {
      c.JSON(http.StatusUnauthorized, gin.H{
        "error": "Invalid or expired token",
      })
      c.Abort()
      return
    }
    
    claims, ok := token.Claims.(jwt.MapClaims)
    if !ok {
      c.JSON(http.StatusUnauthorized, gin.H{
        "error": "Invalid token claims",
      })
      c.Abort()
      return
    }
    
    userID, ok := claims["user_id"].(string)
      
    if !ok {
      c.JSON(http.StatusUnauthorized, gin.H{
        "error": "Invalid token claims",
      })
      c.Abort()
      return
    }
    
    if exp, ok := claims["exp"].(float64); ok {
      expirationTime := time.Unix(int64(exp), 0)
      if time.Now().After(expirationTime) {
        c.JSON(http.StatusUnauthorized, gin.H{
          "error": "token has expired",
        })
        c.Abort()
        return
      }
    }
    
    c.Set("user_id", userID)
    c.Next()
  }
}