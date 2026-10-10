# Backend de Licencias Node-Locked

Backend para la validación, activación y supervisión de licencias vinculadas a hardware (HWID) con Node.js, Express y PostgreSQL.

## Estructura del Proyecto

```text
backend/
├── db/
│   └── schema.sql        # Esquema de base de datos PostgreSQL
├── src/
│   ├── routes/
│   │   ├── auth.js       # Endpoints públicos: /auth y /heartbeat
│   │   └── admin.js      # Endpoints de administración: /keys, /ban, /reset-hwid
│   ├── db.js             # Pool de conexión a PostgreSQL
│   ├── jwt.js            # Firma y verificación de tokens JWT
│   ├── keygen.js         # Generación de claves con formato XXXX-XXXX-XXXX
│   ├── middleware.js     # Autenticación JWT y validación x-admin-token
│   └── index.js          # Punto de entrada de la aplicación Express
├── .env                  # Variables de entorno
└── package.json
```

## Requisitos Previos

- [Node.js](https://nodejs.org/) (versión 18 o superior recomendada)
- [PostgreSQL](https://www.postgresql.org/)

## Configuración y Puesta en Marcha

1. **Instalar dependencias**:
   ```bash
   cd backend
   npm install
   ```

2. **Configurar la base de datos**:
   - Crear una base de datos en PostgreSQL (ejemplo: `licenses_db`).
   - Ejecutar el script SQL inicial:
     ```bash
     psql -U postgres -d licenses_db -f db/schema.sql
     ```

3. **Variables de Entorno (`.env`)**:
   Ajustar los valores según tu configuración local o de servidor:
   ```env
   DATABASE_URL=postgres://postgres:TU_PASSWORD@localhost:5432/licenses_db
   PORT=3000
   JWT_SECRET=tu_secreto_super_seguro_jwt_123456789
   ADMIN_TOKEN=mi_token_maestro_admin_123
   ```

4. **Iniciar el servidor**:
   - Modo desarrollo:
     ```bash
     npm run dev
     ```
   - Modo producción:
     ```bash
     npm start
     ```

## Endpoints de la API

### Cliente iOS (`/api/v1`)
- `POST /api/v1/auth`: Vincula el HWID y activa la clave. Devuelve el JWT.
- `GET /api/v1/heartbeat`: Comprueba la vigencia de la licencia mediante token Bearer.

### Administración (`/api/v1/admin`) — Requiere header `x-admin-token`
- `POST /api/v1/admin/keys`: Genera lotes de claves (`count`, `duration_hours`, `role`, `note`).
- `GET /api/v1/admin/keys`: Lista todas las licencias registradas.
- `POST /api/v1/admin/ban`: Banea o desbanea una clave (`license_key`, `banned`).
- `POST /api/v1/admin/reset-hwid`: Desvincula el HWID de una clave para permitir su reactivación.
