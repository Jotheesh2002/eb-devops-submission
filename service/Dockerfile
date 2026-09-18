# Multi-stage build: compile stage
FROM python:3.11-slim AS builder

WORKDIR /app
COPY app.py .

# Stage 2: runtime — minimal image, non-root user
FROM python:3.11-slim

# Create non-root user
RUN useradd -m -u 1000 appuser

WORKDIR /app
COPY --from=builder /app/app.py .

# Switch to non-root
USER appuser

EXPOSE 8080
CMD ["python3", "app.py"]
