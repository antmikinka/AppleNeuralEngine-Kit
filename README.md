# AppleNeuralEngine-Kit

Project Tree
------------------
**Prequant Optimization**
- SpinQuant/QuaRot
- mlx-squeezellm
- ScaledLinear
- ClusterFriendlyLinear & Quantizer


**Ways to optimize the Cache CoreML**
(would need to implement model chunking into this to make it worth it)
(dont believe we can implement prior prequant optimization because cause issues with model loading since we changed it I think)
- class SliceUpdateKeyValue(Cache):
- class SliceUpdateMistralAttention(MistralAttention):
- class StatefulMistralForCasualLM(torch.nn.Module):


**Model Splitting**
  - into chunks lm head, cache-processor, chunk blocks
  - or alternative is chunking the model + implementing stateful cache class and having all those models in sync from beginnging to end compute



- litgpt dynamic model
  
  - useful for splitting attention in accordance with 
- HF model
- CoreML Conversion


**HF model posting with info**


**Verification Methods**
- KL divergence





**Main.py **
- ideally is the one script that is user input with CLI, parser orgs that just calls everything else and condenses and cuts code into modules for easier management.
