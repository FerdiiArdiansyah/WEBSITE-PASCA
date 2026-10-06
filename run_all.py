"""Jalankan seluruh microservice + gateway secara lokal (tanpa Docker).

    python run_all.py            # semua service
    python run_all.py --reload   # mode pengembangan (auto-reload)
"""
import os
import signal
import subprocess
import sys
import time

import httpx

from services.common.config import settings

SERVICES = [
    ("auth", "services.auth_service.main:app", 8001),
    ("notifikasi", "services.notifikasi_service.main:app", 8006),
    ("akademik", "services.akademik_service.main:app", 8002),
    ("tesis", "services.tesis_service.main:app", 8003),
    ("keuangan", "services.keuangan_service.main:app", 8004),
    ("layanan", "services.layanan_service.main:app", 8005),
    ("gateway", "services.gateway.main:app", settings.GATEWAY_PORT),
]


def main():
    reload = "--reload" in sys.argv
    procs = []
    for nama, target, port in SERVICES:
        cmd = [sys.executable, "-m", "uvicorn", target, "--host", "127.0.0.1", "--port", str(port), "--log-level", "warning"]
        if reload:
            cmd.append("--reload")
        procs.append((nama, port, subprocess.Popen(cmd, cwd=os.path.dirname(os.path.abspath(__file__)))))
        print(f"  > {nama:<11} http://127.0.0.1:{port}/docs")

    print("\nMenunggu service siap...")
    for _ in range(60):
        try:
            r = httpx.get(f"http://127.0.0.1:{settings.GATEWAY_PORT}/health", timeout=2)
            if r.status_code == 200:
                break
        except httpx.HTTPError:
            pass
        time.sleep(0.5)
    print(f"\nOK Gateway siap: http://127.0.0.1:{settings.GATEWAY_PORT}/docs   (Ctrl+C untuk berhenti)\n")

    def stop(*_):
        for _, _, p in procs:
            p.terminate()
        sys.exit(0)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    for _, _, p in procs:
        p.wait()


if __name__ == "__main__":
    main()
