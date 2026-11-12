# Étape 1 : construction du WAR
FROM gradle:8.14-jdk21 AS builder

WORKDIR /app

COPY . .

RUN gradle clean test

RUN gradle clean bootWar --no-daemon

# Étape 2 : exécution de Spring Boot
FROM eclipse-temurin:21-jre

WORKDIR /app

COPY  --from=builder /app/build/libs/*.war app.war

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.war"]