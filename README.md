# Digital Store SEO

Use with dokku
```
cd ds-seo
git remote add dokku dokku@dokku.gsn.io:ds-seo
git push dokku master
```

Use on it's own VPS as a service on redhat/centos server.
* Copy init.d/dsseo to /etc
* clone to folder in /var/node
* run chkconfig to add to startup
```
sudo adduser --system --shell /sbin/nologin --user-group -m --home /var/node node
sudo chkconfig --add dsseo
```
