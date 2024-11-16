// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract RealmToken is ERC20, ERC20Burnable, Pausable, Ownable {
    // Constants
    uint256 private constant INITIAL_SUPPLY = 1000000 * 10**18; // 1 million tokens
    uint256 private constant MAX_SUPPLY = 10000000 * 10**18; // 10 million tokens
    uint256 private constant AIRDROP_AMOUNT = 1000 * 10**18; // 1000 tokens per player
    uint256 private constant MAX_INITIAL_PLAYERS = 100; // Maximum number of initial players

    // State variables
    uint256 private initialPlayersCount;
    mapping(address => bool) private hasReceivedAirdrop;

    // Events
    event PlayerRewarded(
        address indexed player,
        uint256 amount,
        uint256 timestamp,
        string rewardType
    );

    event TokensBurned(
        address indexed player,
        uint256 amount,
        uint256 timestamp,
        string reason
    );

    event GameAction(
        address indexed player,
        string actionType,
        uint256 amount,
        uint256 timestamp
    );

    event AirdropClaimed(
        address indexed player,
        uint256 amount,
        uint256 timestamp
    );

    // Constructor
    constructor(address initialOwner)
    ERC20("Realm Token", "Realm")
    Ownable(initialOwner)
    {
        _mint(initialOwner, INITIAL_SUPPLY);
    }

    // Pause functions
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // Airdrop functions
    function claimInitialTokens() public {
        require(initialPlayersCount < MAX_INITIAL_PLAYERS, "Maximum initial players reached");
        require(!hasReceivedAirdrop[msg.sender], "Address has already claimed airdrop");
        require(totalSupply() + AIRDROP_AMOUNT <= MAX_SUPPLY, "Max supply exceeded");

        hasReceivedAirdrop[msg.sender] = true;
        initialPlayersCount++;

        _mint(msg.sender, AIRDROP_AMOUNT);

        emit AirdropClaimed(msg.sender, AIRDROP_AMOUNT, block.timestamp);
        emit GameAction(
            msg.sender,
            "INITIAL_CLAIM",
            AIRDROP_AMOUNT,
            block.timestamp
        );
    }

    function hasClaimedAirdrop(address player) public view returns (bool) {
        return hasReceivedAirdrop[player];
    }

    function remainingAirdrops() public view returns (uint256) {
        return MAX_INITIAL_PLAYERS - initialPlayersCount;
    }

    // Minting functions
    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply exceeded");
        _mint(to, amount);

        emit GameAction(
            to,
            "MINT",
            amount,
            block.timestamp
        );
    }

    // Game-specific functions
    function rewardPlayer(
        address player,
        uint256 amount,
        string memory rewardType
    ) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply exceeded");
        _mint(player, amount);

        emit PlayerRewarded(
            player,
            amount,
            block.timestamp,
            rewardType
        );
    }

    function burnFromGame(
        address player,
        uint256 amount,
        string memory reason
    ) public onlyOwner {
        _burn(player, amount);

        emit TokensBurned(
            player,
            amount,
            block.timestamp,
            reason
        );
    }

    // Override transfer functions
    function transfer(address to, uint256 amount)
    public
    virtual
    override
    returns (bool)
    {
        bool success = super.transfer(to, amount);
        if (success) {
            emit GameAction(
                msg.sender,
                "TRANSFER",
                amount,
                block.timestamp
            );
        }
        return success;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        bool success = super.transferFrom(from, to, amount);
        if (success) {
            emit GameAction(
                from,
                "TRANSFER_FROM",
                amount,
                block.timestamp
            );
        }
        return success;
    }
}