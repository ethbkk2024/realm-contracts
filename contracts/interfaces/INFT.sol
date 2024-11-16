// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface INFT is IERC1155 {
    // Enums
    enum ItemType { WEAPON, ARMOR }
    enum Rarity { COMMON, RARE, LEGENDARY }
    enum CharacterType { WARRIOR, MAGE }

    struct Item {
        string name;
        ItemType itemType;
        Rarity rarity;
        uint256 powerBonus;
        uint256 attackBonus;
        uint256 defenseBonus;
    }

    struct CharacterTemplate {
        string name;
        CharacterType characterType;
        uint256 baseHealth;
        uint256 baseAttack;
        uint256 baseDefense;
        uint256 basePower;
    }

    struct PlayerCharacter {
        uint256 templateId;
        uint256 level;
        uint256 experience;
        uint256 health;
        uint256 attack;
        uint256 defense;
        uint256 power;
        uint256[] equippedItems;
    }

    struct Character {
        string name;
        CharacterType characterType;
        uint256 level;
        uint256 experience;
        uint256 health;
        uint256 attack;
        uint256 defense;
        uint256 power;
        uint256[] equippedItems;
    }

    // Events
    event LootBoxOpened(address indexed player, uint256 indexed tokenId, uint256 amount);
    event CharacterLootBoxOpened(address indexed player, CharacterType characterType);
    event ItemEquipped(uint256 indexed characterId, uint256 indexed itemId);
    event CharacterMinted(address indexed to, uint256 indexed characterId, CharacterType characterType);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount);

    // Main Functions
    function mintItem(address to, uint256 tokenId, uint256 amount) external;
    function mintCharacter(address to, CharacterType characterType) external;
    function equipItem(uint256 characterId, uint256 itemId) external;
    function openCharacterLootBox() external;
    function openItemLootBox() external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external;
    function withdrawTokens() external;

    // URI Functions
    function uri(uint256 tokenId) external view returns (string memory);
    function setURI(string memory newuri) external;

    // View Functions
    function getCharacter(uint256 characterId) external view returns (Character memory);
    function getItem(uint256 itemId) external view returns (Item memory);
    function getCharacterLootBoxPrice() external pure returns (uint256);
    function getItemLootBoxPrice() external pure returns (uint256);
    function getEquippedItems(uint256 characterId) external view returns (uint256[] memory);
    function isCharacterOwner(address account, uint256 characterId) external view returns (bool);

    // State Variables
    function items(uint256) external view returns (Item memory);
    function characters(uint256) external view returns (Character memory);
    function isCharacter(uint256) external view returns (bool);
    function WARRIOR_ID() external view returns (uint256);
    function MAGE_ID() external view returns (uint256);
    function CHARACTER_LOOTBOX_PRICE() external view returns (uint256);
    function ITEM_LOOTBOX_PRICE() external view returns (uint256);
    function gameToken() external view returns (address);

    function getPlayerCharacter(address player, uint256 characterId) external view returns (PlayerCharacter memory);
    function getCharacterTemplate(uint256 templateId) external view returns (CharacterTemplate memory);
    function getEquippedItems(address player, uint256 characterId) external view returns (uint256[] memory);
    function balanceOf(address account, uint256 id) external view returns (uint256);
}