# 📓 Cuaderno de Cátedra: Infra & DataOps (Bash Scripting & Automatización Cloud)

> **Instructor:** Ingeniero Senior / Career Coach Técnico  
> **Estudiante:** Kevin Stick Arciniegas Marquez  
> **Bloque 3:** Infra & DataOps (Automatización de Pipelines y Herramientas Cloud)  
> **Herramientas de Práctica:** Linux Bash / Git Bash, AWS CLI, Docker, Terminal Antigravity

---

## 📑 Índice de Contenidos
1. [El Rol de Bash en la Ingeniería de Datos Moderna](#1-el-rol-de-bash-en-la-ingeniería-de-datos-moderna)
2. [El Gran Peligro de Bash y el "Strict Mode" (`set -euo pipefail`)](#2-el-gran-peligro-de-bash-y-el-strict-mode-set--euo-pipefail)
3. [Patrones de Scripting Defensivo y Portabilidad](#3-patrones-de-scripting-defensivo-y-portabilidad)
4. [Tuberías de Alto Rendimiento: `find`, `wc` y `xargs`](#4-tuberías-de-alto-rendimiento-find-wc-y-xargs)
5. [Automatización Cloud con AWS CLI: `sync` vs `cp`](#5-automatización-cloud-con-aws-cli-sync-vs-cp)
6. [Preguntas Clave de Entrevistas de DataOps / Infra](#6-preguntas-clave-de-entrevistas-de-dataops--infra)

---

## 1. El Rol de Bash en la Ingeniería de Datos Moderna

En la vida real, los pipelines de datos **no se ejecutan con clics de mouse**:
* Corren en contenedores de **Docker**, pods de **Kubernetes**, instancias **AWS EC2** o tareas programadas de **Apache Airflow** a las 3:00 AM.
* Ninguno de esos servidores tiene pantalla ni interfaz gráfica. Todo se controla mediante **Bash** y la línea de comandos de Linux.

> **Regla Senior:**  
> Un Data Engineer que no sabe Bash depende de herramientas manuales. Un Data Engineer que domina Bash puede conectar cualquier base de datos, archivo o servicio en la nube y automatizarlo de punta a punta.

---

## 2. El Gran Peligro de Bash y el "Strict Mode" (`set -euo pipefail`)

Por defecto, los intérpretes de Bash en Linux tienen un comportamiento riesgoso:  
**Si un comando falla en la línea 2, Bash ignora el error y continúa ejecutando la línea 3, 4 y 5 como si nada hubiera pasado.**

### El Desastre Típico en Producción:
```bash
# Script descuidado sin protección:
cd /directorio_de_archivos_temporales   # <-- Supón que esta carpeta no existe y da error
rm -rf *                               # <-- ¡DESASTRE! Borraste la carpeta actual donde estabas parado
```

Para evitar esto, todo pipeline profesional inicia obligatoriamente con el **Bash Strict Mode**:

```bash
set -euo pipefail
```

### ¿Qué hace cada bandera? (Pregunta obligatoria de entrevistas):

| Bandera | Nombre Técnico | Comportamiento en Producción |
| :--- | :--- | :--- |
| **`-e`** | *Exit on Error* | Si **cualquier comando** devuelve un código de error (distinto de 0), el script se aborta inmediatamente. Nunca continúa a ciegas. |
| **`-u`** | *Unset Variables* | Si intentas usar una variable no definida o con un error tipográfico (ej. `$PATH_DATA` en vez de `$DATA_PATH`), el script se detiene en seco en vez de asumir que vale vacío `""`. |
| **`-o pipefail`** | *Pipeline Failure* | En una tubería (`comando1 \| comando2`), si `comando1` falla pero `comando2` tiene éxito, Bash normalmente reporta éxito. Con `pipefail`, si **cualquier eslabón** de la tubería falla, todo el comando se marca como error. |

---

## 3. Patrones de Scripting Defensivo y Portabilidad

En nuestro script [`sync_bronze_lakehouse.sh`](file:///c:/Users/pc/Desktop/Proyectos%20BigData/mastery-lab/sprint_01_aws_lakehouse/scripts/sync_bronze_lakehouse.sh) implementamos 3 reglas fundamentales:

### 1. Rutas Dinámicas y Portables
```bash
# Obtiene el directorio exacto donde vive este script, sin importar desde dónde lo ejecutes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DATA_DIR="${BASE_DIR}/data/raw"
```
* **El error de un Junior:** Poner rutas fijas como `C:\Users\pc\Desktop\...`. Si ese script lo subes a un contenedor Docker en Linux o a una máquina virtual en AWS, colapsa inmediatamente.
* **La Solución Senior:** Esta línea le pregunta dinámicamente al sistema operativo dónde está el script y calcula las rutas relativas. Funciona en Windows (Git Bash), Mac y Linux.

### 2. Validación Defensiva de Insumos
Antes de tocar cualquier dato, valida que los directorios existan:
```bash
if [ ! -d "${DATA_DIR}" ]; then
    echo -e "[ERROR] El directorio de datos crudos no existe: ${DATA_DIR}"
    echo -e "Ejecuta primero: python scripts/generate_sample_dataset.py"
    exit 1
fi
```
* El operador `! -d` verifica si el directorio NO existe y sale con código `exit 1` (error).

---

## 4. Tuberías de Alto Rendimiento: `find`, `wc` y `xargs`

Para auditar y mover particiones de datos sin abrir miles de archivos en memoria:

```bash
# Inspección y conteo recursivo de archivos Parquet particionados
TOTAL_FILES=$(find "${DATA_DIR}" -type f -name "*.parquet" | wc -l)
```

* **`find "${DATA_DIR}" -type f -name "*.parquet"`**: Recorre todas las subcarpetas del particionado (`year=2026/month=10/day=DD/`) y lista los archivos que coinciden con el patrón.
* **`| wc -l`**: Pasa la lista por la tubería al comando *word count* con la bandera `-l` (lines) para contar cuántos archivos existen.
* En nuestra ejecución de prueba, detectó y validó los **29 archivos Parquet** en 0.05 segundos.

---

## 5. Automatización Cloud con AWS CLI: `sync` vs `cp`

### ¿Por qué nunca usamos `aws s3 cp --recursive` para sincronizar datos masivos?

| Comando | Comportamiento | Impacto en Costo y Red |
| :--- | :--- | :--- |
| **`aws s3 cp --recursive`** | Copia **todos los archivos** ciegamente una y otra vez, incluso si ya existen en S3. | 🔴 Desperdicia ancho de banda, satura la red y aumenta costos de peticiones en AWS. |
| **`aws s3 sync`** | Es **idempotente**. Compara el origen y el destino (usando marcas de tiempo y tamaño) y **solo sube los archivos nuevos o modificados**. | 🟢 Óptimo: Ahorra el 90%+ de transferencias en ejecuciones recurrentes. |

### El Ensayo General con `--dryrun`:
En producción, antes de mover terabytes a la nube, siempre se prueba la sincronización con el flag de seguridad:
```bash
aws s3 sync "/ruta/local/data/raw" "s3://kevin-lakehouse-data-dev/bronze/transactions" --dryrun
```
* **`--dryrun`**: Muestra exactamente qué archivos subiría o borraría, **sin tocar nada ni transferir un solo byte**. Una vez verificado el log, se quita la bandera para ejecutar la subida real.

---

## 6. Arquitectura de Ingesta Defensiva: Checksums, Contrato de Esquema y Cuarentena

En nuestro laboratorio práctico [`drill_01_dataops_validator.sh`](file:///c:/Users/pc/Desktop/Proyectos%20BigData/mastery-lab/daily_drills/bash_scripting/scripts/drill_01_dataops_validator.sh) implementamos el patrón estándar de la industria conocido como **"Dead-Letter Dropzone & Defensive Ingestion"**:

```
[Proveedores / SFTP / Landing Zone]
                 │
                 ▼
       ┌──────────────────┐
       │ ¿Es de 0 bytes?  │ ──── SÍ ────► [data/quarantine/] (Alerta)
       └──────────────────┘
                 │ NO
                 ▼
       ┌──────────────────┐
       │ ¿Esquema coincide│ ──── NO ────► [data/quarantine/] (Alerta)
       │ con el Contrato? │
       └──────────────────┘
                 │ SÍ
                 ▼
       ┌──────────────────┐
       │ Huella Cripto    │ ────► Registro en logs/dataops_pipeline.log
       │ SHA-256 Checksum │
       └──────────────────┘
                 │
                 ▼
       ┌──────────────────┐
       │ Particionado por │
       │ Fecha & GZIP -9  │ ────► [data/processed/year=YYYY/month=MM/]
       └──────────────────┘
```

### Las 5 Reglas de Oro Implementadas:

1. **Detección de Archivos Vacíos (`[ ! -s "$file" ]`):**  
   Si una transferencia SFTP se interrumpe y deja un archivo de 0 bytes, el operador `! -s` lo detecta al instante antes de que rompa los lectores de PySpark.
2. **Contrato de Esquema (*Schema Contract* con `head -n 1`):**  
   Compara los nombres exactos y el orden de las columnas esperadas. Si un proveedor añade o renombra columnas sin previo aviso, el archivo no pasa.
3. **Firma Criptográfica SHA-256 (`sha256sum`):**  
   Genera una huella digital única e inmutable de 64 caracteres hexadecimales. Permite demostrar ante auditorías SOX o financieras que los datos en el Lakehouse son idénticos a los recibidos en origen.
4. **Zona de Cuarentena (*Dead-Letter Dropzone*):**  
   En vez de detener todo el pipeline y no procesar nada, el script aísla el archivo defectuoso en `quarantine/` para investigación manual, y permite que los archivos válidos continúen hacia el Lakehouse.
5. **Compresión Atómica `gzip -9`:**  
   Reduce el tamaño de los CSVs entre un **75% y un 85%**, ahorrando costos de almacenamiento en Amazon S3 y reduciendo drásticamente el tiempo de transferencia por red.

---

## 7. Preguntas Clave de Entrevistas de DataOps / Infra

### P1: "¿Qué significa que un script o pipeline sea 'idempotente'?"
> **Respuesta Senior:**  
> La idempotencia es la propiedad de que un pipeline o script pueda ejecutarse una, dos o cien veces consecutivas produciendo exactamente el mismo resultado final sin generar datos duplicados ni errores. Por ejemplo, `aws s3 sync` o una operación `MERGE INTO` en Delta Lake son idempotentes; un simple `INSERT INTO` o `cp` no lo son, porque duplicarían los registros.

### P2: "¿Por qué incluir `set -euo pipefail` en un script de Bash si en local todo corre bien?"
> **Respuesta Senior:**  
> Porque en entornos locales uno suele supervisar la terminal, pero en producción los scripts corren desatendidos dentro de contenedores o tareas de Airflow. Si un comando de descarga de datos falla silenciosamente, un script sin `set -e` continuaría ejecutando las transformaciones sobre archivos vacíos, corrompiendo las tablas analíticas y generando reportes financieros con datos incompletos.

### P3: "¿Cómo manejas archivos corruptos en una Landing Zone sin tumbar el pipeline de producción?"
> **Respuesta Senior:**  
> Implementando un patrón de zona de cuarentena (*Dead-Letter Dropzone*). El script de Bash inspecciona cada archivo entrante validando que no esté vacío (`[ -s ]`) y que cumpla el contrato de esquema en la primera línea. Si un archivo falla, se mueve inmediatamente a `quarantine/` y se emite una alerta, permitiendo que el resto de los archivos sanos del lote se compriman y se carguen al Lakehouse sin detener la operación de la empresa.

### P4: "¿Qué trampa ocurre al usar `((count++))` en un script con `set -e` y cómo se soluciona?"
> **Respuesta Senior:**  
> Cuando `count` vale `0`, el post-incremento devuelve su valor previo (`0`). En la evaluación aritmética de Bash `(( 0 ))` retorna el código de salida **1** (que significa falso). Al estar activo `set -e`, Bash interpreta ese código 1 como un fallo fatal y aborta el script silenciosamente. La solución estándar en producción es usar la sintaxis POSIX inofensiva `count=$((count + 1))` o pre-incremento `(( ++count ))`.
