from fastapi import FastAPI
from api.routes import versions

app = FastAPI(title="AI Lane Backend")

@app.get("/")
def root():
    return {"status": "ok", "docs": "/docs"}

app.include_router(versions.router)
