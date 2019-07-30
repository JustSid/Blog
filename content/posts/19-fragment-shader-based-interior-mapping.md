+++
title = "Fragment shader based interior mapping"
date = 2018-10-02T00:00:00+00:00
categories = ["Development", "VIM"]
tags = [ "programming", "graphics" ]
slug = "fragment-shader-based-interior-mapping"
+++

Seems like everybody is excited about the fake interior mapping in Spiderman these days. Here is a Kotaku video showing them off:

{{< youtube YQVHtlVEirs >}}

Now, the technique itself is nothing new, it's been proposed by Joost van Dongen who published a paper about it here. The idea is to divide the space into evenly sized "rooms" and then cast a ray in the fragment shader to figure out whether the ceiling/floor or a wall was hit, and then map a texture on top. It's super cool because it works without requiring extra geometry, the fragment shader is relatively cheap and easy to implement and like the Kotaku reviewer mentioned; The fact that the window is no longer just flat or a mirror adds depth (hah) to the world.

Great, I wrote a blogpost about something everyone has been doing lately. But hold on, there is one more thing: I also recently discovered pocket.gl which is a lot like a self hosted shader toy on steroids and I've been dying to use it in a blog post. So, here is Joost's interior mapping in pocket.gl. It's based on his code but I added conditionals instead of the somewhat clunky but very clever step logic in the shader, which cuts down on texture fetches. I also used the golden noise function for pseudo random room texture selection, which further cuts down on texture fetches. Not that any of that is actually necessary, but I didn't want to just paste a carbon copy of the original code here.

{{< pocketgl interior_mapping >}}