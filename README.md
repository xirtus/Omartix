# Artix Linux + Omarchy (Runit Edition)

Este repositorio contiene un instalador completo para desplegar **Artix Linux (Runit)** con sistema de archivos BTRFS cifrado (LUKS2) y configurar automáticamente la distribución **Omarchy**.

## Estructura del Proyecto

*   `base-install/`: Scripts para instalar el sistema base Artix (Particionamiento, Cifrado, Kernel, Bootloader).
*   `bridge/`: Capa de compatibilidad para adaptar Omarchy (originalmente Systemd) a Artix (Runit).
*   `omarchy-config/`: Archivos de configuración y scripts originales de Omarchy.

## Guía de Instalación

### Requisitos Previos
1.  Arrancar con una ISO de Artix Linux (versión **runit**).
2.  Conexión activa a Internet (WiFi o Ethernet).
3.  Estar conectado a la corriente (si es un portátil).

### Paso 1: Sistema Base
1.  Clona este repositorio o copia la carpeta `artix-omarchy-repo` a la máquina en vivo.
2.  Entra en la carpeta de instalación base:
    ```bash
    cd artix-omarchy-repo/base-install
    ```
3.  Ejecuta el instalador maestro:
    ```bash
    ./install.sh
    ```
    *   Sigue las instrucciones en pantalla para seleccionar el disco y establecer contraseñas.
    *   Al finalizar, escribe `reboot` y retira el USB.

### Paso 2: Instalación de Omarchy
Una vez hayas reiniciado y logueado en tu nuevo sistema Artix (pantalla negra/TTY):

1.  Vuelve a clonar o copiar este repositorio (ya que el disco se borró).
    *   *Nota: Si instalaste git en el paso anterior, puedes clonarlo directamente.*
2.  Navega a la carpeta del "puente":
    ```bash
    cd artix-omarchy-repo/bridge
    ```
3.  Ejecuta el instalador de Omarchy adaptado:
    ```bash
    ./install-omarchy.sh
    ```
    *   Este script instalará los paquetes necesarios, activará la capa de compatibilidad `systemctl-shim` y aplicará las configuraciones.

## Notas Técnicas

*   **UEFI:** El instalador está diseñado exclusivamente para sistemas UEFI.
*   **Docker:** Se crea un subvolumen especial `@docker` optimizado (No-COW) en `/var/lib/docker`.
*   **Compatibilidad:** Se usa un *shim* personalizado para interceptar llamadas de `systemctl` y traducirlas a comandos de `runit` (sv), asegurando que los servicios de Omarchy funcionen correctamente.
