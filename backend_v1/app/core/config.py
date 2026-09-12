import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    """Small env-based settings object; no secrets live in source code."""

    database_url = os.getenv("DATABASE_URL", "sqlite:///./support.db")
    # OPENAI_API_KEY fallback lets an existing local .env keep working while it
    # is renamed; the client still sends requests only to Yandex AI Studio.
    yandex_api_key = os.getenv("YANDEX_API_KEY") or os.getenv("OPENAI_API_KEY")
    # Yandex AI Studio's generated example calls this YANDEX_CLOUD_FOLDER.
    # Keep YANDEX_FOLDER_ID as an alias for compatibility with our README.
    yandex_folder_id = os.getenv("YANDEX_CLOUD_FOLDER") or os.getenv(
        "YANDEX_FOLDER_ID"
    )
    yandex_model = os.getenv("YANDEX_MODEL", "aliceai-llm")
    yandex_base_url = os.getenv(
        "YANDEX_BASE_URL", "https://ai.api.cloud.yandex.net/v1"
    )


settings = Settings()
