🧩 Adding a New Static Site (e.g. runway.demonsmp.win)

This webserver stack hosts static HTML apps (like Runway) using Nginx in Docker, fronted by Cloudflare Tunnel for HTTPS and access control.

## 1. Create the Site Directory

mkdir -p data/sites/<sitename>

Example:

mkdir -p data/sites/runway

Copy or deploy your built static app there:

rsync -av /path/to/runway-sim/dist/ data/sites/runway/

## 2. Add an Nginx vhost

Create a config in config/nginx/conf.d/<sitename>.conf:

server {
listen 8080;
server_name <domain>;

root /srv/sites/<sitename>;
index index.html;

location / {
include /etc/nginx/snippets/spa_tryfiles.conf;
}

include /etc/nginx/snippets/static_cache.conf;
}

Example:

server {
listen 8080;
server_name runway.demonsmp.win;

root /srv/sites/runway;
index index.html;

location / {
include /etc/nginx/snippets/spa_tryfiles.conf;
}

include /etc/nginx/snippets/static_cache.conf;
}

Then validate and reload:

./run.sh test-conf
./run.sh reload


⸻

## 3. Update Cloudflare Tunnel Configuration

Edit the tunnel config (cloudflare-homecloud/cf/config.yml) on your M1 mini.

Add a new ingress entry above the http_status:404 line:

- hostname: runway.demonsmp.win
  service: http://192.168.2.10:8088
  originRequest:
  httpHostHeader: runway.demonsmp.win

Then restart Cloudflare Tunnel:

sudo systemctl restart cloudflared


⸻

## 4. Add DNS Record for the Tunnel

Run this command from the cloudflare-homecloud repo:

./run.sh tunnel-dns runway.demonsmp.win

Example output:

2025-10-25T20:38:57Z INF Added CNAME runway.demonsmp.win which will route to this tunnel tunnelID=3bc5583e-c22f-43aa-9f3e-56b2e9c59d89


⸻

## 5. Test Everything

# On mc-proxy (local test)
curl -I http://127.0.0.1:8088/

# Through Cloudflare
curl -I https://runway.demonsmp.win

✅ You should see 200 OK and Cloudflare headers.

⸻

## 6. Common Maintenance Commands

Action	Command
Start stack	./run.sh start
Stop stack	./run.sh stop
Reload Nginx config	./run.sh reload
View logs	./run.sh logs
Validate config	./run.sh test-conf
Backup sites/configs	./run.sh backup


⸻

Notes
•	Nginx listens on 8080 internally → exposed to host on 127.0.0.1:8088
•	Cloudflare Tunnel on your M1 mini forwards HTTPS → http://192.168.2.10:8088
•	Cloudflare caches static content, so Nginx resource limits are low (256 MB RAM, 0.5 CPU).
•	When adding a new site, you only need to:
1.	Create the site folder
2.	Add the Nginx config
3.	Add the Cloudflare ingress entry
4.	Add the tunnel DNS record
5.	Reload both services