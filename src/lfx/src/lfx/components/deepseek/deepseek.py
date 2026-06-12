from typing import Any, cast

import requests

from lfx.base.models.deepseek_constants import (
    DEEPSEEK_MODELS,
    DEFAULT_DEEPSEEK_API_URL,
    TOOL_CALLING_SUPPORTED_DEEPSEEK_MODELS,
    TOOL_CALLING_UNSUPPORTED_DEEPSEEK_MODELS,
)
from lfx.base.models.model import LCModelComponent
from lfx.field_typing import LanguageModel
from lfx.field_typing.range_spec import RangeSpec
from lfx.io import BoolInput, DropdownInput, IntInput, MessageTextInput, SecretStrInput, SliderInput
from lfx.log.logger import logger
from lfx.schema.dotdict import dotdict


class DeepSeekModelComponent(LCModelComponent):
    display_name = "DeepSeek"
    description = "Generate text using DeepSeek LLMs."
    icon = "DeepSeek"
    name = "DeepSeekModel"

    inputs = [
        *LCModelComponent.get_base_inputs(),
        IntInput(
            name="max_tokens",
            display_name="Max Tokens",
            advanced=True,
            value=4096,
            info="The maximum number of tokens to generate. Set to 0 for unlimited tokens.",
        ),
        DropdownInput(
            name="model_name",
            display_name="Model Name",
            options=DEEPSEEK_MODELS,
            refresh_button=True,
            value=DEEPSEEK_MODELS[0],
            combobox=True,
        ),
        SecretStrInput(
            name="api_key",
            display_name="DeepSeek API Key",
            info="The DeepSeek API Key.",
            value=None,
            required=True,
            real_time_refresh=True,
        ),
        SliderInput(
            name="temperature",
            display_name="Temperature",
            value=0.1,
            info="Controls randomness in responses. Must be in the closed interval [0.0, 2.0].",
            range_spec=RangeSpec(min=0, max=2, step=0.01),
            advanced=True,
        ),
        MessageTextInput(
            name="base_url",
            display_name="DeepSeek API URL",
            info="Endpoint of the DeepSeek API. Defaults to 'https://api.deepseek.com' if not specified.",
            value=DEFAULT_DEEPSEEK_API_URL,
            real_time_refresh=True,
            advanced=True,
        ),
        BoolInput(
            name="tool_model_enabled",
            display_name="Enable Tool Models",
            info=(
                "Select if you want to use models that can work with tools. If yes, only those models will be shown."
            ),
            advanced=False,
            value=False,
            real_time_refresh=True,
        ),
    ]

    def build_model(self) -> LanguageModel:
        try:
            from langchain_openai import ChatOpenAI
        except ImportError as e:
            msg = "langchain-openai is not installed. Please install it with `pip install langchain-openai`."
            raise ImportError(msg) from e

        try:
            max_tokens_value = getattr(self, "max_tokens", "")
            max_tokens_value = 4096 if max_tokens_value == "" else int(max_tokens_value)
            output = ChatOpenAI(
                model=self.model_name,
                api_key=self.api_key,
                max_tokens=max_tokens_value,
                temperature=self.temperature,
                base_url=self.base_url or DEFAULT_DEEPSEEK_API_URL,
                streaming=self.stream,
                stream_usage=True,
            )
        except Exception as e:
            msg = "Could not connect to DeepSeek API."
            raise ValueError(msg) from e

        return output

    def get_models(self, *, tool_model_enabled: bool | None = None) -> list[str]:
        try:
            import openai

            client = openai.OpenAI(api_key=self.api_key, base_url=self.base_url or DEFAULT_DEEPSEEK_API_URL)
            models_list = client.models.list().data
            model_ids = DEEPSEEK_MODELS + [model.id for model in models_list]
        except (ImportError, ValueError, requests.exceptions.RequestException) as e:
            logger.exception(f"Error getting model names: {e}")
            model_ids = DEEPSEEK_MODELS

        if tool_model_enabled:
            try:
                from langchain_openai import ChatOpenAI
            except ImportError as e:
                msg = "langchain-openai is not installed. Please install it with `pip install langchain-openai`."
                raise ImportError(msg) from e

            filtered_models = []
            for model in model_ids:
                if model in TOOL_CALLING_SUPPORTED_DEEPSEEK_MODELS:
                    filtered_models.append(model)
                    continue

                model_with_tool = ChatOpenAI(
                    model=model,
                    api_key=self.api_key,
                    base_url=self.base_url or DEFAULT_DEEPSEEK_API_URL,
                )

                if (
                    not self.supports_tool_calling(model_with_tool)
                    or model in TOOL_CALLING_UNSUPPORTED_DEEPSEEK_MODELS
                ):
                    continue

                filtered_models.append(model)

            return filtered_models

        return model_ids

    def _get_exception_message(self, exception: Exception) -> str | None:
        """Get a message from a DeepSeek API exception."""
        try:
            from openai import BadRequestError

            if isinstance(exception, BadRequestError):
                message = exception.body.get("message")
                if message:
                    return message
        except ImportError:
            pass
        return None

    def update_build_config(self, build_config: dotdict, field_value: Any, field_name: str | None = None):
        if "base_url" in build_config and build_config["base_url"]["value"] is None:
            build_config["base_url"]["value"] = DEFAULT_DEEPSEEK_API_URL
            self.base_url = DEFAULT_DEEPSEEK_API_URL
        if field_name in {"base_url", "model_name", "tool_model_enabled", "api_key"} and field_value:
            try:
                if len(self.api_key) == 0:
                    ids = DEEPSEEK_MODELS
                else:
                    try:
                        ids = self.get_models(tool_model_enabled=self.tool_model_enabled)
                    except (ImportError, ValueError, requests.exceptions.RequestException) as e:
                        logger.exception(f"Error getting model names: {e}")
                        ids = DEEPSEEK_MODELS
                build_config.setdefault("model_name", {})
                build_config["model_name"]["options"] = ids
                build_config["model_name"].setdefault("value", ids[0])
                build_config["model_name"]["combobox"] = True
            except Exception as e:
                msg = f"Error getting model names: {e}"
                raise ValueError(msg) from e
        return build_config
