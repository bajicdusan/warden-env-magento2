<PROJECT_NAME> Magento 2 Application
========================================================

| Env | FrontURL | AdminURL |
| --- | :------- | :------- |
| DEV | https://app.exampleproject.test/  | https://app.exampleproject.test/backend/  |
| STG | https://stage.exampleproject.com/ | https://stage.exampleproject.com/backend/ |
| PRD | https://www.exampleproject.com/   | https://www.exampleproject.com/backend/   |

Other useful URLs on DEV:

* https://mailhog.warden.test/
* https://rabbitmq.exampleproject.test/
* https://elasticsearch.exampleproject.test/

## Developer Setup

### Prerequisites:

* [Warden](https://warden.dev/) 0.6.0 or later is installed. See the [Installing Warden](https://docs.warden.dev/installing.html) docs page for further info and procedures.
* `pv` is installed and available in your `$PATH` (you can install this via `brew`, `dnf`, `apt` etc)

### Initializing Environment

In the below examples `~/Sites/exampleproject` is used as the path. Simply replace this with whatever path you will be running this project from. It is recommended however to deploy the project locally to a case-sensitive volume.

 1. Clone the project codebase.

        git clone -b develop https://github.com/bajicdusan/warden-env-magento2.git \
            ~/Sites/exampleproject

 2. Change into the project directory.

        cd ~/Sites/exampleproject

 3. Configure composer credentials.

        composer config -f ./webroot/composer.json http-basic.repo.magento.com <username> <password>

     If you don't have `composer` installed on the host machine, manually create `webroot/auth.json` using the following template:

        {
            "http-basic": {
                "repo.magento.com": {
                    "username": "<username>",
                    "password": "<password>"
                }
            }
        }

 4. Run the init script to bootstrap the environment, starting the containers and mutagen sync (on macOS), installing the database (or importing if `--db-dump` or short `-u` is specified), and creating the local admin user for accessing the Magento backend.

        warden bootstrap -cv 2.4.6

 5. Load the site in your browser using the links and credentials taken from the init script output. 

    **Note:** If you are using **Firefox** and it warns you the SSL certificate is invalid/untrusted, go to Preferences -> Privacy & Security -> View Certificates (bottom of page) -> Authorities -> Import and select `~/.warden/ssl/rootca/certs/ca.cert.pem` for import, then reload the page.
    
    **Note:** If you are using **Chrome** on **Linux** and it warns you the SSL certificate is invalid/untrusted, go to Chrome Settings -> Privacy And Security -> Manage Certificates (see more) -> Authorities -> Import and select `~/.warden/ssl/rootca/certs/ca.cert.pem` for import, then reload the page.

### Additional Configuration

Information on configuring and using tools such as Xdebug, LiveReload, MFTF, and multi-domain site setups may be found in the Warden docs page on [Configuration](https://docs.warden.dev/configuration.html).

### Destroying Environment

To completely destroy the local environment we just created, run `warden env down -v` to tear down the project’s Docker containers, volumes, and (where applicable) cleanup the Mutagan sync session.

### Newly added Features

- Added support for single slash arguments:
    - Automatic detection of either short or long argument and parsing,
    - Figure out what arguments are missing or if there are too many arguments and inform the user,
    - Automatic parsing of the arguments (.tar.gz, Magento version regex and allowed meta packages),

- Added more descriptive error messages:
    - Added ASCII art for error messages to be easily detected,
    - Added descriptive text that will describe the issue or display a help message,
    - Added help messages when it detects unknown argument,

- Added support for multi environments - defined under env folder.
If specified Magento version with (warden bootstrap -cv 2.4.5-p1), it will copy over existing .env file to the env/backup/.env and it will override .env file for env/2.4.5/.env,

- Added default setting when the command is parsed without arguments to start up warden environment and services,

- Added support to only have a domain without the subdomain. It will automatically resolve if there is subdomain - appends it before domain so it can work both with and without the subdomain,

- Added configuration for admin path and default admin username,

- Added support to open the URL in the browser (default to off). Supports the following configurations: 2 = xdg-open, 1 = sensible-browser, 0 = off,

- Added support to have no default webroot folder (automatic creation of the webroot/app/etc/env.php.init.php along with folders),

- Added support to have patches, currently needed to ensure the installation will go trough in one go (backfill/patches/778.patch),

- Added support to use pre-defined admin password, if none is provided generates random one,

- Added support to configure Two Factor Authentication, if disabled, it will disable module as well,

- Added support to to install sample data (-w argument or --with-sample-data),

- Added support to have aliases in ~/.bashrc file on warden (defined under .warden/php-fpm/.bashrc file),

- Added configuration to enable/disable printing out of the Admin User/Credentials (it will display them if the password is random),

- Added configuration to display more services URL's when printing out install information,

- Added support to use 'cat' command dependency instead of the 'pv',

- Added support for Magento 2.4.6 version (Known Issues):
    - ElasticSearch version is 7.17, should be 8.4 but that version is throwing error when reindexing ({"error":"no handler found for uri [/magento2_product_1_v3/document/_mapping?include_type_name=true] and method [PUT]"}),