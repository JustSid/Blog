---
title: "The Rendering of Civiliation VI"
date: 2019-04-12T00:00:00+00:00
lastmod: 2019-04-12T00:00:00+00:00
slug: "the-rendering-of-civiliation-vi"
draft: true
---

I'm a huge fan of Civilization VI, not only is it about as complex as I can reasonably stumble through while occasionally winning a round, it also has a gorgeous art style. Mixing the old school parchment map style with the cartoonish, saturated colours is just incredibly pleasing on my eyes. And ever since Civ VI came out on the Nintendo Switch, I have found myself playing it a lot since I can just pick it up for 10-20 minutes at a time.

There also seems to be a lot of blog posts about dissecting the rendering tricks of various games, which are always fun to read. I didn't expect Civ VI to be super complex from a rendering standpoint, but I was still curious how frames are rendered, so here we are!

Disclaimer: I used the DirectX 12 version of Civ VI, but I'm by no means a DirectX expert! I use OpenGL and Vulkan with a bit of Metal during my day to day job, and especially dissecting DirectX shader bytecode has been a challenge for me. I'm under the expression that the new IR format, DXIL, is heaps better to convert back to a high level language, but unfortunately Civ VI doesn't seem to make use of it. Or potentially I have been too stupid to find it, who knows. Again, no DirectX expert here and if I get something wrong, I'd love some correction.

## The Frame

This is the frame we are going to look at. [Some more frame info]
