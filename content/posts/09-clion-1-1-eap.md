---
title: "CLion 1.1 EAP"
date: 2015-07-10T00:00:00+00:00
lastmod: 2015-07-10T00:00:00+00:00
tags: [ "programming" ]
slug: "clion-1-1-eap"
---

After writing about my thoughts on the CLion 1.0 release, I figured it’s only fair if I now also write about the new [1.1 EAP](blog.jetbrains.com/clion/2015/07/clion-1-1-eap-starts/) which Jetbrains released yesterday. I’ve only tested it for about an hour, but, I’m very very pleased with it!
The parser

The parser got some major improvements! It’s still not a Clang but something home cooked, but boy did they put some serious effort into it. It’s still not quite there, for example, it still has issues deducing potential side effects in lambdas properly, like in the following snippet:

```cpp
template<class T>
void Enumerate(const std::function<void (T *, size_t, bool &)>& callback) const
{
    bool stop = false;
    
    for(size_t i = 0; i < _count; i ++)
    {
        callback(static_cast<T *>(_data[i]), i, stop);
        
        if(stop) // Complains about condition always being false here
            break;
    }
}
```

Another issue that is still there is that it complains about truncation when using an implicit cast to bool, although the C++ standard says this in *4.12 Boolean Conversion*

> A prvalue of arithmetic, unscoped enumeration, pointer, or pointer to member type can be converted to a prvalue of type bool. A zero value, null pointer value, or null member pointer value is converted to false; any other value is converted to true. For direct-initialization (8.5), a prvalue of type std::nullptr_t can be converted to a prvalue of type bool; the resulting value is false.

I know that might sound pedantic, but I do make use of that quite often and I don't want to see a warning every time.

On the other hand it did learn that things with a non-trivial destructor have side effects and thus doesn’t complain about an unused variable when using scope or lock guards like this:

```cpp
void foo()
{
    std::lock_guard<std::mutex> lock(_lock); // No longer complains about lock being unused

    // ...
}
```

It also learned about override and similar keywords, as well as decltype(), so all in all it definitely got better and I’m now at a point where I feel okay with turning those live static analysis things back on. Just a tiny bit more.

## Debugger

My second biggest issue: The fact that GDB simply wasn’t working for me. Breakpoints didn’t work, symbols weren’t properly symbolicated despite compilation with debug symbols... I didn’t even use CLion for debugging, I attached LLDB via command line instead. The good news is, CLion 1.1 supports LLDB and it is god send! It works, flawlessly, and I’m more than happy. It also works with custom LLDB python scripts, so CLion can now used as a complete and fully working IDE. I’m really really happy with how this has turned out.

## Performance

I mentioned performance a little bit in my first post and it seems like that has improved as well. The CPU usage definitely went down and it all feels a tad smoother. I don’t have actual numbers, but it seems like it definitely got better and I like that a lot.

## Some more general thoughts

Once 1.1 is final (and there is no regressions), I would definitely recommend buying CLion if anyone is looking for a cross platform C++ IDE. I know 99€ is not a drop in the bucket, but it definitely is a really good IDE now.

But this is also something where I would like to mention something else, I read on reddit and other forums about people complaining that there is free Visual Studio and CLion is not free and what the fuck is wrong with Jetbrains. No, what the fuck is wrong with you? Visual Studio is not Microsofts income source, whereas Jetbrains does IDEs as a business. And it’s cross platform, unlike Visual Studio (and don’t tell me Visual Studio Source was anything like the real Visual Studio), which is huge because it means that you don’t need to work with different IDEs and potentially keep different projects in sync. And last but not least, unless this is just a hobby, 99€ is nothing compared what it probably indirectly generates you in revenue. For fucks sake, it’s like people bitching about Sublime Text costing a lot of money: Yes, it does, but I use IDEs and text editors daily for multiple hours for work and that makes the very minimal investment in good tools so worth it.
