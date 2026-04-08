FROM frappe/bench:latest

ARG FRAPPE_BRANCH=version-16
ARG ERPNEXT_BRANCH=version-16
ARG PAYMENTS_BRANCH=version-16

USER frappe
WORKDIR /home/frappe

ENV NVM_DIR=/home/frappe/.nvm
SHELL ["/bin/bash", "-c"]

# bench init WITHOUT --skip-assets so frappe's node_modules (esbuild etc.) get installed
RUN source "$NVM_DIR/nvm.sh" && \
    bench init \
        --frappe-branch ${FRAPPE_BRANCH} \
        --skip-redis-config-generation \
        frappe-bench

WORKDIR /home/frappe/frappe-bench

RUN source "$NVM_DIR/nvm.sh" && \
    bench get-app --branch ${ERPNEXT_BRANCH} --skip-assets erpnext && \
    bench get-app --branch ${PAYMENTS_BRANCH} --skip-assets payments

COPY --chown=frappe:frappe . apps/hrms

RUN printf '\nhrms\n' >> sites/apps.txt && \
    ./env/bin/pip install -e apps/hrms

RUN source "$NVM_DIR/nvm.sh" && \
    cd apps/hrms && yarn install && yarn build

RUN source "$NVM_DIR/nvm.sh" && \
    export NODE_OPTIONS="--max-old-space-size=4096" && \
    bench build

RUN sed -i '/redis/d' Procfile && \
    sed -i '/watch/d' Procfile

RUN cp -r sites sites-init

RUN cp apps/hrms/docker/entrypoint.sh /home/frappe/entrypoint.sh

USER root
RUN chmod +x /home/frappe/entrypoint.sh && \
    apt-get update && \
    apt-get install -y --no-install-recommends netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*
USER frappe

EXPOSE 8000 9000

ENTRYPOINT ["/home/frappe/entrypoint.sh"]
CMD ["bench", "start"]
