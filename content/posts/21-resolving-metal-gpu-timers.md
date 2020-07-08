+++
title = "Resolving Metal GPU timers"
date = 2020-07-08T15:45:00+00:00
categories = ["Development", "VIM"]
tags = [ "metal", "programming" ]
slug = "resolving-metal-gpu-timers"
+++

Almost a year ago, with macOS 10.15, Apple finally added GPU timer queries to Metal. The [documentation](https://developer.apple.com/documentation/metal/mtlcounterresulttimestamp?language=objc) for it is incredibly lacklustre to this day, saying the following about [`[MTLCounterResultTimestamp timestamp]`](https://developer.apple.com/documentation/metal/mtlcounterresulttimestamp/3081724-timestamp?language=objc): A timestamp.". That's pretty useless, there's no unit attached to it! I ended up writing the following tweet last December when I first implemented GPU timers for Metal:

{{< tweet 1207478938588418048 >}}

I actually put down GPU timers on Metal because they were pretty damn broken in general, besides their absolute lack of documentation. For example, they would just crash on Intel. And then they would crash on AMD hardware. It wasn't until the release of macOS 10.15.5 a few days before Apple announced macOS 11, that GPU timers were actually fixed. The documentation, however, was not updated.

As it turns out, the resolved timestamps are in whatever unit the GPU's clock operates in. That's not surprising, Vulkan works the same way and you have to convert it using the `timestampPeriod` of the device to get nanoseconds out of it. Metal doesn't make it so easy for you, the timestamp factor is not exposed in any way whatsoever. Instead, you have to calibrate the GPU timestamp using the CPU!

A `MTLDevice` has the following function: [`sampleTimestamps:gpuTimestamp:`](https://developer.apple.com/documentation/metal/mtldevice/3194378-sampletimestamps?language=objc), which you can use to grab the current timestamp from both the CPU and GPU. The docs say that they are taken as close together as possible, but realistically they will never be taken at 100% the same time. But hey, close enough. The trick is to sample CPU and GPU, wait for a bit, then sample both of them again. That way you can then derive your own GPU timestamp period calibrated against the CPU period.

So, after doing all this, you can now resolve your GPU timestamps into the unit that CPU timestamps are in. But we aren't done here, because CPU timestamps are also in _some_ unit. You have to resolve this as well, using `mach_timebase_info()` to get the factor to convert to nanoseconds. And then, finally, you have timestamps on Metal!

## Putting it all together

The main part of this is calling `sampleTimestamps:gpuTimestamp:` twice in order to figure out how GPU and CPU timestamps correlate to each other. Of course while waiting some amount of time inbetween. The returned timestamps are 64bit, but the returned timestamp might not have that precision and can roll over at any point. So you'll have to take two measurements and verify that the timestamps are actually increasing, otherwise take the measurement again.[^1]

Because the CPU and GPU timestamps can't be taken perfectly at the same time, you might want to sample the timestamps regularly and adjust your translation factor. Alternatively, measure multiple times at the beginning and average the result to hopefully reduce the error. Or just ignore it and hope the difference isn't too big. We decided to sample once per-frame and continuously adjust the timestamp factor. Essentially we end up with this:

```cpp
NSUInteger cpu_timestamp, gpu_timestamp;
[m_device sampleTimestamps:&cpu_timestamp gpuTimestamp:&gpu_timestamp];

if(cpu_timestamp > m_cpu_timestamp && gpu_timestamp > m_gpu_timestamp)
{
    const double cpu_delta = cpu_timestamp - m_cpu_timestamp;
    const double gpu_delta = gpu_timestamp - m_gpu_timestamp;
        
    m_gpu_cpu_timestamp_factor = cpu_delta / gpu_delta;
}

m_gpu_timestamp = gpu_timestamp;
m_cpu_timestamp = cpu_timestamp;
```

To finally resolve a GPU timestamp, we do the following (assuming that `begin` and `end` are retrieved from `[MTLCounterSampleBuffer resolveCounterRange:]`)

```cpp
const uint64_t delta = (end - begin) * m_gpu_cpu_timestamp_factor;

mach_timebase_info_data_t time_info;
mach_timebase_info(&time_info);

const uint64_t nanoseconds = delta * time_info.numer / time_info.denom;

```

## Final thoughts

And there you have it. A completely insane way to resolve timestamps, with absolutely no guidance on how to actually do it from the documentation.

I always liked the Apple documentation in the past, they had some really well written and thought out stuff. Unfortunately it seems that in recent years new documentation has not been held to the same standard, making things very confusing at best. Metal is a great example of this, because a lot of things aren't spelled out in the documentation at all. The validation layers may or may not catch it, but that's about all that you get. Say what you want about the Vulkan specification, but at least it kills most questions with absolute verbosity.

This issue here is particularly maddening, because if you have an AMD GPU paired with an Intel CPU, you will actually see GPU timestamps in the exact same range. Not just that, but CPU timestamps are already in nanoseconds, so `numer` and `denorm` are 1! So the straightforward and stupid code of assuming the resolved timestamps are in nanoseconds will work just fine with an AMD GPU, and it's super easy to ship broken GPU timers.

Intel iGPUs on the other hand don't report their timestamps in nanoseconds. The naive code will break with that set up. It'll also break on iOS because CPU ticks are no longer nanoseconds and `mach_timebase_info()` will return different values.

My issue isn't with the way timer resolving on Metal works. Although it is a bit asinine, the Vulkan model works much nicer here in my opinion. The problem is that resolving GPU timers is absolutely non-trivial and there is no documentation for any of it. That's really sad, to say the least

[^1]: If there was a way to retrieve how many bits of the timestamp are valid, you could in theory avoid measuring twice. Alas this is Metal, so you don't get that info.