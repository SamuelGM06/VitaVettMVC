# syntax=docker/dockerfile:1

# ---- Build ----
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restaurar primero para aprovechar la caché de capas.
COPY VitaVettMVC.csproj ./
RUN dotnet restore VitaVettMVC.csproj

COPY . ./
RUN dotnet publish VitaVettMVC.csproj -c Release -o /app/publish --no-restore

# ---- Runtime ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

ENV ASPNETCORE_ENVIRONMENT=Production \
    ASPNETCORE_URLS=http://+:8080

COPY --from=build /app/publish .

# Render asigna el puerto vía PORT; por defecto usamos 8080.
EXPOSE 8080

USER app

ENTRYPOINT ["dotnet", "VitaVettMVC.dll"]
