#!/usr/bin/env bash
[[ ! ${WARDEN_DIR} ]] && >&2 echo -e "\033[31mThis script is not intended to be run directly!\033[0m" && exit 1
set -euo pipefail

## configure command defaults
## leave as is, it determines if the arguments are single or two slash ones (def:SINGLE_SLASH_ARGUMENTS=)
SINGLE_SLASH_ARGUMENTS=
## leave as is, enables db import. Will be overriden if no argument is supplied --skip-db-import (-s) or --clean-install (-c) (def:DB_IMPORT=1)
DB_IMPORT=1
## leave as is, it determines if it should do a clean install if argument is supplied --clean-install (-c) (def:CLEAN_INSTALL=)
CLEAN_INSTALL=
## leave as is, if specified argument --no-pull (-n) it won't pull latest env images (def:AUTO_PULL=1)
AUTO_PULL=1
## leave as is, it defaults to this Magento meta package, if specified argument --meta-package (-p) you can change to magento/project-enterprise-edition (def:META_PACKAGE="magento/project-community-edition")
META_PACKAGE="magento/project-community-edition"
## leave as is, if specified argument --with-sample-data (-w) it will install Magento sample data (def:SAMPLE_DATA=0)
SAMPLE_DATA=0
## leave as is, determines the magento version (supported: 2.4.3, 2.4.4 and 2.4.5) and applies patches needed to finish install in one go (def: APPLY_PATCHES=)
APPLY_PATCHES=
## leave as is, used to check if there are present env folder with multiple envs (def: MULTI_ENV=1)
MULTI_ENV=1
## leave as is, default meta version, if specified argument --meta-version (-v) then it will proceed to instal that version (def: META_VERSION="")
META_VERSION=""
## default Magento admin path
ADMIN_PATH="admin"
## default Magento admin password
ADMIN_PASS=Test1234
## default Magento admin username
ADMIN_USER=admin
## if it should print out admin credentials on install
PRINT_ADMIN_CREDENTIALS=
## if it should setup two factor authentication
USE_TFA=0
## http protocol, either http or https
HTTP_PROTOCOL="https"
## prints out more urls on install (warden env urls and warden svc urls)
PRINT_MORE_VERBOSE_ON_INSTALL=1
## if magento store url should be opened on install (2 = xdg-open, 1 = sensible-browser, 0 = off -> $traefik_url &>/dev/null)
OPEN_IN_BROWSER=0
## if warden bootstrap is passed without other arguments, default to clean install (default: SKIP=, SKIP=-1 will default to start env and svc)
SKIP=0

## error messages:
META_PACKAGE_ERROR_MESSAGE="Allowed magento2 metapackages: magento/project-community-edition, magento/project-enterprise-edition"
META_VERSION_ERROR_MESSAGE="Did not find meta version, valid values are 2.3.4 or later."
SQL_ERROR_MESSAGE="Did not find sql file. Make sure that the file is in the following format: .sql.gz"

## prints time with command or comment
function :: {
  echo
  echo "==> [$(date +%H:%M:%S)] $@"
}

## help message, triggers bootstrap --help
function print_help_message {
  warden bootstrap --help
  exit 1
}

## error ascii art
function error_message {
    echo "
  ___ _ __ _ __ ___  _ __ 
 / _ \ '__| '__/ _ \| '__|
|  __/ |  | | | (_) | |   
 \___|_|  |_|  \___/|_|   
                          
"
}

## default error message with ascii art and comment
function print_error_message {
  error_message
  echo -e "$@\n"
  exit 1
}

## start up warden environment and services
function set_warden_up {
  if [[ ${SKIP} -eq -1 ]]; then
    echo "Defaulting to start services and environment."
    echo ""
    warden svc up
    warden env up -d
    exit 1
  fi
}

## prints our help message for short arguments only
function print_single_slash_help_message {
  error_message
  echo -e "$@"
  echo ""
  echo "Usage:"
  echo "warden bootstrap -cpvsunw magento/project-community-edition 2.4.5-p1 magento.sql.gz"
  echo ""
  echo "Options:"
  echo "-c   --clean-install     install from scratch rather than use existing database dump"
  echo "-p   --meta-package      passed to 'create-project' and defaults to community"
  echo "-v   --meta-version      specify alternate version to install, defaults to latest"
  echo "-s   --skip-db-import    skips over db import (assume db has already been imported)"
  echo "-u   --db-dump           expects path to .sql.gz file for import during init"
  echo "-n   --no-pull           latest images will not be pulled prior env start"
  echo "-w   --with-sample-data  installs magento sample data"

  exit 1
}

## check to see if there are no arguments provided to the warden bootstrap command, if there are none - start env and exit
if [[ $# -eq 0 ]]; then
  echo "There are no arguments passed to the command."
  echo ""
  set_warden_up
  SKIP=1
  SINGLE_SLASH_ARGUMENTS=0
fi

## check is short or long argument parsing
if [[ ${SKIP} != 1 && ! ${SINGLE_SLASH_ARGUMENTS} && "$1" = --* ]]; then
  SINGLE_SLASH_ARGUMENTS=0
  ## echo "DOUBLE quote"
fi

if [[ ${SKIP} != 1 && ! ${SINGLE_SLASH_ARGUMENTS} && "$1" = -* ]]; then
  SINGLE_SLASH_ARGUMENTS=1
  ## echo "SINGLE quote"
fi

## locates .env file (.env file needs to be present, can not use ones under env folder)
WARDEN_ENV_PATH="$(locateEnvPath)" || exit $?

## searching trough argument list for a meta version argument
if [[ ${SINGLE_SLASH_ARGUMENTS} == 1 && ${MULTI_ENV} == 1 ]]; then
  for ver in "$@"
  do
    if [[ "$ver" =~ ^2\.[3-9]\.[0-9].* ]]; then
      ## printf "Found meta-version: $ver\n"
      META_VERSION=$ver
      break
    fi
  done
fi

## if found meta version in arguments load its config else load default config
if [[ ${MULTI_ENV} == 1 && $META_VERSION ]]; then
  printf "Loading env config for meta version: $META_VERSION\n"
  ENV_FOLDER_NAME=${META_VERSION%-*}

  if [ -f "./env/${ENV_FOLDER_NAME}/.env" ]; then
    echo "Loading latest system requirements for meta version ${META_VERSION} from ./env/${ENV_FOLDER_NAME}/.env"
    :: "cp .env file to env/${ENV_FOLDER_NAME}/backup"
    cp .env ./env/backup/.env

    :: "cp ./env/${ENV_FOLDER_NAME}/.env to .env"
    cp ./env/${ENV_FOLDER_NAME}/.env .env
    loadEnvConfig "./env/${ENV_FOLDER_NAME}" || exit $?
  else
    echo "There is no .env file under: env/${ENV_FOLDER_NAME}/.env"
    echo "Please create the folder and new .env file with right parameters."
    exit 1
  fi
else
  ## load configuration needed for setup
  loadEnvConfig "${WARDEN_ENV_PATH}" || exit $?
fi

assertDockerRunning

## change into the project directory
cd "${WARDEN_ENV_PATH}"

## sets default warden configurations
WARDEN_WEB_ROOT="$(echo "${WARDEN_WEB_ROOT:-/}" | sed 's#^/#./#')"
REQUIRED_FILES=("${WARDEN_WEB_ROOT}/auth.json")
DB_DUMP="${DB_DUMP:-./backfill/magento-db.sql.gz}"
FULL_DOMAIN="${TRAEFIK_DOMAIN}"

## if there is subdomain, append it before domain so it can work both with and without subdomain
if [[ ${TRAEFIK_SUBDOMAIN} ]]; then
  FULL_DOMAIN="${TRAEFIK_SUBDOMAIN}.${TRAEFIK_DOMAIN}"
fi

URL_FRONT="${HTTP_PROTOCOL}://${FULL_DOMAIN}/"
URL_ADMIN="${HTTP_PROTOCOL}://${FULL_DOMAIN}/${ADMIN_PATH}/"

## open url in browser, 2 = xdg-open, 1 = sensible-browser, 0 = off $traefik_url &>/dev/null
function open_url_in_browser {
  if [[ ${OPEN_IN_BROWSER} == 2 ]]; then
    :: Opening URL in browser
    xdg-open $URL_FRONT &>/dev/null
  fi

  if [[ ${OPEN_IN_BROWSER} == 1 ]]; then
    :: Opening URL in browser
    sensible-browser $URL_FRONT &>/dev/null
  fi
}

## short argument parsing
FOUND_SQL_FILENAME=
if [[ ${SINGLE_SLASH_ARGUMENTS} == 1 ]]; then
  EXPECTED_ARGS=1
  ALLOWED_META_PACKAGES=(magento/project-community-edition magento/project-enterprise-edition)
  FOUND_META_PACKAGE=
  FOUND_META_VERSION=

  while read -n1 character; do

    if [[ "$character" = -* ]]; then
      ## echo skipping $character
      continue
    fi

    ## echo second arg is $2
    case "$character" in
      c)
        REQUIRED_FILES+=("${WARDEN_WEB_ROOT}/app/etc/env.php.init.php")
        CLEAN_INSTALL=1
        DB_IMPORT=
        ;;
      p)
        EXPECTED_ARGS=$(($EXPECTED_ARGS + 1))
        FOUND_META_PACKAGE=0
        ;;
      v)
        EXPECTED_ARGS=$(($EXPECTED_ARGS + 1))
        FOUND_META_VERSION=0
        ;;
      s)
        DB_IMPORT=
        ;;
      u)
        EXPECTED_ARGS=$(($EXPECTED_ARGS + 1))
        FOUND_SQL_FILENAME=0
        ;;
      n)
        AUTO_PULL=
        ;;
      w)
        SAMPLE_DATA=1
        ;;
      *)
        ## error "Unrecognized argument '$character'"
        print_single_slash_help_message "Unrecognized argument '$character'"
        exit -1
        ;;
    esac
  done < <(echo -n "$1")

  ## figure out what arguments are missing, inform the user of their mistake
  if [[ $# -gt ${EXPECTED_ARGS} ]]; then
    print_single_slash_help_message "There are too many arguments. Please remove $(($# - $EXPECTED_ARGS))."
    exit 1
  fi

  if [[ $# -lt ${EXPECTED_ARGS} ]]; then
    NOT_FOUND_ERROR_MESSAGE="Missing some arguments, you need to pass exactly $(($EXPECTED_ARGS - $#)) more."

    if [[ $FOUND_META_PACKAGE == 0 ]]; then
      NOT_FOUND_ERROR_MESSAGE="$NOT_FOUND_ERROR_MESSAGE\n\nYou passed -p (--meta-package) argument.\nDid not find meta package. $META_PACKAGE_ERROR_MESSAGE"
    fi

    if [[ $FOUND_META_VERSION == 0 ]]; then
      NOT_FOUND_ERROR_MESSAGE="$NOT_FOUND_ERROR_MESSAGE\n\nYou passed -v (--meta-version) argument.\n$META_VERSION_ERROR_MESSAGE"
    fi

    if [[ $FOUND_SQL_FILENAME == 0 ]]; then
      NOT_FOUND_ERROR_MESSAGE="$NOT_FOUND_ERROR_MESSAGE\n\nYou passed -u (--db-dump) argument.\n$SQL_ERROR_MESSAGE"
    fi

    print_single_slash_help_message "$NOT_FOUND_ERROR_MESSAGE"
    exit 1
  fi

  ## go trough all arguments that are not stating with single slash (-), being either meta version, meta package or db sql.gz file
  ## sets the right argument to the right tag, mostly with the help of regex for sql.gz, magento meta versions and one of allowed meta packages
  COUNTER=0
  while test $# -gt 0
  do
    if [[ "$1" = -* ]]; then
      ## echo skipping first argument: $1
      shift
      continue
    fi

    ## echo "Searching for: $1"

    ## if found all break from loop
    if [[ $FOUND_SQL_FILENAME != 0 && $FOUND_META_VERSION != 0 && $FOUND_META_PACKAGE != 0 ]]; then
      ## echo "Found all"
      break;
    fi

    for package in ${ALLOWED_META_PACKAGES[@]};
    {
      if [[ $FOUND_META_PACKAGE == 0 && "$1" =~ $package ]]; then
        printf "Found meta-package: $1\n"
        FOUND_META_PACKAGE=$1
        META_PACKAGE="$1"
        shift
        break
      fi
    }

    if [[ $FOUND_META_VERSION == 0 && "$1" =~ ^2\.[3-9]\.[0-9].* ]]; then
      printf "Found meta-version: $1\n"
      FOUND_META_VERSION=$1
      META_VERSION="$1"

      if test $(version "${META_VERSION}") -lt "$(version 2.3.4)"; then
        print_single_slash_help_message $META_VERSION_ERROR_MESSAGE
        exit 1
      fi
    fi

    if [[ $FOUND_SQL_FILENAME == 0 && "$1" =~ .*\.sql\.gz$ ]]; then
      printf "Found SQL filename: $1\n"
      FOUND_SQL_FILENAME=$1
      DB_DUMP="$1"
    fi

    if [[ COUNTER -ge 10 ]]; then
      print_single_slash_help_message "Force break out of while loop."
      exit -1
    fi

    COUNTER=$(($COUNTER + 1))
    shift
  done

  ## if it didn't fine something but was searching for it, display error and exit
  if [[ $FOUND_META_PACKAGE == 0 ]]; then
    echo "Did not find meta package."
    print_single_slash_help_message  $META_PACKAGE_ERROR_MESSAGE
    exit 1
  fi

  if [[ $FOUND_META_VERSION == 0 ]]; then
    print_single_slash_help_message $META_VERSION_ERROR_MESSAGE
    exit 1
  fi

  if [[ $FOUND_SQL_FILENAME == 0 ]]; then
    print_single_slash_help_message $SQL_ERROR_MESSAGE
    exit 1
  fi
fi

## argument parsing
## parse long arguments two slashes (--)
while (( ${SINGLE_SLASH_ARGUMENTS} != 1 && "$#" )); do
    case "$1" in
        --clean-install)
            REQUIRED_FILES+=("${WARDEN_WEB_ROOT}/app/etc/env.php.init.php")
            CLEAN_INSTALL=1
            DB_IMPORT=
            shift
            ;;
        --meta-package)
            shift
            META_PACKAGE="$1"
            shift
            ;;
        --meta-version)
            shift
            META_VERSION="$1"
            if
                ! test $(version "${META_VERSION}") -ge "$(version 2.3.4)" \
                && [[ ! "${META_VERSION}" =~ ^2\.[3-9]\.x$ ]]
            then
                fatal "Invalid --meta-version=${META_VERSION} specified (valid values are 2.3.4 or later and 2.[3-9].x)"
            fi
            shift
            ;;
        --skip-db-import)
            DB_IMPORT=
            shift
            ;;
        --db-dump)
            shift
            DB_DUMP="$1"
            FOUND_SQL_FILENAME=$1
            shift
            ;;
        --no-pull)
            AUTO_PULL=
            shift
            ;;
        --with-sample-data)
            SAMPLE_DATA=1
            shift
            ;;
        *)
            error "Unrecognized argument '$1'"
            exit -1
            ;;
    esac
done

## check to see if it there is app/code folder in webroot, which would mean that magento has already been installed.
if [[ ${FOUND_SQL_FILENAME} == "" && -d "${WARDEN_WEB_ROOT}/app/code" ]]; then
  printf "You already have Magento2 instance installed.\n"
  open_url_in_browser
  exit 1
fi

## check for etc directory (could be deleted or missing)
if [ ! -d "${WARDEN_WEB_ROOT}/app/etc" ]; then
  mkdir -p "${WARDEN_WEB_ROOT}/app/etc"
fi

## check for env.php.init.php file if not found copy one from backfill/config/files folder
if [ ! -f "${WARDEN_WEB_ROOT}/app/etc/env.php.init.php" ]; then
  cp ./backfill/config/files/env.php.init.php "${WARDEN_WEB_ROOT}/app/etc/"
fi

## if no composer.json is present in web root imply --clean-install flag when not specified explicitly
if [[ ! ${CLEAN_INSTALL} ]] && [[ ! -f "${WARDEN_WEB_ROOT}/composer.json" ]]; then
  warning "Implying --clean-install since file ${WARDEN_WEB_ROOT}/composer.json not present"
  REQUIRED_FILES+=("${WARDEN_WEB_ROOT}/app/etc/env.php.init.php")
  CLEAN_INSTALL=1
  DB_IMPORT=
fi

## include check for DB_DUMP file only when database import is expected
[[ ${DB_IMPORT} ]] && REQUIRED_FILES+=("${DB_DUMP}" "${WARDEN_WEB_ROOT}/app/etc/env.php.warden.php")

:: Verifying configuration
INIT_ERROR=

## attempt to install mutagen if not already present
if [[ $OSTYPE =~ ^darwin ]] && ! which mutagen 2>/dev/null >/dev/null && which brew 2>/dev/null >/dev/null; then
    warning "Mutagen could not be found; attempting install via brew."
    brew install havoc-io/mutagen/mutagen
fi

USE_CAT_DEPENDENCY=0
## check for presence of host machine dependencies
for DEP_NAME in warden mutagen docker-compose pv; do
  if [[ "${DEP_NAME}" = "mutagen" ]] && [[ ! $OSTYPE =~ ^darwin ]]; then
    continue
  fi

  if ! which "${DEP_NAME}" 2>/dev/null >/dev/null; then
    if [[ "${DEP_NAME}" = "pv" ]]; then
      echo "Command '${DEP_NAME}' not found. Defaulting the usage to 'cat' command."
      USE_CAT_DEPENDENCY=1
      continue
    fi

    error "Command '${DEP_NAME}' not found. Please install."
    INIT_ERROR=1
  fi
done

## verify warden version constraint
WARDEN_VERSION=$(warden version 2>/dev/null) || true
WARDEN_REQUIRE=0.6.0
if ! test $(version ${WARDEN_VERSION}) -ge $(version ${WARDEN_REQUIRE}); then
  error "Warden ${WARDEN_REQUIRE} or greater is required (version ${WARDEN_VERSION} is installed)"
  INIT_ERROR=1
fi

## copy global Marketplace credentials into webroot to satisfy REQUIRED_FILES list; in ideal
## configuration the per-project auth.json will already exist with project specific keys
if [[ ! -f "${WARDEN_WEB_ROOT}/auth.json" ]] && [[ -f ~/.composer/auth.json ]]; then
  if docker run --rm -v ~/.composer/auth.json:/tmp/auth.json \
      composer config -g http-basic.repo.magento.com >/dev/null 2>&1
  then
    warning "Configuring ${WARDEN_WEB_ROOT}/auth.json with global credentials for repo.magento.com"
    echo "{\"http-basic\":{\"repo.magento.com\":$(
      docker run --rm -v ~/.composer/auth.json:/tmp/auth.json composer config -g http-basic.repo.magento.com
    )}}" > ${WARDEN_WEB_ROOT}/auth.json
  fi
fi

## verify mutagen version constraint
MUTAGEN_VERSION=$(mutagen version 2>/dev/null) || true
MUTAGEN_REQUIRE=0.11.4
if [[ $OSTYPE =~ ^darwin ]] && ! test $(version ${MUTAGEN_VERSION}) -ge $(version ${MUTAGEN_REQUIRE}); then
  error "Mutagen ${MUTAGEN_REQUIRE} or greater is required (version ${MUTAGEN_VERSION} is installed)"
  INIT_ERROR=1
fi

## check for presence of local configuration files to ensure they exist
for REQUIRED_FILE in ${REQUIRED_FILES[@]}; do
  if [[ ! -f "${REQUIRED_FILE}" ]]; then
    error "Missing local file: ${REQUIRED_FILE}"
    INIT_ERROR=1
  fi
done

## exit script if there are any missing dependencies or configuration files
[[ ${INIT_ERROR} ]] && exit 1

:: Starting Warden
warden svc up
if [[ ! -f ~/.warden/ssl/certs/${TRAEFIK_DOMAIN}.crt.pem ]]; then
    warden sign-certificate ${TRAEFIK_DOMAIN}
fi

:: Initializing environment
if [[ $AUTO_PULL ]]; then
  warden env pull --ignore-pull-failures || true
  warden env build --pull
else
  warden env build
fi
warden env up -d

## wait for mariadb to start listening for connections
warden shell -c "while ! nc -z db 3306 </dev/null; do sleep 2; done"

if [[ ${META_VERSION} ]]; then
  if test $(version "${META_VERSION}") -eq "$(version 2.4.6)"; then
    :: "Applying temporary fix for Magento version 2.4.6, where PATH is not defined for this version, so it will default to install latest one."
    META_VERSION=
  fi
fi

if [[ ${CLEAN_INSTALL} ]] && [[ ! -f "${WARDEN_WEB_ROOT}/composer.json" ]]; then
  :: "Installing meta-package: '${META_PACKAGE}', Magento version: '${META_VERSION}'"
  warden env exec -T php-fpm composer create-project -q --no-interaction --prefer-dist --no-install \
      --repository-url=https://repo.magento.com/ "${META_PACKAGE}" /tmp/create-project "${META_VERSION}"
  warden env exec -T php-fpm rsync -a /tmp/create-project/ /var/www/html/
fi

:: Installing dependencies
warden env exec -T php-fpm bash \
  -c '[[ $(composer -V | cut -d\  -f3 | cut -d. -f1) == 2 ]] || composer global require hirak/prestissimo'
warden env exec -T php-fpm composer install

## import database only if --skip-db-import is not specified
if [[ ${DB_IMPORT} ]]; then
  :: Importing database
  warden db connect -e 'drop database magento; create database magento;'

  if [[ ${USE_CAT_DEPENDENCY} == 1 ]]; then
    cat "${DB_DUMP}" | gunzip -c | warden db import
  else
    pv "${DB_DUMP}" | gunzip -c | warden db import
  fi

elif [[ ${CLEAN_INSTALL} ]]; then
  
  INSTALL_FLAGS=""

  ## rabbitmq
  if [[ ${WARDEN_RABBITMQ} == 1 ]]; then
    INSTALL_FLAGS="${INSTALL_FLAGS} --amqp-host=rabbitmq
      --amqp-port=5672
      --amqp-user=guest 
      --amqp-password=guest 
      --consumers-wait-for-messages=0 "
  fi
  
  ## redis
  if [[ ${WARDEN_REDIS} == 1 ]]; then
    INSTALL_FLAGS="${INSTALL_FLAGS} --session-save=redis
      --session-save-redis-host=redis
      --session-save-redis-port=6379
      --session-save-redis-db=2
      --session-save-redis-max-concurrency=20
      --cache-backend=redis
      --cache-backend-redis-server=redis
      --cache-backend-redis-db=0
      --cache-backend-redis-port=6379
      --page-cache=redis
      --page-cache-redis-server=redis
      --page-cache-redis-db=1
      --page-cache-redis-port=6379 "
  fi

  ## varnish
  if [[ ${WARDEN_VARNISH} == 1 ]]; then
    INSTALL_FLAGS="${INSTALL_FLAGS} --http-cache-hosts=varnish:80 "
  fi

  INSTALL_FLAGS="${INSTALL_FLAGS} \
    --cleanup-database \
    --backend-frontname="${ADMIN_PATH}" \
    --db-host=db \
    --db-name=magento \
    --db-user=magento \
    --db-password=magento"

  ## patching versions that are known to throw an error on install (https://github.com/wardenenv/warden-env-magento2/issues/16)
  ## (https://patch-diff.githubusercontent.com/raw/magento/magento2-page-builder/pull/778.patch)
  if [[ ${META_VERSION} ]]; then
    if test $(version "${META_VERSION}") -eq "$(version 2.4.5)"; then
      APPLY_PATCHES=1
    fi
    if test $(version "${META_VERSION}") -eq "$(version 2.4.4)"; then
      APPLY_PATCHES=1
    fi
    if test $(version "${META_VERSION}") -eq "$(version 2.4.3)"; then
      APPLY_PATCHES=1
    fi
  fi

  if [[ ${APPLY_PATCHES} == 1 ]]; then
    :: Patching Magento module-page-builder
    patch ${WARDEN_WEB_ROOT}/vendor/magento/module-page-builder/Plugin/Catalog/Model/Product/Attribute/RepositoryPlugin.php ./backfill/patches/778.patch
  fi

  :: Installing application
  warden env exec -- -T php-fpm rm -vf app/etc/config.php app/etc/env.php app/etc/env.php.warden.php
  warden env exec -- -T php-fpm cp app/etc/env.php.init.php app/etc/env.php
  warden env exec -- -T php-fpm bin/magento setup:install $(echo ${INSTALL_FLAGS})

  :: Configuring application
  warden env exec -T php-fpm cp -n app/etc/env.php app/etc/env.php.warden.php
  warden env exec -T php-fpm ln -fsn env.php.warden.php app/etc/env.php
  warden env exec -T php-fpm bin/magento app:config:import

  warden env exec -T php-fpm bin/magento config:set -q --lock-env web/unsecure/base_url ${URL_FRONT}
  warden env exec -T php-fpm bin/magento config:set -q --lock-env web/secure/base_url ${URL_FRONT}

  warden env exec -T php-fpm bin/magento deploy:mode:set -s developer
  warden env exec -T php-fpm bin/magento cache:disable block_html full_page
  warden env exec -T php-fpm bin/magento app:config:dump themes scopes i18n
fi

if [[ ! ${CLEAN_INSTALL} ]]; then
  :: Configuring application
  warden env exec -T php-fpm ln -fsn env.php.warden.php app/etc/env.php
  warden env exec -T php-fpm bin/magento cache:flush -q
  warden env exec -T php-fpm bin/magento app:config:import

  :: bin/magento setup:db-schema:upgrade
  warden env exec -T php-fpm php -d memory_limit=-1 bin/magento setup:db-schema:upgrade

  :: bin/magento setup:db-data:upgrade
  warden env exec -T php-fpm php -d memory_limit=-1 bin/magento setup:db-data:upgrade

fi

## check if default admin pass is configured
if [[ ${ADMIN_PASS} == "" ]]; then
  :: There is no Admin pass defined, using random one
  PRINT_ADMIN_CREDENTIALS=1
  ADMIN_PASS=$(warden env exec -T php-fpm pwgen -n1 16)
fi

:: Creating admin user
warden env exec -T php-fpm bin/magento admin:user:create \
    --admin-password="${ADMIN_PASS}" \
    --admin-user="${ADMIN_USER}" \
    --admin-firstname="Local" \
    --admin-lastname="Admin" \
    --admin-email="${ADMIN_USER}@example.com"

## check if two factor authentication is enabled and set it up
OTPAUTH_QRI=
MAGENTO_VERSION=$(warden env exec -T php-fpm bin/magento -V | awk '{print $3}')
if [[ ${USE_TFA} == 1 ]]; then
  if test $(version ${MAGENTO_VERSION}) -ge $(version 2.4.0); then
    TFA_SECRET=$(warden env exec -T php-fpm pwgen -A1 128)
    TFA_SECRET=$(
      warden env exec -T php-fpm python -c "import base64; print base64.b32encode('${TFA_SECRET}')" | sed 's/=*$//'
    )
    OTPAUTH_URL=$(printf "otpauth://totp/%s%%3Alocaladmin%%40example.com?issuer=%s&secret=%s" \
      "${FULL_DOMAIN}" "${FULL_DOMAIN}" "${TFA_SECRET}"
    )
    if [[ ${CLEAN_INSTALL} ]]; then
      warden env exec -T php-fpm bin/magento config:set -q --lock-env twofactorauth/general/force_providers google
    fi
    warden env exec -T php-fpm bin/magento security:tfa:google:set-secret "${ADMIN_USER}" "${TFA_SECRET}"

    printf "%s\n\n" "${OTPAUTH_URL}"
    printf "2FA Authenticator Codes:\n%s\n" \
      "$(warden env exec -T php-fpm oathtool -s 30 -w 10 --totp --base32 "${TFA_SECRET}")"

    warden env exec -T php-fpm segno "${OTPAUTH_URL}" -s 4 -o "pub/media/${ADMIN_USER}-totp-qr.png"
    OTPAUTH_QRI="${URL_FRONT}media/${ADMIN_USER}-totp-qr.png?t=$(date +%s)"
  fi
fi

## check if two factor authentication is disabled, so it means that tfa module can be disabled as well
if [[ ${USE_TFA} == 0 ]]; then
  if test $(version ${MAGENTO_VERSION}) -ge $(version 2.4.6); then
    :: Disabling Two Factor Auth and Admin Adobe Ims Two Factor Auth
    warden env exec -T php-fpm bin/magento module:disable Magento_AdminAdobeImsTwoFactorAuth Magento_TwoFactorAuth
  else
    :: Disabling Two Factor Auth
    warden env exec -T php-fpm bin/magento module:disable Magento_TwoFactorAuth
  fi
fi

## sampledata install
if [[ ${SAMPLE_DATA} == 1 ]]; then
  :: Installing magento sample data
  warden env exec -T php-fpm bin/magento sampledata:deploy
  warden env exec -T php-fpm bin/magento setup:upgrade
fi

:: Rebuilding indexes
warden env exec -T php-fpm bin/magento indexer:reindex

:: Flushing cache
warden env exec -T php-fpm bin/magento cache:flush
warden env exec -T php-fpm bin/magento cache:disable block_html full_page

## call function to see if it can open magento url in browser
open_url_in_browser

## create app/code folder which would indicate that the project has been installed and ready for development
if [[ ! -d "${WARDEN_WEB_ROOT}/app/code" ]]; then
  :: Creating app/code folder
  mkdir -p "${WARDEN_WEB_ROOT}/app/code"
fi

:: Initialization complete
function print_install_info {
  echo ""
  FILL=$(printf "%0.s-" {1..128})
  LONGEST_STRING_FOR_C1="AdminURL"
  let "C2_LEN=${#URL_ADMIN}>${#ADMIN_PASS}?${#URL_ADMIN}:${#ADMIN_PASS}"
  let "C2_LEN=${C2_LEN}>${#OTPAUTH_QRI}?${C2_LEN}:${#OTPAUTH_QRI}"

  if [[ ${PRINT_MORE_VERBOSE_ON_INSTALL} == 1 ]]; then
    WARDEN_URL_DOMAIN=".warden.test"
    RABBITMQ_URL="${HTTP_PROTOCOL}://rabbitmq.${TRAEFIK_DOMAIN}/"
    ELASTICSEARCH_URL="${HTTP_PROTOCOL}://elasticsearch.${TRAEFIK_DOMAIN}/"
    TRAEFIK_URL="${HTTP_PROTOCOL}://traefik${WARDEN_URL_DOMAIN}/"
    PORTAINER_URL="${HTTP_PROTOCOL}://portainer${WARDEN_URL_DOMAIN}/"
    DNSMASQ_URL="${HTTP_PROTOCOL}://dnsmasq${WARDEN_URL_DOMAIN}/"
    MAILHOG_URL="${HTTP_PROTOCOL}://mailhog${WARDEN_URL_DOMAIN}/"
    LONGEST_STRING_FOR_C1="Elasticsearch"
    let "C2_LEN=${C2_LEN}>${#ELASTICSEARCH_URL}?${C2_LEN}:${#ELASTICSEARCH_URL}"
  fi

  C1_LEN=${#LONGEST_STRING_FOR_C1}

  ## note: in CentOS bash .* isn't supported (is on Darwin), but *.* is more cross-platform
  printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
  printf "+ %-*s + %-*s + \n" $C1_LEN FrontURL $C2_LEN "$URL_FRONT"
  printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
  printf "+ %-*s + %-*s + \n" $C1_LEN AdminURL $C2_LEN "$URL_ADMIN"
  printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL

  if [[ ${OTPAUTH_QRI} ]]; then
    printf "+ %-*s + %-*s + \n" $C1_LEN AdminOTP $C2_LEN "$OTPAUTH_QRI"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
  fi

  if [[ ${PRINT_ADMIN_CREDENTIALS} ]]; then
    printf "+ %-*s + %-*s + \n" $C1_LEN Username $C2_LEN "$ADMIN_USER"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN Password $C2_LEN "$ADMIN_PASS"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
  fi

  if [[ ${PRINT_MORE_VERBOSE_ON_INSTALL} == 1 ]]; then
    if [[ ${WARDEN_RABBITMQ} == 1 ]]; then
      printf "+ %-*s + %-*s + \n" $C1_LEN RabbitMQ $C2_LEN "$RABBITMQ_URL"
      printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    fi

    if [[ ${WARDEN_ELASTICSEARCH} == 1 ]]; then
      printf "+ %-*s + %-*s + \n" $C1_LEN Elasticsearch $C2_LEN "$ELASTICSEARCH_URL"
      printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    fi

    printf "+ %-*s + %-*s + \n" $C1_LEN Traefik $C2_LEN "$TRAEFIK_URL"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN Portainer $C2_LEN "$PORTAINER_URL"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN Dnsmasq $C2_LEN "$DNSMASQ_URL"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
    printf "+ %-*s + %-*s + \n" $C1_LEN MailHog $C2_LEN "$MAILHOG_URL"
    printf "+ %*.*s + %*.*s + \n" 0 $C1_LEN $FILL 0 $C2_LEN $FILL
  fi
}
print_install_info
