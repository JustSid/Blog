---
title: "CLion, a couple of weeks after the EAP"
date: 2015-05-15T00:00:00+00:00
lastmod: 2015-05-15T00:00:00+00:00
tags: [ ]
slug: "clion-a-couple-of-weeks-after-the-eap"
---

I bought [CLion](https://www.jetbrains.com/clion/) after sporadically using it in during the EAP phase. I’ve been using Xcode and Visual Studio as IDE of choice so far on OS X and Windows, and both are great, but when developing a cross platform library like [Rayne](https://rayne3d.com/) it definitely was a pain to keep both project files in sync. CLion promises to not have that issue, be cross platform AND allow me to use one single build system: CMake. If you are unaware about what CLion is, CLion is a C/C++ IDE by Jetbrains, the guys behind products like IntelliJ, AppCode, WebStorm and more. In short, they know IDEs.

![CLion overview](/images/2017/06/Screen-Shot-2015-05-15-at-00.11.26.png)

CLion is my first Jetbrains product. I’ve heard good things about them, and I was super excited about a cross-platform C/C++ IDE. I started using it back when it was in the Early Access Program (EAP), but never did too much with it since it was still very beta-ish. The IDE itself is written in Java, but is quite performant. No Sublime Text, but definitely fast enough for every day use. I do have to say though that I have a very beefy MacBook with a 2.8 GhZ Haswell, 16 Gb of RAM, Geforce GT 750M with 2Gb VRAM, so I would expect what is essentially a text editor with fluff to run fast.

The greatest thing about CLion is the sheer number of settings you have. Tweaking the editor from color scheme over keyboard shortcuts to the way it formats the code. Everything can be changed, which might take a bit of setting up when the standards don’t match, but I found just changing issues once they arise to be sufficient. And! code formatting changes can be saved on a per project base. This is unbelievably great and neither Visual Studio nor especially Xcode get anywhere near this.

![CLion settings](/images/2017/06/CLion-settings.png)

## Nativeness

As already mentioned, it’s cross platform Java. If you have ever used a Java application on OS X, you will know that they have a certain degree of not “getting it right”. This may sound first world problem-ish, but I’m used to applications behaving a certain way, including keyboard shortcuts. CLion is on the better end of the spectrum, it is surprisingly good at pretending to be a native application, it only falls apart when what usually is a window is no longer one. Especially noticeable when switching into Mission Control and suddenly CLion is no longer visible. On the up side, it gets things like `ctrl + a` and `ctrl + e` right-ish. `ctrl + a` doesn’t move to the beginning of the line but rather to where the indentation ends, wether that is preferable is up to. There probably even is a setting for it somewhere, I just haven’t found it yet. But all in all, it feels very native. Even on Windows, but mostly because everything feels native there.

## CMake integration

CLion uses CMake as build system and CMake only. And it does a pretty good job at that, it correctly gets the targets out of CMake and can keep track of them, so making changes and not losing target specific settings in CLion works well. The downside is that you have to touch and write the CMakeList.txt yourself, CLion does not provide many smart tools to work with it there. This is fine by me, but could potentially be bothersome for some people. I like being able to script the build system, instead of having a defined set of checkboxes like Xcode provides, even though it is somewhat more work. But really, that is about all there is to that. They have announced plans to support normal Make files, but for the time being it’s CMake and the integration works well.

## Static analysis, aka inspections

CMake runs static analysis on the code at all times (of course, it can be disabled in the settings). This is a great source of warm knees, empty batteries and what the fuck were they thinking?! The good thing is, it works reasonably well once it works and it did catch some things for me already. The bad thing is, it still breaks quite often and I’m torn between turning an otherwise useful feature off or just ignoring false positives. The whole problem is that instead of using a real compiler like Clang to parse the code, they have written their own parser, lexer and static analysis tool and it fails spectacularly at times. Normal C++ idioms like scope guards trigger unused variable warnings. Side effects aren’t properly deduced either:

```cpp
void test()
{
    std::atomic<bool> end = false;

    auto f = [&](){
        end = true;
    };

    std::async(std::move(f));

    while(!end)
    {}

    // Code is never reached warning here, because the side effect of f is never taken into account
    return; 
}
```

It’s not the end of the world, but it is so incredibly annoying. And there seems to be very little care about this. I filed [5 bug reports](https://youtrack.jetbrains.com/issues/CPP?q=by%3A+justsid) about broken inspections, over half a month ago, and so far there has been no sign of anyone even bothering to read them.

I want to love this feature so badly, but it just doesn’t work properly. Especially in projects that make usage of lambdas it seems. Yes, C++11 is hard to parse properly, so for the love of god, use something that can actually do that.

On top of that, CLion tries to be helpful by automatically including files when you use an identifier that it thinks is in that file but you haven’t included it in the current translation unit. That feature just doesn’t work. On OS X it constantly tries to include Cocoa and Foundation, two Objective-C frameworks that are neither linked through CMake nor do they make sense in a C++ context. The worst part is that it never tells you that it did that, so when you are scrolled in far enough and don’t see the line numbers magically change, good luck ever finding out about it before hitting compile. It’s just annoying. It does seem to do that less often than during the EAP builds though, which is at least something.

## Debugging

I don’t need to talk about compiler integration, this is where the CMake integration shines as it simply takes care of that. Debugger integration is sadly not its strength. It ships with GDB 7 but you an supply your own GDB, if it is version 7, and that’s it. I would really like to see LLDB integration. It’s planned for “late summer” according to Jetbrains, but I want it now, because the GDB integration sucks. And I’m not sure if it is just GDB not really having much love for mach-o binaries or CLion not getting it right, but half the time my symbols simply don’t resolve and I’m left with an unsymbolicated call stack. Also, breakpoints half of the time never trigger and are simply ignored. That sucks big time. It sucks so bad that I just fire up LLDB in the console and just work from there. This is **NOT** good for an IDE.

On Windows, things work much better and I haven’t run into these issues. But then again, I don’t feel like booting up windows just to have a functioning debugger.

## Conclusion

CLion feels very mature at points and then again super beta at others. The debugger integration issue is a huge annoyance for me and borderline dealbreaker if I wasn’t trying to love CLion so much. Don’t get me wrong, I still recommend it because I think it’s a good IDE for everything else, but come on. Maybe wait until the 1.1 or 1.2 if you can before dropping your money for a license, since the updates aren’t limited to major version but by time, so you will only get 1 year of free updates before having to drop money again. Don’t get me wrong, I don’t think that is a bad thing, I like supporting software I use often and regularly, but it might just be too early to buy it yet.

Definitely keep an eye on it though if that is even remotely of your interest. I’ll keep developing Rayne with it, since I like the IDE and especially its customization abilities quite a lot.
