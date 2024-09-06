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
* [solved] BAG_UPDATE is a bit broken - it was supposed not to refresh the view when items are removed, but fixing one bug caused it to no longer work this way in all cicrumstances. To verify what can we do about it, when actually this event is sent and what info we can get from it.
* the checks in drag and drop using pickedItemButton could be replaced with  C_Cursor.GetCursorItem() .
* blizzMove addon breakes it seems with this addon - to check whether it breaks only with this addon, or with it disabled as well as it currently does not work properly with other things like talents window so it might just be broken blizzmove.
* clearup the todos as I think there are duplicates and also these have become unordered due to that
* if ther was a way to properly higlight that an item would have been categorized differentlty by QL if it was unassigned directly by id to a category, we maybe would not need protected categories(Although I think it always should be an option, and those categories would also work before assignment by id). In the menu there should be an option to "always show given category".
    * categorize by QL if protected
    * categorize by id assignment
    * categorize by QL
    * unassigned
* add option to force new line on a given category
* breaking of groups does not seem to work properly - looks like it calculates only the amount within a given group whether it goes above the limit, not the entire amount of items in the column
* unassigned to junk was behaving weirdly
* taking of an item to just drop it onto a bag behaved weirdly. I think in such situation it should by default add it to unassigned maybe? Maybe if unassigned was always visible it owouldnt be an issue though
* the categorizers might need a rework. With custom query like option, assignments by mouse, and ability to show always - this is needed, and needed to be easily changed. Also prioritisation of them, if we are talking about query like language as it will be based on the first one to catch with the query will get the item.
* unassigned group should always be visible
* maybe if unassigned group is visible it should be added a bit more info to the tooltip what will happen if you move item over that group - that it will get unassigned from a custom group and can be picked by other categorizers
* make it so that when a category is selected, the custom category becomes always visible during that time (?). Alternative is also to allow for multiselect and those selected are always shown, even after categories menu close.
* the config should be stored in account wide config so maybe at some point we could introduce profiles.
* reenable new categorizer to work properly with merchant. Maybe mark those items bought from merchant somehow?
* show somewhere how many empty spaces are left
* display empty space if available to show how many items we can still add as well as allow for stack splits.
* add the effect when dragging to indicate that a given cateogry is protected so you cannot assign to it - ie red background, shield pickture and some small text? And when howevering over a category to which you can assign indicate with text that it will be assigned to this one?
* create a categorizer that is based on a query language. Categorizer would create protected categories (is this actually needed?).
* add sound when picking a category - maybe use the same sound that is used picking up items for simplicity
* there is a lot of bad code, broken domains. Especially in the place of:
  * custom categories and categories,
  * which code [class/domain] should trigger visual updates as it is a random to an extent at this point
* a lot of todo's
* add support for other bags. This is not a priority. I am doing this for fun and I feel current implementation of handling of the main bag kinda of works, I want to be adjusting it to a point I will be happy with it's behaviour. when I will extend the support onto other bags. But clean up the code toward proper mixin that maybe could be put on top of other frames if that is even possible.
* consider actually adding some options - number of columns, items per column, always break category to new line.
* ~the draggin workaround with empty button might not work properly when the bag is full, reagent is bought or pulled from bank / merchant. We could verify the type of the item dragged and then if it is reagent then try by default to put in the reagent. Or maybe there is some other, more generic function which would just put the item into the bags?~ Actually it seems game somehow handles this correctly when trying to assign from merchant, but still not from bank. Either I figure this out, leave as it [as you can still right click], or create a check if reagent then assign another empty button from reagent frame.
* Add ability to hide category so it won't show, nor the items in it
* add ability to disable category so it will stop catching items, but will exist. Items assigned by category will no longer be caught by this category. If they are moved to another category from unassigned, they will get removed from this category.