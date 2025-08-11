import json
import os
from abc import ABC, abstractmethod
from llama_cpp import Llama

CONFIG_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "config", "model_config.json")

with open(CONFIG_PATH, "r") as f:
    config = json.load(f)

MODEL_PATH = config.get("gguf_model_path", "").strip()
if not MODEL_PATH or not os.path.exists(MODEL_PATH):
    raise FileNotFoundError(f"Model file not found: {MODEL_PATH}")

class CodeLlamaBaseModel:
    def __init__(self, model_path: str):
        self.llm = Llama(
            model_path=model_path,
            n_gpu_layers=-1,
            n_threads=8,
            verbose=False
        )

    def predict(self, prompt: str, max_tokens: int = 256, temperature: float = 0.7) -> str:
        output = self.llm(
            prompt,
            max_tokens=max_tokens,
            temperature=temperature,
            stop=["</s>", "###"]
        )
        return output["choices"][0]["text"].strip()

class CodeLlamaAdapter(ABC):
    def __init__(self, base_model: CodeLlamaBaseModel):
        self.base_model = base_model

    @abstractmethod
    def prepare(self, prompt: str) -> str:
        pass

    def infer(self, prompt: str, **kwargs) -> str:
        return self.base_model.predict(prompt, **kwargs)

    @abstractmethod
    def post_process(self, output: str) -> str:
        pass

class DefaultAdapter(CodeLlamaAdapter):
    def prepare(self, prompt: str) -> str:
        return prompt

    def post_process(self, output: str) -> str:
        return output

class DocumentationAdapter(CodeLlamaAdapter):
    def prepare(self, prompt: str) -> str:
        return f"[Documentation] {prompt}"

    def post_process(self, output: str) -> str:
        return output.strip()

class TestGenerationAdapter(CodeLlamaAdapter):
    def prepare(self, prompt: str) -> str:
        return f"[TestGen] {prompt}"

    def post_process(self, output: str) -> str:
        return output.strip()

class AdapterFactory:
    @staticmethod
    def load(brand: str, base_model: CodeLlamaBaseModel) -> CodeLlamaAdapter:
        mapping = {
            "documentation": DocumentationAdapter,
            "test_generation": TestGenerationAdapter,
            "default": DefaultAdapter
        }
        adapter_cls = mapping.get(brand.lower(), DefaultAdapter)
        return adapter_cls(base_model)

class CodeLlamaClient:
    def __init__(self, model_path: str, brand: str = "default"):
        base_model = CodeLlamaBaseModel(model_path)
        self.adapter = AdapterFactory.load(brand, base_model)

    def run(self, prompt: str, **kwargs) -> str:
        prepped = self.adapter.prepare(prompt)
        raw_output = self.adapter.infer(prepped, **kwargs)
        return self.adapter.post_process(raw_output)

def generate_response(brand: str, prompt: str, max_tokens: int = 256, temperature: float = 0.7) -> str:
    client = CodeLlamaClient(model_path=MODEL_PATH, brand=brand)
    return client.run(prompt, max_tokens=max_tokens, temperature=temperature)

if __name__ == "__main__":
    brand = os.getenv("BRAND", "default")
    prompt = "Write a Python function to check if a number is prime:"
    print(generate_response(brand, prompt))
