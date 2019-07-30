+++
title = "Compiling 1 million shaders in 30 seconds"
date = 2019-04-12T00:00:00+00:00
slug = "compiling-1-million-shaders-in-30-seconds"
draft = true
+++

This post is about the internal shader toolchain we use in X-Plane called gfx-cc. It is responsible for compiling all of our shaders and extracting reflection information from it, while also trying to be fast. Originally shaders were handled just by the engine itself via OpenGL, with just the tiniest amount of pre-processing to handle `#include` directives in the GLSL files. Basically, the old system is exactly what you would expect to find. It was all GLSL, the files had some pre-processor magic to deal with different GLSL versions and that's it.

With our goal to move to Vulkan and Metal, this was no longer adequate though. While Vulkan in theory can do GLSL, this is a non-starter for Metal, so we had to find a new solution. One solution was to just re-write the shaders for Metal and compile SPIR-V for Vulkan from the existing GLSL. Unfortunately our GLSL shaders are targeting GLSL 1.20, 1.30 and 1.50 so directly compiling SPIR-V from them wasn't the most straight forward. And of course besides modernizing our GLSL while keeping it backwards compatible, it would also require a complete rewrite for Metal introducing who knows how many rendering regression. This solution wasn't gonna work for us.

There was one more consideration, we are making heavy use of ubershaders, where the behaviour of the shader is modified at compile time through defines and a bunch of `#if/#endif pairs` in the code. SPIR-V does not support this, so we'd have to compile one GLSL ubershader into thousands of SPIR-V shaders.
