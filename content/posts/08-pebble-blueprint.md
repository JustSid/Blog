---
title: "Pebble Blueprint"
date: 2015-06-06T00:00:00+00:00
lastmod: 2015-06-06T00:00:00+00:00
tags: [ ]
slug: "pebble-blueprint"
---

Guys, guys, guys... I have been working on a project for a couple of weekends now and to make a long story short it's a watchface and watchapp generator for the Pebble Time for iOS. The basic idea is that it allows putting watchfaces/watchapps together easily and then deploying them on the Pebble that is attached to the iOS device.

Here is a video of the whole thing in action, note that the iPad simulator uses US keyboard layout and I only have my German one, so, yeah, you can watch me stumble over the keyboard quite a bit at times:

{{< vimeo 128727516 >}}

Also, my Pebble Time arrived yesterday and this is how it looks like in real life:

![Pebble Blueprint and Pebble](/images/2017/06/pb-1.jpg)

Took quite a bit to get a working LLVM/Clang cross compiler ready, but it basically is completely working now. Needs a ton of polish obviously, but I think for a weekend project this is quite cool. The only real big thing missing right now is an action system a la RPG Maker to allow some more customization than just the expression system.