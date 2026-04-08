FROM frappe/bench:latest

ARG FRAPPE_BRANCH=version-16
ARG ERPNEXT_BRANCH=version-16
ARG PAYMENTS_BRANCH=version-16

USER frappe
WORKDIR /home/frappe

RUN bench init \
    --frappe-branch ${FRAPPE_BRANCH} \
    --skip-redis-config-generation \
    --skip-assets \
    frappe-bench

WORKDIR /home/frappe/frappe-bench

RUN bench get-app --branch ${ERPNEXT_BRANCH} --skip-assets erpnext && \
    bench get-app --branch ${PAYMENTS_BRANCH} --skip-assets payments

COPY --chown=frappe:frappe . apps/hrms

RUN echo "hrms" >> sites/apps.txt && \
    ./env/bin/pip install -e apps/hrms

RUN cd apps/hrms && yarn install && yarn build

RUN bench build

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
