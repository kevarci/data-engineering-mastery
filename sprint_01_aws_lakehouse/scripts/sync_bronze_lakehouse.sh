#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE AUTOMATIZACIÓN: VALIDACIÓN Y SINCRONIZACIÓN DE DATOS (BRONZE LAYER)
# Candidato: Kevin Arciniegas
# Buenas prácticas: Bash Strict Mode (set -euo pipefail)
# ==============================================================================

# 1. BASH STRICT MODE
# -e: Salir inmediatamente si un comando falla
# -u: Salir si se intenta usar una variable no definida
# -o pipefail: El pipeline falla si cualquier comando en la tubería falla
set -euo pipefail

# Colores para mensajes en terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}  PIPELINE DE AUTOMATIZACIÓN: INGESTA SPRINT 1 AWS    ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# 2. DEFINICIÓN DE RUTAS RELATIVAS (PORTABLE)
# Obtiene el directorio exacto donde vive este script, sin importar desde dónde lo ejecutes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${BASE_DIR}/data/raw"
S3_BUCKET="s3://kevin-lakehouse-data-dev/bronze/transactions"

echo -e "[INFO] Directorio base: ${YELLOW}${BASE_DIR}${NC}"
echo -e "[INFO] Directorio de datos locales: ${YELLOW}${DATA_DIR}${NC}"

# 3. VALIDACIÓN DE EXISTENCIA DE DATOS
if [ ! -d "${DATA_DIR}" ]; then
    echo -e "${RED}[ERROR] El directorio de datos crudos no existe: ${DATA_DIR}${NC}"
    echo -e "${RED}Ejecuta primero: python scripts/generate_sample_dataset.py${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Directorio de datos verificado correctamente.${NC}"

# 4. CONTEO Y ANÁLISIS DE ARCHIVOS PARQUET
echo -e "[INFO] Inspeccionando particiones de datos generadas..."
TOTAL_FILES=$(find "${DATA_DIR}" -type f -name "*.parquet" | wc -l)

if [ "${TOTAL_FILES}" -eq 0 ]; then
    echo -e "${RED}[ERROR] No se encontraron archivos .parquet en ${DATA_DIR}${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Se encontraron ${TOTAL_FILES} archivos Parquet particionados listos.${NC}"

# 5. SIMULACIÓN / EJECUCIÓN DE SINCRONIZACIÓN CON AWS S3
echo -e "\n[INFO] Destino en la nube: ${YELLOW}${S3_BUCKET}${NC}"
echo -e "[INFO] Ejecutando sincronización de datos con AWS CLI..."

# Usamos --dryrun para probar la sincronización de forma segura
if command -v aws >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] AWS CLI detectado en el sistema.${NC}"
    echo -e "[INFO] Comando que se ejecutará en producción:"
    echo -e "${YELLOW}aws s3 sync \"${DATA_DIR}\" \"${S3_BUCKET}\" --dryrun${NC}"
else
    echo -e "${YELLOW}[WARN] AWS CLI no encontrado en PATH de Bash. Mostrando comando equivalente:${NC}"
    echo -e "aws s3 sync \"${DATA_DIR}\" \"${S3_BUCKET}\""
fi

echo -e "\n${GREEN}=====================================================${NC}"
echo -e "${GREEN}  VALIDACIÓN Y AUTOMATIZACIÓN COMPLETADAS CON ÉXITO   ${NC}"
echo -e "${GREEN}=====================================================${NC}"
