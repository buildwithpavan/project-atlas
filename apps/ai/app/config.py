from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "voceive-ai"
    environment: str = "development"
    openai_api_key: str = ""
    openai_model: str = "gpt-5.6-luna"
    openai_timeout: float = 25.0
    ai_internal_token: str = ""

    model_config = {"env_prefix": ""}


settings = Settings()
