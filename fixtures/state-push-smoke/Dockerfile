FROM alpine:3.22

COPY message.txt /message.txt
RUN dd if=/dev/zero of=/payload.bin bs=1M count=64

CMD ["cat", "/message.txt"]
