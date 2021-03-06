ARG BASE_IMAGE=mcr.microsoft.com/azure-functions/base:2.0
FROM ${BASE_IMAGE} as runtime-image

FROM microsoft/dotnet:2.2-aspnetcore-runtime

ENV LANG=C.UTF-8 \
    ACCEPT_EULA=Y \
    PYTHON_VERSION=3.6.8 \
    PYTHON_PIP_VERSION=19.0 \
    PYENV_ROOT=/root/.pyenv \
    PATH=/root/.pyenv/shims:/root/.pyenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    AzureWebJobsScriptRoot=/home/site/wwwroot \
    HOME=/home \
    FUNCTIONS_WORKER_RUNTIME=python	
	

# Install Python dependencies
RUN apt-get update && \
    apt-get install -y wget && \
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt-get update && \
    apt-get install -y apt-transport-https curl gnupg && \
    curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    # Needed for libss1.0.0 and in turn MS SQL
    echo 'deb http://security.debian.org/debian-security jessie/updates main' >> /etc/apt/sources.list && \
    # install necessary locales for MS SQL
    apt-get update && apt-get install -y locales && \
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && \
    locale-gen && \
    # install MS SQL related packages
    apt-get update && \
    apt-get install -y debconf libcurl3 libc6 openssl libstdc++6 libkrb5-3 unixodbc msodbcsql17 mssql-tools libssl1.0.0 \
    git make build-essential libssl-dev zlib1g-dev libbz2-dev  \
    libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev \
    xz-utils tk-dev libpq-dev python3-dev libevent-dev unixodbc-dev && \
    curl -L https://github.com/pyenv/pyenv-installer/raw/master/bin/pyenv-installer | bash && \
	\
	# Install Python
    PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install $PYTHON_VERSION && \
    pyenv global $PYTHON_VERSION && \
    pip install pip==$PYTHON_PIP_VERSION && \
	\
    export WORKER_TAG=1.0.0b4 && \
    export AZURE_FUNCTIONS_PACKAGE_VERSION=1.0.0b3 &&\
    wget --quiet https://github.com/Azure/azure-functions-python-worker/archive/$WORKER_TAG.tar.gz && \
    tar xvzf $WORKER_TAG.tar.gz && \
    mv azure-functions-python-worker-* azure-functions-python-worker && \
    mv /azure-functions-python-worker/python /python && \
    rm -rf $WORKER_TAG.tar.gz /azure-functions-python-worker && \
    pip install azure-functions==$AZURE_FUNCTIONS_PACKAGE_VERSION azure-functions-worker==$WORKER_TAG


COPY --from=runtime-image ["/azure-functions-host", "/azure-functions-host"]
RUN mv /python /azure-functions-host/workers

# Add custom worker config
COPY ./python-context/start.sh /azure-functions-host/workers/python/
COPY ./python-context/worker.config.json /azure-functions-host/workers/python/
RUN chmod +x /azure-functions-host/workers/python/start.sh

CMD [ "dotnet", "/azure-functions-host/Microsoft.Azure.WebJobs.Script.WebHost.dll" ]