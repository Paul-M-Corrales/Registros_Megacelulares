# MegaCelulares · Gestión de Órdenes

Sistema de gestión de órdenes de reparación para MegaCelulares (San Martín 370, Luján de Cuyo, Mendoza). Reemplaza la hoja de papel manuscrita por una app web con base de datos de clientes, historial de reparaciones, orden imprimible por duplicado y envío directo a WhatsApp.

## Stack

- **Frontend**: HTML + CSS + JavaScript vanilla, un solo archivo (`index.html`), sin build step.
- **Backend / base de datos**: [Supabase](https://supabase.com) (Postgres + Auth + Row Level Security).
- **Hosting**: [Vercel](https://vercel.com), dominio propio `megacelulares1.com`.
- **Cliente de Supabase**: cargado vía CDN (`@supabase/supabase-js@2`), no requiere `npm install` ni build.

## Estructura del repo

```
/
├── index.html    # La app completa (UI + lógica + logo embebido en base64)
├── schema.sql    # Esquema de base de datos para correr en Supabase (SQL Editor)
└── README.md     # Este archivo
```

## Funcionalidades

- **Nueva orden**: formulario con datos del cliente, datos del equipo (marca, modelo, IMEI, N° de serie, PIN, estado al recibir), tipo de orden (Presupuesto / Reparación / Diagnóstico) y montos.
- **Autocompletado de clientes**: al escribir el nombre, si el cliente ya existe se sugiere y se auto-completan sus datos de contacto (DNI, teléfono, WhatsApp). Los datos del equipo siempre se cargan de cero. Cada orden nueva se asocia al mismo `client_id`, por lo que se acumula en su historial.
- **Garantía fija**: siempre se guarda como `"30 días"` (no editable desde la UI).
- **Código de orden**: se genera de forma atómica en Postgres vía la función `next_repair_code()` (formato `REP-YYMM-0001`), evitando colisiones si dos personas cargan órdenes al mismo tiempo.
- **Impresión por duplicado**: genera una hoja en blanco y negro con el formato "Reporte del Servicio Técnico", con los datos de la orden, la cláusula legal de 60 días para retirar el equipo, y el patrón de desbloqueo en blanco (lo dibuja el cliente a mano). Imprime dos copias en la misma hoja: "Original para el taller" y "Duplicado para el cliente".
- **WhatsApp**: botón que abre `wa.me` con el número del cliente y un mensaje prellenado con los datos de la orden.
- **Historial de clientes**: búsqueda por nombre / DNI / teléfono, con las órdenes de cada cliente y su estado (Recibido / En reparación / Listo / Entregado) editable en el momento.
- **Login**: pantalla de acceso con email/contraseña (Supabase Auth). Sin sesión válida, la app no carga ningún dato.

## Puesta en marcha desde cero

### 1. Crear el proyecto en Supabase

1. Crear una cuenta/organización en [supabase.com](https://supabase.com) y un nuevo proyecto.
2. Ir a **SQL Editor → New query**, pegar el contenido completo de `schema.sql` y ejecutar (`Run`). Esto crea las tablas `clients` y `repairs`, la función `next_repair_code()`, y las políticas de Row Level Security.
3. Ir a **Authentication → Users → Add user** y crear un usuario (email + contraseña) por cada persona del taller que vaya a usar la app.
4. Ir a **Project Settings → API** y copiar:
   - `Project URL`
   - `anon public` key

### 2. Configurar el frontend

Abrir `index.html` y completar, cerca del final del archivo (dentro del `<script>` principal):

```js
const SUPABASE_URL = "https://xxxxxxxx.supabase.co";
const SUPABASE_ANON_KEY = "ey.........";
```

> La `anon key` es pública por diseño (viaja en el HTML del cliente), la protección real está en las políticas RLS de `schema.sql`, que exigen `auth.role() = 'authenticated'` para leer o escribir cualquier fila.

### 3. Deploy en Vercel

1. Subir el repo a GitHub (o arrastrar la carpeta directo en `vercel.com/new`).
2. Importar el repo en Vercel. No requiere configuración de build (es un sitio estático).
3. En **Settings → Domains**, agregar `megacelulares1.com` y seguir las instrucciones de DNS que da Vercel (se configuran en el proveedor donde se compró el dominio).

## Modelo de datos

**`clients`**
| columna | tipo | notas |
|---|---|---|
| id | uuid | PK |
| name | text | |
| dni | text | único cuando no es null (evita duplicados) |
| phone | text | |
| whatsapp | text | |
| created_at | timestamptz | |

**`repairs`**
| columna | tipo | notas |
|---|---|---|
| id | uuid | PK |
| code | text | único, generado por `next_repair_code()` |
| client_id | uuid | FK → `clients.id` |
| order_date, due_date | date | |
| brand, model, work_requested, equipment_state, imei, serial, pin | text | |
| type_presupuesto, type_reparacion, type_diagnostico | boolean | |
| monto, senia, garantia | text | `garantia` siempre `"30 días"` |
| status | text | Recibido / En reparación / Listo / Entregado |
| shop_name | text | default `"MegaCelulares"` |
| created_at | timestamptz | |

## Seguridad

- RLS habilitado en ambas tablas: solo usuarios autenticados (`auth.role() = 'authenticated'`) pueden leer o escribir.
- No hay rol anónimo con permisos — sin login, la app no trae ni un registro.
- La `anon key` de Supabase es segura de exponer en el cliente; **nunca** exponer la `service_role key` en el frontend.

## Limitaciones conocidas / posibles mejoras futuras

- El logo se imprime a color sobre fondo negro; en impresoras sin buena capacidad de color puede consumir más tinta de la esperada. Si hace falta, se puede generar una variante del logo en blanco y negro solo para la versión impresa.
- El plan gratuito de Supabase pausa el proyecto luego de 7 días sin actividad (se reactiva solo, tarda unos segundos). No debería ser un problema con uso diario del local.
- No hay backup automático propio más allá de lo que ofrece Supabase en el plan gratuito — considerar exportar la tabla `repairs`/`clients` periódicamente si el volumen de datos crece.
- El texto legal de la orden (plazo de 60 días, cláusula de equipos mojados, etc.) fue provisto por el cliente a partir de una plantilla que ya usaban; no fue revisado por un abogado. Se recomienda una revisión legal antes de un uso a gran escala.

## Desarrollado por Paúl Matías Corrales
