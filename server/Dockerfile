# بناء ثنائي صغير وتشغيله — يصلح لأي استضافة تدعم Docker
# (Render, Railway, Fly.io, Google Cloud Run، إلخ)
FROM golang:1.23-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /out/server .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=build /out/server ./server
# uploads و data.json ينكتبون وقت التشغيل؛ ننشئ المجلد مسبقاً
RUN mkdir -p uploads
EXPOSE 8080
CMD ["./server"]
