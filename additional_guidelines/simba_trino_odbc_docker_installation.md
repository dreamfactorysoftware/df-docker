## Adding Simba Trino ODBC Driver to a Docker Environment

In case you want to utilize Trino connectors on DreamFactory, you will have to install the ODBC driver for it, which will allow DreamFactory to communicate with Trino through the ODBC interface and perform SQL queries via supported endpoints.

### Preparation

1. **Download the Simba Trino ODBC driver**  
   Visit the official [InsightSoftware Simba Trino ODBC Driver page](https://www.insightsoftware.com/drivers/trino-odbc-jdbc/) and download the appropriate driver for Ubuntu. Preferably, get the `.deb` package.

2. **Retrieve the license file**  
   After registering and downloading the driver, you should receive an email containing the `SimbaTrinoODBCDriver.lic` license file. Download and keep it ready.

---

### Installation Methods

You can proceed with either of the following approaches:

#### Option 1: Move both the `.deb` driver file and the `.lic` license file into dreamfactory folder

1. Inside the container:
   ```bash
   docker-compose exec web bash
   ```

2. From inside the container, install the driver:
   ```bash
   dpkg -i /path/to/your/simba-trino-driver-name.deb
   ```

3. Place the license file:
   ```bash
   cp /path/to/your/SimbaTrinoODBCDriver.lic /opt/simba/trinoodbc/lib/
   ```

---

#### Option 2: Copy from host to container

1. Use `docker cp` to copy the files into the container:
   ```bash
   docker cp simba-trino-driver-name.deb dreamfactory_web_1:/tmp/
   docker cp SimbaTrinoODBCDriver.lic dreamfactory_web_1:/tmp/
   ```

2. Enter the container:
   ```bash
   docker-compose exec web bash
   ```

3. Inside the container, run:
   ```bash
   dpkg -i /tmp/simba-trino-driver-name.deb
   cp /tmp/SimbaTrinoODBCDriver.lic /opt/simba/trinoodbc/lib/
   ```

---

### Troubleshooting

#### Problem: You only have an `.rpm` file

InsightSoftware may only provide `.rpm` packages. Since the Docker container is Ubuntu-based, you'll need to convert the `.rpm` to `.deb` using `alien`.

1. Install `alien` (on your host):
   ```bash
   sudo apt-get install alien
   ```

2. Convert the `.rpm` file:
   ```bash
   sudo alien --to-deb simba-trino-driver-name.rpm
   ```

3. Proceed with installation inside the container as described above using the converted `.deb` file.