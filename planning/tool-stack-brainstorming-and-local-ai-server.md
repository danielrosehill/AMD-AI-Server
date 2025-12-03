# Tool Stack Brainstorming and Local AI Server

> The speaker reflects on the progress made at the end of the year regarding their tool stack, particularly with Claude. They discuss their motivation for a control panel and the challenges faced with AMD GPUs and Python environments.

*Transcribed: 3 Dec 2025 22:05*

---

# Tool Stack and Progress

All right, so this is the first voice note using some voice notes. I'm just really ranting off my tool stack at the end of the year and making very, very amazing progress with Claude on all these components such that I feel like in a couple of days I'll kind of have all these things I really wanted to have for the last year. It's kind of like I guess the geeky equivalent to Christmas come early and getting all my goodies for the next year and beyond.

So this particular component is--here's here's my motivation for what I asked for and I'm very, very impressed with the control panel that has been generated so far. It's actually kind of--it's really nice. It's a beautiful little UI, and it's actually kind of exactly what I was looking for.

# AMD GPU and Local AI

So I have an AMD GPU, which I kind of got before I became--before I got into AI stuff. And it was great until I said, "Oh, wait, I can do some local AI stuff, or my GPU is, you know, good enough at 12 gigabytes VRAM. It's a Radeon 7700 that I can probably play around with some of this local AI stuff." And then I sort of began hitting all these walls related to AMD and ROCm, and stuff really only supporting NVIDIA.

In general, I have a hard time wrapping my head around Python environments and dependence and there are so many different package managers. And trying to recall to friends who work with Python and said, how do you guys just--I guess I'm sort of old school in the sense that when I build these huge images, ROCm and PyTorch, I keep thinking, "I can't keep creating these. I'm going to run out of space." I grew up in an era where the modem squeaked to download 4 megabytes, so the idea of repetitively pulling 20 and 30 gigabyte packages kind of makes me squeamish, or nervous. I don't know that my ISP is going to cut off my internet. I have no idea what I'm worried about, but at any event, it seems kind of inefficient. 

# Conda, Docker, and Isolation

So I stumbled upon Conda for kind of working around this, saying I have a couple of bigger environments, PyTorch, ROCm, and then I build out for the specific workload. And nothing really against Conda except that it seemed just a lot of complications involved with it and kind of felt like I was using something the wrong thing. So reluctantly, I decided let's just try to dockerize everything. I have nothing against Docker. In fact, I think Docker is amazing, but I didn't really understand, I think, that one of the advantages of Docker is this layering mechanism of-- I understood the isolation benefits, but not--I didn't actually realize there was utility there in caching and reusing layers in different stacks. And when I realized that, I'm like, wait, Docker actually solves exactly what I was trying to solve with Conda. So why don't I just use Docker? I already know kind of how to use it. 

I guess it seemed the disadvantage was isolation from the from the host. It seemed that I worried that it's going to be super complicated to get pass through and stuff like that.

Anyway, I'm just giving this context in case over time the idea pulls back towards maybe being mixed Conda-Docker, but and just explain how I kind of got to this point of dockerizing all these stacks.

# Local AI Services

So for local AI basically, the services we have now--there's Ollama. And if I'm not mistaken, that's in Docker. If it's not in Docker, because I think I have it on host as well, then we should I guess uninstall on host and move over the the models because I hate again for my scarcity mentality with digital electronics. I hate pulling and repulling these gigantic models. And I think it's better to have one set or the other.

So the ones I use--Ollama is brilliant for--I use it mostly. I rarely, rarely use it for anything like chat. I don't really use chat interface locally, but I do use it for scripting and especially for kind of text. But more than that, I think it's got utility in sitting alongside the other stack components here.

ASR and Whisper is actually what brought me to make this because it's been challenging to--I've been seeing there's a lot of Whisper tech out there, but frequently the ROCm issue is a big deal. So sort of what I figured out with voice detects and ASR was just have that backbone PyTorch ROCm solid. Don't use bleeding edge, keep it kind of reliable, sit back from the cutting edge a little bit there. And then you can just kind of layer stuff into it. That's my kind of ideal mechanism. So the purpose of this repository was actually to firstly, I had a lot of stuff in Conda still and caches and wasting a ton of space. I wanted to have a single source of truth for these are the local AI services. It's all being brought up from here. It's a Docker deployment.

After doing that, then I was like, well, the only other--just the only other reason I don't like using Docker is simply UI. If I start something--one of the other things that took me a while to figure out with Docker is, I always had this idea that running anything involved a lot of resource usage. And then I saw that actually idle containers don't really use much if at all.

So having a way that even if they're auto-starting, being able to stop them, being able to change that without needing to go into Portainer and the Docker compose and editing manually--and that's something that, if that can be done visually, is a lot more easy and friendly than trying to remember where's this deploying from etcetera.

# Core Services and Remaining Components

So for the stack components, we actually have--I'm just trying to make sure I've got this right. I think we're only lacking--I think we're only lacking one. So the idea in this server was basically inference. It's not--these aren't finished products, or these are more like--it's kind of what I'd like to have is something that's a unified stack. It starts on boost, and I know that the stuff I need is there without needing to individually start up each Docker component, and that they're not--they're not--they're not going to run into port conflicts. They're spaced out, etcetera.

The other idea I think I noted here was that I wanted to--there's one particular workflow that I think really works well together, which is Whisper and Ollama, and for speech to text, I'm trying to use MCP in a way that maybe there's--maybe at this microservice level, this is it, the the the answer to how do I create services that use them both is just you create the services that use them both. You have them both available. You run stuff through Whisper and then you run it through Ollama. And I think that's probably the answer. In my planning notes I was kind of thinking more along the lines of, should we define different stacks for--should we have Whisper-Ollama and then a Whisper plus Ollama stack? Looking at the stack, I'm guessing there's no need to actually do that.

So the only missing component now is TTS.

For TTS, the main utility for me would be creating podcasts. I'm just looking through the repository because I was certain I recorded this earlier today. Apparently not. Okay, so for TTS, I'm working on using a workflow. I've tried to use a workflow for creating podcasts with AI. So typically it's using two different voices, and something like single shot cloning, they're like character voices. And generally the the system that I've kind of created is, I have my prompt. It--an agent creates a script, script gets read out, diarized by the two hosts, and that then gets concatenated with my prompt to give me the episode. 

So that's its own project, because I really like to use it frequently. But where this local inference server comes into play is that it would be useful to have the everything ready for that to happen.

So there's a couple that--I'm just noting and looking at what I've noted here for TTS models, Vib voice Diya, DIA, Kakaro and Fish Speech. Future ASR options, Whisper, faster Whisper, fine-tuned models. So an MCP server. So I think really the question is, where do I want to draw the line between the stuff I want to pack into this AI server and the stuff that I want to implement at the program level? That's probably the direction that I would tend towards is try to keep this just the core services running, and then the specificity is handled by the applications. But the other little microservices that would be useful here: for Whisper X, which if I'm not mistaken is diarizing Whisper with diarization, comes in handy for this podcast workflow a lot. Nice to have if it doesn't add a lot of background weight as a process. And VAD right now we cannot. But let's just--I'm just recording for again for just as a note that VAD is a very--is a useful component in speech detect, really.

I'm conscious. I don't know if I've already reinvented a wheel here, but I try not to do that. So there's bigger projects for TTS web UI that I'm just trying to say I don't need all those bells and whistles. I just want to But if there is even anything stack that can be incorporated into this just for the TTS, the baseline functionality I'd like to have is just a human-sounding, natural-sounding TTS voice. And some of the models, Kakaro, Diya, the only question is if they can run on AMD. And I think it's more a question of rather than looking at the differences, what can run the most easily? Voice cloning is not really, I would say, a key requirement in the sense that yes, for my podcast, it makes--I really like to use my character voices, but if there's just a few stock voices, I can work with that. Right now, it just be nice to have something that is part of the stack that's brought up and I know that I can use it for TTS. So that's here. Part two of the sort of plan for this project that just kind of came to me as I was looking at this.

# Microservices and API Considerations

Because we talked about MCP, and part of what I'm doing at the moment is creating MCP servers for all this stuff that I've been doing manually repetitively with AI that's absolutely amazing that it can work. Stuff like moving data to my NAS. To have sort of a local MCP server that has all those tools ready, so I can just connect it and never again have to repeat the same information about my NAS, the land address, the where the volumes are, it's synology. That's a tool that I can just have to repeat. And for this local AI inference server, it would be--the main use for this is actually all local AI for local agents to use. So for example, in Claude code, I'm creating an MCP for local transcription, and that's why I want this the transcription API to be accessible and running, so that I can say it's here and not have to that that MCP server doesn't have to deal with just the additional complication of creating the stack. The stack is there. It's an own environment. It'd be really bummer to find out that something already existed for this. I'm sure probably for NVIDIA. I figured for AMD and my specific utilities, it might just be specific enough to do to do like this.

# Local API Architecture and Design

So for MCP, Model Context Protocol, we're wrapping around APIs. That's the fundamental technology. So, so long as these services provide local APIs, we're kind of good. And an open API compatible API is kind of the key. It's machine-readable. Great. Very easy then to to scaffold in MCP. So my initial thought was, okay, let's add TTS and then let's make sure that they're all providing a local API and that it's there is a each one has an API definition, and then somewhere in this controller panel I can have links to the definitions and one maybe master definition. That was idea number one.

Idea number two was something I would have regarded a short while ago as way too complicated, and now I'm thinking maybe this actually does make sense, which is rather than have four parallel APIs, local APIs, one for Ollama, one for speech to text, one for Whisper, one for comfy UI, we'll have one local AI API that has the open API schema and is proxying between to all these back-end services. And I think that's probably actually the that would be a pretty slick architecture to strive towards. I think probably what we should whether it's incremental progress to get there or not feasible. I'll just put it down as a note for how I think this would be really cool.
