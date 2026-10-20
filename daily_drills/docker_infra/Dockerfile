# ==============================================================================
# Dockerfile: Pipeline de Datos Containerizado (DataOps Drill 01)
# Estudiante: Kevin Stick Arciniegas Marquez
# Base: Python 3.12 Slim (Ultraliviana y Segura)
# ==============================================================================

# 1. Imagen base oficial ultraliviana (apenas ~150 MB vs 1 GB de la estándar)
FROM python:3.12-slim

# 2. Configuración de entorno:
# PYTHONUNBUFFERED=1 garantiza que los logs aparezcan de inmediato en la terminal sin retraso
ENV PYTHONUNBUFFERED=1

# 3. Directorio de trabajo interno del contenedor
WORKDIR /app

# 4. Estructura interna de directorios
RUN mkdir -p /app/scripts /app/data

# 5. Copiar el script de ejecución
COPY scripts/pipeline_runner.py /app/scripts/

# 6. Punto de entrada (El contenedor corre este comando automáticamente al arrancar)
ENTRYPOINT ["python", "/app/scripts/pipeline_runner.py"]
