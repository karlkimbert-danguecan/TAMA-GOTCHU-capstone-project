import cellular 
import usocket
import time
import gps
from machine import Pin

# --- SIM / Server configuration ---
APN = "internet" 
USER = ""
PWD = ""

HOST = "tamagotchu.x10.network"
PORT = 80
ENDPOINT = "/TamaGotchu2/update_location.php"
ENDPOINT_EMERGENCY = "/TamaGotchu2/emergency.php"

device_id = "9702425019"
user_id = "o2nNqGRLosentS0lipHbs3kSYwx1"

# --- LED Setup ---
led = Pin(27, Pin.OUT)

# --- Emergency Button Setup ---
emergency_btn = Pin(6, Pin.IN, Pin.PULL_UP)  # active LOW

# Turn LED ON
led.value(1)
time.sleep(3)
led.value(0)

# --- Start GPRS ---
def start_gprs():
    time.sleep(60)
    print("Starting GPRS with APN:", APN)
    cellular.gprs(APN, USER, PWD)
    time.sleep(5)

start_gprs()

def ensure_dns_and_connectivity(hostname="example.com"):
    try:
        addr = usocket.getaddrinfo(hostname, 80)[0][-1]
        s = usocket.socket()
        s.settimeout(10)
        s.connect(addr)
        s.send(b"GET / HTTP/1.0\r\nHost: %s\r\n\r\n" % hostname.encode())
        s.recv(64)
        s.close()
        return True
    except Exception as e:
        print("Connectivity check failed:", e)
        try:
            s.close()
        except:
            pass
        return False

print("Checking internet connectivity...")
retry = 0
while not ensure_dns_and_connectivity(HOST):
    retry += 1
    print("No connectivity yet. Retry", retry, "in 5s...")
    time.sleep(5)
    start_gprs()

print("Internet reachable. Starting GPS + POST loop.")

# --- Enable GPS ---
gps.on()
print("Waiting for GPS fix...")

def send_location(lat, lng):
    post_body = "device_id={}&user_id={}&lat={:.6f}&lng={:.6f}".format(device_id, user_id, lat, lng)
    content_length = len(post_body)

    http_req = []
    http_req.append("POST {} HTTP/1.1".format(ENDPOINT))
    http_req.append("Host: {}".format(HOST))
    http_req.append("Content-Type: application/x-www-form-urlencoded")
    http_req.append("Content-Length: {}".format(content_length))
    http_req.append("Connection: close")
    http_req.append("")
    http_req.append(post_body)
    http_request = "\r\n".join(http_req)

    try:
        addr = usocket.getaddrinfo(HOST, PORT)[0][-1]
        s = usocket.socket()
        s.settimeout(20)
        s.connect(addr)
        s.send(http_request.encode())
        while s.recv(512):
            pass
        s.close()
        return True
    except Exception as e:
        print("Error sending location:", e)
        try:
            s.close()
        except:
            pass
        start_gprs()
        return False

# --- Emergency send (ONLY user_id) ---
def send_emergency_user_only():
    post_body = "device_id={}&user_id={}".format(device_id, user_id)
    content_length = len(post_body)

    http_req = []
    http_req.append("POST {} HTTP/1.1".format(ENDPOINT_EMERGENCY))
    http_req.append("Host: {}".format(HOST))
    http_req.append("Content-Type: application/x-www-form-urlencoded")
    http_req.append("Content-Length: {}".format(content_length))
    http_req.append("Connection: close")
    http_req.append("")
    http_req.append(post_body)
    http_request = "\r\n".join(http_req)

    print("🚨 EMERGENCY BUTTON PRESSED — sending user_id only")

    try:
        addr = usocket.getaddrinfo(HOST, PORT)[0][-1]
        s = usocket.socket()
        s.settimeout(20)
        s.connect(addr)
        s.send(http_request.encode())
        while s.recv(512):
            pass
        s.close()
        print("✅ Emergency sent")
    except Exception as e:
        print("❌ Emergency failed:", e)
        try:
            s.close()
        except:
            pass
        start_gprs()

# --- Main loop (emergency button checked every 0.1s, GPS every 60s) ---
gps_update_interval = 60  # seconds
last_gps_time = time.time() - gps_update_interval  # force immediate GPS send on start

while True:
    # --- Emergency Button Check ---
    if emergency_btn.value() == 0:  # active LOW
        send_emergency_user_only()

        # LED feedback
        for _ in range(6):
            led.value(1)
            time.sleep(0.2)
            led.value(0)
            time.sleep(0.2)

        time.sleep(0.5)  # short debounce

    # --- GPS Update every 60s ---
    current_time = time.time()
    if current_time - last_gps_time >= gps_update_interval:
        loc = gps.get_location()
        sats = gps.get_satellites()

        print("Location:", loc)
        print("Satellites (tracked, visible):", sats)

        if loc and isinstance(loc, tuple) and len(loc) == 2:
            lat, lng = loc
            if lat != 0 and lng != 0:
                led.value(1)
                send_location(lat, lng)
            else:
                for _ in range(10):
                    led.value(1)
                    time.sleep(0.1)
                    led.value(0)
                    time.sleep(0.1)
        else:
            for _ in range(5):
                led.value(1)
                time.sleep(0.1)
                led.value(0)
                time.sleep(0.1)

        led.value(0)
        last_gps_time = current_time

    # --- Small sleep to allow frequent emergency button checks ---
    time.sleep(0.1)
