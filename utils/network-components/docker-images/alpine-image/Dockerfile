FROM alpine:latest
LABEL maintainer=”vitorreiel”
RUN apk update 
RUN apk add bash \ 
	tcpdump \
	iperf \
	busybox-extras \
	iproute2 \
	iputils

CMD ["/bin/sh"]