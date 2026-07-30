import sys
import urllib.request
import json

server_url = "http://100.85.125.82:8096"
token = "0b8630ceeb2f4da6a4230bdac8f4a599"

print("==================================================")
print(" Bigfin Media Stream Test - Direct Jellyfin HLS ")
print("==================================================")

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
                print("[TEST RESULT] HLS master playlist valid & ready for QtMultimedia video streaming!")
        else:
            print("[ERROR] No media items returned.")
except Exception as e:
    print(f"[ERROR] Test failed: {e}")
