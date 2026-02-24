from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    SUPABASE_URL: str
    SUPABASE_SERVICE_ROLE_KEY: str
    ACEI_ACTIVE_VERSION: str = "v1.0.0"

    class Config:
        env_file = ".env"

settings = Settings()
