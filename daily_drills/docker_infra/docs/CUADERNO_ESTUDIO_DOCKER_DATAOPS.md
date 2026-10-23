# 📓 Cuaderno de Cátedra: Docker & Contenedores para Data Engineers

> **Instructor:** Ingeniero Senior / Career Coach Técnico  
> **Estudiante:** Kevin Stick Arciniegas Marquez  
> **Bloque 3:** Infra & DataOps (Contenedores, Aislamiento y Persistencia)  
> **Herramientas de Estudio:** Docker Desktop, Docker CLI, Linux Alpine, Python 3.12

---

## 📑 Índice de Contenidos

1. [La Revolución de los Contenedores en Ingeniería de Datos](#1-la-revolución-de-los-contenedores-en-ingeniería-de-datos)
2. [Máquinas Virtuales (VMs) vs Contenedores Docker](#2-máquinas-virtuales-vms-vs-contenedores-docker)
3. [La Anatomía de Docker: Dockerfile, Imagen, Contenedor y Registro](#3-la-anatomía-de-docker)
4. [Persistencia de Datos: El Almacenamiento Efímero vs Docker Volumes](#4-persistencia-de-datos-almacenamiento-efímero-vs-docker-volumes)
5. [Buenas Prácticas para Dockerfiles de Producción](#5-buenas-prácticas-para-dockerfiles-de-producción)
6. [Laboratorio Práctico: Pipeline de Datos Containerizado con Volumen](#6-laboratorio-práctico-pipeline-containerizado)
7. [Orquestación Multi-Contenedor con Docker Compose](#7-orquestación-multi-contenedor-con-docker-compose)
8. [Redes Virtuales Privadas (Bridge) y DNS Interno en Docker](#8-redes-virtuales-privadas-bridge-y-dns-interno-en-docker)
9. [Resiliencia con Healthchecks y Dependencias de Servicio](#9-resiliencia-con-healthchecks-y-dependencias-de-servicio)
10. [Simulador de Preguntas Trampa de Entrevistas](#10-simulador-de-preguntas-trampa-de-entrevistas)

---

## 1. La Revolución de los Contenedores en Ingeniería de Datos

En el pasado, para ejecutar un pipeline de ETL, la empresa debía configurar un servidor con un sistema operativo específico, instalar versiones exactas de Python, drivers de bases de datos ODBC/JDBC y variables de entorno.

### El Desastre Típico en Producción:
* En la laptop del desarrollador (Windows con Python 3.12) el script funciona perfecto.
* Cuando se despliega en el servidor de pruebas (Linux con Python 3.9 y versiones distintas de librerías), el pipeline se rompe a las 3:00 AM.
* **La excusa del Junior:** *"¡Pero si en mi máquina funcionaba!"*
* **La respuesta del Senior:** *"Pues no podemos enviar tu laptop a producción"*.

**Docker elimina este problema para siempre:**  
Empaqueta el código, el sistema operativo Linux mínimo, las librerías exactas y los archivos de configuración en una unidad sellada e inmutable llamada **Contenedor**.

---

## 2. Máquinas Virtuales (VMs) vs Contenedores Docker

Esta es una pregunta fija de arquitectura en entrevistas:

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│     MÁQUINA VIRTUAL (VM)        │       │       CONTENEDOR DOCKER         │
├─────────────────────────────────┤       ├─────────────────────────────────┤
│ [App A]     [App B]     [App C] │       │ [App A]     [App B]     [App C] │
│ (Deps A)    (Deps B)    (Deps C)│       │ (Deps A)    (Deps B)    (Deps C)│
│ [Guest OS]  [Guest OS]  [GuestOS]│      │         [Docker Engine]         │
│         [Hypervisor]            │       │      (Comparte el Kernel)       │
│    [Sistema Operativo Host]     │       │    [Sistema Operativo Host]     │
│        [Hardware Físico]        │       │        [Hardware Físico]        │
└─────────────────────────────────┘       └─────────────────────────────────┘
```

| Característica | Máquina Virtual (VM) | Contenedor Docker |
| :--- | :--- | :--- |
| **Virtualización** | Virtualiza el **Hardware completo**. | Virtualiza a nivel de **Sistema Operativo**. |
| **Sistema Operativo** | Cada VM tiene su propio sistema operativo completo (Guest OS de 5 a 20 GB). | **Comparte el Kernel de Linux del host**. Solo pesa megabytes. |
| **Tiempo de Arranque** | Minutos (debe bootear el SO). | **Milisegundos / Segundos** (solo arranca un proceso). |
| **Consumo de Memoria** | Alto: reserva Gigabytes de RAM fijos. | Ultraliviano: consume solo lo que el proceso necesita. |

---

## 3. La Anatomía de Docker

```
[Dockerfile] ────(docker build)────► [Imagen] ────(docker run)────► [Contenedor]
(El Código)                          (El Paquete)                   (El Proceso Vivo)
```

1. **`Dockerfile`:** El archivo de texto plano con la receta paso a paso para construir el entorno.
2. **Imagen (*Image*):** El molde binario inmutable resultante de compilar el Dockerfile. Contiene el sistema operativo, las dependencias y el código congelados.
3. **Contenedor (*Container*):** Una instancia en ejecución de esa imagen. Puedes lanzar 10 contenedores idénticos a partir de la misma imagen.
4. **Registro (*Docker Hub / AWS ECR*):** El repositorio en la nube donde se suben y versionan las imágenes (como GitHub, pero para contenedores).

---

## 4. Persistencia de Datos: Almacenamiento Efímero vs Docker Volumes

### ⚠️ El Gran Peligro del Almacenamiento Efímero:
Por diseño, la capa de escritura de un contenedor es **efímera (*stateless*)**.  
Si tu pipeline descarga 50 GB de transacciones dentro del contenedor y luego el contenedor se apaga o colapsa:  
**¡TODOS LOS DATOS DENTRO DEL CONTENEDOR SE BORRAN PARA SIEMPRE!**

### ✅ La Solución: Volúmenes y Bind Mounts (`-v`)
Para desacoplar el cómputo del almacenamiento, conectamos una carpeta física de tu computadora (*Host*) dentro del contenedor (*Container*):

```bash
docker run -v "C:/mis_datos/output:/app/data" mi-imagen:1.0
```

* Todo lo que el script escribe en `/app/data` dentro del contenedor se guarda instantáneamente en `C:/mis_datos/output` de tu máquina real.
* Aunque el contenedor se destruya, **los datos procesados sobreviven al 100%**.

---

## 5. Buenas Prácticas para Dockerfiles de Producción

En entrevistas y revisiones de código corporativo, buscan que apliques estas 4 reglas de oro:

### A. Imágenes Base Livianas (`slim` o `alpine`)
* ❌ `FROM python:3.12` (Pesa casi **1 Gigabyte** de librerías innecesarias).
* ✅ `FROM python:3.12-slim` o `FROM python:3.12-alpine` (Pesa apenas **50 a 150 MB**, descarga en segundos y tiene menor superficie de vulnerabilidades de seguridad).

### B. El Truco del Caché de Capas (*Docker Layer Caching*)
Docker ejecuta el Dockerfile de arriba a abajo y **guarda en caché cada línea**:

```dockerfile
# ❌ INEFICIENTE (Rompe la caché cada vez que editas código):
COPY . .
RUN pip install -r requirements.txt

# ✅ ÓPTIMO DE PRODUCCIÓN:
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
```
* Si solo cambias una línea de tu script de Python, Docker no vuelve a descargar las librerías de `requirements.txt`. El build tarda **0.5 segundos** en vez de 3 minutos.

### C. Usuario sin Privilegios de Administrador (Non-root user)
* Por defecto, Docker corre como `root` (superusuario). Si tu contenedor es vulnerado, el atacante podría ganar control del servidor host.
* En producción siempre se crea y activa un usuario sin privilegios: `USER appuser`.

---

## 6. Laboratorio Práctico: Pipeline Containerizado con Volumen

En nuestro ejercicio práctico [`daily_drills/docker_infra/Dockerfile`](file:///c:/Users/pc/Desktop/Proyectos%20BigData/mastery-lab/daily_drills/docker_infra/Dockerfile) implementamos un pipeline real de ingesta:

```dockerfile
# 1. Imagen base oficial ultraliviana
FROM python:3.12-slim

# 2. Variable de entorno para evitar buffering en logs
ENV PYTHONUNBUFFERED=1

# 3. Directorio de trabajo
WORKDIR /app

# 4. Copiar script de procesamiento
COPY scripts/pipeline_runner.py /app/scripts/

# 5. Punto de entrada
ENTRYPOINT ["python", "/app/scripts/pipeline_runner.py"]
```

---

## 7. Orquestación Multi-Contenedor con Docker Compose

En entornos corporativos reales, un pipeline de datos rara vez se ejecuta en el vacío. Requiere interactuar con múltiples servicios simultáneos:
1. **Bases de datos transaccionales (OLTP / Data Warehouses):** PostgreSQL, MySQL, SQL Server, ClickHouse.
2. **Colas de mensajería y caché:** Redis, Apache Kafka, RabbitMQ.
3. **Orquestadores:** Apache Airflow (Scheduler, Webserver, Triggerer, Metastore).

Levantar 4 o 5 contenedores manualmente con comandos `docker run` individuales es propenso a errores humanos, inviable en CI/CD y desordenado.

**Docker Compose** es la herramienta de infraestructura como código (IaC) que permite definir, orquestar y levantar toda la topología de servicios con un único comando:
```bash
docker compose up --build -d
```

---

## 8. Redes Virtuales Privadas (Bridge) y DNS Interno en Docker

### El Error Fatal del Desarrollador Junior:
Cuando un desarrollador junior levanta un contenedor con una base de datos PostgreSQL y otro con su script de Python, escribe en su código:
```python
# ❌ ERROR JUNIOR: Falla con ConnectionRefusedError
conn = psycopg2.connect(host="localhost", port=5432, ...)
```

#### ¿Por qué falla?
Dentro de un contenedor, `localhost` (la dirección `127.0.0.1`) se refiere al **propio contenedor**, no a tu máquina host ni a otros contenedores. Como la base de datos corre en su propio contenedor aislado, el pipeline intenta conectarse a sí mismo y colapsa.

### La Solución Senior: Redes Virtuales (Bridge Network) y DNS Automático
Al declarar una red en `docker-compose.yml`:
```yaml
networks:
  dataops_network:
    driver: bridge
```
Docker crea un switch virtual privado y activa un **servidor DNS interno integrado**. 
Cualquier contenedor conectado a esa red puede resolver y comunicarse con otro contenedor utilizando directamente el **nombre del servicio** como hostname:
```python
# ✅ SOLUCIÓN SENIOR: Resuelto por el DNS interno de Docker
conn = psycopg2.connect(host="postgres_db", port=5432, ...)
```

---

## 9. Resiliencia con Healthchecks y Dependencias de Servicio

### El Problema de la Condición de Carrera (*Race Condition*):
Si configuras simplemente `depends_on: [postgres_db]`, Docker Compose inicia el contenedor de la base de datos y milisegundos después inicia el pipeline de Python.

Sin embargo, aunque el contenedor de PostgreSQL esté "corriendo", el proceso del motor necesita entre 5 y 10 segundos para inicializar los catálogos en disco, cargar extensiones y abrir el socket de red en el puerto 5432.
El script de Python intenta conectarse en el segundo 1 y colapsa con `OperationalError: could not connect to server`.

### La Solución Senior: `condition: service_healthy`
Un Ingeniero Senior implementa un **Healthcheck nativo** en el servicio de la base de datos y condiciona el arranque del pipeline a que ese chequeo sea exitoso:

```yaml
services:
  postgres_db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d mastery_dw"]
      interval: 5s
      timeout: 5s
      retries: 5

  dataops_pipeline:
    depends_on:
      postgres_db:
        condition: service_healthy # Espera hasta que pg_isready responda OK
```

---

## 10. Simulador de Preguntas Trampa de Entrevistas

### P1: "¿Qué sucede con los datos de un pipeline si el contenedor de Docker colapsa por Out Of Memory (OOM)?"
> **Respuesta Senior:**  
> Por defecto, el sistema de archivos de un contenedor es efímero. Si el contenedor se destruye, todos los datos escritos en su capa local se pierden definitivamente. Para evitar esto en ingeniería de datos, siempre desacoplamos el almacenamiento utilizando **Docker Volumes** o montajes tipo bind (`-v`), garantizando que la salida del pipeline persista de forma segura en el host o en almacenamiento en la nube (ej. Amazon S3).

### P2: "¿Por qué en un Dockerfile se copia `requirements.txt` e instala dependencias ANTES de copiar el resto del código?"
> **Respuesta Senior:**  
> Por la estrategia de **Docker Layer Caching**. Docker solo reconstruye las capas que han cambiado. Como las librerías externas rara vez cambian en comparación con el código fuente que se edita constantemente, colocar `COPY requirements.txt` y `RUN pip install` primero permite que Docker reutilice la capa de dependencias en caché, reduciendo el tiempo de build de minutos a fracciones de segundo.

### P3: "¿Cuál es la diferencia entre `CMD` y `ENTRYPOINT` en un Dockerfile?"
> **Respuesta Senior:**  
> `ENTRYPOINT` define el ejecutable inmutable que siempre correrá cuando se inicie el contenedor (por ejemplo, `python main.py`).  
> `CMD` proporciona los argumentos por defecto que se le pasarán a ese ejecutable, los cuales pueden ser fácilmente sobreescritos desde la terminal al ejecutar `docker run` sin modificar la imagen.

### P4: "¿Qué ventajas tiene usar `python:3.12-slim` sobre la imagen oficial completa `python:3.12`?"
> **Respuesta Senior:**  
> La imagen completa pesa cerca de 1 GB porque incluye compiladores C++, utilidades de desarrollo y herramientas de depuración que no se necesitan en tiempo de ejecución. La variante `-slim` pesa alrededor de 150 MB, lo que reduce el tiempo de descarga por red en clústeres de Kubernetes/ECS, minimiza el consumo de disco y reduce drásticamente las vulnerabilidades de seguridad (*CVEs*) al eliminar paquetes superfluos.

### P5: "¿Por qué `depends_on` en Docker Compose no garantiza por sí solo que tu script de Python pueda conectarse a la base de datos?"
> **Respuesta Senior:**  
> Porque por defecto `depends_on` solo espera a que el contenedor de la base de datos alcance el estado *running* a nivel de proceso del sistema operativo. No espera a que el servicio interno (PostgreSQL o MySQL) complete su inicialización, lea los catálogos y esté escuchando en el puerto TCP.  
> Para garantizar que la base de datos esté lista para aceptar conexiones reales, se debe definir un bloque `healthcheck` (por ejemplo usando `pg_isready`) y declarar en el servicio consumidor `depends_on: { service_name: { condition: service_healthy } }`.

### P6: "¿Cómo se comunican dos contenedores en Docker Compose sin exponer puertos hacia la máquina host?"
> **Respuesta Senior:**  
> A través de la **Docker Bridge Network** que Compose crea automáticamente. Docker levanta un switch virtual privado y un servidor DNS interno embebido. Cualquier contenedor en esa red puede conectarse a otro usando su nombre de servicio como hostname (ej. `postgres_db:5432`).  
> La directiva `ports:` (puertos mapeados hacia el host) solo es necesaria si una aplicación externa en el host (como DBeaver o Power BI) necesita ingresar; la comunicación entre contenedores dentro de la red virtual es completamente interna y segura sin necesidad de mapeo de puertos públicos.
