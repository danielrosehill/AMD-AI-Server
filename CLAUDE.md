The purpose of this repository is to version control a couple of docker compose scripts For bringing up several key stack components for AI workflows on AMD, GPU running machines like the one that I work on. 

Compared to users with Nvidia Gpus AMD users face an uphill battle in getting compatibility to work. My experience going from setting up conda environments to trying to resolve package dependency issues has been that Docker actually provides a very elegant means of modularising the installation process. 

## Layering

Whether dockerized or not, AI stacks commonly involve a couple of very large foundational technologies coupled with smaller components that fit around them to enable certain functionalities. 

For AMD, the big ones are:

- ROCM
- Pytorch 

The concept that I found success with and which I would like to work with in this repository and docker configuration system is that of having a stable (non bleeding edge) ROCM + Pytorch stack and then layering on components. 

Getting this container right is important because Compatibility issues with other stock components can mean that discrete stacks require different PyTorch builds which is what, I have found, quickly leads to "disk bloat." 

Note: This repository will be open sourced. I will make a note that users will want to edit the scripts to depart from my very specific filesystem prefernces.

## Core Tooling

### Ollama 

Ollama is a foundational tool. 

I like to keep my AI models In an easily accessible and memorable part of the file system so that I can see what I have and Sometimes reuse the same models across different GUIs and compoennts.

Base level for Ollama: /home/daniel/ai/models/gguf (Host bound)

## STT Stack 

Speech to text is probably the most useful technology that I find for local AI on a daily basis. I have a number of fine tunes in CTranslate2 format (and GGML and safetensors). However, for the most part at the moment I use the standard images from Open AI, Whisper. Foundational path for models is /home/daniel/ai/models/stt

GPU Accelerated Whisper with Punctuation Restoration is an extremely useful stack to have and should be setup to run on default. An approach that I very frequently take in addition, however, is using a large language model to lightly rewrite the text for clarity after it has been transcribed. 

This can be elegantly achieved with a stack that combines the core STT stack with. Post processing transcription via O Lama. Additional components like voice activity detection can add more versatility. 

The question is, from a docker component, how it makes the most sense to break up these stacks And at what point it makes more sense to deploy an actual program versus a backbone or server? At the moment I tend towards the following approach. If it doesn't involve a significant replication of baseline, compute and of. Storage and I think it makes the most sense to have two parallel speech to text workers. The first is a simpler stack consisting of whisper and GPU accelerated inference model. The second is a more fulsome implementation involving the Ollama post processing and the voice activity detection.  Having both of these persistently available would greatly simplify the amount of stock components that need to be bundled when creating specific user interfaces. 

A persistent challenge with speech to text on Wayland Linux specifically is regarding the virtual keyboard text input layer. However, my feeling is that this particular aspect of the challenge is definitely best left to the program level implementation, as it typically requires engaging with the operating system at the kernel level, which makes little sense from a dockerized environment. 

For the most part I use speech to text to output text. But now and again I do have uses for producing text outputs that are diarised and in SRT format (videos, etc). For that reason, perhaps we might consider even a 3rd speech to text stack, consisting in this case of whisper X for word level diarization and an engine that can output natively to SRT. 

## TTS Stack 

The second stock component that it would be useful to have persistently available In the environment is TTS.  I've checked out a few of the natural voice sounding speech to text tools and they're very good. 

My main use for text to speech is generating podcasts, which is a mechanism I've used several times to create podcasts for my own listening from lengthy AI outputs. Typically I use two presenters and single shot or zero shot voice cloning with a couple of character voices to make it interesting. But even on a more mundane level, it would be useful to have the ability to generate natural sounding audio from a body of text using a stock voice. 

A second stack that would be useful, therefore would be a efficient natural sounding local TTS engine. 

## Local APIs

For the text to speech stack, and for this stack approach in general, there are two approaches I found that are helpful for actually making these services usable. The first and easier method is to present a user interface like a web UI. The second is to expose a local API. The challenge with this approach is that it's not exactly easy to use.

I have found that MCP (modexl context protocol) provides an excellent middle ground. Using MCP I can expose a local API with natural language tools that are easy to call through simply engaging with a CLi agent like Claude. So in some cases it makes more sense to rely upon this approach for inference than upon directly creating a program. For this to work an MCP server it needs to be created. Which can authenticate against the API and access defined routes.