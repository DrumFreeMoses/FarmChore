FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /relay .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
COPY --from=build /relay /usr/local/bin/relay
ENV ADDR=:8080 DATABASE_PATH=/data/farmchore.db
VOLUME ["/data"]
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/relay"]
