import argparse
import os
from pathlib import Path

import uvicorn


BACKEND_DIR = Path(__file__).resolve().parent
SRC_DIR = BACKEND_DIR / "src"
DEFAULT_WORKERS = min(4, os.cpu_count() or 1)


def main():
    parser = argparse.ArgumentParser(description="Servidor de producao do Flash-Dash")
    parser.add_argument("--host", default=os.getenv("HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.getenv("PORT", "8000")))
    parser.add_argument(
        "--workers",
        type=int,
        default=int(os.getenv("WEB_CONCURRENCY", str(DEFAULT_WORKERS))),
    )
    parser.add_argument(
        "--backlog",
        type=int,
        default=int(os.getenv("UVICORN_BACKLOG", "4096")),
    )
    args = parser.parse_args()
    if args.workers < 1:
        parser.error("workers precisa ser maior que zero.")

    uvicorn.run(
        "main:app",
        app_dir=str(SRC_DIR),
        host=args.host,
        port=args.port,
        workers=args.workers,
        backlog=args.backlog,
        access_log=False,
        server_header=False,
        date_header=False,
        timeout_keep_alive=5,
        loop="auto",
        http="auto",
    )


if __name__ == "__main__":
    main()
