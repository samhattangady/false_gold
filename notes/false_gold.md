# False Gold

False Gold is action-strategy roguelike, where you spend the days building a colony
of Djinns to convert base metals into gold, and the nights protecting your factory from
the things that hide in the shadows.

Primarily it is a dual mode game, something like _They are Billions_, _Mindustry_ or _Thronefall_.
There will be one mode which is more about strategy and setup, and the other that is more action.
Decisions in one mode affect the other mode, and keeping that balance in mind is critical.

### Name Ideas:
1. False Gold
2. Alchemists Apprentice
3. Djinn Mob
4. Shadows and Alchemy
5. Philosphically Stoned ?

---

## High Level Overview

The day mode - strategy / logistics - will be automation/idle, where you divide your djinns
between different tasks, some which help your game-goals, and some which help your night goals.
The night mode - action - will be simplistic wave defense based. The night mode will involve a
certain amount of strategy, so you can defend against enemies in different ways based on the
resources / bonuses you require.

Doing better in the night will allow you to have more djinns/automatons, which gives you more
strategic depth during the day, which overall forms a tight loop between the two game modes.

The day time will be fixed by "energy", so the player can only do a fixed number of actions, which
they can take as much time as required. Having djinns do these tasks means that the player has
energy to do other things. Additionally, the player can build some kind of automation lines (maybe
conveyors or something along those lines), and their configuration will matter in the night phase.
So there will be tradeoffs between being efficient with the automation, and having some inefficiency
to make the night time defenses easier.

The night time is a fixed time period. Either 60-90 seconds fixed, or something that is wave based,
where each wave adds to the timer. The difficulty scaling will ideally come partly through larger
numbers / sizes of waves, and also from the daytime automation structures, which will be a hindrance
of some kind at night.

The end goal of the game would be to synthesise gold, which is a daytime task. Once the gold has been
synthesised, the player wins. Synthesising gold would require a large number of operations that have
been automated by the djinn. Ideally, the player should be able to finish the game in 8-10 cycles of
day and night.

### Theme Interpretation
The theme is _Shadows and Alchemy_.

The day time is about _Alchemy_, specifically about converting base metals into gold
by combining smaller/lesser metals into greater ones. 

The night time is about protecting the base from
_Shadows_. As the shadowy figures attack, they cannot be attacked, and need to be dealt with by light.

I choose to interpret the _and_ to be significant as well. So the game has two different modes of play
which have a deep connection with each other mechanically.

---

## Market Experiment

HTMAG talks about how the Steam audience is not a fan of "casualised" games. So a game that says it
wants to be like Factorio but "more casual" tends to fail because the players who like Factorio
don't want a casual version of it, while the playerse who didn't like Factorio wouldn't be too
interested in anything that markets itself to be like Factorio.

Here, I am trying to build upon that argument, and see if it can help find a different way
to think about the target audience. There is something about Factorio (or KSP, or any other niche
hardcore game) that is inherently compelling. Players that don't enjoy those games bounce off
for various reasons, but not neccessarily because the concept itself was not compelling. That's
why devs want to make "casual"/"approachable" versions of these games, because the pitch is that
the compelling thing will still remain compelling.

So the pitch for me is: Make a casual version of a hardcore niche, but strongly link it to a more
established genre / well understood target audience. So the casual version of Factorio is not an
automation game, but a tower defense with automation elements. This game is trying to build on
that thesis.

## Tools
The game will be made with ziglang using the [haathi](https://github.com/samhattangady/haathi) engine.

The game will target the web as a platform.

Graphics will be made in aseprite.

Audio will not be a focus for the prototype, so exploration still needs to be done.

---


## Gameplay

The game will be a top down 2d game, where you control the player avatar with wasd keys, and mouse.
Depending on day and night there will be differences in the contextual controls, but to whatever
extent possible, the same mechanics will also exist, with different effects. 
For ex. in day time, if you can
throw materials to move them around, in night time you can throw fireworks to chase away shadows.

### Day Time - Logistics / Strategy

The basic concept of day time, is that the player is trying to synthesise gold. This involves
mining for metals, and going through a number of processing steps, slowly transforming it into higher and
higher levels, until the final gold is reached. Each level will require multiple items of the
previous level. So if the chain is lead-copper-iron-aluminium-silver-gold, then copper will need
4 (say) lead, and iron will need 3 (say) copper. So eventually gold will required maybe ~1000 lead.

In day time, the world will be grid based. Each structure will occupy a few grid cells. Structures
will have action slots attached to them, for example to obtain ore, build a mine. The mine will have
one cell for "action", which in this case would cause a unit of ore to be created on the "pickup" cell.
So the mine will take up three cells. These two actions, mining and lifting ore, will consume energy.

The idea is that every step in the process - mining, transporting and processing will take a certain
amount of energy from the player. The automation comes from making the djinn do these tasks instead
of the player. Each djinn will have a smaller amount of energy per day than the player, but over
time, enough djinn means that a large amount of work can be done by them, and new work by the player.
So overall, energy is a limited resource, and winning the game will require creating enough djinn so
that all the required tasks can be completed over the course of a single day.

Djinns can either be purchased at the start of the day, or by performing the night time defense in
specific ways.

To automate the djinn, the player will create a path that passes through the different action stations,
and assign djinn on that path. As the djinn pass over the action grid cells, it will perform the actions.
So for example- a path that goes through the `mine` cell, `pickup` cell and `base` cell will have
the djinn do mining, lift the ore, and drop it off at the base.

Paths cannot interesect with each other, so space will be at a premium, and that is a part of the challenge
of setting up the entire automation chain.

Every night, the alchemy progress is reset. So carrying things into the next day is not possible.
The only way to succeed at the game would be to have enough djinn automating all the tasks so that
all the metals are collected and processed over the course of a single day.

But the progress made each day is not lost. All the resource collected will give gems, which
will allow you to buy things that help at night time. More processed resources give exponentially
more gems.

### Night Time - Action / Wave Defense

The night time is a kind of wave defense idea. Enemies (shadows) will spawn within and around the base.
To get rid of them, the player needs to trap then in a fire trail. The player will run around creating
a trail of fire behind them. The shadows will bounce off this trail. If the trail intersects with itself
then, at that point, all the things that are enclosed in the shape will be acted upon.

So if the player encloses only shadows, then they will get destroyed. But enclosing more shadows will
be more beneficial. If a structure (like a mine built in daytime) is enclosed, then it will also
get damaged. There will also be special night time structures built, that have an effect. For example
if you build a trap, and enclose the trap structure along with shadows, then those shadows will get
trapped and converted into djinn.

Additionally, there will be some kind of optional ways to destroy the shadows, which will give other
benefits, either for night time or day time. For example, catch exactly 2 a-type shadows and 1 b-type
shadow, and earn 100 gems.

The shadows themselves just aimlessly bounce around. If they hit any structure, then the structure takes
damage. So when there are more structures tightly packed, then a single shadow can bounce around them
and do a lot of damage. The shadows do not damage the player.

The player has a fixed number of loops per night. Everytime they enclose, if something is enclosed
(including a structure), then that loop is retained. Otherwise the loop is wasted. If the player
runs out of loops, then all the shadows in the scene will home in and attack the base. If the base
is destroyed, the player loses the game.

### Day - Night Interplay

Ideas for Mechanics from one cycle that only affect the other cycle:
1. Day: Using resources not for alchemy but for defense / magic points (base health)
2. Day: Creating automation routes that are inefficient but provide blocking capabilities for waves ?
3. Night: Summon djinns at night, and have to protect them from the shadows along with the stone.

### Balancing Knobs

These are the different knobs that can be tweaked to change the overall experience of the game.

1. Actions per day - player + djinn
2. Recipes for higher level products - more or less ingredients required
3. Value of processed goods / cost of defense tools
4. Relative speed of shadows compared to player
5. Length of trail - how to increase
6. Enemy wave scaling / Size, number of waves

#### Difficulty Scaling

Day time difficulty scaling is mostly intrinsic. As you build more structures and paths, since
paths and structures cannot intersect, the placements will have to get more thoughtful over time.
Additionally djinn will get more expensive over time, so the value of djinn keeps increasing.
Maybe there is also some kind of maintenance cost with djinn, so that you want to avoid collecting
them at night if that's the position you are in.

Every night, the overall difficulty of the game needs to increase. We do this in a few way:
1. Increased number of shadows / waves
2. More structures are harder to defend, so more running around trying to keep things safe.
3. A longer trail will also be harder to control, as you might accidentally intersect with yourself
4. Faster shadow speed

As the game progresses, the player also gets certain powers that will help them in their defense.
1. Build light walls - shadows will automatically bounce off them, but djinn paths cannot pass through
2. Freeze mechanic ? - so that the player can freeze all the shadows, which will make specific
captures easier

---

## Jam Goals
Make a basic prototype where both of the modes are somewhat fleshed out. I believe all the interesting
things comes from the interplay between the modes, so its important to make sure that we are able
to spend some time prototyping ideas there.

There is no - very little focus on the graphics and sounds. Maybe just enough to give an
idea of what it is. Similarly, no UI polish. Keep UX as simple as possible. We want to make a prototype
of the gameplay, and interplay between day-night.


## Post Jam Goals
If things work out well and the game feels like it is fun, and has room to grow, then figure out a
way to add either meta-progression,  or a "campaign" mode. If either of those ideas bear fruit, then
there is a compelling case to decide to make this into something to work on for ~9-12 months, and then
release on Steam at a $5-$10 scope.
