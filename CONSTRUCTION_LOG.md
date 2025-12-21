# Registro de Construcción: Artix Omarchy (Runit Edition)

Este documento resume la arquitectura, decisiones de diseño y correcciones críticas implementadas durante la creación de este instalador. Sirve como contexto para futuras modificaciones.

## 1. Arquitectura del Sistema
*   **Base:** Artix Linux (Edición Runit).
*   **Kernel:** Linux (estándar) con microcódigo dual (Intel/AMD).
*   **Sistema de Archivos:** BTRFS con compresión `zstd:1` y subvolúmenes optimizados.
*   **Cifrado:** LUKS2 (AES-XTS-Plain64).
*   **Bootloader:** Limine (UEFI Fallback mode).
*   **Configuración:** Omarchy Distribution (adaptada mediante capa de compatibilidad).

## 2. Características Implementadas (Fase 1: Base)
*   **BTRFS Layout:**
    *   `@`: Root.
    *   `@home`: Datos de usuario.
    *   `@snapshots`: Integración con Snapper.
    *   `@docker`: **No-COW** (`chattr +C`) para rendimiento óptimo de contenedores.
    *   `@pkg`, `@log`, `@tmp`: Excluidos de snapshots para ahorrar espacio.
*   **Resiliencia:**
    *   Detección inteligente de particiones para discos NVMe/eMMC (`p1`, `p2`) vs SATA (`1`, `2`).
    *   Habilitación de `ParallelDownloads` para instalaciones rápidas.
    *   Actualización forzada de keyrings antes de instalar para evitar errores de firma GPG.
*   **UEFI:** Instalación en ruta `Fallback` (`/EFI/BOOT/BOOTX64.EFI`) para máxima portabilidad sin depender de variables NVRAM.
*   **Optimización:**
    *   **ZRAM:** Swap comprimido en RAM (50% de capacidad) mediante servicio Runit nativo.
    *   **NVIDIA:** Instalación automática de drivers DKMS y configuración de DRM/KMS para Wayland/Hyprland.
    *   **SSD:** Script semanal de `fstrim` vía cron.

## 3. Capa de Compatibilidad (Fase 2: Bridge)
*   **Systemctl Shim:**
    *   Intercepta comandos `systemctl` y los traduce a `sv` (Runit).
    *   Gestiona la **persistencia** vinculando servicios a `/etc/runit/runsvdir/default`.
    *   Mapea nombres de servicios de Systemd a Runit (ej: `bluetooth` -> `bluetoothd`).
*   **Patching Dinámico:**
    *   `patch-packages.sh`: Modifica las listas de paquetes de Omarchy para inyectar versiones `-runit`.
    *   `sed` runtime: Reemplaza referencias a `systemd-networkd/resolved` por `NetworkManager` en los scripts de Omarchy.

## 4. Flujo de Trabajo para el Usuario
1.  **Boot Live:** Usar `connmanctl` para red.
2.  **Fase 1:** `./install.sh` (Base). El instalador se copia automáticamente a `~/artix-installer`.
3.  **Fase 2:** `./bridge/install-omarchy.sh` (Configuración). Usa `nmtui` para red.

## 5. Notas para el Futuro
*   **Añadir Software:** Si se añaden aplicaciones que dependan de servicios, actualizar el `systemctl-shim` con los nuevos mapeos de nombres si difieren de la versión de Arch.
*   **Kernels:** Si se cambia a `linux-lts` o `linux-zen`, recordar actualizar `limine.cfg` y el hook de `nvidia-dkms`.
*   **Multilib:** Ya está habilitado por defecto para dar soporte a Steam/Wine.
