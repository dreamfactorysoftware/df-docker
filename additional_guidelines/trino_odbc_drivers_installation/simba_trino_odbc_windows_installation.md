# Simba Trino ODBC Driver Setup (Windows)

> ⚠️ The Simba Trino ODBC driver is proprietary. Downloading it requires registration.

## 1. Download & Licensing

- 🔗 [Download Page](https://www.insightsoftware.com/drivers/trino-odbc-jdbc/)
- 📩 Registration required — fill out a form to receive:
  - A `.zip` file with `.msi` installers and docs  
  - `.lic` license file (via email)

> Place the `.lic` file into the installed driver's `lib` folder after installation.

---

## 2. Install the Driver

Choose the correct version:

| Application | Installer                |
|-------------|--------------------------|
| 64-bit      | `SimbaTrinoODBC64.msi`   |
| 32-bit      | `SimbaTrinoODBC32.msi`   |

### Steps

1. Run the installer (`.msi`)
2. Accept the license
3. Complete the install
4. Copy the `.lic` file into the `lib` subfolder of the Simba Trino ODBC Driver installation directory. E.g.:  
   `C:\Program Files\Simba Trino ODBC Driver\lib\`

### (Optional) Test with a System DSN

You might want to test your driver before using it with DreamFactory:

5. Open **ODBC Data Source Administrator** (`odbcad32`)
6. Add a **System DSN**
7. Select **Simba Trino ODBC Driver**
8. Fill in:
   - Host, Port  
   - Catalog/Schema (optional)  
   - Username/Password  
9. Click **Test**

---

## 3. Configure DreamFactory Trino Connector

After installing the driver, set up your Trino service via DreamFactory.

1. Navigate to:  
   **API Generation & Connections → API Types → Database**
2. Click the **"+"** icon
3. Select **Trino** from the list of databases
4. Fill in the fields

### Required Fields

| Field           | Example                     | Notes                                                                 |
|------------------|-----------------------------|-----------------------------------------------------------------------|
| **Namespace**    | `trino-db`                  | Used in API URI: `/api/v2/{type}/{namespace}`. Lowercase & alphanumeric. |
| **Host**         | `127.0.0.1`                 | IP or hostname of Trino server                                        |
| **Port**         | `8080`                      | Default Trino port                                                    |
| **Username**     | `trino`                     | Trino login                                                           |
| **Password**     | `mypassword`                | Trino user password                                                   |
| **Driver Path**  | `{Simba Trino ODBC Driver}` | Use driver **name**, not full DLL path                                |

### Optional Fields

- **Catalog**: e.g., `memory`
- **Schema**: e.g., `default`

> ✅ DreamFactory uses **DSN-less ODBC**. No manual DSN setup is required.

---

## 4. Troubleshooting

- **Error IM002**: Usually means the driver name was not found — use `{Simba Trino ODBC Driver}`.
- Ensure bitness (32/64-bit) matches your app.
- License file must be placed inside the `lib` folder of the install path.

---

## References

- [Simba Trino ODBC Docs](https://documentation.insightsoftware.com/trino-online-documentation-windows/content/odbc/windows/installing.htm)
