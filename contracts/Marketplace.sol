// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface INFT is IERC1155 {
    enum ItemType { WEAPON, ARMOR }
    enum Rarity { COMMON, RARE, LEGENDARY }

    struct Item {
        string name;
        ItemType itemType;
        Rarity rarity;
        uint256 powerBonus;
        uint256 attackBonus;
        uint256 defenseBonus;
    }

    function items(uint256 tokenId) external view returns (
        string memory name,
        ItemType itemType,
        Rarity rarity,
        uint256 powerBonus,
        uint256 attackBonus,
        uint256 defenseBonus
    );
}

interface IRealmToken is IERC20 {
    function burn(uint256 amount) external;
}

interface IGameSystem {
    function addToRewardPool(uint256 amount) external;
}

contract Marketplace is ReentrancyGuard, ERC1155Holder, Pausable, Ownable {
    // Structs
    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 pricePerItem;
        bool isActive;
    }

    struct ListingDetails {
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 pricePerItem;
        bool isActive;
        string itemName;
        INFT.ItemType itemType;
        INFT.Rarity rarity;
        uint256 powerBonus;
        uint256 attackBonus;
        uint256 defenseBonus;
    }

    // State variables
    INFT public immutable gameItems;
    IRealmToken public immutable paymentToken;
    IGameSystem public gameSystem;

    mapping(uint256 => Listing) public listings;
    uint256 private _listingIds;

    // Fee related constants
    uint256 public constant BURN_FEE = 10; // 1% (in basis points)
    uint256 public constant REWARD_POOL_FEE = 10; // 1% (in basis points)

    // Events
    event Listed(
        uint256 indexed listingId,
        address indexed seller,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerItem
    );

    event Sale(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 tokenId,
        uint256 amount,
        uint256 totalPrice
    );

    event ListingCancelled(uint256 indexed listingId);
    event TokensBurned(uint256 amount);
    event RewardPoolUpdated(uint256 amount);
    event GameSystemUpdated(address newGameSystem);

    // Constructor
    constructor(
        address _gameItemsAddress,
        address _paymentTokenAddress,
        address _gameSystem,
        address initialOwner
    ) Ownable(initialOwner) {
        gameItems = INFT(_gameItemsAddress);
        paymentToken = IRealmToken(_paymentTokenAddress);
        gameSystem = IGameSystem(_gameSystem);
    }

    // Core functions
    function listItem(
        uint256 _tokenId,
        uint256 _amount,
        uint256 _pricePerItem
    ) external whenNotPaused returns (uint256) {
        require(_pricePerItem > 0, "Price must be greater than zero");
        require(_amount > 0, "Amount must be greater than zero");
        require(
            gameItems.balanceOf(msg.sender, _tokenId) >= _amount,
            "Insufficient balance"
        );
        require(
            gameItems.isApprovedForAll(msg.sender, address(this)),
            "Marketplace not approved"
        );

        _listingIds++;
        listings[_listingIds] = Listing({
            seller: msg.sender,
            tokenId: _tokenId,
            amount: _amount,
            pricePerItem: _pricePerItem,
            isActive: true
        });

        gameItems.safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId,
            _amount,
            ""
        );

        emit Listed(_listingIds, msg.sender, _tokenId, _amount, _pricePerItem);
        return _listingIds;
    }

    function buyItem(uint256 _listingId, uint256 _amount) external nonReentrant whenNotPaused {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "Listing is not active");
        require(_amount > 0 && _amount <= listing.amount, "Invalid amount");
        require(msg.sender != listing.seller, "Seller cannot buy their own items");

        uint256 totalPrice = listing.pricePerItem * _amount;

        // Calculate fees
        uint256 burnAmount = (totalPrice * BURN_FEE) / 1000; // 1%
        uint256 rewardPoolAmount = (totalPrice * REWARD_POOL_FEE) / 1000; // 1%
        uint256 sellerAmount = totalPrice - burnAmount - rewardPoolAmount;

        require(
            paymentToken.balanceOf(msg.sender) >= totalPrice,
            "Insufficient token balance"
        );
        require(
            paymentToken.allowance(msg.sender, address(this)) >= totalPrice,
            "Marketplace not approved for tokens"
        );

        // Update listing
        listing.amount = listing.amount - _amount;
        if (listing.amount == 0) {
            listing.isActive = false;
        }

        // Transfer NFT
        gameItems.safeTransferFrom(
            address(this),
            msg.sender,
            listing.tokenId,
            _amount,
            ""
        );

        // Transfer payment to seller
        require(
            paymentToken.transferFrom(msg.sender, listing.seller, sellerAmount),
            "Seller payment failed"
        );

        // Handle burn
        require(
            paymentToken.transferFrom(msg.sender, address(this), burnAmount),
            "Burn transfer failed"
        );
        paymentToken.burn(burnAmount);
        emit TokensBurned(burnAmount);

        // Handle reward pool
        require(
            paymentToken.transferFrom(msg.sender, address(gameSystem), rewardPoolAmount),
            "Reward pool transfer failed"
        );
        gameSystem.addToRewardPool(rewardPoolAmount);
        emit RewardPoolUpdated(rewardPoolAmount);

        emit Sale(
            _listingId,
            msg.sender,
            listing.tokenId,
            _amount,
            totalPrice
        );
    }

    function cancelListing(uint256 _listingId) external whenNotPaused {
        Listing storage listing = listings[_listingId];
        require(listing.isActive, "Listing is not active");
        require(listing.seller == msg.sender, "Only seller can cancel listing");

        listing.isActive = false;

        gameItems.safeTransferFrom(
            address(this),
            msg.sender,
            listing.tokenId,
            listing.amount,
            ""
        );

        emit ListingCancelled(_listingId);
    }

    // View functions
    function getListingDetails(uint256 _listingId)
    external
    view
    returns (ListingDetails memory)
    {
        Listing memory listing = listings[_listingId];
        ListingDetails memory details;

        details.seller = listing.seller;
        details.tokenId = listing.tokenId;
        details.amount = listing.amount;
        details.pricePerItem = listing.pricePerItem;
        details.isActive = listing.isActive;

        (
            details.itemName,
            details.itemType,
            details.rarity,
            details.powerBonus,
            details.attackBonus,
            details.defenseBonus
        ) = gameItems.items(listing.tokenId);

        return details;
    }

    function getTotalListings() external view returns (uint256) {
        return _listingIds;
    }

    function getActiveListings() external view returns (uint256[] memory) {
        uint256[] memory activeListingIds = new uint256[](_listingIds);
        uint256 activeCount = 0;

        for (uint256 i = 1; i <= _listingIds; i++) {
            if (listings[i].isActive) {
                activeListingIds[activeCount] = i;
                activeCount++;
            }
        }

        // Resize array to actual count
        assembly {
            mstore(activeListingIds, activeCount)
        }

        return activeListingIds;
    }

    // Admin functions
    function setGameSystem(address _gameSystem) external onlyOwner {
        require(_gameSystem != address(0), "Invalid address");
        gameSystem = IGameSystem(_gameSystem);
        emit GameSystemUpdated(_gameSystem);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}