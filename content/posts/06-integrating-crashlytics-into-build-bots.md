---
title: "Integrating Crashlytics into Build Bots"
date: 2015-01-30T00:00:00+00:00
lastmod: 2015-01-30T00:00:00+00:00
tags: [ "ios" ]
slug: "integrating-crashlytics-into-build-bots"
---


Testflight has seemingly no interest in its regular business anymore and broke the crashreport symbolication a long time ago. We are quite dependent on that though, we don’t want to know how many times the app crashed but where it crashed. So, a week and a bit ago we jumped ship to Crashlytics, which is a really nice platform to analyze crashes. The only issue is that their dSYM upload requires a run script build phase, so their upload script runs as part of the build process. Now, you can add plenty of ifs around that to make sure that you don’t upload debug dSYMs, but still, chances are you will end up uploading more dSYMs than you need to. And I was on cruiseship wifi and am now in hotel wifi, both are shitty, and I don’t want Crashlytics to use up bandwidth that I don’t have to upload dSYMs that we don’t need. We have a build server running Xcode bots, that uploads builds to Testflight and these are the builds for which dSYMs are needed. Local crashes I can debug using the debugger.

So, I spend the day trying to figure out how the Crashlytics binary works using the disassembler `Hopper` and `lldb`, after the naive way of just batching it into a post integration script didn’t work. Actually, the start was quite easy, since the `run` binary complained about missing environment variables:

 * `INFOPLIST_PATH`
 * `DWARF_DSYM_FILE_NAME`
 * `DWARF_DSYM_FILE_NAME`
 * `DWARF_DSYM_FOLDER_PATH`

After providing these, it bailed with:

> Crashlytics: Use a Target Run Script Build Phase 
> Make sure the Crashlytics command is added to your project Target and not the scheme 'Post-actions'. 
> Then, Build your project to continue. 
> (Crashlytics error 602)

Looking that string up in Hopper led to the discovery that it also expects the `SRCROOT` variable to be set and after providing that... Nothing. The binary exited without error code, but I could see that there was no upload going on. Looking into the Console.app for hints, I found a crashreport from the Fabric.app:

> Assertion failed: (0), function -[CLSXcodeIntegration openURL:withReplyEvent:], file /Users/crashlytics/buildAgent/work/741cdaa878dfaeb/MacApp2_5/MacApp/Controllers/Integrations/CLSXcodeIntegration.m, line 81.

Okay, cool, someone put an `assert(0)` on line 81 of a source file I have no access too. Don’t put too much info in, buddy. So, `lldb` attached to the Fabric app and a breakpoint set. Turns out, it `openURL:withReplyEvent:` is an Apple Script endpoint, and the URL parameter is not a `NSURL`. Apparently Crashlytics is creating a plist with information about the build and copies the dsym and app file into an intermediate directory and then posts an Apple Event to the Fabric App which opens the plist to find out what to do. That plist also contains the environment variables, however, stepping a bit more through the code and looking at it Hopper as well, it expects a bunch of more environment variables which the Crashlytics app isn’t complaining about ever when missing.

Also, for some reason, someone thought it was a great idea to do the equivalent of this:

```objc
@try
{
    LoadInfoPLIST();
}
@catch(NSException *e)
{
    assert(0); // Line 81
}
```

Again, please, don’t try to be too helpful here...

So, long story short, here is the complete list of environment variables that need to be present in order to get Crashlytics and Fabric running:

 * `SRCROOT`
 * `BUILT_PRODUCTS_DIR`
 * `INFOPLIST_PATH`
 * `DWARF_DSYM_FILE_NAME`
 * `DWARF_DSYM_FOLDER_PATH`
 * `PROJECT_FILE_PATH`
 * `CONFIGURATION`
 * `PLATFORM_NAME`
 * `CODE_SIGN_IDENTITY`
 * `SDKROOT`
 * `TARGET_NAME`
 * `INFOPLIST_FILE`
 * `DEVELOPER_DIR`
 * `PROVISIONING_PROFILE`

On the upside, I’m getting quite good at working with `lldb` and `Hopper`. On the downside, I’m not sure if I really want to. Maybe this post will help someone encountering the same issues, or at least, help future me.
