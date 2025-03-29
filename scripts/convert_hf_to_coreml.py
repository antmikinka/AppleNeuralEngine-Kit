#!/usr/bin/env python3
# Convert HuggingFace model to CoreML format

import argparse
import os
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import coremltools as ct
import numpy as np
from pathlib import Path

def parse_args():
    parser = argparse.ArgumentParser(description="Convert HuggingFace model to CoreML format")
    parser.add_argument("--model_path", type=str, required=True, help="Path to HuggingFace model or model ID")
    parser.add_argument("--output_path", type=str, required=True, help="Output directory for CoreML model")
    parser.add_argument("--quantize_weights", type=int, choices=[4, 8], default=4, help="Quantize weights to 4 or 8 bits")
    parser.add_argument("--batch_size", type=int, default=1, help="Batch size for inference")
    parser.add_argument("--max_seq_len", type=int, default=256, help="Maximum sequence length")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose output")
    return parser.parse_args()

def get_dummy_inputs(batch_size, seq_len, vocab_size):
    """Create dummy inputs for model tracing."""
    inputs = {
        "input_ids": torch.ones((batch_size, seq_len), dtype=torch.int64),
        "attention_mask": torch.ones((batch_size, seq_len), dtype=torch.int64),
    }
    return inputs

def create_position_ids(attention_mask):
    """Create position IDs from attention mask."""
    position_ids = torch.cumsum(attention_mask, dim=1).to(attention_mask.dtype)
    position_ids = position_ids * attention_mask - 1
    return position_ids

def convert_to_coreml(model, args):
    """Convert PyTorch model to CoreML format with ANE optimizations."""
    print(f"Converting model to CoreML format with {args.quantize_weights}-bit quantization...")
    
    # Get model configuration
    config = model.config
    vocab_size = config.vocab_size
    hidden_size = config.hidden_size
    
    # Prepare dummy inputs for tracing
    example_inputs = get_dummy_inputs(
        batch_size=args.batch_size,
        seq_len=args.max_seq_len,
        vocab_size=vocab_size
    )
    
    # Trace the model with dummy inputs
    print("Tracing model with dummy inputs...")
    model.eval()
    with torch.no_grad():
        traced_model = torch.jit.trace(model, example_inputs.values())
    
    # Convert the traced model to CoreML format
    print("Converting traced model to CoreML...")
    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.TensorType(name="input_ids", shape=example_inputs["input_ids"].shape, dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=example_inputs["attention_mask"].shape, dtype=np.int32),
        ],
        compute_units=ct.ComputeUnit.CPU_AND_NE,
        minimum_deployment_target=ct.target.macOS14,
    )
    
    # Apply quantization if requested
    if args.quantize_weights == 4:
        print("Applying 4-bit quantization...")
        mlmodel = ct.compression_utils.affine_quantize_weights(mlmodel, nbits=4)
    elif args.quantize_weights == 8:
        print("Applying 8-bit quantization...")
        mlmodel = ct.compression_utils.affine_quantize_weights(mlmodel, nbits=8)
    
    # Save the CoreML model
    os.makedirs(args.output_path, exist_ok=True)
    mlmodel_path = os.path.join(args.output_path, "model.mlpackage")
    mlmodel.save(mlmodel_path)
    
    # Also save the tokenizer for convenience
    tokenizer = AutoTokenizer.from_pretrained(args.model_path)
    tokenizer.save_pretrained(args.output_path)
    
    print(f"CoreML model and tokenizer saved to {args.output_path}")
    return mlmodel_path

def main():
    args = parse_args()
    
    print(f"Loading model from {args.model_path}...")
    model = AutoModelForCausalLM.from_pretrained(args.model_path, torch_dtype=torch.float16)
    
    # Convert to CoreML
    output_path = convert_to_coreml(model, args)
    
    print(f"Conversion complete! CoreML model saved to: {output_path}")

if __name__ == "__main__":
    main()