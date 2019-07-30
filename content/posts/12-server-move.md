+++
title = "Moving servers & domains"
date = 2017-06-10T00:00:00+00:00
categories = ["Development", "VIM"]
slug = "server-move"
+++

For years I have hosted all of my servers at [uberspace](https://uberspace.de), which are a fantastic company that makes hosting websites incredibly easy. At this point in time, I have 4 uberspaces running.

As you may or may not have noticed, this blog now sports a new look and also a new domain name! Under the hood, it also moved away from Uberspace and over to Linode. This change has been a long time coming, [feresignum.com](https://feresignum.com/) has been up and running as a staging server for almost 120 days now! Together with the blog I moved a bunch of other services that were running on my server as well as all of my private Github repos, which are now hosted on a private gitlab installation. This has overall decreased my server/services bills and also allows me to have much more freedom in terms of what I'm doing with my servers. Sometimes, super user rights are useful. Also, all domains are now served as HTTPS, which I'm really excited about.

For now, the old widerwille.com and the new feresignum.com are absolutely equivalent. Potentially I'll keep both of them, the main reason for the change is that I've been now living in an english speaking country for a while and widerwille is just hard to pronounce for most and just sounds weird. On the other hand, I have put my email address (ending in @widerwille.com) into a lot of email fields now and it wouldn't make sense to just discontinue that domain.

On the software side this no longer is a CentOS 5 installation, but instead it's a Ubuntu server. Still running Apache2, but it's now serving Ghost as blogsoftware instead of the discontinued [#pants](https://github.com/hmans/pants). Sorry [Hendrik](https://hmans.io)!

Sooo, does that mean more frequent blog posts? Maybe, I have a couple of posts that I'm eager to write.
