// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IRealmToken is IERC20 {
    /**
     * @dev Pauses all token transfers.
     * Requirements:
     * - caller must be the owner
     */
    function pause() external;

    /**
     * @dev Unpauses all token transfers.
     * Requirements:
     * - caller must be the owner
     */
    function unpause() external;

    /**
     * @dev Mints new tokens
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     * Requirements:
     * - caller must be the owner
     * - total supply after minting must not exceed MAX_SUPPLY
     */
    function mint(address to, uint256 amount) external;

    /**
     * @dev Burns tokens from the caller's account
     * @param amount The amount of tokens to burn
     */
    function burn(uint256 amount) external;

    /**
     * @dev Rewards a player with tokens
     * @param player The address of the player to reward
     * @param amount The amount of tokens to reward
     * Requirements:
     * - caller must be the owner
     * - total supply after rewarding must not exceed MAX_SUPPLY
     */
    function rewardPlayer(address player, uint256 amount) external;

    /**
     * @dev Burns tokens from a player's account through game mechanics
     * @param player The address of the player
     * @param amount The amount of tokens to burn
     * Requirements:
     * - caller must be the owner
     */
    function burnFromGame(address player, uint256 amount) external;

    /**
     * @dev Transfers tokens from the caller's account to another account
     * @param to The recipient address
     * @param amount The amount of tokens to transfer
     * @return bool Returns true if the transfer was successful
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Transfers tokens from one account to another using allowance
     * @param from The sender address
     * @param to The recipient address
     * @param amount The amount of tokens to transfer
     * @return bool Returns true if the transfer was successful
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    /**
     * @dev Sets amount as the allowance of spender over the caller's tokens
     * @param spender The address which will spend the funds
     * @param amount The amount of tokens to allow spender to use
     * @return bool Returns true if the approval was successful
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that spender is allowed to spend on behalf of owner
     * @param owner The address which owns the funds
     * @param spender The address which will spend the funds
     * @return uint256 The amount of remaining tokens allowed to be spent
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Returns the total supply of tokens
     * @return uint256 The total token supply
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the balance of the specified account
     * @param account The address to query the balance of
     * @return uint256 The token balance
     */
    function balanceOf(address account) external view returns (uint256);
}