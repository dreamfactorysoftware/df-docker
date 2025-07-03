## Adding Simba Trino ODBC Driver to a Docker Environment

To enable Trino connectors in DreamFactory, you need to install the Simba Trino ODBC driver and provide a valid license file.

### Preparation

1. **Download the Simba Trino ODBC driver**  
   Get the `.deb` package from [InsightSoftware Simba Trino ODBC Driver page](https://www.insightsoftware.com/drivers/trino-odbc-jdbc/).

2. **Obtain the license file**  
   You should receive `SimbaTrinoODBCDriver.lic` after registering.

3. **Place them into the folder with Dockerfile**

---

### Installation in Docker

Add the following (uncommented) lines to your Dockerfile to install the driver and license:

```dockerfile
COPY <SimbaTrinoODBCDriverFileName>.deb /tmp/
COPY SimbaTrinoODBCDriver.lic /tmp/
RUN dpkg -i /tmp/<SimbaTrinoODBCDriverFileName>.deb \
    && mkdir -p /opt/simba/trinoodbc/lib/64/ \
    && cp /tmp/SimbaTrinoODBCDriver.lic /opt/simba/trinoodbc/lib/64/
```

Replace `<SimbaTrinoODBCDriverFileName>` with your actual driver file name.

> **Note:** If you only have an `.rpm` file, try converting it to `.deb` using `alien` before building the Docker image:
>
> ```bash
> sudo apt-get install alien
> sudo alien --to-deb simba-trino-driver-name.rpm
> ```

---
