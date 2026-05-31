Full App Backup Before High Risk Upgrade

Recommended Pi rollback structure

Create a dated backup folder:

sudo mkdir -p /opt/orchidapp-rollbacks/2026-05-31

Then copy the current app exactly:

sudo rsync -aHAX --numeric-ids /opt/orchidapp/ /opt/orchidapp-rollbacks/2026-05-31/orchidapp/

That backs up the deployed application files, including the web app, scripts and any bundled files under /opt/orchidapp.

Step 1 — list OrchidApp-related services

Run this first:

systemctl list-unit-files | grep -i orchid

You will probably see something like:

orchidapp.service                          enabled
orchidapp-environment-importer.service     enabled

You may see fewer or slightly different names. Paste the output if you want me to sanity-check it.

Step 2 — create a backup folder for service files

Run:

sudo mkdir -p /opt/orchidapp-rollbacks/2026-05-31/systemd
Step 3 — copy the actual service files

Run:

sudo cp -a /etc/systemd/system/orchid*.service \
  /opt/orchidapp-rollbacks/2026-05-31/systemd/ 2>/dev/null || true

That copies any service file starting with orchid.

3. Verify the copy exists
sudo du -sh /opt/orchidapp
sudo du -sh /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/orchidapp

The sizes should be broadly similar.

Then:

ls -la /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/orchidapp

You should see the current app files.

4. Capture a quick file listing

This gives you a readable record of what was present before the upgrade:

sudo find /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/orchidapp \
  -maxdepth 3 \
  -type f \
  | sort \
  | sudo tee /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/orchidapp-file-list.txt

Step 4 — save what systemd currently sees

This is useful because systemd can include overrides or expanded definitions.

Run:

systemctl cat orchidapp.service \
  | sudo tee /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/systemd/orchidapp.service.cat.txt

If you have the environment importer service too, run:

systemctl cat orchidapp-environment-importer.service \
  | sudo tee /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/systemd/orchidapp-environment-importer.service.cat.txt

If the second one says the service does not exist, that is fine.

Step 5 — verify what was backed up

Run:

ls -la /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/systemd

You want to see at least:

orchidapp.service
orchidapp.service.cat.txt

And possibly:

orchidapp-environment-importer.service
orchidapp-environment-importer.service.cat.txt

After this, the systemd service backup part is done.

Next is to back up the currently working deployed application folder. That is the bit that lets you roll back the actual software if the upgrade breaks.

Assuming the app is at:

/opt/orchidapp
1. Create the rollback folder
sudo mkdir -p /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/orchidapp
2. Copy the current app exactly
sudo rsync -aHAX --numeric-ids \
  /opt/orchidapp/ \
  /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/orchidapp/

The trailing slashes matter. This copies the contents of /opt/orchidapp into the rollback copy.

3. Verify the copy exists
sudo du -sh /opt/orchidapp
sudo du -sh /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/orchidapp

The sizes should be broadly similar.

Then:

ls -la /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/orchidapp

You should see the current app files.

4. Capture a quick file listing

This gives you a readable record of what was present before the upgrade:

sudo find /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/orchidapp \
  -maxdepth 3 \
  -type f \
  | sort \
  | sudo tee /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade/orchidapp-file-list.txt
5. Confirm the existing app still works

Restart it cleanly:

sudo systemctl restart orchidapp.service
sudo systemctl status orchidapp.service --no-pager

Then open OrchidApp in the browser and confirm it still loads.

1. Save a Pi state report

Run this as one block:

{
  echo "Date:"
  date

  echo
  echo "Hostname:"
  hostnamectl

  echo
  echo "Kernel:"
  uname -a

  echo
  echo "OS release:"
  cat /etc/os-release

  echo
  echo ".NET:"
  dotnet --info 2>/dev/null || true

  echo
  echo "MariaDB:"
  mariadb --version 2>/dev/null || mysql --version 2>/dev/null || true

  echo
  echo "OrchidApp service:"
  systemctl status orchidapp.service --no-pager || true

  echo
  echo "Environment importer service:"
  systemctl status orchidapp-environment-importer.service --no-pager || true

  echo
  echo "Orchid-related unit files:"
  systemctl list-unit-files | grep -i orchid || true

  echo
  echo "Listening ports:"
  ss -ltnp | grep -E '5000|5001|3306|3308' || true

  echo
  echo "Disk usage:"
  df -h

  echo
  echo "App folder size:"
  sudo du -sh /opt/orchidapp 2>/dev/null || true

  echo
  echo "Rollback folder size:"
  sudo du -sh /opt/orchidapp-rollbacks/2026-05-31-pre-upgrade 2>/dev/null || true

} | sudo tee /opt/orchidapp-rollbacks/2026-05-31/pi-state-report.txt

Then check it exists:

ls -lh /opt/orchidapp-rollbacks/2026-05-31/pi-state-report.txt

2. Compress the rollback folder into one archive

Run:

cd /opt/orchidapp-rollbacks

sudo tar -czpf 2026-05-31.tar.gz 2026-05-31

Then verify the archive:

ls -lh /opt/orchidapp-rollbacks/2026-05-31.tar.gz

1. Optional but strongly recommended: test the archive can be read

Run:

sudo tar -tzf /opt/orchidapp-rollbacks/2026-05-31.tar.gz | head -50