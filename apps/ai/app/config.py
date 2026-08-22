from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "atlas-ai"
    environment: str = "development"
    openai_api_key: str = ""

    model_config = {"env_prefix": ""}


settings = Settings()
