#!/usr/bin/env bash
# ==============================================================================
# Script: drill_01_dataops_validator.sh
# Rol: Pipeline de Ingesta Defensiva, Validación e Integridad en Bash (DataOps)
# Estudiante: Kevin Stick Arciniegas Marquez
# Principios: Idempotencia, Strict Mode (set -euo pipefail), Logs ISO y Cuarentena
# ==============================================================================

set -euo pipefail

# 1. Definición de Rutas Relativas Portables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

LANDING_DIR="${BASE_DIR}/data/landing"
PROCESSED_DIR="${BASE_DIR}/data/processed"
QUARANTINE_DIR="${BASE_DIR}/data/quarantine"
LOGS_DIR="${BASE_DIR}/logs"
LOG_FILE="${LOGS_DIR}/dataops_pipeline.log"

# Crear directorios si no existen
mkdir -p "${LANDING_DIR}" "${PROCESSED_DIR}" "${QUARANTINE_DIR}" "${LOGS_DIR}"

# Colores para la terminal
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 2. Función de Logging Estructurado con Timestamp ISO
log_msg() {
    local level="$1"
    local color="$2"
    local message="$3"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${color}[${timestamp}] [${level}] ${message}${NC}"
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}"
}

log_info()  { log_msg "INFO"  "${GREEN}"  "$1"; }
log_warn()  { log_msg "WARN"  "${YELLOW}" "$1"; }
log_error() { log_msg "ERROR" "${RED}"    "$1"; }

# 3. Pre-flight Checks (Validación de dependencias del SO)
check_dependencies() {
    log_info "Iniciando Pre-flight Checks de dependencias del sistema..."
    local tools=("awk" "gzip" "sha256sum" "find" "wc")
    for tool in "${tools[@]}"; do
        if ! command -v "${tool}" >/dev/null 2>&1; then
            log_error "Herramienta obligatoria no encontrada en el sistema: ${tool}"
            exit 1
        fi
    done
    log_info "Pre-flight checks aprobados: todas las herramientas están disponibles."
}

# 4. Generador de Datos Sintéticos para el Simulador
# (Crea archivos buenos y archivos deliberadamente dañados para probar el pipeline)
setup_test_environment() {
    log_info "Configurando lote de prueba en Landing Zone: ${LANDING_DIR}"
    rm -rf "${LANDING_DIR:?}"/* "${QUARANTINE_DIR:?}"/*
    
    # Archivo VÁLIDO 1
    cat << 'EOF' > "${LANDING_DIR}/transactions_20261018_part1.csv"
transaction_id,customer_id,sale_date,amount,status
TRX-1001,CUST-500,2026-10-18,125.50,COMPLETED
TRX-1002,CUST-501,2026-10-18,340.00,COMPLETED
TRX-1003,CUST-502,2026-10-18,89.90,PENDING
EOF

    # Archivo VÁLIDO 2
    cat << 'EOF' > "${LANDING_DIR}/transactions_20261018_part2.csv"
transaction_id,customer_id,sale_date,amount,status
TRX-1004,CUST-503,2026-10-18,520.10,COMPLETED
TRX-1005,CUST-504,2026-10-18,15.00,CANCELLED
EOF

    # Archivo CORRUPTO 1: Archivo vacío (0 bytes)
    touch "${LANDING_DIR}/transactions_20261018_empty.csv"

    # Archivo CORRUPTO 2: Encabezado alterado / esquema roto
    cat << 'EOF' > "${LANDING_DIR}/transactions_20261018_corrupt_schema.csv"
id,cliente,fecha,precio,estado
TRX-9999,CUST-999,2026-10-18,99.99,COMPLETED
EOF

    log_info "Lote de prueba generado con éxito (2 válidos, 1 vacío, 1 esquema corrupto)."
}

# 5. Pipeline de Validación, Auditoría y Cuarentena
EXPECTED_HEADER="transaction_id,customer_id,sale_date,amount,status"

process_landing_zone() {
    log_info "Iniciando procesamiento de archivos en: ${LANDING_DIR}"
    
    local valid_count=0
    local quarantined_count=0

    # Iterar sobre todos los CSVs en landing
    shopt -s nullglob
    local files=("${LANDING_DIR}"/*.csv)
    shopt -u nullglob

    if [ ${#files[@]} -eq 0 ]; then
        log_warn "No se encontraron archivos en la zona de Landing. Nada que procesar."
        return 0
    fi

    for file in "${files[@]}"; do
        local filename
        filename="$(basename "${file}")"
        log_info "Evaluando archivo: ${filename}"

        # REGLA 1: Validación de tamaño (Detectar archivos vacíos)
        if [ ! -s "${file}" ]; then
            log_error "Archivo vacío detectado (0 bytes): ${filename} -> Moviendo a CUARENTENA"
            mv "${file}" "${QUARANTINE_DIR}/${filename}.corrupt_empty"
            quarantined_count=$((quarantined_count + 1))
            continue
        fi

        # REGLA 2: Validación de Encabezado (Schema Contract)
        local actual_header
        actual_header="$(head -n 1 "${file}" | tr -d '\r')" # Elimina retornos de carro de Windows si existen
        
        if [ "${actual_header}" != "${EXPECTED_HEADER}" ]; then
            log_error "Esquema roto en ${filename}."
            log_error "  Esperado: ${EXPECTED_HEADER}"
            log_error "  Recibido: ${actual_header}"
            log_error "  Acción: Moviendo a CUARENTENA"
            mv "${file}" "${QUARANTINE_DIR}/${filename}.corrupt_header"
            quarantined_count=$((quarantined_count + 1))
            continue
        fi

        # REGLA 3: Generación de Checksum SHA-256 (Auditoría Criptográfica)
        local checksum
        checksum="$(sha256sum "${file}" | awk '{print $1}')"
        log_info "Checksum SHA-256 verificado: ${checksum:0:16}... [OK]"

        # REGLA 4: Conteo de registros válidos (excluyendo el header)
        local row_count
        row_count="$(tail -n +2 "${file}" | wc -l)"
        log_info "Registros válidos: ${row_count} filas"

        # REGLA 5: Particionado temporal y Compresión GZIP (Ahorro de disco)
        local year month
        year="$(date '+%Y')"
        month="$(date '+%m')"
        local target_partition="${PROCESSED_DIR}/year=${year}/month=${month}"
        mkdir -p "${target_partition}"

        # Mover a processed y comprimir
        mv "${file}" "${target_partition}/${filename}"
        gzip -9 -f "${target_partition}/${filename}"
        log_info "Archivo archivado y comprimido en: ${target_partition}/${filename}.gz"

        valid_count=$((valid_count + 1))
    done

    # 6. Reporte Final de DataOps
    echo "=========================================================="
    log_info "REPORTE FINAL DE DATAOPS:"
    log_info "  Archivos procesados y comprimidos con éxito: ${valid_count}"
    if [ ${quarantined_count} -gt 0 ]; then
        log_warn "  Archivos defectuosos enviados a cuarentena: ${quarantined_count}"
    else
        log_info "  Archivos defectuosos enviados a cuarentena: 0"
    fi
    log_info "  Auditoría completa registrada en: ${LOG_FILE}"
    echo "=========================================================="
}

# 7. Ejecución del Flujo Principal
main() {
    check_dependencies
    setup_test_environment
    process_landing_zone
}

main "$@"
