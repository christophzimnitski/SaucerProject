# Multi-stage build for Sauce Robot application
# Stage 1: Build the React frontend
FROM node:18-alpine as frontend-build

WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# Stage 2: Build the Spring Boot backend with embedded frontend
FROM maven:3.9.4-openjdk-17-slim as backend-build

WORKDIR /app
COPY backend/pom.xml ./
COPY backend/src ./src

# Copy built React app to Spring Boot static resources
COPY --from=frontend-build /app/frontend/build ./src/main/resources/static/

RUN mvn clean package -DskipTests

# Stage 3: Runtime image
FROM openjdk:17-jre-slim

WORKDIR /app

# Copy the built JAR
COPY --from=backend-build /app/target/*.jar app.jar

# Copy database initialization files
COPY backend/src/main/resources/data.sql /app/
COPY backend/src/main/resources/schema.sql /app/

# Create data directory for H2 database
RUN mkdir -p /app/data

# Expose port 8080
EXPOSE 8080

# Set environment variables for containerized deployment
ENV SPRING_PROFILES_ACTIVE=docker
ENV SERVER_PORT=8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/api/recipes || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
