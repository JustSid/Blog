---
title: "Debugging VK_ERROR_DEVICE_LOST with Nvidia Device Diagnostics"
date: 2019-04-12T00:00:00+00:00
lastmod: 2019-04-12T00:00:00+00:00
tags: [ "debugging", "graphics", "vulkan" ]
slug: "debugging-vk_error_device_lost-with-nvidia-device-diagnostics"
---


If you are working with Vulkan, chances are that at some point you'll run into a `VK_ERROR_DEVICE_LOST` error. It's the worst kind of error, chances are that your GPU choked on some data sometime about a frame or two ago and the position where you received the error is nowhere near where the GPU actually decided to throw up its hands and give up. This is of course because GPUs and CPUs are inherently decoupled from each other, and when you submit your work from the CPU to the GPU, the GPU will start crunching your numbers while in the meantime the CPU goes on with its busy life doing other things. Now, maybe while crunching your numbers the GPU encountered a page fault or did some other computation where it just couldn't proceed anymore afterwards. Or maybe it took too long to compute results and the kernel watchdog decided that enough was enough and restarted the device. Or something completely different! Either way, at some point this error will have propagated all the way back to your application in userspace and you'll have no idea why it happened. And are only left to guess about what went wrong and where. Well, Nvidia has your back with the extremely verbosely named [VK_NV_device_diagnostic_checkpoints](https://www.khronos.org/registry/vulkan/specs/1.1-extensions/man/html/VK_NV_device_diagnostic_checkpoints.html) extension, which is a lot like Nvidias Aftermath for DirectX, except it works on Vulkan. And because for some reason nobody on the internet seems to sing its praise, I will do so now in the form of this blog post!

## What it does and how it works

The idea of the extension is super simple, in fact, if you look at the [specification](https://www.khronos.org/registry/vulkan/specs/1.1-extensions/man/html/VK_NV_device_diagnostic_checkpoints.html), you'll notice that it consists of just 2 structs and 2 functions. [vkCmdSetCheckpointNV](https://www.khronos.org/registry/vulkan/specs/1.1-extensions/man/html/vkCmdSetCheckpointNV.html) allows you to insert a single pointer into the command buffers command stream (more on how you can use that later). Once the GPU starts executing the command buffer, your checkpoints will propagate through the pipeline and will get marked as seen by the GPU. This happens at certain pipeline stages, for example on my 980Ti it's at the top of the pipe and at the bottom of pipe. When a checkpoint is marked as seen by a pipeline stage, it means that all preceding commands have been completed by that stage! Of course this wouldn't be any good unless you could also query what stage has seen what last, which is done via the [vkGetQueueCheckpointDataNV](https://www.khronos.org/registry/vulkan/specs/1.1-extensions/man/html/vkGetQueueCheckpointDataNV.html) function. This function returns a list of stages and the last checkpoint they saw on a per queue basis. The killer feature is that `vkGetQueueCheckpointDataNV` is meant to be called after you have received a lost device error, so you can figure out roughly where your GPU died.

As a practical example, let's say your command stream looks like this:

 * Draw 1
 * Draw 2
 * Checkpoint 1
 * Draw 3
 * Draw 4
 * Checkpoint 2

You receive a lost device error, read the checkpoint data and it tells you that the top of the pipe has seen `Checkpoint 2` and the bottom of the pipe has seen `Checkpoint 1`. Well, clearly, the GPU must've died between those two checkpoints while working on either `Draw 3` or `Draw 4`! Everything that has cleared the bottom of the pipe is completely retired, and everything that has cleared the top of the pipe has to be executing somewhere on the GPU.

That's the basic principle behind VK_NV_device_diagnostic_checkpoints. It doesn't tell you why you crashed the GPU or the exact trace leading up to the event, or even the exact event itself. However, it allows you to put in breadcrumbs to figure out a region of where things have gone awry. This is incredibly useful information, since device lost errors usually happen so far removed from where the GPU encounters the problem. No more guessing and stabbing in the dark to hopefully by luck find the culprit. Even better, this is fast enough to be shipped in a game, so you can gather diagnostics when your customers encounter this. This is what makes this API such a killer feature.

## Implementing this in practice

The big problem in terms of practical usage is that the API allows you to put in a single pointer only and nothing else. It's all you get and it's really hard to express any kind of information with just 8 bytes. Or even worse, 4 bytes, on 32bit platforms. In X-Plane, we solve this problem by inserting pointers to structured data, in particular we have this struct:

```cpp
enum class gfx_vk_checkpoint_type : uint8_t
{
    begin_render_pass,
    end_render_pass,
    push_marker,
    pop_marker,
    draw,
    generic
};

struct gfx_vk_checkpoint_data
{
    gfx_vk_checkpoint_data(const char *name, gfx_vk_checkpoint_type type) :
        type(type),
        prev(nullptr)
    {
        strncpy(this->name, name, sizeof(this->name));
        this->name[sizeof(this->name) - 1] = '\0';
    }

    char name[48];
    gfx_vk_checkpoint_type type;
    gfx_vk_checkpoint_data *prev;
};
```

(Note that I omitted a bunch of convenience constructors for brevity here)

The idea is to treat the checkpoint data as a stack that gets pushed onto, with each checkpoint linking back to the previous one. When encountering a device lost error, we can "unwind" this stack by grabbing the latest entry for each pipeline stage and then iterating over the chain. To format this better after the fact, each entry is also associated with a type. To make this all work, it's tied into a super fast bump allocator system that manages arenas of pools. On creation of our high level command buffer wrapper, we dequeue memory out of the pool.

The struct itself is purposefully kept trivially destructible because that means when we return the memory back to the pool, no work needs to be done to destruct the objects. It also means that no extra space is required to record destructor function pointers, since our bump allocator has support for allocating and automatically de-allocating non trivial objects. Of course this also means that technically the prev pointer is superfluous since all objects are of equal length. However, keeping the pointer allows us to use the bump allocator for additional scratch memory if we need it in the future.

And finally, we have an `encode_checkpoint` method on our command buffer abstraction, which provides the insertion mechanic:

```cpp
template<class... Args>
void encode_checkpoint(Args&&... args)
{
#if GFX_VK_CHECKPOINTS
    if(m_supports_checkpoints)
    {
        auto *data = m_checkpoint_allocator->alloc<gfx_vk_checkpoint_data>(std::forward<Args>(args)...);
    
        data->prev = m_last_checkpoint;
        m_last_checkpoint = data;

        m_device->vkCmdSetCheckpointNV(m_command_buffer, data);
    }
#endif
}
```

With all of that in place, all that's left is to annotate the engine! By default, the engine will automatically encode checkpoints at render pass boundaries and when pushing or popping debug markers. After encountering the device lost error, it becomes easy to pepper the general region with more fine grained checkpoints to really narrow things in.

Here is some sample output that X-Plane produced after encountering a device loss:

    0:02:01.835 E/GFX: Vulkan device lost error!
    0:02:01.835 E/GFX: Diagnostics for graphics queue
    0:02:01.835 E/GFX:  Top of pipe markers (reverse order, bottom of pipe cut):
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    <--- Snip for brevity -->
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX: 
    0:02:01.835 E/GFX:  Bottom of pipe markers (reverse order):
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      draw (Draw)
    0:02:01.835 E/GFX:      Terrain grid (Push Marker)
    0:02:01.835 E/GFX:       (Pop Marker)
    0:02:01.835 E/GFX:      Cockpit prefill (Push Marker)
    0:02:01.835 E/GFX:      DSF terrain (Push Marker)
    0:02:01.835 E/GFX:       (Pop Marker)
    0:02:01.835 E/GFX:      main surface (Push Marker)
    0:02:01.835 E/GFX:      -> window 00000212690D4D10 (Begin Renderpass)
    0:02:01.835 E/GFX:       (Pop Marker)
    0:02:01.835 E/GFX:      <- fbuf_backgrounds (End Renderpass)
    0:02:01.835 E/GFX:      planet (Push Marker)
    0:02:01.835 E/GFX:      -> fbuf_backgrounds (Begin Renderpass)
    0:02:01.835 E/GFX:      Globe (Push Marker)
    0:02:01.835 E/GFX: 
    0:02:01.835 E/GFX: No diagnostics for transfer queue, queue was empty!

The idea is to show the pipeline in order, so in this case the top of the pipe is at the beginning. Anything that happens in the checkpoints between the first and last stage could be a potential culprit. For sanity's sake, when printing a stage, everything that is also found in a lower stage is cut off to avoid repeating information. Next up, on my GPU, is already the bottom of the pipe. Everything that's here is work that has completed and is for sure done. The device loss will be somewhere in-between, and printing these checkpoints only serves to show a high level picture of the command buffers timeline.

Note that there will be a lot of things that have passed the top of the pipe but not the bottom, especially if you use really fine grained markers. Modern GPUs will have a ton of draw calls in flight at once! So even with the most fine grained checkpoints, you will still have quite a large range to work with. But hopefully having any meaningful range of where the crash happened is enough to give you a head start at solving it.
