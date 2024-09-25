# My Bags

*Disclaimer: I do this for fun. I do this mainly for myself :). There are other bag addons with great support, but just lacked the flexibility in the setup of the bags that I wanted. To be on a safe side you might consider using those as I cannot guarantee keeping this up to date. I am exposing it though so it was easier for my friends who wanted to use it to download it :)*

## What is this

This is yet another bag addon with a focus on manually creating groups and easy management of them to keep the bags organised.

**Bank bags and other are currently not supported.**

## Features

Main features provided by the addon

### Easy category adjustments

![Category adjustments](https://raw.githubusercontent.com/MyGamesDevelopmentAcc/MyBags/main/.previews/cat_move.gif)

### Easy item category change

Moving items between categories easily reassgins to a new category. Please note it is intentionally restricted to assign an item to a equipment set category.

![item category change](https://raw.githubusercontent.com/MyGamesDevelopmentAcc/MyBags/main/.previews/items_movement.gif)

### Easy category creation

![Category creation](https://raw.githubusercontent.com/MyGamesDevelopmentAcc/MyBags/main/.previews/cat_creation.gif)

### Built in always visible categories

![Category always visible](https://raw.githubusercontent.com/MyGamesDevelopmentAcc/MyBags/main/.previews/cat_always_visible.gif)

Some other worth mentioning:

* correct items orders kept
* two default categorizers:
  * for Junk
  * for equipment sets (with pretty icons ;) )
  * for New items. Right click on category name to move items to their preassigned categories.
* All items by default land in Unassigned category.

## Move, resize, do not close
I do not plan at this moment to add this functionality and it can be achieved via these two addons:
* [BlizzMove](https://github.com/Kiatra/BlizzMove) - move and scale. Unfortunately it does not currently (at the moment of writing) remeber user defined scale and reset with each open. One of the reasons I am considering adding such functionality within this addon.
* [NoAutoClose](https://github.com/NumyAddon/NoAutoClose) - prevents automatic close of frames when too many open at the same time.

## Design Decisions

Below are the key decisions made during the development of this addon:

#### Simplicity First

This addon is designed to be extremely simple and straightforward. It is not intended to be configurable. Instead, it follows a set of default behaviors that I believe will meet the needs of users who choose to use it.

#### Built on Existing Bags

The addon is designed to enhance the functionality of the default game bags rather than create an entirely new bag system. I’ve observed that many bag addons, when disabled, leave behind features added by the default bags that aren't available in those addons—whether intentionally or not. This addon aims to build on what’s already there, avoiding such issues.

#### Preserves Default Bag Item Slot Layout

The addon will display items exactly as they appear in the default bag slots. This approach ensures that any new features supported by the default game bags will be available without any additional work.

## TODOs, Ideas and other things considering for this addon

See "[TODOs, Ideas and other things considering for this addon](https://github.com/MyGamesDevelopmentAcc/MyBags/blob/main/TODOs.md)" to learn more.
