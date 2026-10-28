# Fixed .NET 8.0.33 Bookworm ARM64 manifest. Record installed native package
# versions in every result; this is an acceptance harness, not a Pi OS image.
FROM mcr.microsoft.com/dotnet/aspnet@sha256:80897d3ea774fafcedb2858f01266533b2d093e8574307eec70806f83115b5f0
RUN apt-get update && apt-get install -y --no-install-recommends \
    libvips42=8.14.1-3+deb12u3 curl python3 mariadb-client rclone \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /specimen/publish /specimen/uploads /specimen/configuration /checks
WORKDIR /checks
ENV ASPNETCORE_ENVIRONMENT=Production ASPNETCORE_URLS=http://127.0.0.1:5080
ENTRYPOINT ["python3", "-c", "import time; time.sleep(86400)"]
