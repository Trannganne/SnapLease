FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY ["NuGet.Config", "./"]
COPY ["RentalCamera.Api/RentalCamera.Api.csproj", "RentalCamera.Api/"]

RUN dotnet restore "RentalCamera.Api/RentalCamera.Api.csproj" \
    --configfile "/src/NuGet.Config"

COPY . .

WORKDIR "/src/RentalCamera.Api"

RUN dotnet publish "RentalCamera.Api.csproj" \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app

EXPOSE 8080

COPY --from=build /app/publish .

ENTRYPOINT ["dotnet", "RentalCamera.Api.dll"]