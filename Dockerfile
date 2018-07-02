FROM alpine:3.7

RUN apk update && apk add ipsec-tools

COPY run.sh /run.sh
RUN chmod a+x /run.sh
CMD "/run.sh"
