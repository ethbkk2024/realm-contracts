// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IRealmToken.sol";
import "./interfaces/INFT.sol";

contract GameSystem is Ownable {
    // Core Events
    event GameInitialized(address indexed owner, address realmToken, address nftContract);
    event GameStateChanged(bool isPaused);
    event GameServerChanged(address indexed newServer);

    // Player Events
    event PlayerScoreUpdated(
        address indexed player,
        uint256 weekNumber,
        uint256 newScore,
        uint256 timestamp
    );
    event PlayerRankChanged(
        address indexed player,
        uint256 weekNumber,
        uint256 newRank,
        uint256 score
    );

    // Quest Events
    event QuestStarted(
        address indexed player,
        uint256 characterId,
        uint256 timestamp
    );
    event QuestCompleted(
        address indexed player,
        uint256 characterId,
        uint256 reward,
        uint256 timestamp
    );

    // Battle Events
    event BattleStarted(
        uint256 indexed battleId,
        address indexed player,
        uint256 characterId,
        uint256 enemyId,
        uint256 timestamp
    );
    event BattleCompleted(
        uint256 indexed battleId,
        address indexed player,
        uint256 characterId,
        bool victory,
        uint256 rewardAmount,
        uint256 timestamp
    );

    // Reward Events
    event WeeklyRewardsDistributed(
        uint256 indexed weekNumber,
        uint256 totalRewards,
        address[] winners,
        uint256[] amounts
    );
    event RewardPoolUpdated(
        uint256 newTotal,
        uint256 added,
        uint256 timestamp
    );
    event ForceDistributionExecuted(
        uint256 indexed weekNumber,
        address indexed triggeredBy,
        uint256 totalDistributed,
        uint256 timestamp
    );

    event MultiplierUpdated(
        address indexed player,
        uint256 baseMultiplier,
        uint256 stakingMultiplier,
        uint256 nftMultiplier,
        uint256 activityMultiplier
    );

    // Constants
    uint256 public constant WEEK_DURATION = 7 days;
    uint256 public constant QUEST_FEE = 500;    // 5%
    uint256 public constant BATTLE_FEE = 1000;  // 10%
    uint256 public constant MAX_WEEKLY_REWARD_PERCENTAGE = 3000; // 30%
    uint256 public constant WARRIOR_ID = 10001;
    uint256 public constant MAGE_ID = 10002;
    uint256 public constant BASE_MULTIPLIER = 10000; // 100%

    // Core State Variables
    IRealmToken public immutable realmToken;
    INFT public immutable nftContract;
    address public gameServer;
    bool public paused;

    // Game State
    uint256 public weeklyRewardPercentage;
    uint256 public lastWeekNumber;
    uint256 public battleCount;
    uint256 public minimumScoreForRewards;
    uint256 public weeklyParticipationThreshold;

    // Structs
    struct WeeklyLeaderboard {
        address[10] topPlayers;
        uint256[10] topScores;
        bool rewardsDistributed;
    }

    struct PlayerState {
        uint256 weekNumber;
        uint256 score;
        uint256 lastBattleTime;
        uint256 lastQuestTime;
    }

    struct GameStats {
        uint256 battlesWon;
        uint256 battlesLost;
        uint256 questsCompleted;
    }

    struct RewardMultiplier {
        uint256 baseMultiplier;
        uint256 stakingMultiplier;
        uint256 nftMultiplier;
        uint256 activityMultiplier;
    }

    // Mappings
    mapping(uint256 => WeeklyLeaderboard) public weeklyLeaderboards;
    mapping(address => PlayerState) public playerStates;
    mapping(address => GameStats) public playerStats;
    mapping(address => RewardMultiplier) public playerMultipliers;

    // Pool State
    uint256 public rewardPoolBalance;

    constructor(
        address _realmToken,
        address _nftContract,
        address _gameServer,
        address initialOwner
    ) Ownable(initialOwner) {
        realmToken = IRealmToken(_realmToken);
        nftContract = INFT(_nftContract);
        gameServer = _gameServer;
        weeklyRewardPercentage = 1000; // 10% default

        emit GameInitialized(initialOwner, _realmToken, _nftContract);
    }

    function startQuest(uint256 characterId) external {
        require(!paused, "Game is paused");
        require(nftContract.balanceOf(msg.sender, characterId) > 0, "Not character owner");
        require(nftContract.isCharacter(characterId), "Not a valid character");

        INFT.PlayerCharacter memory character = nftContract.getPlayerCharacter(msg.sender, characterId);
        require(character.level > 0, "Character not initialized");

        playerStates[msg.sender].lastQuestTime = block.timestamp;
        emit QuestStarted(msg.sender, characterId, block.timestamp);
    }

    function completeQuest(uint256 characterId) external {
        require(!paused, "Game is paused");
        require(nftContract.balanceOf(msg.sender, characterId) > 0, "Not character owner");

        INFT.PlayerCharacter memory character = nftContract.getPlayerCharacter(msg.sender, characterId);
        uint256 reward = _calculateQuestReward(character);

        playerStats[msg.sender].questsCompleted++;
        updatePlayerScore(msg.sender, reward);

        uint256 fee = (reward * QUEST_FEE) / 10000;
        uint256 netReward = reward - fee;
        rewardPoolBalance += fee;

        if(netReward > 0) {
            require(realmToken.transfer(msg.sender, netReward), "Reward transfer failed");
        }

        emit QuestCompleted(msg.sender, characterId, netReward, block.timestamp);
    }

    function startBattle(uint256 characterId, uint256 enemyId) external returns (uint256) {
        require(!paused, "Game is paused");
        require(nftContract.balanceOf(msg.sender, characterId) > 0, "Not character owner");
        require(nftContract.isCharacter(characterId), "Not a valid character");

        INFT.PlayerCharacter memory character = nftContract.getPlayerCharacter(msg.sender, characterId);
        require(character.level > 0, "Character not initialized");

        battleCount++;
        playerStates[msg.sender].lastBattleTime = block.timestamp;

        emit BattleStarted(
            battleCount,
            msg.sender,
            characterId,
            enemyId,
            block.timestamp
        );

        return battleCount;
    }

    function completeBattle(
        uint256 battleId,
        uint256 characterId,
        uint256 enemyId,
        bool victory
    ) external {
        require(!paused, "Game is paused");
        require(nftContract.balanceOf(msg.sender, characterId) > 0, "Not character owner");

        INFT.PlayerCharacter memory character = nftContract.getPlayerCharacter(msg.sender, characterId);
        uint256 reward = _calculateBattleReward(character, enemyId, victory);

        if(victory) {
            playerStats[msg.sender].battlesWon++;
            updatePlayerScore(msg.sender, reward);

            uint256 fee = (reward * BATTLE_FEE) / 10000;
            uint256 netReward = reward - fee;
            rewardPoolBalance += fee;

            if(netReward > 0) {
                require(realmToken.transfer(msg.sender, netReward), "Reward transfer failed");
            }
        } else {
            playerStats[msg.sender].battlesLost++;
        }

        emit BattleCompleted(
            battleId,
            msg.sender,
            characterId,
            victory,
            victory ? (reward - (reward * BATTLE_FEE) / 10000) : 0,
            block.timestamp
        );
    }

    function _distributeWeeklyRewards(uint256 weekNumber) internal {
        WeeklyLeaderboard storage board = weeklyLeaderboards[weekNumber];
        require(!board.rewardsDistributed, "Rewards already distributed");

        uint256 totalRewards = (rewardPoolBalance * weeklyRewardPercentage) / 10000;
        uint256 totalWeight = 0;

        // Calculate total weight
        for (uint256 i = 0; i < 10; i++) {
            address player = board.topPlayers[i];
            if (player == address(0)) break;
            if (board.topScores[i] < minimumScoreForRewards) break;

            uint256 multiplier = _calculatePlayerMultiplier(player);
            totalWeight += multiplier;
        }

        require(totalWeight > 0, "No eligible players");

        uint256[] memory rewardAmounts = new uint256[](10);
        address[] memory winners = new address[](10);
        uint256 distributedAmount = 0;

        // Distribute rewards
        for (uint256 i = 0; i < 10; i++) {
            address player = board.topPlayers[i];
            if (player == address(0) || board.topScores[i] < minimumScoreForRewards) break;

            uint256 multiplier = _calculatePlayerMultiplier(player);
            uint256 playerWeight = (multiplier * 10000) / totalWeight;
            uint256 reward = (totalRewards * playerWeight) / 10000;

            rewardAmounts[i] = reward;
            winners[i] = player;
            distributedAmount += reward;

            require(realmToken.transfer(player, reward), "Reward transfer failed");
        }

        rewardPoolBalance -= distributedAmount;
        board.rewardsDistributed = true;

        emit WeeklyRewardsDistributed(weekNumber, totalRewards, winners, rewardAmounts);
    }

    function _calculatePlayerMultiplier(address player) internal view returns (uint256) {
        RewardMultiplier memory multiplier = playerMultipliers[player];
        uint256 total = BASE_MULTIPLIER;

        // NFT multiplier (0-30%)
        uint256 nftCount = _calculatePlayerNFTs(player);
        if (nftCount > 0) {
            total += multiplier.nftMultiplier;
        }

        // Activity multiplier (0-20%)
        if (_checkPlayerActivity(player)) {
            total += multiplier.activityMultiplier;
        }

        return total;
    }

    function _calculatePlayerNFTs(address player) internal view returns (uint256) {
        uint256 characterCount = 0;
        if (nftContract.balanceOf(player, WARRIOR_ID) > 0) characterCount++;
        if (nftContract.balanceOf(player, MAGE_ID) > 0) characterCount++;
        return characterCount;
    }

    function _checkPlayerActivity(address player) internal view returns (bool) {
        uint256 currentWeek = block.timestamp / WEEK_DURATION;
        PlayerState storage state = playerStates[player];
        return state.weekNumber == currentWeek && state.score >= weeklyParticipationThreshold;
    }

    function _calculateQuestReward(INFT.PlayerCharacter memory character) private pure returns (uint256) {
        return 10 + (character.level * 5);
    }

    function _calculateBattleReward(
        INFT.PlayerCharacter memory character,
        uint256 enemyId,
        bool victory
    ) private pure returns (uint256) {
        if (!victory) return 0;

        uint256 baseReward = 20 + (character.level * 10);
        uint256 enemyBonus = enemyId * 5;
        uint256 powerBonus = character.power / 100;

        return baseReward + enemyBonus + powerBonus;
    }

    function updatePlayerScore(address player, uint256 points) internal {
        uint256 currentWeek = block.timestamp / WEEK_DURATION;
        PlayerState storage state = playerStates[player];
        if (currentWeek > lastWeekNumber) {
            if (lastWeekNumber > 0 && !weeklyLeaderboards[lastWeekNumber].rewardsDistributed) {
                _distributeWeeklyRewards(lastWeekNumber);
            }
            lastWeekNumber = currentWeek;
        }

        if (state.weekNumber != currentWeek) {
            state.weekNumber = currentWeek;
            state.score = points;
        } else {
            state.score += points;
        }

        emit PlayerScoreUpdated(player, currentWeek, state.score, block.timestamp);
        _updateLeaderboard(currentWeek, player, state.score);
    }

    function _updateLeaderboard(
        uint256 weekNumber,
        address player,
        uint256 newScore
    ) internal {
        WeeklyLeaderboard storage board = weeklyLeaderboards[weekNumber];
        int256 currentPos = -1;
        int256 newPos = -1;

        // Find positions
        for (uint256 i = 0; i < 10; i++) {
            if (board.topPlayers[i] == player) {
                currentPos = int256(i);
            }
            if (newPos == -1 && (board.topPlayers[i] == address(0) || newScore > board.topScores[i])) {
                newPos = int256(i);
            }
        }

        // Update leaderboard
        if (newPos >= 0) {
            if (currentPos >= 0) {
                if (currentPos != newPos) {
                    _shiftLeaderboardEntries(board, uint256(currentPos), uint256(newPos));
                }
            } else {
                _insertLeaderboardEntry(board, uint256(newPos), player, newScore);
            }

            emit PlayerRankChanged(player, weekNumber, uint256(newPos), newScore);
        }
    }

    function _shiftLeaderboardEntries(
        WeeklyLeaderboard storage board,
        uint256 from,
        uint256 to
    ) private {
        address playerAddr = board.topPlayers[from];
        uint256 playerScore = board.topScores[from];

        if (from > to) {
            for (uint256 i = from; i > to; i--) {
                board.topPlayers[i] = board.topPlayers[i-1];
                board.topScores[i] = board.topScores[i-1];
            }
        } else {
            for (uint256 i = from; i < to; i++) {
                board.topPlayers[i] = board.topPlayers[i+1];
                board.topScores[i] = board.topScores[i+1];
            }
        }

        board.topPlayers[to] = playerAddr;
        board.topScores[to] = playerScore;
    }

    function _insertLeaderboardEntry(
        WeeklyLeaderboard storage board,
        uint256 position,
        address player,
        uint256 score
    ) private {
        for (uint256 i = 9; i > position; i--) {
            board.topPlayers[i] = board.topPlayers[i-1];
            board.topScores[i] = board.topScores[i-1];
        }
        board.topPlayers[position] = player;
        board.topScores[position] = score;
    }

    // View Functions
    function getCurrentWeekLeaderboard() external view returns (
        address[10] memory players,
        uint256[10] memory scores
    ) {
        uint256 currentWeek = block.timestamp / WEEK_DURATION;
        WeeklyLeaderboard storage board = weeklyLeaderboards[currentWeek];
        return (board.topPlayers, board.topScores);
    }

    function getWeekLeaderboardDetails(uint256 weekNumber) external view returns (
        address[10] memory players,
        uint256[10] memory scores,
        bool distributed,
        uint256 potentialRewards
    ) {
        WeeklyLeaderboard storage board = weeklyLeaderboards[weekNumber];
        uint256 totalRewards = (rewardPoolBalance * weeklyRewardPercentage) / 10000;

        return (
            board.topPlayers,
            board.topScores,
            board.rewardsDistributed,
            totalRewards
        );
    }

    function getBattleInfo(address player) external view returns (
        uint256 battlesWon,
        uint256 battlesLost,
        uint256 lastBattleTime,
        bool canBattle
    ) {
        GameStats memory stats = playerStats[player];
        PlayerState memory state = playerStates[player];
        return (
            stats.battlesWon,
            stats.battlesLost,
            state.lastBattleTime,
            true // Always can battle for demo
        );
    }

    function calculatePotentialBattleReward(
        uint256 characterId,
        uint256 enemyId
    ) external view returns (
        uint256 totalReward,
        uint256 fee,
        uint256 netReward
    ) {
        INFT.PlayerCharacter memory character = nftContract.getPlayerCharacter(msg.sender, characterId);
        totalReward = _calculateBattleReward(character, enemyId, true);
        fee = (totalReward * BATTLE_FEE) / 10000;
        netReward = totalReward - fee;
    }

    function addToRewardPool(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(
            realmToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        rewardPoolBalance += amount;

        emit RewardPoolUpdated(
            rewardPoolBalance,
            amount,
            block.timestamp
        );
    }

    function getRewardPoolBalance() external view returns (uint256) {
        return rewardPoolBalance;
    }

    function adminAddToRewardPool(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(
            realmToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        rewardPoolBalance += amount;

        emit RewardPoolUpdated(
            rewardPoolBalance,
            amount,
            block.timestamp
        );
    }

    function addFeeToRewardPool(uint256 amount) external {
        rewardPoolBalance += amount;
        emit RewardPoolUpdated(rewardPoolBalance, amount, block.timestamp);
    }

    function forceDistributeRewards(uint256 weekNumber) external onlyOwner {
        require(weekNumber < block.timestamp / WEEK_DURATION, "Cannot distribute future rewards");
        require(!weeklyLeaderboards[weekNumber].rewardsDistributed, "Already distributed");

        uint256 beforeBalance = rewardPoolBalance;
        _distributeWeeklyRewards(weekNumber);
        uint256 distributed = beforeBalance - rewardPoolBalance;

        emit ForceDistributionExecuted(
            weekNumber,
            msg.sender,
            distributed,
            block.timestamp
        );
    }

    function setGameServer(address _newServer) external onlyOwner {
        require(_newServer != address(0), "Invalid address");
        gameServer = _newServer;
        emit GameServerChanged(_newServer);
    }

    function setWeeklyRewardPercentage(uint256 percentage) external onlyOwner {
        require(percentage <= MAX_WEEKLY_REWARD_PERCENTAGE, "Percentage too high");
        weeklyRewardPercentage = percentage;
    }

    function updatePlayerMultiplier(
        address player,
        uint256 nftMultiplier,
        uint256 activityMultiplier
    ) external onlyOwner {
        require(nftMultiplier <= 3000, "NFT multiplier too high"); // max 30%
        require(activityMultiplier <= 2000, "Activity multiplier too high"); // max 20%

        playerMultipliers[player] = RewardMultiplier({
            baseMultiplier: BASE_MULTIPLIER,
            stakingMultiplier: 0,
            nftMultiplier: nftMultiplier,
            activityMultiplier: activityMultiplier
        });

        emit MultiplierUpdated(
            player,
            BASE_MULTIPLIER,
            0,
            nftMultiplier,
            activityMultiplier
        );
    }

    function setRewardParameters(
        uint256 _minimumScore,
        uint256 _participationThreshold
    ) external onlyOwner {
        minimumScoreForRewards = _minimumScore;
        weeklyParticipationThreshold = _participationThreshold;
    }

    function togglePause() external onlyOwner {
        paused = !paused;
        emit GameStateChanged(paused);
    }

    function emergencyWithdraw() external onlyOwner {
        require(paused, "Game must be paused");
        uint256 balance = rewardPoolBalance;
        rewardPoolBalance = 0;
        require(realmToken.transfer(owner(), balance), "Transfer failed");
    }
}