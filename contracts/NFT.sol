// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGameSystem {
    function addToRewardPool(uint256 amount) external;
    function addFeeToRewardPool(uint256 amount) external;
}

contract NFT is ERC1155, Ownable {
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

    mapping(uint256 => Item) public items;
    mapping(uint256 => CharacterTemplate) public characterTemplates;
    mapping(address => mapping(uint256 => PlayerCharacter)) public playerCharacters;
    mapping(uint256 => bool) public isCharacter;

    uint256 public constant WARRIOR_ID = 10001;
    uint256 public constant MAGE_ID = 10002;
    uint256 public constant CHARACTER_LOOTBOX_PRICE = 10 ether;
    uint256 public constant ITEM_LOOTBOX_PRICE = 5 ether;
    uint256 public constant LOOTBOX_FEE = 200; // 2%

    IERC20 public immutable gameToken;
    IGameSystem public gameSystem;

    event LootBoxOpened(address indexed player, uint256 indexed tokenId, uint256 amount, uint256 timestamp);
    event CharacterLootBoxOpened(address indexed player, CharacterType characterType, uint256 timestamp);
    event ItemEquipped(address indexed player, uint256 indexed characterId, uint256 indexed itemId, uint256 timestamp);
    event CharacterMinted(address indexed to, uint256 indexed characterId, CharacterType characterType, uint256 timestamp);
    event ItemMinted(address indexed to, uint256 indexed itemId, uint256 amount, uint256 timestamp);
    event CharacterLevelUp(address indexed player, uint256 indexed characterId, uint256 newLevel, uint256 timestamp);
    event FeeCollected(uint256 amount, address indexed gameSystem, uint256 timestamp);
    event GameSystemUpdated(address indexed newGameSystem, uint256 timestamp);

    constructor(
        address initialOwner,
        address _gameToken
    ) ERC1155("https://gateway.lighthouse.storage/ipfs/bafybeih5yh6iz42y4fjpygr2vcvdovnniud36z6b2htorgahso4dc2ujc4/{id}.json")
    Ownable(initialOwner) {
        require(_gameToken != address(0), "Invalid addresses");
        gameToken = IERC20(_gameToken);
        _initializeGame();
    }

    function _initializeGame() private {
        _createInitialItems();
        _createInitialCharacterTemplates();
    }

    function _createInitialItems() private {
        _createWeapon(1, "Iron Sword", Rarity.COMMON, 20, 15, 0);
        _createWeapon(2, "Mythril Blade", Rarity.RARE, 40, 30, 5);
        _createWeapon(3, "Dragon Slayer", Rarity.LEGENDARY, 60, 50, 10);
        _createArmor(4, "Iron Armor", Rarity.COMMON, 15, 0, 20);
        _createArmor(5, "Mythril Plate", Rarity.RARE, 30, 5, 40);
        _createArmor(6, "Divine Platemail", Rarity.LEGENDARY, 50, 10, 60);
    }

    function _createInitialCharacterTemplates() private {
        characterTemplates[WARRIOR_ID] = CharacterTemplate({
            name: "Warrior",
            characterType: CharacterType.WARRIOR,
            baseHealth: 150,
            baseAttack: 15,
            baseDefense: 12,
            basePower: 100
        });
        isCharacter[WARRIOR_ID] = true;

        characterTemplates[MAGE_ID] = CharacterTemplate({
            name: "Mage",
            characterType: CharacterType.MAGE,
            baseHealth: 100,
            baseAttack: 20,
            baseDefense: 8,
            basePower: 100
        });
        isCharacter[MAGE_ID] = true;
    }

    function _createWeapon(
        uint256 id,
        string memory name,
        Rarity rarity,
        uint256 powerBonus,
        uint256 attackBonus,
        uint256 defenseBonus
    ) private {
        items[id] = Item({
            name: name,
            itemType: ItemType.WEAPON,
            rarity: rarity,
            powerBonus: powerBonus,
            attackBonus: attackBonus,
            defenseBonus: defenseBonus
        });
    }

    function _createArmor(
        uint256 id,
        string memory name,
        Rarity rarity,
        uint256 powerBonus,
        uint256 attackBonus,
        uint256 defenseBonus
    ) private {
        items[id] = Item({
            name: name,
            itemType: ItemType.ARMOR,
            rarity: rarity,
            powerBonus: powerBonus,
            attackBonus: attackBonus,
            defenseBonus: defenseBonus
        });
    }

    function _mintCharacter(address player, uint256 templateId) internal {
        require(isCharacter[templateId], "Invalid character template");
        require(balanceOf(player, templateId) == 0, "Already owns this character type");

        CharacterTemplate memory template = characterTemplates[templateId];

        playerCharacters[player][templateId] = PlayerCharacter({
            templateId: templateId,
            level: 1,
            experience: 0,
            health: template.baseHealth,
            attack: template.baseAttack,
            defense: template.baseDefense,
            power: template.basePower,
            equippedItems: new uint256[](0)
        });

        _mint(player, templateId, 1, "");
    }

    function _collectAndSendFee(uint256 amount) private returns (uint256) {
        uint256 fee = (amount * LOOTBOX_FEE) / 10000;
        if (fee > 0) {
            require(gameToken.transfer(address(gameSystem), fee), "Fee transfer failed");
            gameSystem.addFeeToRewardPool(fee);
            emit FeeCollected(fee, address(gameSystem), block.timestamp);
        }
        return amount - fee;
    }

    function openCharacterLootBox() external {
        require(gameToken.balanceOf(msg.sender) >= CHARACTER_LOOTBOX_PRICE, "Insufficient tokens");
        require(gameToken.allowance(msg.sender, address(this)) >= CHARACTER_LOOTBOX_PRICE, "Token allowance too low");

        gameToken.transferFrom(msg.sender, address(this), CHARACTER_LOOTBOX_PRICE);
        _collectAndSendFee(CHARACTER_LOOTBOX_PRICE);

        uint256 characterId = block.timestamp % 2 == 0 ? WARRIOR_ID : MAGE_ID;
        CharacterType characterType = characterId == WARRIOR_ID ? CharacterType.WARRIOR : CharacterType.MAGE;

        _mintCharacter(msg.sender, characterId);

        emit CharacterLootBoxOpened(msg.sender, characterType, block.timestamp);
        emit CharacterMinted(msg.sender, characterId, characterType, block.timestamp);
    }

    function openItemLootBox() external {
        require(gameToken.balanceOf(msg.sender) >= ITEM_LOOTBOX_PRICE, "Insufficient tokens");
        require(gameToken.allowance(msg.sender, address(this)) >= ITEM_LOOTBOX_PRICE, "Token allowance too low");

        gameToken.transferFrom(msg.sender, address(this), ITEM_LOOTBOX_PRICE);
        _collectAndSendFee(ITEM_LOOTBOX_PRICE);

        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 6 + 1;
        _mint(msg.sender, randomNumber, 1, "");

        emit LootBoxOpened(msg.sender, randomNumber, 1, block.timestamp);
        emit ItemMinted(msg.sender, randomNumber, 1, block.timestamp);
    }

    function equipItem(uint256 characterId, uint256 itemId) external {
        require(isCharacter[characterId], "Not a character ID");
        require(balanceOf(msg.sender, characterId) > 0, "Not character owner");
        require(balanceOf(msg.sender, itemId) > 0, "Don't own this item");

        PlayerCharacter storage character = playerCharacters[msg.sender][characterId];
        Item memory item = items[itemId];

        character.power += item.powerBonus;
        character.attack += item.attackBonus;
        character.defense += item.defenseBonus;
        character.equippedItems.push(itemId);

        emit ItemEquipped(msg.sender, characterId, itemId, block.timestamp);
    }

    function addExperience(address player, uint256 characterId, uint256 expAmount) external {
        require(msg.sender == address(gameSystem), "Only game system can add experience");
        require(balanceOf(player, characterId) > 0, "Not character owner");

        PlayerCharacter storage character = playerCharacters[player][characterId];
        character.experience += expAmount;

        // Simple level up logic (can be made more complex)
        uint256 newLevel = (character.experience / 1000) + 1;
        if (newLevel > character.level) {
            character.level = newLevel;
            character.power += 10;
            character.attack += 5;
            character.defense += 5;
            character.health += 20;

            emit CharacterLevelUp(player, characterId, newLevel, block.timestamp);
        }
    }

    function getPlayerCharacter(address player, uint256 characterId) external view returns (PlayerCharacter memory) {
        require(isCharacter[characterId], "Not a character ID");
        require(balanceOf(player, characterId) > 0, "Not character owner");
        return playerCharacters[player][characterId];
    }

    function getCharacterTemplate(uint256 templateId) external view returns (CharacterTemplate memory) {
        require(isCharacter[templateId], "Not a character template ID");
        return characterTemplates[templateId];
    }

    function getItem(uint256 itemId) external view returns (Item memory) {
        return items[itemId];
    }

    function getEquippedItems(address player, uint256 characterId) external view returns (uint256[] memory) {
        require(isCharacter[characterId], "Not a character ID");
        require(balanceOf(player, characterId) > 0, "Not character owner");
        return playerCharacters[player][characterId].equippedItems;
    }

    function setGameSystem(address _gameSystem) external onlyOwner {
        require(_gameSystem != address(0), "Invalid address");
        gameSystem = IGameSystem(_gameSystem);
        emit GameSystemUpdated(_gameSystem, block.timestamp);
    }

    function withdrawTokens() external onlyOwner {
        uint256 balance = gameToken.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(gameToken.transfer(owner(), balance), "Transfer failed");
    }

    function setURI(string calldata newuri) external onlyOwner {
        _setURI(newuri);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}