package main

import (
  "log"
  
  "github.com/ayaz9988/goTodoAndAuth.git/internal/config"
  "github.com/ayaz9988/goTodoAndAuth.git/internal/database"
  "github.com/gin-gonic/gin"
)

func main() {
  cfg, err := config.Load()
  if err != nil {
    log.Fatal("Failed to load configuration: ", err)
  }
  pool, err := database.Connect(cfg.DatabaseURL)
  if err != nil {
    log.Fatal("Failed to connect to database", err)
  }
  defer pool.Close()
  
  var router *gin.Engine = gin.Default()
  router.SetTrustedProxies(nil)
  router.GET("/", func(c *gin.Context) {
    c.JSON(200, gin.H{
      "message": "The Server is alive and running",
      "status":  "Success",
      "database": "Connected",
    })
  })

  router.Run(":" + cfg.Port)
}
