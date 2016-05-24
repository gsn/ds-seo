# Digital Store SEO

Use with dokku
```
cd ds-seo
git remote add dokku dokku@dokku.brick.io:ds-seo
git push dokku master
```

With docker
```
docker run --env-file=.env -p 4001:4001 -it brickinc/ds-seo /bin/run.sh
```

Build
```
docker build -t brickinc/ds-seo:0.0.7 .
docker tag brickinc/ds-seo:0.0.7 brickinc/ds-seo:latest
```
