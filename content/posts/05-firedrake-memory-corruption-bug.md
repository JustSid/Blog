---
title: "Firedrake memory corruption bug"
date: 2015-01-04T00:00:00+00:00
lastmod: 2015-01-04T00:00:00+00:00
tags: [ "programming", "firedrake", "debugging" ]
slug: "firedrake-memory-corruption-bug"
---


There was a bug that I couldn’t figure out for the life of me. It was somewhere deep in my hobby kernel Firedrake and it made zero sense.

It manifests as memory corruption, more specifically, at some point a pointer suddenly becomes zero. I tried to narrow it down with printf() debugging, but that didn’t get me very far because at that point the scheduler is already running and regular task switches occur, which have the side effect of the kernel not running in consecutive order any longer. Luckily, QEMU, my go to emulator, has support for GDB. The easy solution is therefore to fire up GDB, attach it to the remote debugger exposed by QEMU and set a watchpoint on the address... And suddenly everything was fine, the pointer was no longer overwritten and retained its correct value.

I have an uncommitted `.bochrc` file that I sometimes use when I want to understand what is truly going on at the CPU side, since Bochs is not only incredibly slow, but also verbose when it comes to APIC and MSRs etc, which usually are more like black boxes. Bochs verified that the pointer is indeed overwritten as it has the same behaviour. It didn’t tell me why, at least not out of the box.

I put the whole thing aside for days. I disabled the memory manager and just used whole pages for every allocation. I disabled reclaiming memory and turned the free/delete functions into stubs. It worked, somewhat but still broke somewhere else. I rewrote the memory manager as I suspected it to be broken since a long time already. It broke again.

Then I just decided to let Bochs trace all memory access, reading and writing. It took five minutes to get through Grub and another two to get it to load the kernel and have that one crash. I ended up with a 3gb log file that took another two or so minutes to import into Sublime Text and which made me glad I have an SSD and 16gb of RAM in this laptop. It still took about 20 minutes to search the output for the address I was interested in, with Sublime Text hanging for a good 1-3 minutes when jumping around.

And then it made click. The linear address `0x18008`, the one that was getting overwritten, was previously mapped to `0x8008`, the physical address that contains the SMP bootstrap location (ie the code that all non bootstrap CPUs execute to be hoisted out of real mode and get into protected mode and then rendezvous with the Firedrake bootstrap CPU). The value at the physical address was `0x0`. Later `0x18008` is mapped to another location, but when I was rewriting the virtual memory interface, I forgot the code to invalidate the page table entry when remapping virtual addresses. Writes where going to the new physical locations, and reads where still served from the old one.

And that’s why no hardware breakpoints where helping and why the Bochs hardware watchpoints where useless. And I guess QEMU disables TLB simulation when GDB is attached, or something like that. Not that a GDB watchpoint would’ve helped, the memory was never actually overwritten in the first place after all.

I feel incredibly stupid right now.
