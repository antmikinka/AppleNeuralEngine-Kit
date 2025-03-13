# AppleNeuralEngine-Kit

Project Tree
------------------
- SpinQuant/QuaRot
- mlx-squeezellm
- ScaledLinear
- ClusterFriendlyLinear & Quantizer
- Model Splitting
  - into chunks lm head, cache-processor, chunk blocks
  - or alternative is chunking the model + implementing stateful cache class and having all those models in sync from beginnging to end compute
- litgpt dynamic model
- HF model
- CoreML Conversion
- HF model posting with info
Main.py 
- ideally is the one script that is user input with CLI, parser orgs that just calls everything else and condenses and cuts code into modules for easier management.
