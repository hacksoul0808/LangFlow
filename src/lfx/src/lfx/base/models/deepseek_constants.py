"""DeepSeek model catalog primitives.

DeepSeek provides an OpenAI-compatible API at ``https://api.deepseek.com``.
The unified model layer uses ``ChatOpenAI`` pointed at the DeepSeek base URL.

Model IDs are static defaults shown when the user has not yet configured a
``DEEPSEEK_API_KEY``. Once credentials are saved the live model list can be
refreshed through the provider settings page.
"""

from .model_metadata import create_model_metadata

DEEPSEEK_MODELS_DETAILED = [
    # Current tool-calling supported models
    create_model_metadata(provider="DeepSeek", name="deepseek-v4-pro", icon="DeepSeek", tool_calling=True),
    create_model_metadata(provider="DeepSeek", name="deepseek-v4-flash", icon="DeepSeek", tool_calling=True),
    # Deprecated models (will be removed 2026/07/24)
    create_model_metadata(
        provider="DeepSeek", name="deepseek-chat", icon="DeepSeek", tool_calling=True, deprecated=True
    ),
    create_model_metadata(
        provider="DeepSeek", name="deepseek-reasoner", icon="DeepSeek", tool_calling=True, deprecated=True
    ),
]

DEEPSEEK_MODELS = [
    metadata["name"]
    for metadata in DEEPSEEK_MODELS_DETAILED
    if not metadata.get("deprecated", False) and metadata.get("tool_calling", False)
]

TOOL_CALLING_SUPPORTED_DEEPSEEK_MODELS = [
    metadata["name"] for metadata in DEEPSEEK_MODELS_DETAILED if metadata.get("tool_calling", False)
]

TOOL_CALLING_UNSUPPORTED_DEEPSEEK_MODELS = [
    metadata["name"] for metadata in DEEPSEEK_MODELS_DETAILED if not metadata.get("tool_calling", False)
]

DEPRECATED_MODELS = [metadata["name"] for metadata in DEEPSEEK_MODELS_DETAILED if metadata.get("deprecated", False)]

DEFAULT_DEEPSEEK_API_URL = "https://api.deepseek.com"
