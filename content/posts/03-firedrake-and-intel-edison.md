---
title: "Firedrake and Intel Edison"
date: 2014-11-12T00:00:00+00:00
lastmod: 2014-11-12T00:00:00+00:00
tags: [ "programming", "firedrake" ]
slug: "firedrake-and-intel-edison"
---

I'm back from a business trip to [Nice](http://f.cl.ly/items/2O3c3i1L0W1T2k1X082r/IMG_0622.JPG) and a lot of stress that has kept me busy since the end of October is slowly fading away, which means I can go back and actually start hacking on the Intel Edison. Which actually means that I'm going to polish up a lot of parts of Firedrake before actually turning around and attacking the Edison. It helps to have a solid foundation to bootstrap oneself with.

Two things that are really high up on my bucket list for Firedrake are more independence from the BIOS and GRUB as booatloader, with eventual independence from the CPU architecture itself. For that I want to implement a system that allows compiling the kernel with different personalities, which take care of the underlying platform and things like hardware discovery and interfacing. On top of that would be high level facilities for things like for example memory management, VFS etc.

The second thing that I want to work on is IPC, with the eventual goal of a microkernel. Not as extensive and complex as Mach, but in a way that makes it easy to extend the kernel and the system within it. Ideally I'd like to create a simple system that supports message passing and most importantly marshalling that works with the kernel primitives. Also something I really want is simple service discovery and advertisement, as that is something where I feel Mach is falling short. On OS X launchd is responsible for that, but even that is not straight forward at all.

Oh well, that's a pretty hefty longterm goal and not all of that is required to run on the Edison. What I would like to know, is there any interest in an occasional `"Here is what I learned hacking on a kernel"` post? I'm thinking of writing some in depth technical blog posts about x86, Edison and kernel implementation details as I come along them, but I'm not sure if there is any interest in something like that? Just trying to figure out what kind of content I could post here.

Last but not least: I've updated this pants instance. Look at my fancy ~~strikethrough~~!
