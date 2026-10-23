# ==============================================================================
# Dockerfile: Pipeline de Datos Multi-Contenedor (DataOps Drill 02)
# Estudiante: Kevin Stick Arciniegas Marquez
# Base: Python 3.12 Slim (Ultraliviana, Segura y con Layer Caching)
# ==============================================================================

# 1. Imagen base oficial ultraliviana (Linux Debian bookworm-slim con Python 3.12)
FROM python:3.12-slim

# 2. Configuración de entorno:
# PYTHONUNBUFFERED=1 garantiza que los logs aparezcan de inmediato en la terminal sin buffering
ENV PYTHONUNBUFFERED=1

# 3. Directorio de trabajo interno del contenedor
WORKDIR /app

# 4. Buenas prácticas de Layer Caching:
# Copiar requirements.txt e instalar dependencias ANTES del código.
# Si el código cambia pero las librerías no, Docker reutiliza esta capa en caché en 0 segundos.
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# 5. Crear la estructura interna de directorios
RUN mkdir -p /app/scripts /app/data/output

# 6. Copiar los scripts de ejecución al contenedor
COPY scripts/ /app/scripts/

# 7. Punto de entrada por defecto
ENTRYPOINT ["python", "/app/scripts/compose_pipeline_runner.py"]
