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

---

## High Level Overview

The day mode - strategy / logistics - will be automation/idle, where you divide your djinns
between different tasks, some which help your game-goals, and some which help your night goals.
The night mode - action - will be simplistic tower defense based. But rather than killing the
"enemies", you will scare them away with light. Over time, you can build up various defenses
that make the whole set of tasks easier.

Doing better in the night will allow you to have more djinns/automatons, which gives you more
strategic depth during the day, which overall forms a tight loop between the two game modes.

The day time will be fixed by "energy", so the player can only do a fixed number of actions, which
they can take as much time as required. Having djinns do these tasks means that the player has
energy to do other things. Additionally, the player can build some kind of automation lines (maybe
conveyors or something along those lines), and their configuration will matter in the night phase.
So there will be tradeoffs between being efficient with the automation, and having some inefficiency
to make the night time defenses easier.

The night time is a fixed time period. Either 60-90 seconds fixed, or something that is wave based,
where each wave adds to the timer. Since the task is to do with keeping the shadow fiends away (as
opposed to killing them), the difficulty scale might have a slightly different balance. Each night
will get consecutively more difficult, with continous scaling.

The end goal of the game would be to synthesise gold, which is a daytime task. Once the gold has been
synthesised, the player wins. Synthesising gold would require a large number of operations that have
been automated by the djinn. Ideally, the player should be able to finish the game in 8-10 cycles of
day and night.

### Theme Interpretation
The theme is _Shadows and Alchemy_.

The day time is about _Alchemy_, specifically about converting base metals into gold
by combining smaller/lesser metals into greater ones. 

The night time is about protecting the base from
_Shadows_. As the shadowy figures attack, they cannot be attacked, and need to be chased away by light.

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
automation game, but a tower defense with automation elements. While there are many games like this,
I don't believe many of them explicitly pitch this as a solution to the problem as stated by HTMAG.

---

## Gameplay

The game will be a top down 2d game, where you control the player avatar with wasd keys, and mouse.
Depending on day and night there will be differences in the contextual controls, but to whatever
extent possible, the same mechanics will also exist, with different effects. Ex. in day time, you can
throw materials to move them around, in night time you can throw fireworks to chase away shadows.

### Day Time - Logistics / Strategy

The basic concept of day time, is that the player is trying to synthesise gold. This involves
mining for metals, and going through a number of steps, slowly transforming it into higher and
higher levels, until the final gold is reached. Each level will require multiple items of the
previous level. So if the chain is lead-copper-iron-aluminium-silver-gold, then copper will need
4 (say) lead, and iron will need 3 (say) copper. So eventually gold will required maybe ~1000 lead.

The idea is that every step in the process - mining, transporting and processing will take a certain
amount of energy from the player. The automation comes from making the djinn do these tasks instead
of the player. Each djinn will have a smaller amount of energy per day than the player, but over
time, enough djinn means that a large amount of work can be done by them, and new work by the player.

Every night, the alchemy progress is reset. So carrying things into the next day is not possible.
The only way to succeed at the game would be to have enough djinn automating all the tasks so that
all the metals are collected and processed over the course of a single day.

But the progress made each day is not lost. All the processing done gives alchemical points, which
will allow you to buy things in a marketplace before night time.

### Night Time - Action / Tower Defense

The night time is a kind of tower defense idea, except that rather than killing the waves, the goal
is to outlast them by scaring them away. Initially, the player has a torch, and runs around the map
chasing aways the shadows that are incoming. Over the days, the player gets more powerful tools,
like fireworks, "towers" and other tools that can change the routing of the wave ai.

Every night, the shadows come to attack the base to attain its magic / alchemy, and the player has
to chase them away. The player themself has no concept of health and cannot die. The game is lost
if all the magic is stolen from the base. The shadows cannot die as well, just be chased away by
the player, or the other tools at their disposal. The basic idea is that the shadows are scared of
light, and thus will run away from the player.

The shadows will try to carry away the magic, and the player can still try to keep those shadows inside
the map till sunrise, in which case the damage will not be taken. This gives the player a second chance
to prevent the base from taking damage.

Over the course of the night, the player can also choose to try and trap some shadows, and convert
them into djinns. This process will be a little bit time consuming, and have a risk-reward concept
attached, and the reward is the use of that djinn during the day time. This ability needs to be unlocked.

Other ways that djinns can be obtained:
- Protecting Djinn hotspots. Each night a small number of djinn hotspots will be generated over the
map and the shadows will target those as well. If they survive the night, new djinn will be added to
the day

### Day - Night Interplay

Ideas for Mechanics from one cycle that only affect the other cycle:
1. Day: Using resources not for alchemy but for defense / magic points (base health)
2. Day: Creating automation routes that are inefficient but provide blocking capabilities for waves ?
3. Night: Capturing / converting shadows into djinns for automation

### Balancing Knobs

These are the different knobs that can be tweaked to change the overall experience of the game.

1. Actions per day - player + djinn
2. Recipes for higher level products - more or less ingredients required
3. Value of processed goods / cost of defense tools
4. Relative speed of shadows compared to player
5. Weapon power scaling / How scared shadows are of the light
6. Time for conversions
7. Length of nights
8. Enemy wave scaling / Size, number of waves

---


