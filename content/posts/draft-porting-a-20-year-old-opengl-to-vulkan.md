+++
title = "Porting a 20 year old OpenGL engine to Vulkan and Metal"
date = 2019-04-12T00:00:00+00:00
slug = "porting-a-20-year-old-opengl-to-vulkan"
draft = true
+++


This is going to be a very long blog post about how we (Ben Supnik and I) brought X-Plane into the 21st century. The project started over a year ago with the first bits of code being written in early 2018 but the planning phase and ground work started before that. Neither of us worked on it full time, since we are an exceedingly small team and had new features to ship as well. To give a little bit of background, X-Plane is a professional flight simulator used both by enthusiasts (generally called avgeeks) as well as professionals for actual flight training using a FAA certified version. More interestingly though, X-Plane was first released in 1995 and is now at version 11! 24 years is an insane timeframe for a codebase to have lived through, and although it's been constantly worked on and has seen a lot of modernization and refactorings, there is still a lot of legacy code in it.

## Motivation

Not only is X-Plane old, it also runs on a lot of platforms. The Desktop version runs on Windows, macOS and Linux while the Mobile version runs on iOS and Android (there used to be support for WebOS as well). This is why previous versions have used OpenGL and OpenGL ES, it just works (tm)! Unfortunately writing a cross-platform OpenGL engine isn't all that much fun, especially with the macOS version being stuck on OpenGL 2.0 due to a variety of legacy requirements. But the two biggest issues were CPU utilization and frame timings.

X-Plane is extremely CPU intensive, after all there is a lot of simulation happening in the background. On top of that, a lot of our users also run with a lot of plugins, that further eat into the CPU budget. In the past, 30 FPS was deemed as the performance goal, but with the advent of VR we are now ideally looking for a stable 90 FPS. Going from 30 to 90 FPS means that the frame time has decrease from 33ms per frame to just 11ms! One of the single biggest sources of CPU time usage turned out to be OpenGL for us and the new APIs, Vulkan and Metal, both promised to solve this issue for us.

The other issue is that X-Plane has a very large level, in fact, it's the whole planet. And planes move very fast across the planet, which means that a lot of resources are constantly streamed, and new objects and materials can show up at almost every point at runtime. On OpenGL, this meant that a lot of users saw some very spiky FPS as the OpenGL driver discovered a new pipeline configuration it had never seen and required re-compiling shaders. Both Vulkan and Metal expose pipeline objects as first class citizens that can be pre-compiled by the application before use, guaranteeing that the main thread won't have to pause for shader re-compilation.

Also, thinking ahead into the future, it's clear that multithreading is a necessity. Single core CPU performance is kinda very much stagnant, but OpenGL doesn't lend itself nicely to multithreading. Again, both Vulkan and Metal solve this, or at least give us options to play with. This wasn't part of the initial rewrite of the rendering engine, but it's definitely something that we want to look into after the dust has settled.

The bottom line is that X-Plane's FPS is dominated by the CPU for the vast majority of our users, so switching to Vulkan and Metal promised some nice performance improvements for us.

## Legacy

One of the biggest issues with this port was legacy code. Before there wasn't a rendering or graphics engine in the traditional sense, instead, a lot of the code just assumed there to be a OpenGL context and it can just whack state and do stuff as it pleases. OpenGL allows you to get away with a lot of highly dynamic behaviour, and X-Plane ran with it. There were a lot of helper objects to do most of the heavy lifting around resources (textures, vertex buffers, constant buffers, shaders), but
