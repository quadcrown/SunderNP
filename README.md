# SunderNP

## FOR TURTLE WOW

https://github.com/balakethelock/SuperWoW

## NEEDS SuperWoW TO FUNCTION PROPERLY

Adds sunder armor count to the right of the nameplate, similar to plate addons in classic wow. If you do not use SuperWoW, then it will display sunder stacks for the current target on every nameplate that is currently on your screen, sort of making this useless. SuperWoW allows us to recognize that each mob has their own debuffs using GUIDs.

Works with default blizzard nameplates and pfUI nameplates currently. If you have any other nameplate addons that you would like this to be functional with, please make a request as I am not going to dig for every single nameplate addon used on Turtle WoW

### Commands
- /sundernp or /snp in game for list of commands

### Preview
![1-4 stacks sunder](https://imgur.com/n7SeHHe.jpg "1-4 stacks sunder")

![5 Stacks](https://imgur.com/qwwF3N9.jpg "5 Stacks")

## Hotfix 1/09/25
- Removed pfUI dependence by using GUIDs without pfUI
- Performance enhancements
- Credit to Shagu for providing me guidance for these changes! I am but a novice at making addons and working with lua, and I could have not made this addon without him and those who also have contributed to our Turtle WoW community.

## Color Differential 1/17/25
- Added color differential to sunder stacks.
- 1 = Red
- 2 = Orange
- 3 = Yellow
- 4 = Dark green
- 5 = Light green

## Feature added 1/21/25 -- Overpower overlay 
- Now has a icon overlay above the current target nameplate that displays the overpower proc timer, and cooldown text if it is on cooldown.
- Example: You get a dodge, you will see the icon. However, let's say you just used overpower 3 seconds ago and have 2 seconds left on the cooldown, the timer text will display as red now with the icon. Once overpower is off cooldown, it will default back to showing white timer text (signifying you have an available overpower proc, in this case, 2 seconds left).
- Can be toggled on and off with new commands. Please type /sundernp for available commands
- Please open an issue if you find problems with it, I have done minimal testing with this feature but based on my testing, it should work as intended without issues.
- <b>Credits to percs for helping me having this work flawlessly! His commit really made this work exactly as I wanted and he saved me a lot of heartache.</b>

## New feature added 1/27/25 -- Whirlwind range overlay 
- **UNITXP REQUIRED**
- New function to add whirlwind icon over nameplate IF whirlwind is off cooldown and mobs are within range of whirlwind
- Will not appear if on cooldown. However, if within 3 seconds of coming off cooldown, it will show the cooldown time with the icon
- If within 8 to 10 yards, it will show an icon with a 30% opacity to show leeway. This means if you are moving or jumping, your whirlwind will hit the mob. If you are moving in the 8 to 10 yard distance, it will appear at 100% opacity as if you're in range (movement detection).
- This will not function without UnitXP_SP3 v22 or greater. There is a function built in that checks for UnitXP and the version. Therefore, this addon as a whole is still useable if you do not have UnitXP, you just will not be able to use new Whirlwind function. https://github.com/allfoxwy/UnitXP_SP3/releases
- Fixed whirlwind icon when showing cooldown text appearing on every nameplate unless in range **1/28/25**

### Whirlwind display examples

![Whirlwind within 8 yards](https://imgur.com/ZBkVrr2.jpg "Whirlwind within 8 yards") 

![Whirlwind 8 to 10 yards](https://imgur.com/0MHLtD0.jpg "Whirlwind 8 to 10 yards") 
 
### Overpower display examples
![Overpower overlay proc](https://imgur.com/lws9HCG.jpg "Overpower overlay proc") 

![Overpower overlay cooldown](https://imgur.com/EuuKd46.jpg "Overpower overlay cooldown")
