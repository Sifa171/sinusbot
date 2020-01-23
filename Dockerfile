FROM quay.io/galexrt/sinusbot:latest

ENV SINUS_USER=1001 \
    SINUS_GROUP=1001

ENTRYPOINT ["/entrypoint.sh"]