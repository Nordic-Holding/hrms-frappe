FROM frappe/bench:latest

ARG FRAPPE_BRANCH=version-16
ARG ERPNEXT_BRANCH=version-16
ARG PAYMENTS_BRANCH=version-16

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends netcat-openbsd && \
    rm -rf /var/lib/apt/lists/*
USER frappe

WORKDIR /home/frappe
ENV NVM_DIR=/home/frappe/.nvm
SHELL ["/bin/bash", "-c"]

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

RUN source "$NVM_DIR/nvm.sh" && \
    printf '\nhrms\n' >> sites/apps.txt && \
    ./env/bin/pip install -e apps/hrms && \
    cd apps/hrms && yarn install && yarn build && cd ../.. && \
    export NODE_OPTIONS="--max-old-space-size=4096" && \
    bench build && \
    sed -i '/redis/d' Procfile && \
    sed -i '/watch/d' Procfile && \
    cp apps/hrms/docker/entrypoint.sh /home/frappe/entrypoint.sh && \
    chmod +x /home/frappe/entrypoint.sh && \
    cp -r sites sites-init && \
    rm -rf \
        apps/frappe/.git \
        apps/erpnext/.git \
        apps/payments/.git \
        apps/hrms/.git \
        apps/hrms/node_modules \
        apps/hrms/frontend/node_modules \
        apps/hrms/roster/node_modules \
        apps/frappe/node_modules/.cache \
        env/lib/python*/site-packages/pip* \
        /home/frappe/.cache \
        /tmp/*

EXPOSE 8000 9000

ENTRYPOINT ["/home/frappe/entrypoint.sh"]
CMD ["bench", "start"]
