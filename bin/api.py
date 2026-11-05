import os

import uvicorn

from src.fastapi import create_app

app = create_app()

if __name__ == "__main__":
    reload = os.getenv("UVICORN_RELOAD", "0") == "1"
    uvicorn.run(
        # Строка нужна только для autoreload; без него передаём готовое
        # приложение, чтобы не импортировать модуль второй раз.
        "bin.api:app" if reload else app,
        host="0.0.0.0",
        port=8000,
        reload=reload,
    )
