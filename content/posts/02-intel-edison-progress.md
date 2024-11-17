---
title: "Intel Edison Progress"
date: 2014-10-26T00:00:00+00:00
lastmod: 2014-10-26T00:00:00+00:00
tags: [ "firedrake" ]
slug: "intel-edison-progress"
---
So, progress report on my Edison adventure: I managed to get my own kernel on it and have U-Boot boot it, which in retrospect took way longer than it should have (I'm not good at computers and embedded). Now the next issue is that the Edison has a Watchdog that will automatically reset the board if the Kernel is not periodically pinging it. The whole thing works by doing IPC from the Atom to the Quark, and so now I'm going through the Linux patch that comes with the Edison SDK to figure out how the hell all of this is supposed to work.

Oh, and the UART is of course PCI based, so no way of just "simply" getting a "hello world" out before the watchdog grace period runs out. Which also means, I'm not 100% sure if my kernel is actually running. Right now it's an endless loop and the board resets at the expected watchdog timeout, but that could also be just a coincidence[^1]. Maybe I should start with figuring out which GPIO pin is driving the the LED and turn that on/off? Or just in general turn one of the GPIO pins on and attach a multimeter to it... [^2]

Anyways, here is where I am right now. This is turning out to be much more fun than expected:

![Intel Edison output](/images/2017/06/Screen-Shot-2014-10-26-at-13.59.08.png)

[^1]: Edit: Is definitely running. Causing the CPU to triple fault will reset the board. An interesting debug method to say the least ↩︎

[^2]: Edit: Turns out the GPIO pins are also on the PCI bus, so it's hard to avoid writing some PCI interface... Which sucks, because that also means that I have to at least bootstrap far enough to get the PIC working. Without being able to debug it at all. ↩︎

