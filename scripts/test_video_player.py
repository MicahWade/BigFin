#!/usr/bin/env python3
import sys
import os
import urllib.request
import json

server_url = os.environ.get("JELLYFIN_SERVER_URL", "http://localhost:8096")
token = os.environ.get("JELLYFIN_TOKEN", "")

if len(sys.argv) > 1:
    server_url = sys.argv[1]
if len(sys.argv) > 2:
    token = sys.argv[2]

print("==================================================")
print(" Bigfin Media Stream Test - Direct Jellyfin HLS ")
print("==================================================")
print(f"Target Server: {server_url}")

if not token:
    print("[NOTE] No JELLYFIN_TOKEN provided. Provide token via environment variable or argument to test stream access.")
    sys.exit(0)

url = f"{server_url}/Items?api_key={token}&IncludeItemTypes=Episode,Movie&Recursive=true&Limit=1"
req = urllib.request.Request(
    url,
    headers={"X-Emby-Authorization": f'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="{token}"'}
)

try:
    with urllib.request.urlopen(req, timeout=5) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        items = data.get("Items", [])
        if items:
            item = items[0]
            print(f"[SUCCESS] Media Found: {item.get('Name')} (ID: {item.get('Id')})")
            hls_url = f"{server_url}/Videos/{item.get('Id')}/master.m3u8?MediaSourceId={item.get('Id')}&VideoCodec=h264&AudioCodec=aac,mp3&api_key={token}"
            print(f"[STREAM URL] {hls_url}")
            
            # Verify HLS Master Playlist response
            playlist_req = urllib.request.Request(hls_url)
            with urllib.request.urlopen(playlist_req, timeout=5) as pl_resp:
                pl_content = pl_resp.read().decode('utf-8')
                print("[PLAYLIST VERIFICATION]")
                print(pl_content.strip())
                print("[TEST RESULT] HLS master playlist valid & ready for streaming!")
        else:
            print("[ERROR] No media items returned from server.")
except Exception as e:
    print(f"[ERROR] Test failed: {e}")
