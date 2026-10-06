FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY services ./services
ARG SERVICE_MODULE
ARG PORT=8000
ENV SERVICE_MODULE=${SERVICE_MODULE} PORT=${PORT} DATA_DIR=/data UPLOAD_DIR=/data/uploads
VOLUME ["/data"]
EXPOSE ${PORT}
CMD ["sh", "-c", "uvicorn ${SERVICE_MODULE} --host 0.0.0.0 --port ${PORT}"]
