# Automated creation of web scenarios in Zabbix

This tool is build on top of jwilder/docker-gen project. It knows when new container is created and adds this container's URL to Zabbix Web tab. This way you don't have to maintain it manually. Works great when you have a lot of URL endpoints to monitor.

Out of the box it will work if your containers will have `VIRTUAL_HOST` environment variable with url. To change the way it works you can adjust `endpoints.tmpl` to implement more complex logic. Check docker-gen documentation for more info.

Check example folder to see how it will work with Zabbix. Just run `docker-compose up -d`. Then login to Zabbix and check Web tab, you should see some web scenarios there.

Tested with Zabbix 3.2. May work with other versions as well
