from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from api.deps import supabase_client

app = FastAPI(title="Ailane ACEI API")


# =========================
# HEALTH CHECK
# =========================
@app.get("/health")
def health():
    return {"status": "ok"}


# =========================
# ACTIVE VERSION
# =========================
@app.get("/versions/active")
def active_version():
    sb = supabase_client()

    res = (
        sb.table("acei_versions")
        .select("version,published_at,active")
        .eq("active", True)
        .limit(1)
        .execute()
    )

    data = res.data or []
    if not data:
        raise HTTPException(
            status_code=404,
            detail="No active ACEI version found"
        )

    return data[0]


# =========================
# UPDATE MODEL
# =========================
class UpdateIn(BaseModel):
    title: str
    summary: str
    jurisdiction: str
    source_url: Optional[str] = None
    published_at: Optional[str] = None


# =========================
# CREATE UPDATE
# =========================
@app.post("/updates")
def create_update(payload: UpdateIn):
    sb = supabase_client()

    res = (
        sb.table("regulatory_updates")
        .insert(payload.model_dump())
        .execute()
    )

    return {"inserted": res.data}


# =========================
# LIST UPDATES
# =========================
@app.get("/updates")
def list_updates(limit: int = 50):
    sb = supabase_client()

    res = (
        sb.table("regulatory_updates")
        .select("*")
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )

    return {
        "count": len(res.data or []),
        "items": res.data or []
    }
