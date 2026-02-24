from supabase import create_client, Client
from api.settings import settings

_supabase: Client | None = None

def supabase_client() -> Client:
    global _supabase
    if _supabase is None:
        _supabase = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
    return _supabase
