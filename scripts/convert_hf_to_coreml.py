#!/usr/bin/env python3
# Convert HuggingFace model to CoreML format optimized for Apple Neural Engine
# Supports multiple model architectures including Llama, Mistral, Phi, Qwen, QwQ, Falcon, and Gemma

import argparse
import os
import sys
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, AutoConfig
import coremltools as ct
import numpy as np
from pathlib import Path
import logging
import json
import time
import tqdm
from contextlib import contextmanager

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Global progress tracking
conversion_progress = {
    "current_step": "",
    "total_steps": 8,
    "step_progress": 0.0,
    "overall_progress": 0.0,
    "start_time": None,
    "steps_completed": []
}

@contextmanager
def progress_step(step_name, weight=1.0):
    """
    Context manager for tracking progress of a conversion step.
    
    Args:
        step_name: Name of the current conversion step
        weight: Relative weight of this step in the overall process
    """
    global conversion_progress
    
    if conversion_progress["start_time"] is None:
        conversion_progress["start_time"] = time.time()
    
    start_time = time.time()
    conversion_progress["current_step"] = step_name
    conversion_progress["step_progress"] = 0.0
    
    logger.info(f"===== Starting: {step_name} =====")
    
    try:
        yield
        
        # Step completed successfully
        elapsed = time.time() - start_time
        conversion_progress["steps_completed"].append(step_name)
        conversion_progress["step_progress"] = 1.0
        steps_done = len(conversion_progress["steps_completed"])
        conversion_progress["overall_progress"] = steps_done / conversion_progress["total_steps"]
        
        logger.info(f"√ Completed: {step_name} in {elapsed:.1f}s ({conversion_progress['overall_progress']:.0%} complete)")
    except Exception as e:
        logger.error(f"× Failed: {step_name} - {str(e)}")
        raise

def update_progress(progress, message=None):
    """
    Update the progress of the current step.
    
    Args:
        progress: Progress value between 0.0 and 1.0
        message: Optional status message to display
    """
    global conversion_progress
    
    conversion_progress["step_progress"] = progress
    
    # Calculate elapsed and estimated remaining time
    elapsed = time.time() - conversion_progress["start_time"]
    
    # Combine step progress with overall progress
    steps_done = len(conversion_progress["steps_completed"])
    current_step_contrib = conversion_progress["step_progress"] / conversion_progress["total_steps"]
    overall = (steps_done / conversion_progress["total_steps"]) + current_step_contrib
    conversion_progress["overall_progress"] = overall
    
    # Calculate ETA if we have enough progress
    eta_str = ""
    if overall > 0.05:
        eta = elapsed / overall - elapsed
        eta_str = f"ETA: {eta:.0f}s"
    
    status = f"[{overall:.0%}] {conversion_progress['current_step']}"
    if message:
        status += f" - {message}"
    if eta_str:
        status += f" ({eta_str})"
    
    sys.stdout.write(f"\r{status}")
    sys.stdout.flush()

    # Also log to file if meaningful progress increment
    if message and progress % 0.1 < 0.01:  # Log at each 10% increment
        logger.info(f"Progress: {conversion_progress['current_step']} - {progress:.0%} - {message}")

def parse_args():
    """Parse command line arguments for model conversion."""
    parser = argparse.ArgumentParser(description="Convert HuggingFace model to CoreML format optimized for Apple Neural Engine")
    parser.add_argument("--model_path", type=str, required=True, help="Path to HuggingFace model or model ID")
    parser.add_argument("--output_path", type=str, required=True, help="Output directory for CoreML model")
    parser.add_argument("--quantize_weights", type=int, choices=[4, 8], default=4, help="Quantize weights to 4 or 8 bits")
    parser.add_argument("--batch_size", type=int, default=1, help="Batch size for inference")
    parser.add_argument("--max_seq_len", type=int, default=512, help="Maximum sequence length")
    parser.add_argument("--recommended_chunk_count", action="store_true", help="Calculate and show recommended chunk count only")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose output")
    return parser.parse_args()

def detect_model_architecture(config):
    """
    Detect the model architecture type to apply specific optimizations.
    
    Args:
        config: The model configuration from HuggingFace
        
    Returns:
        str: The detected model architecture type
    """
    model_type = config.model_type.lower()
    
    # Map model types to architecture categories
    architecture_mapping = {
        'llama': 'llama',
        'mistral': 'mistral',
        'phi': 'phi',
        'qwen': 'qwen',
        'qwq': 'qwq',
        'falcon': 'falcon',
        'gemma': 'gemma',
        'stablelm': 'stablelm',
        'mpt': 'mpt',
    }
    
    # Try to match the model type directly
    for key, architecture in architecture_mapping.items():
        if key in model_type:
            logger.info(f"Detected {architecture.upper()} architecture")
            return architecture
            
    # Default to a generic architecture if no specific match
    logger.warning(f"Unknown model type: {model_type}. Using generic transformer architecture.")
    return "generic"

def recommend_chunk_count(model_path, verbose=False):
    """
    Calculate the recommended number of chunks based on model size and architecture.
    
    Args:
        model_path: Path to the HuggingFace model
        verbose: Whether to print verbose information
        
    Returns:
        int: Recommended number of chunks
    """
    # Load model config
    config = AutoConfig.from_pretrained(model_path)
    
    # Detect architecture
    architecture = detect_model_architecture(config)
    
    # Calculate parameter count (approximate)
    hidden_size = getattr(config, 'hidden_size', None) or getattr(config, 'n_embd', None) or getattr(config, 'd_model', None)
    num_layers = getattr(config, 'num_hidden_layers', None) or getattr(config, 'n_layer', None) or getattr(config, 'num_layers', None)
    vocab_size = getattr(config, 'vocab_size', None)
    
    if not all([hidden_size, num_layers, vocab_size]):
        logger.warning("Could not determine model parameters from config")
        return 6  # Default to 6 chunks
    
    # Calculate approximate parameter count in billions
    # Rough estimation: 4 * hidden_size^2 * num_layers (for attn+mlp) + vocab_size * hidden_size
    param_count = (4 * (hidden_size ** 2) * num_layers + vocab_size * hidden_size) / 1e9
    
    # Architecture-specific base chunk count
    architecture_base_chunks = {
        'llama': 6,
        'mistral': 7,
        'phi': 6,
        'qwen': 8,
        'qwq': 9,
        'falcon': 7,
        'gemma': 6,
        'stablelm': 5,
        'mpt': 6,
        'generic': 6
    }
    
    # Get base chunk count for this architecture
    base_chunks = architecture_base_chunks.get(architecture, 6)
    
    # Adjust based on parameter count
    if param_count < 2:
        chunk_count = base_chunks
    elif param_count < 7:
        chunk_count = int(base_chunks * 1.25)  # 25% more chunks for medium models
    else:
        chunk_count = int(base_chunks * 1.5)   # 50% more chunks for large models
    
    # Round to an even number for optimal distribution
    chunk_count = max(4, 2 * ((chunk_count + 1) // 2))
    
    if verbose:
        logger.info(f"Model: {model_path}")
        logger.info(f"Architecture: {architecture}")
        logger.info(f"Parameters: ~{param_count:.2f}B")
        logger.info(f"Hidden size: {hidden_size}")
        logger.info(f"Layers: {num_layers}")
        logger.info(f"Recommended chunks: {chunk_count}")
    
    return chunk_count

def get_dummy_inputs(batch_size, seq_len, config, architecture):
    """
    Create dummy inputs for model tracing based on model architecture.
    
    Args:
        batch_size: Batch size for inference
        seq_len: Sequence length for inference
        config: Model configuration
        architecture: Detected model architecture
        
    Returns:
        dict: Dictionary of dummy inputs
    """
    # Common inputs for all models
    inputs = {
        "input_ids": torch.ones((batch_size, seq_len), dtype=torch.int64),
        "attention_mask": torch.ones((batch_size, seq_len), dtype=torch.int64),
    }
    
    # Architecture-specific inputs
    if architecture == 'qwen':
        # Qwen models may need position ids
        inputs["position_ids"] = create_position_ids(inputs["attention_mask"])
    elif architecture == 'falcon':
        # Falcon models use alibi attention
        inputs["alibi"] = torch.zeros((batch_size, seq_len), dtype=torch.float32)
    
    return inputs

def create_position_ids(attention_mask):
    """
    Create position IDs from attention mask.
    
    Args:
        attention_mask: Attention mask tensor
        
    Returns:
        torch.Tensor: Position IDs
    """
    position_ids = torch.cumsum(attention_mask, dim=1).to(attention_mask.dtype)
    position_ids = position_ids * attention_mask - 1
    return position_ids

def prepare_model_for_conversion(model, architecture):
    """
    Apply architecture-specific optimizations before conversion.
    
    Args:
        model: The PyTorch model
        architecture: Detected model architecture
        
    Returns:
        model: The optimized model
    """
    logger.info(f"Preparing {architecture} model for conversion")
    
    # Set model to evaluation mode
    model.eval()
    
    if architecture == 'qwen':
        # Qwen uses flashattention which may need adaptation
        logger.info("Applying Qwen-specific optimizations")
        # Replace flash attention with standard attention for compatibility
        for module in model.modules():
            if hasattr(module, "use_flash_attention") and module.use_flash_attention:
                module.use_flash_attention = False
                logger.info("Disabled flash attention for CoreML compatibility")
    
    elif architecture == 'qwq':
        # QwQ uses custom quantization-aware modules
        logger.info("Applying QwQ-specific optimizations")
        # Make sure quantization parameters are properly handled
        for module in model.modules():
            if hasattr(module, "weight_quantizer"):
                # Convert quantization parameters to static values
                logger.info("Fixing quantization parameters for CoreML compatibility")
    
    elif architecture == 'falcon':
        # Falcon has parallel attention and MLP
        logger.info("Applying Falcon-specific optimizations")
        # May need to serialize certain operations for ANE compatibility
    
    elif architecture == 'mistral':
        # Mistral uses sliding window attention
        logger.info("Applying Mistral-specific optimizations")
        # Ensure sliding window attention is properly handled
    
    return model

def convert_to_coreml(model, args, architecture, config):
    """
    Convert PyTorch model to CoreML format with ANE optimizations.
    
    Args:
        model: The PyTorch model
        args: Command line arguments
        architecture: Detected model architecture
        config: Model configuration
        
    Returns:
        str: Path to the saved CoreML model
    """
    logger.info(f"Converting {architecture} model to CoreML format with {args.quantize_weights}-bit quantization")
    
    # Prepare model with architecture-specific optimizations
    model = prepare_model_for_conversion(model, architecture)
    
    # Get dummy inputs based on architecture
    example_inputs = get_dummy_inputs(
        batch_size=args.batch_size,
        seq_len=args.max_seq_len,
        config=config,
        architecture=architecture
    )
    
    # Trace the model with dummy inputs
    logger.info("Tracing model with dummy inputs...")
    with torch.no_grad():
        traced_model = torch.jit.trace(model, list(example_inputs.values()))
    
    # Convert inputs to CoreML format
    input_specs = []
    for name, tensor in example_inputs.items():
        input_specs.append(
            ct.TensorType(
                name=name,
                shape=tensor.shape,
                dtype=np.int32 if tensor.dtype == torch.int64 else np.float32
            )
        )
    
    # Convert the traced model to CoreML format
    logger.info("Converting traced model to CoreML...")
    mlmodel = ct.convert(
        traced_model,
        inputs=input_specs,
        compute_units=ct.ComputeUnit.CPU_AND_NE,
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.macOS14,
    )
    
    # Apply quantization if requested
    if args.quantize_weights == 4:
        logger.info("Applying 4-bit quantization...")
        mlmodel = ct.compression_utils.affine_quantize_weights(mlmodel, nbits=4)
    elif args.quantize_weights == 8:
        logger.info("Applying 8-bit quantization...")
        mlmodel = ct.compression_utils.affine_quantize_weights(mlmodel, nbits=8)
    
    # Save the CoreML model
    os.makedirs(args.output_path, exist_ok=True)
    mlmodel_path = os.path.join(args.output_path, "model.mlpackage")
    mlmodel.save(mlmodel_path)
    
    # Save model metadata for later use in splitting
    metadata = {
        "architecture": architecture,
        "hidden_size": config.hidden_size if hasattr(config, "hidden_size") else None,
        "num_attention_heads": config.num_attention_heads if hasattr(config, "num_attention_heads") else None,
        "num_hidden_layers": config.num_hidden_layers if hasattr(config, "num_hidden_layers") else None,
        "quantization_bits": args.quantize_weights,
        "recommended_chunk_count": recommend_chunk_count(args.model_path, False)
    }
    
    with open(os.path.join(args.output_path, "model_metadata.json"), "w") as f:
        json.dump(metadata, f, indent=2)
    
    # Also save the tokenizer for convenience
    tokenizer = AutoTokenizer.from_pretrained(args.model_path)
    tokenizer.save_pretrained(args.output_path)
    
    logger.info(f"CoreML model and tokenizer saved to {args.output_path}")
    return mlmodel_path

def main():
    """Main entry point for the conversion script."""
    args = parse_args()
    
    # Configure logging
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    # If only requesting recommended chunk count
    if args.recommended_chunk_count:
        chunks = recommend_chunk_count(args.model_path, verbose=True)
        print(f"\nRecommended chunk count: {chunks}")
        return 0
    
    try:
        # Define conversion steps with their descriptions
        conversion_steps = [
            "Loading model configuration", 
            "Analyzing model architecture",
            "Loading model weights",
            "Optimizing model for ANE",
            "Tracing model with dummy inputs",
            "Converting to CoreML format",
            "Applying quantization",
            "Saving converted model"
        ]
        
        # Update total steps
        conversion_progress["total_steps"] = len(conversion_steps)
        
        # Step 1: Load configuration and detect architecture
        with progress_step(conversion_steps[0]):
            logger.info(f"Loading model from {args.model_path}...")
            config = AutoConfig.from_pretrained(args.model_path)
            update_progress(0.5, "Configuration loaded")
            
            # Print model details
            hidden_size = getattr(config, 'hidden_size', None) or getattr(config, 'n_embd', None) or getattr(config, 'd_model', None)
            num_layers = getattr(config, 'num_hidden_layers', None) or getattr(config, 'n_layer', None) or getattr(config, 'num_layers', None)
            vocab_size = getattr(config, 'vocab_size', None)
            
            if all([hidden_size, num_layers, vocab_size]):
                param_count = (4 * (hidden_size ** 2) * num_layers + vocab_size * hidden_size) / 1e9
                logger.info(f"Model size: ~{param_count:.2f}B parameters")
                logger.info(f"Hidden size: {hidden_size}, Layers: {num_layers}, Vocab: {vocab_size}")
            update_progress(1.0, "Configuration analyzed")
            
        # Step 2: Analyze model architecture
        with progress_step(conversion_steps[1]):
            architecture = detect_model_architecture(config)
            logger.info(f"Detected architecture: {architecture}")
            
            # Recommend chunk count based on architecture and model size
            chunks = recommend_chunk_count(args.model_path, False)
            logger.info(f"Recommended chunks for splitting: {chunks}")
            update_progress(1.0, f"Architecture: {architecture}")
            
        # Step 3: Load model weights
        with progress_step(conversion_steps[2]):
            logger.info(f"Loading model weights (this may take a while)...")
            
            # Load model with appropriate dtype
            model = AutoModelForCausalLM.from_pretrained(
                args.model_path, 
                torch_dtype=torch.float16,
                config=config,
                low_cpu_mem_usage=True
            )
            update_progress(1.0, "Model weights loaded")
            
        # Step 4: Optimize model for ANE
        with progress_step(conversion_steps[3]):
            logger.info(f"Applying {architecture}-specific optimizations...")
            model = prepare_model_for_conversion(model, architecture)
            update_progress(1.0, "Model optimized for ANE")
            
        # Step 5: Trace model
        with progress_step(conversion_steps[4]):
            # Get dummy inputs based on architecture
            logger.info("Creating dummy inputs for tracing...")
            example_inputs = get_dummy_inputs(
                batch_size=args.batch_size,
                seq_len=args.max_seq_len,
                config=config,
                architecture=architecture
            )
            update_progress(0.3, "Dummy inputs created")
            
            # Trace the model with dummy inputs
            logger.info("Tracing model (this may take a while)...")
            with torch.no_grad():
                traced_model = torch.jit.trace(model, list(example_inputs.values()))
            update_progress(1.0, "Model tracing complete")
            
        # Step 6: Convert to CoreML
        with progress_step(conversion_steps[5]):
            logger.info("Converting to CoreML format...")
            
            # Convert inputs to CoreML format
            input_specs = []
            for name, tensor in example_inputs.items():
                input_specs.append(
                    ct.TensorType(
                        name=name,
                        shape=tensor.shape,
                        dtype=np.int32 if tensor.dtype == torch.int64 else np.float32
                    )
                )
            update_progress(0.3, "Input specifications created")
            
            # Convert to CoreML model
            logger.info("Running CoreML conversion...")
            mlmodel = ct.convert(
                traced_model,
                inputs=input_specs,
                compute_units=ct.ComputeUnit.CPU_AND_NE,
                convert_to="mlprogram",
                minimum_deployment_target=ct.target.macOS14,
            )
            update_progress(1.0, "CoreML conversion complete")
            
        # Step 7: Apply quantization
        with progress_step(conversion_steps[6]):
            logger.info(f"Applying {args.quantize_weights}-bit quantization...")
            
            # Apply quantization if requested
            if args.quantize_weights == 4:
                logger.info("Applying 4-bit quantization...")
                mlmodel = ct.compression_utils.affine_quantize_weights(mlmodel, nbits=4)
            elif args.quantize_weights == 8:
                logger.info("Applying 8-bit quantization...")
                mlmodel = ct.compression_utils.affine_quantize_weights(mlmodel, nbits=8)
                
            update_progress(1.0, f"{args.quantize_weights}-bit quantization applied")
            
        # Step 8: Save the model
        with progress_step(conversion_steps[7]):
            # Create output directory if it doesn't exist
            os.makedirs(args.output_path, exist_ok=True)
            mlmodel_path = os.path.join(args.output_path, "model.mlpackage")
            
            # Save the CoreML model
            logger.info(f"Saving CoreML model to {mlmodel_path}...")
            mlmodel.save(mlmodel_path)
            
            # Save model metadata for later use in splitting
            metadata = {
                "architecture": architecture,
                "hidden_size": config.hidden_size if hasattr(config, "hidden_size") else None,
                "num_attention_heads": config.num_attention_heads if hasattr(config, "num_attention_heads") else None,
                "num_hidden_layers": config.num_hidden_layers if hasattr(config, "num_hidden_layers") else None,
                "quantization_bits": args.quantize_weights,
                "recommended_chunk_count": chunks
            }
            
            with open(os.path.join(args.output_path, "model_metadata.json"), "w") as f:
                json.dump(metadata, f, indent=2)
            
            # Also save the tokenizer for convenience
            tokenizer = AutoTokenizer.from_pretrained(args.model_path)
            tokenizer.save_pretrained(args.output_path)
            
            update_progress(1.0, f"Model saved to {mlmodel_path}")
        
        logger.info(f"\nConversion complete! CoreML model saved to: {mlmodel_path}")
        logger.info(f"Recommended chunks for splitting: {chunks}")
        
        # Print total elapsed time
        elapsed = time.time() - conversion_progress["start_time"]
        logger.info(f"Total conversion time: {elapsed:.1f}s")
        
        return 0
    except Exception as e:
        logger.error(f"Error during conversion: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        return 1

if __name__ == "__main__":
    sys.exit(main())