Below is the documentation for each supported attribute in the query system, including possible values where applicable and a simple example for each.

---

# Supported Item Attributes Documentation

### 1. **`stackCount`** (number)
   - **Description**: The number of items stacked in the item slot.
   - **Possible Values**: Any positive integer representing the stack count.
   
   **Example Query**:
   ```lua
   stackCount >= 20
   ```
   - **Explanation**: Categorizes items that have 20 or more in a stack.

### 2. **`expansionID`** (number)
   - **Description**: The ID of the World of Warcraft expansion in which the item was introduced.
   - **Possible Values**:

   | Expansion Name                     | expansionID |
   |-------------------------------------|-------------|
   | Base Game (Classic)                 | 0           |
   | The Burning Crusade                 | 1           |
   | Wrath of the Lich King              | 2           |
   | Cataclysm                           | 3           |
   | Mists of Pandaria                   | 4           |
   | Warlords of Draenor                 | 5           |
   | Legion                              | 6           |
   | Battle for Azeroth                  | 7           |
   | Shadowlands                         | 8           |
   | Dragonflight                        | 9           |

   **Example Query**:
   ```lua
   expansionID = 8
   ```
   - **Explanation**: Categorizes all items introduced in the Shadowlands expansion.

### 3. **`quality`** (number)
   - **Description**: The quality (rarity) of the item.
   - **Possible Values**:

   | Quality Name       | quality |
   |--------------------|---------|
   | Poor (Gray)        | 0       |
   | Common (White)     | 1       |
   | Uncommon (Green)   | 2       |
   | Rare (Blue)        | 3       |
   | Epic (Purple)      | 4       |
   | Legendary (Orange) | 5       |
   | Artifact           | 6       |
   | Heirloom           | 7       |

   **Example Query**:
   ```lua
   quality >= 3
   ```
   - **Explanation**: Categorizes items that are Rare (blue) or higher in quality.

### 4. **`isReadable`** (boolean)
   - **Description**: Indicates whether the item is readable (e.g., books or scrolls).
   - **Possible Values**: `true` or `false`

   **Example Query**:
   ```lua
   isReadable = true
   ```
   - **Explanation**: Categorizes all items that are readable.

### 5. **`hasLoot`** (boolean)
   - **Description**: Indicates whether the item contains loot (e.g., chests or containers).
   - **Possible Values**: `true` or `false`

   **Example Query**:
   ```lua
   hasLoot = true
   ```
   - **Explanation**: Categorizes all items that contain loot.

### 6. **`hasNoValue`** (boolean)
   - **Description**: Indicates whether the item has no sell price.
   - **Possible Values**: `true` or `false`
   
   **Example Query**:
   ```lua
   hasNoValue = false
   ```
   - **Explanation**: Categorizes all items that have a sell price.

### 7. **`itemID`** (number)
   - **Description**: The unique ID of the item.
   - **Possible Values**: Any valid item ID number.
   
   **Example Query**:
   ```lua
   itemID = 6948
   ```
   - **Explanation**: Categorizes the item with ID 6948 (e.g., Hearthstone).

### 8. **`isBound`** (boolean)
   - **Description**: Indicates whether the item is bound to the player.
   - **Possible Values**: `true` or `false`

   **Example Query**:
   ```lua
   isBound = true
   ```
   - **Explanation**: Categorizes all items that are soulbound to the player.

### 9. **`itemName`** (STRING)
   - **Description**: The name of the item.
   - **Possible Values**: Any valid string matching the item’s name.

   **Example Query**:
   ```lua
   itemName = "Epic Sword"
   ```
   - **Explanation**: Categorizes all items with the name "Epic Sword".

### 10. **`ilvl` (Item Level)** (number)
   - **Description**: The item level of the item.
   - **Possible Values**: Any positive integer representing the item level.

   **Example Query**:
   ```lua
   ilvl >= 100
   ```
   - **Explanation**: Categorizes items with an item level of 100 or higher.

### 11. **`itemMinLevel`** (number)
   - **Description**: The minimum character level required to use the item.
   - **Possible Values**: Any positive integer representing the minimum level.

   **Example Query**:
   ```lua
   itemMinLevel <= 60
   ```
   - **Explanation**: Categorizes items usable by characters of level 60 or lower.

### 12. **`itemType`** (number)
   - **Description**: The type of the item (e.g., Weapon, Armor).
   - **Possible Values**:


| Item Type                     | `itemType` |
|-------------------------------|------------|
| Consumable                    | 0          |
| Container                     | 1          |
| Weapon                        | 2          |
| Gem                           | 3          |
| Armor                         | 4          |
| Reagent                       | 5          |
| Projectile                    | 6          |
| Trade Goods                   | 7          |
| Recipe                        | 9          |
| Money                         | 10         |
| Quiver                        | 11         |
| Quest                         | 12         |
| Key                           | 13         |
| Permanent                     | 14         |
| Miscellaneous                 | 15         |
| Glyph                         | 16         |
| Battle Pets                   | 17         |
| WoW Token                     | 18         |

---

Here’s a brief description of each `itemType`:

- **0 - Consumable**: Items that are consumed when used, such as potions, food, flasks, and bandages.
- **1 - Container**: Bags and specialized storage containers (e.g., herb bags, mining bags).
- **2 - Weapon**: Items used in combat, including swords, axes, bows, and more.
- **3 - Gem**: Socketable gems that enhance stats when placed into equipment with sockets.
- **4 - Armor**: Worn items that provide protection, including shields.
- **5 - Reagent**: Materials used in crafting recipes, such as enchanting materials.
- **6 - Projectile**: Arrows or bullets, used with certain ranged weapons. (Mostly deprecated after changes to ranged weapons in WoW)
- **7 - Trade Goods**: Items used for professions and crafting that don’t fit under other categories.
- **9 - Recipe**: Crafting recipes for professions like Alchemy, Blacksmithing, and Cooking.
- **10 - Money**: Currency in the game (though this is rarely used as an item type in common queries).
- **11 - Quiver**: Items that were used to store projectiles (e.g., arrows). This item type is mostly deprecated.
- **12 - Quest**: Items that are tied to quests, often required to complete objectives.
- **13 - Key**: Items that unlock specific areas or chests, no longer commonly used in the game.
- **14 - Permanent**: Special items that often have a permanent effect, rare to see in modern expansions.
- **15 - Miscellaneous**: Items that don’t fit into other categories, including mounts, pets, and vanity items.
- **16 - Glyph**: Items that apply visual or mechanical modifications to spells (used with the Glyph system).
- **17 - Battle Pets**: Pets used in the pet battle system.
- **18 - WoW Token**: In-game tokens that can be sold for gold or redeemed for game time.

   **Example Query**:
   ```lua
   itemType = 2
   ```
   - **Explanation**: Categorizes all items that are weapons.

### 13. **`itemSubType`** (number)
   - **Description**: The subtype of the item, such as Sword, Mace, etc., when `itemType` is a Weapon or Armor.
   - **Possible Values**: Depends on the `itemType`.

The `itemSubType` attribute specifies the detailed subtype of an item, such as the specific weapon or armor type. The available values for `itemSubType` depend on the item's `itemType`. Below is the expanded documentation for `itemSubType`, broken down by `itemType`.

---

#### `itemSubType` Values Based on `itemType`

##### 1. **`itemType = 0`** (Consumable)
   | Subtype Name               | itemSubType |
   |----------------------------|-------------|
   | Explosives                  | 0           |
   | Potions                     | 1           |
   | Elixirs                     | 2           |
   | Flasks                      | 3           |
   | Food & Drink                | 5           |
   | Bandages                    | 7           |
   | Other                       | 8           |
   | Vantus Runes                | 9           |
   | Scrolls                     | 11          |
   | Artifact Power              | 13          |

   **Example Query**:
   ```lua
   itemType = 0 AND itemSubType = 1
   ```
   - **Explanation**: Categorizes all items that are Potions under the Consumable item type.

##### 2. **`itemType = 1`** (Container)
   | Subtype Name               | itemSubType |
   |----------------------------|-------------|
   | Bag                        | 0           |
   | Soul Bag                   | 1           |
   | Herb Bag                   | 2           |
   | Enchanting Bag             | 3           |
   | Engineering Bag            | 4           |
   | Gem Bag                    | 5           |
   | Mining Bag                 | 6           |
   | Leatherworking Bag         | 7           |
   | Inscription Bag            | 8           |
   | Tackle Box                 | 9           |
   | Cooking Bag                | 10          |

   **Example Query**:
   ```lua
   itemType = 1 AND itemSubType = 3
   ```
   - **Explanation**: Categorizes all Enchanting Bags under the Container item type.

##### 3. **`itemType = 2`** (Weapon)
   | Subtype Name               | itemSubType |
   |----------------------------|-------------|
   | One-Handed Axes             | 0           |
   | Two-Handed Axes             | 1           |
   | Bows                        | 2           |
   | Guns                        | 3           |
   | One-Handed Maces            | 4           |
   | Two-Handed Maces            | 5           |
   | Polearms                    | 6           |
   | One-Handed Swords           | 7           |
   | Two-Handed Swords           | 8           |
   | Warglaives                  | 9           |
   | Staffs                      | 10          |
   | Fist Weapons                | 13          |
   | Daggers                     | 15          |
   | Thrown                      | 16          |
   | Crossbows                   | 18          |
   | Wands                       | 19          |
   | Fishing Poles               | 20          |

   **Example Query**:
   ```lua
   itemType = 2 AND itemSubType = 7
   ```
   - **Explanation**: Categorizes all One-Handed Swords under the Weapon item type.

##### 4. **`itemType = 4`** (Armor)
   | Subtype Name               | itemSubType |
   |----------------------------|-------------|
   | Cloth                      | 1           |
   | Leather                    | 2           |
   | Mail                       | 3           |
   | Plate                      | 4           |
   | Shields                    | 6           |
   | Librams                    | 7           |
   | Idols                      | 8           |
   | Totems                     | 9           |
   | Sigils                     | 10          |
   | Relics                     | 11          |

   **Example Query**:
   ```lua
   itemType = 4 AND itemSubType = 4
   ```
   - **Explanation**: Categorizes all Plate Armor items under the Armor item type.

##### 5. **`itemType = 9`** (Recipe)
   | Subtype Name               | itemSubType |
   |----------------------------|-------------|
   | Book                       | 0           |
   | Leatherworking              | 1           |
   | Tailoring                  | 2           |
   | Engineering                | 3           |
   | Blacksmithing              | 4           |
   | Cooking                    | 5           |
   | Alchemy                    | 6           |
   | First Aid                  | 7           |
   | Enchanting                 | 8           |
   | Fishing                    | 9           |
   | Jewelcrafting              | 10          |
   | Inscription                | 11          |

   **Example Query**:
   ```lua
   itemType = 9 AND itemSubType = 6
   ```
   - **Explanation**: Categorizes all Alchemy recipes under the Recipe item type.

##### 6. **`itemType = 15`** (Miscellaneous)
   | Subtype Name               | itemSubType |
   |----------------------------|-------------|
   | Junk                       | 0           |
   | Reagent                    | 1           |
   | Pet                        | 2           |
   | Holiday                    | 3           |
   | Other                      | 4           |
   | Mount                      | 5           |
   | Mount Equipment            | 6           |
   | Token                      | 8           |

   **Example Query**:
   ```lua
   itemType = 15 AND itemSubType = 2
   ```
   - **Explanation**: Categorizes all Pets under the Miscellaneous item type.

##### 7. **`itemType = 16`** (Glyph)
   | Subtype Name               | itemSubType |
   |----------------------------|-------------|
   | Glyph                      | 1           |

   **Example Query**:
   ```lua
   itemType = 16 AND itemSubType = 1
   ```
   - **Explanation**: Categorizes all Glyphs.

---

### Explanation of Usage

You can use `itemSubType` in your queries by combining it with the `itemType` to make specific selections. The `itemType` defines the general category (e.g., Weapon, Armor, Consumable), and `itemSubType` defines the specific kind of item within that category (e.g., One-Handed Sword for Weapons, Plate for Armor).

**Example Full Query**:
```lua
itemType = 2 AND itemSubType = 7 AND ilvl >= 100
```
- **Explanation**: This query categorizes all One-Handed Swords with an item level of 100 or higher.

---

This documentation should give you a detailed understanding of how to use the `itemSubType` attribute in your queries based on the `itemType`. Let me know if you need more examples or clarifications!

### 14. **`inventoryType`** (number)
   - **Description**: Specifies the inventory slot type (e.g., Head, Chest).
   - **Possible Values**:

   | Slot Name       | inventoryType |
   |-----------------|---------------|
   | Head            | 1             |
   | Chest           | 5             |
   | Legs            | 7             |
   | Feet            | 8             |
   | Weapon (Main)   | 13            |
   | Weapon (Offhand)| 14            |

   **Example Query**:
   ```lua
   inventoryType = 1
   ```
   - **Explanation**: Categorizes all items that fit in the head slot.

### 15. **`sellPrice`** (number)
   - **Description**: The price at which the item can be sold to a vendor.
   - **Possible Values**: Any positive integer representing the sell price in copper.

   **Example Query**:
   ```lua
   sellPrice >= 1000
   ```
   - **Explanation**: Categorizes items with a sell price of 1000 copper (1 silver) or more.

### 16. **`isCraftingReagent`** (boolean)
   - **Description**: Indicates whether the item is a crafting reagent.
   - **Possible Values**: `true` or `false`

   **Example Query**:
   ```lua
   isCraftingReagent = true
   ```
   - **Explanation**: Categorizes all items that are crafting reagents.

### 17. **`isQuestItem`** (boolean)
   - **Description**: Indicates whether the item is a quest item.
   - **Possible Values**: `true` or `false`

   **Example Query**:
   ```lua
   isQuestItem = true
   ```
   - **Explanation**: Categorizes all items that are quest items.

### 18. **`questID`** (number)
   - **Description**: The ID of the quest associated with the item.
   - **Possible Values**: Any valid quest ID number.

   **Example Query**:
   ```lua
   questID = 12345
   ```
   - **Explanation**: Categorizes items associated with the quest ID `12345`.

### 19. **`isQuestItemActive`** (boolean)
   - **Description**: Indicates whether the item is associated with an active quest.
   - **Possible Values**: `true` or `false`

   **Example Query**:
   ```lua
   isQuestItemActive = true
   ```
   - **Explanation**: Categorizes all items that are part of an active quest.

### 20. **`bindType`** (number)
   - **Description**: Indicates the type of binding for the item.
   - **Possible Values**:

   | Bind Type             | bindType |
   |-----------------------|----------|
   | None                  | 0        |
   | Bind on Pickup (BoP)   | 1        |
   | Bind on Equip (BoE)    | 2        |
   | Bind on Use (BoU)      | 3        |

   **Example Query**:
   ```lua
   bindType = 1
   ```
   - **Explanation**: Categorizes all items that are Bind on Pickup (BoP).

---