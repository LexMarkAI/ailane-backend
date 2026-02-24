from fastapi import APIRouter, HTTPException
from api.deps import supabase_client

router = APIRouter()

@router.get("/versions")
async def get_versions():
    try:
        client = supabase_client()          # ✅ CALL the function
        response = client.table("acei_versions").select("*").execute()
        return response.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
