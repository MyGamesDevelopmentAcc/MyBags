# My Bags

*Disclaimer: I do this for fun. I do this mainly for myself :). There are other bag addons with great support, but just lacked the flexibility in the setup of the bags that I wanted. To be on a safe side you might consider using those as I cannot guarantee keeping this up to date.*


Work in progress



## Design decisions 

Here are a list of decisions regarding features of this addon.

### I want this addon to be super simple.

This addon is not inteded to be configurable. It is inteded to have some default behaviour that I hope will fit some people that will decided to use it.

### Addon is build on top of existing bags

Idea is to expand current default bags funcionalities, create a separate bag addon. I have observed bag addons behaving in a way, that once I disabled them there were many features added to default bags, but due to total rewriter they were not available in those addons - either knowingly or not.

### Will display items as they are in bag slots as they are

This allows for any new features supported by default game bags to be available out of the box.

## Things to consider to change:

* [solved] click on an item in the bag requires you to drop it onto a different item in anothe rcategory. You cannot click another category which is miasligned with the ability to drag onto another category. Same when draggoning on the categories in edit mode.
* [solved] when too many items are to expand the height to far, the addon should try to automatically split given categories into separate columns.
* [solved] when dropping an item on bg [outside of category] it should it be assigned to latest category in the column.
* [solved] when buying from merchant you should be able to assign to a category automatically when dropping on an item 
* [solved] when buying from merchant you should be able to drop an item onto a free space to buy the item as long as there is an itembutton available
* [solved] When moving items from vendor or bank by mouse consider allowing for direct association with a category. Currently only dropping on items would work, but in the case of bank this results in items switching places. The only way is to right click which is doable, but then association with category has to be done afterwards resulting in two clicks which would be good to avoid.
* [solved] when moving an item from bank you should be able to assing to a category
* [solved] make it possible to always display certain categories, even if it is empty currently. I mean "Junk" - I want to see it all the time for cleanup purposes.
* [solved] as we have to use placedholder anyway rewrite the Junk how it is handled, and just add a category with one placeholder item to the arrange list and remove all the other code as it is not needed lol.... :|
* [solved] using placeholder items which allowed for better categories placements from the begining
* [solved] initial categories assignment is done by alphabetic order. Useful when we will allow for import of custom categories or external categorizers
* [solved] the gear categorizer could add icon of the category at the begining? :)
* the config should be stored in account wide config so maybe at some point we could introduce profiles.
* reenable new categorizer to work properly with merchant. Maybe mark those items bought from merchant somehow?
* show somewhere how many empty spaces are left
* display empty space if available to show how many items we can still add as well as allow for stack splits.
* add the effect when dragging to indicate that a given cateogry is protected so you cannot assign to it - ie red background, shield pickture and some small text? And when howevering over a category to which you can assign indicate with text that it will be assigned to this one?
* there is a lot of bad code, broken domains. Especially in the place of:
  * custom categories and categories,
  * which code [class/domain] should trigger visual updates as it is a random to an extent at this point
* a lot of todo's
* add support for other bags. This is not a priority. I am doing this for fun and I feel current implementation of handling of the main bag kinda of works, I want to be adjusting it to a point I will be happy with it's behaviour. when I will extend the support onto other bags. But clean up the code toward proper mixin that maybe could be put on top of other frames if that is even possible.
