from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "atlas-ai"
    environment: str = "development"
    openai_api_key: str = ""
    openai_model: str = "gpt-5.6-luna"

    model_config = {"env_prefix": ""}


settings = Settings()
