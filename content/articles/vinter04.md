Vinter 0.4.0 is almost here, there are a few tiny things missing, but it just got its nice and shiny beta Tag over at [GitHub](https://github.com/JustSid/Vinter/tree/Beta-0.4.0 "Beta 0.4.0 commit") and it has sooo many new features that I decided that I have to blog about it. However, as I said, there are a few tiny missing things before it can get its stable tag. Of course it misses extensive testing, its possible that some of the new stuff behave incorrectly and those things need to be sorted out before a stable release, but another missing thing is documentation. I sat down and began rewriting the documentation from scratch to be much more descriptive and helpful. Large parts of the new documentation are missing and Vinter won't get its stable tag before this is done.

But what about the new stuff? There are so many awesome new things, I don't really know where to start, but I guess the two most awesome things are Physics integration via [Chipmunk](http://chipmunk-physics.net/ "Chipmunk Physics home") and animations. Well, like I said, Physics in Vinter is done using the excellent Chipmunk framework. Chipmunk is natively wrapped, so you can turn on Physics for every node in your scene, you can alter the physical properties of every node and so on. Here is a small example about how this looks like:

	// This example assumes that sprite is a valid object
	sprite->enablePhysics(vi::scene::sceneNodePhysicTypeCircle); 
    sprite->setElasticity(0.3);
    sprite->setFriction(0.4);
    sprite->setMass(10.0);
    sprite->setInertia(sprite->suggestedInertia());

    sprite->applyImpulse(vi::common::vector2(5000.0f, 0.0f));

What this code does should be easily to figure out, it enables physics for a sprite and marks it as circle like. The radius of the circle is figured out by Vinter using the size of the sprite (altering this later will automatically update the physical node). Then it sets up some properties, and lastly it applies a horizontal impulse rocketing the sprite to the right.

Of course you can also place static physic objects into your scene and you can do much more stuff with physical nodes. Vinter also supports Joints via the `vi::common::constraint` class and its subclasses. All constraint types provided by Chipmunk are available in Vinter as well, nicely wrapped in high level C++ sugar.

The next big thing I talked about were Animations. Now you might think about simple atlas animations or gif support or something similar, but thats not exactly what I mean. A animation in Vinter means the transition between one state into another, eg. a position change from `0|0` to `512|512`. Vinter can animate these changes, you just have to provide it with an duration and an animation curve and you are done. Here is a small example that demonstrates a sprite changing its position and rotation so that it looks like it would fall of an invisible cliff:
	
	vi::animation::animationServer *server;
    server = scene->getAnimationServer();
   	
    vi::animation::animationStack *stack = server->beginAnimation();
    stack->setAnimationDuration(2.0);
    stack->setAnimationCurve(vi::animation::animationCurveExponentialEaseIn);
    
    // Tell the animation system where we want the sprite to be positioned at the end of the animation path
    sprite->setPosition(vi::common::vector2(512.0, 512.0) - sprite->getSize());
    sprite->setRotation(ViDegreeToRadian(90.0));
    
    // We are done building the animation, lets communicate that with the animation server:
    server->commitAnimation();

Animations are driven by a so called animation server, the default one is provided by the scene object that you are working with and which is tight to the framerate of your app. How the animation looks like is saved inside the so called animation stack, which contains all the needed informations. Of course you can also create more advanced animations with paths and different curves, durations etc.
And of course, you can also animate your own properties too, the system is really really simple and straightforward to use.

A third thing that is really awesome and new in Vinter are particle effects. They are not only simple to use but extremely flexible, as long as the hardware can run the effect that you have in mind, you can build it. Here is a short movie that demonstrates a simple particle effect: <http://www.youtube.com/watch?v=FeQbEP_Mpng>

Well, those are the three top features, of course there are many many tiny improvements too, for example the `vi::common::objCBridge` is now much more robust and failsafe and the scene allows you to send a invisible trace through the scene to check if it hits an object.