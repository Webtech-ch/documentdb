# image

## Build Image

```sh
# build the image image
./packaging/webtech_build.sh

#tag
docker tag documentdb ghcr.io/webtech-ch/documentdb:latest

# authenticate if needed
docker login --username <username> --password <deploy token> ghcr.io

# Push Image
docker push ghcr.io/webtech-ch/documentdb:latest
```

## github change visibility

-  GitHub Packages
-  Package Settings
-  Change Visibility

## use Image

```
# reference FROM: or IMAGE:
ghcr.io/webtech-ch/documentdb:latest
```