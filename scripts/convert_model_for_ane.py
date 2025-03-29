#!/usr/bin/env python3
# Main script to convert models for Apple Neural Engine

import argparse
import os
import subprocess
import sys
from pathlib import Path
import time

def parse_args():
    parser = argparse.ArgumentParser(description="Convert models for Apple Neural Engine")
    parser.add_argument("--model_id", type=str, required=True, help="HuggingFace model ID or local path")
    parser.add_argument("--output_dir", type=str, required=True, help="Output directory for converted model")
    parser.add_argument("--quant_bits", type=int, choices=[4, 8], default=4, help="Quantization precision (4 or 8 bits)")
    parser.add_argument("--num_chunks", type=int, default=6, help="Number of chunks to split the model into")
    parser.add_argument("--skip_download", action="store_true", help="Skip downloading if model already exists")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose output")
    return parser.parse_args()

def check_dependencies():
    """Check if all required dependencies are installed."""
    required_packages = ["torch", "transformers", "coremltools", "numpy"]
    
    print("Checking for required dependencies...")
    missing_packages = []
    
    for package in required_packages:
        try:
            __import__(package)
            print(f"✓ {package}")
        except ImportError:
            missing_packages.append(package)
            print(f"✗ {package}")
    
    if missing_packages:
        print("\nMissing required packages: " + ", ".join(missing_packages))
        print("Please install them with:")
        print(f"pip install {' '.join(missing_packages)}")
        return False
    
    return True

def run_script(script_name, args_list, verbose=False):
    """Run a Python script with the given arguments."""
    command = [sys.executable, script_name] + args_list
    
    if verbose:
        print(f"Running command: {' '.join(command)}")
    
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True
    )
    
    # Print output in real-time
    for line in iter(process.stdout.readline, ""):
        print(line, end="")
    
    process.wait()
    
    if process.returncode != 0:
        print(f"Error running {script_name}:")
        for line in process.stderr.readlines():
            print(line, end="")
        return False
    
    return True

def main():
    args = parse_args()
    
    # Check for required dependencies
    if not check_dependencies():
        return 1
    
    # Create output directories
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Get path to this script's directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Step 1: Convert from HuggingFace to CoreML
    print("\n===== STEP 1: Converting HuggingFace model to CoreML =====")
    coreml_output_dir = os.path.join(args.output_dir, "coreml_model")
    
    convert_args = [
        "--model_path", args.model_id,
        "--output_path", coreml_output_dir,
        "--quantize_weights", str(args.quant_bits)
    ]
    
    if args.verbose:
        convert_args.append("--verbose")
    
    start_time = time.time()
    if not run_script(os.path.join(script_dir, "convert_hf_to_coreml.py"), convert_args, args.verbose):
        print("Conversion to CoreML failed. Exiting.")
        return 1
    
    print(f"CoreML conversion completed in {time.time() - start_time:.2f} seconds.")
    
    # Step 2: Split the model into chunks
    print("\n===== STEP 2: Splitting model into chunks =====")
    split_output_dir = os.path.join(args.output_dir, "split_model")
    
    split_args = [
        "--model_path", os.path.join(coreml_output_dir, "model.mlpackage"),
        "--output_path", split_output_dir,
        "--num_chunks", str(args.num_chunks)
    ]
    
    if args.verbose:
        split_args.append("--verbose")
    
    start_time = time.time()
    if not run_script(os.path.join(script_dir, "split_coreml_model.py"), split_args, args.verbose):
        print("Model splitting failed. Exiting.")
        return 1
    
    print(f"Model splitting completed in {time.time() - start_time:.2f} seconds.")
    
    # Step 3: Generate KV cache and logit processors
    print("\n===== STEP 3: Generating processor models =====")
    
    processor_args = [
        "--model_path", coreml_output_dir,
        "--output_path", split_output_dir
    ]
    
    if args.verbose:
        processor_args.append("--verbose")
    
    start_time = time.time()
    if not run_script(os.path.join(script_dir, "generate_processors.py"), processor_args, args.verbose):
        print("Processor generation failed. Exiting.")
        return 1
    
    print(f"Processor generation completed in {time.time() - start_time:.2f} seconds.")
    
    # Step 4: Copy tokenizer files to the final model directory
    print("\n===== STEP 4: Finalizing model =====")
    
    # Create a README file with model information
    readme_path = os.path.join(split_output_dir, "README.md")
    with open(readme_path, "w") as f:
        f.write(f"# Apple Neural Engine Optimized Model\n\n")
        f.write(f"Original model: {args.model_id}\n")
        f.write(f"Quantization: {args.quant_bits}-bit\n")
        f.write(f"Number of chunks: {args.num_chunks}\n\n")
        f.write("Created with AppleNeuralEngine-Kit\n")
    
    print(f"\nConversion complete! The converted model is available at:")
    print(f"{os.path.abspath(split_output_dir)}")
    print("\nYou can use this model with AppleNeuralEngine-Kit using:")
    print(f"swift run ANEToolCLI --local-model-directory {os.path.abspath(split_output_dir)}")
    print("\nOr load it in the ANEChat app.")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())