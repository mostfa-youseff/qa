# ملف Python يحتوي دالة generate_text فقط (تستخدم كـ API)
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
from peft import PeftModel
import torch
import os
import threading

base_model_name = "codellama/CodeLlama-7b-hf"
model = None
tokenizer = None
adapter_models = {}
lock = threading.Lock()

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_use_double_quant=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.float16,
)

def initialize_base_model():
    global model, tokenizer
    if model is None or tokenizer is None:
        hf_token = os.getenv("HF_TOKEN")
        tokenizer = AutoTokenizer.from_pretrained(
            base_model_name,
            use_auth_token=hf_token,
            trust_remote_code=True,
        )
        model = AutoModelForCausalLM.from_pretrained(
            base_model_name,
            use_auth_token=hf_token,
            trust_remote_code=True,
            device_map="auto",
            quantization_config=bnb_config,
        )
        model.eval()

def get_adapter_model(checkpoint_path):
    with lock:
        if checkpoint_path not in adapter_models:
            adapter_models[checkpoint_path] = PeftModel.from_pretrained(
                model,
                checkpoint_path,
                is_trainable=False,
                device_map="auto",
                quantization_config=bnb_config,
            )
            adapter_models[checkpoint_path].eval()
        return adapter_models[checkpoint_path]

def generate_text(prompt: str, adapter_id: str, checkpoint_path: str) -> str:
    try:
        initialize_base_model()
        adapter_model = get_adapter_model(checkpoint_path)
        inputs = tokenizer(prompt, return_tensors="pt").to(next(adapter_model.parameters()).device)
        outputs = adapter_model.generate(**inputs, max_length=512)
        result_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
        return result_text
    except Exception as e:
        return f"Error: {str(e)}"
