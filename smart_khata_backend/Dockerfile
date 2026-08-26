FROM python:3.11-slim

WORKDIR /app

# Install system build dependencies for audio & ML libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy and install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY . .

# Expose port
ENV PORT=8000
EXPOSE 8000

# Start FastAPI server via python run_server.py
CMD ["python", "run_server.py"]
