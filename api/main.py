from fastapi import FastAPI, HTTPException
from api.deps import supabase_client

app = FastAPI(title="Ailane ACEI API")


@app.get("/health")
def health():
    return {"status": "ok"}


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
        raise HTTPException(status_code=404, detail="No active ACEI version found")
    return data[0]


@app.get("/updates")
def get_updates():
    sb = supabase_client()
    res = (
        sb.table("regulatory_updates")
        .select("*")
        .order("created_at", desc=True)
        .limit(50)
        .execute()
    )
    return res.data or []
