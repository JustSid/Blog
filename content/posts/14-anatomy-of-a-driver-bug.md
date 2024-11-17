---
title: "Anatomy of a graphics driver bug"
date: 2017-07-31T00:00:00+00:00
lastmod: 2017-07-31T00:00:00+00:00
tags: [ "debugging", "x-plane", "opengl" ]
slug: "anatomy-of-a-driver-bug"
---


X-Plane's plugin systems allows authors to load models in two ways: Asynchronously and Synchronously. Most plugins tend to use synchronous loading, but since all plugins run on the main thread there is a need and desire for some to use asynchronous loading. Up until now, the latter was broken however, and plugin authors complained about invisible models. From what I understand [Pilot Edge](https://www.pilotedge.net/) were the first to complain, but they want to use async loading to dynamically load in models of planes that flew in via multiplayer, which makes it non-trivial to debug. Luckily, the author of the fantastic [Better Pushback](https://github.com/skiselkov/BetterPushbackC) also ran into the issue and his plugin is completely local, so it's no problem to stop at a debugger for any amount of time without being worried a multiplayer socket closes and the whole setup has to be recreated.

## Symptoms

As mentioned, authors would complain about their models being invisible when using async loading. However, the object was there in X-Plane, and for example attached lights would function as expected. In the case of Better Pushback this looked like this:

![Better Pushback truck with lights but no model](/images/2017/07/b738_1.png)

*Note the lights of the pushback truck being there, but the model being invisible.*

Now, at that point we had no idea wether this was a potential plugin problem or a bug in X-Plane, so Ben went out and looked at the code of Better Pushback while I dug into X-Plane's source code.

## The first issue

What I found was a problem with the way the multithreaded OpenGL was handled. Basically it would load the model, create the VBO and IBO and then queue a continuation on the main thread that would call the plugins callback. However, what it didn't do was any synchronization between the background OpenGL context and the main threads context. So basically we ended up in a race where if the VBO or IBO upload wasn't finished uploading by the time we told the plugin it was okay to use the model, potentially we would render with a non existent VBO or IBO. The thing with OpenGL is though that it takes just about any abuse from us programmers and just does the least dumb thing, so rendering with an invalid VBO/IBO is like rendering with no VBO/IBO: It simply doesn't do anything. Which fits with the description of no visible model. What is weird though is that after a frame or two it should start working because the VBO/IBO upload completes and the resources are available. From what we gather this was a bug exclusive to Nvidia though, and potentially their driver doesn't automatically propagate side effects unless explicitly asked or the side effects already happened. Nvidia does interesting things in the name of performance (it's like an optimizing compiler that deduces that you will never see the side effects of your code therefore it can elide it). That would fit our bug since sometimes the async load would just work, but more often it didn't (ie. sometimes we won the race and sometimes we lost).

The solution to all of that is simple, of course: OpenGL provides sync fences that can be inserted into the command stream and that get signalled when the GPU gets to the point in the stream where they are. So, the solution is to put the fence in, flush our work and then on the main thread periodically check if the fence is signalled and then tell the callback. Easy solution.

## The second issue

This is where things got interesting. 99% of the time it was working now, the model was there. This was in contrast to before where it only worked every once in a while. So the sync fence definitely fixed some of the problem, just not all of it. Now, X-Plane does a lot of caching of OpenGL state just to avoid driver overhead. One of the implications of that is that VBO and IBOs are never unbound and instead code binds the VBO and IBO that they need indirectly through the cache: Ie, code requests a VBO to be bound, the cache checks what VBO is currently bound and then either binds the new VBO or just does nothing. So potentially somewhere else in the lifetime of the background thread that loads the model, it also does some weird operation on the currently active buffer that results in its data becoming corrupt and that's why the model is gone that 1% of the time. Luckily that's easy to check, just bind the 0 VBO/IBO after we are done creating the VBO/IBO and see if the problem persists. It turns out, the problem went away. Our bug was fixed!

Now, this is a very unsatisfying fix and it points to a deeper bug in the X-Plane codebase. We should never manipulate objects we don't own. To figure out what went wrong I hooked all calls that manipulate VBOs and their data: `glBufferSubData`, `glBufferData`, `glMapBuffer` and `glDeleteBuffers` paired with `glGenBuffers`. Nothing touched our buffers. This was the point where things started to slide towards WTF territory, because if nothing touches our buffer, why isn't our object rendering? The background thread that creates the buffer MUST be the one that also corrupts it, because binding the 0 VBO on that thread fixes the problem. But that thread never touched it afterwards. To proof that, I wired the thread to spin until the sync fence signals the main thread (at which point the buffer was already corrupt). And it turns out, even with the spinning, the buffer was still corrupt. The only other thing that could touch our buffer was the Nvidia OpenGL driver now, all the evidence pointed at it.

So what do you do when it's the drivers fault? You go for the Whiskey, of course! In all seriousness though, we are now using the workaround of binding the 0 VBO in addition to the proper fix for the first bug. I have no idea what is going wrong there, but I have some additional observations: `glIsBuffer` returns `GL_FALSE` for the corrupt buffer. And since we are in the compatibility profile, which allows arbitrary binding of non-existing resources (and then actually creates them), it would explain why we only see a size of 0 but not an OpenGL error. In fact, any `glIsXXX` call fails on that object, essentially in the eyes of OpenGL it doesn't exist. Yet, it's never deleted and its creation succeeds.

## Conclusion

Everybody always assumes the bugs they see are their fault and try the hardest proving that. In this case this was made worse because there was an actual bug in the X-Plane code base. It just happened to also hit a driver bug at the same time. So a lot of time was spend trying to find the second smoking gun in the codebase, except it never existed in the first place. This was a very interesting coincidence a fun bug to debug, even though the end result is very unsatisfying because god knows what the Nvidia driver does.
