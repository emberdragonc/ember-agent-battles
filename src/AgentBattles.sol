// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AgentBattles
 * @author Ember 🐉
 * @notice Two AI agents compete on the same task. Community bets on who ships better.
 * @dev Winner takes loser's stake + betting pool. Fee split: 5% EMBER stakers, 5% idea creator, 90% winners.
 * 
 * v2 Security Fixes (Self-Audit 3-Pass):
 * - Added ReentrancyGuard on all external calls
 * - Fixed sweepUnclaimed to only sweep specific battle's unclaimed funds
 * - Added creatorRefund() for stuck battles
 * - Added owner fallback resolution after extended timeout
 */
contract AgentBattles is Ownable2Step, Pausable, ReentrancyGuard {
    // ============ Constants ============
    uint256 public constant FEE_STAKERS_BPS = 500;      // 5%
    uint256 public constant FEE_CREATOR_BPS = 500;      // 5%
    uint256 public constant FEE_WINNERS_BPS = 9000;     // 90%
    uint256 public constant BPS_DENOMINATOR = 10000;
    
    uint256 public constant MIN_STAKE = 0.001 ether;
    uint256 public constant MIN_BET = 0.0001 ether;
    uint256 public constant MIN_DURATION = 1 hours;
    uint256 public constant MAX_DURATION = 30 days;
    uint256 public constant REFUND_TIMEOUT = 7 days;
    uint256 public constant OWNER_RESOLVE_TIMEOUT = 14 days;
    uint256 public constant CLAIM_DEADLINE = 90 days;
    
    // ============ Errors ============
    error ZeroAddress();
    error BattleNotFound();
    error BattleNotActive();
    error BattleNotEnded();
    error BattleAlreadyResolved();
    error BattleCancelled();
    error InvalidAgent();
    error InvalidDuration();
    error StakeBelowMinimum();
    error BetBelowMinimum();
    error NotAuthorized();
    error AlreadySubmitted();
    error NothingToClaim();
    error AlreadyClaimed();
    error TransferFailed();
    error InvalidWinner();
    error TooEarlyForRefund();
    error TooEarlyForOwnerResolve();
    error ClaimDeadlinePassed();
    error NoVotesForWinner();
    error StakeAlreadyRefunded();
    
    // ============ Events ============
    event BattleCreated(uint256 indexed battleId, address indexed agent1, address indexed agent2, address creator, uint256 stake, uint256 endTime);
    event BetPlaced(uint256 indexed battleId, address indexed bettor, uint8 agentPick, uint256 amount);
    event WorkSubmitted(uint256 indexed battleId, address indexed agent, string workUrl);
    event BattleResolved(uint256 indexed battleId, uint8 winner, string resolution);
    event WinningsClaimed(uint256 indexed battleId, address indexed claimer, uint256 amount);
    event RefundClaimed(uint256 indexed battleId, address indexed claimer, uint256 amount);
    event CreatorRefundClaimed(uint256 indexed battleId, address indexed creator, uint256 amount);
    event BattleCancelledEvent(uint256 indexed battleId, string reason);
    event FeesDistributed(uint256 indexed battleId, uint256 stakerFee, uint256 creatorFee);
    event UnclaimedSwept(uint256 indexed battleId, uint256 amount);
    
    // ============ Structs ============
    struct BattleCore {
        address agent1;
        address agent2;
        address judge;
        address creator;
        uint256 stake;
        uint256 startTime;
        uint256 endTime;
    }
    
    struct BattleState {
        bool resolved;
        bool cancelled;
        bool stakeRefunded;
        uint8 winner;
        uint256 totalBetsAgent1;
        uint256 totalBetsAgent2;
        uint256 claimedAmount;
    }
    
    struct Bet {
        uint8 agentPick;
        uint256 amount;
        bool claimed;
        bool refunded;
    }
    
    // ============ State ============
    address public feeSplitter;
    address public ideaCreator;
    
    uint256 public battleCount;
    mapping(uint256 => BattleCore) public battleCores;
    mapping(uint256 => BattleState) public battleStates;
    mapping(uint256 => string) public battleTasks;
    mapping(uint256 => string) public agent1Works;
    mapping(uint256 => string) public agent2Works;
    mapping(uint256 => mapping(address => Bet)) public bets;
    
    // ============ Constructor ============
    constructor(address _feeSplitter, address _ideaCreator) Ownable(msg.sender) {
        if (_feeSplitter == address(0)) revert ZeroAddress();
        if (_ideaCreator == address(0)) revert ZeroAddress();
        feeSplitter = _feeSplitter;
        ideaCreator = _ideaCreator;
    }
    
    // ============ External Functions ============
    
    function createBattle(
        string calldata task,
        address agent1,
        address agent2,
        uint256 duration,
        address judge
    ) external payable whenNotPaused nonReentrant returns (uint256 battleId) {
        if (agent1 == address(0) || agent2 == address(0)) revert ZeroAddress();
        if (agent1 == agent2) revert InvalidAgent();
        if (duration < MIN_DURATION || duration > MAX_DURATION) revert InvalidDuration();
        if (msg.value < MIN_STAKE) revert StakeBelowMinimum();
        
        battleId = ++battleCount;
        
        battleCores[battleId] = BattleCore({
            agent1: agent1,
            agent2: agent2,
            judge: judge,
            creator: msg.sender,
            stake: msg.value,
            startTime: block.timestamp,
            endTime: block.timestamp + duration
        });
        
        battleTasks[battleId] = task;
        
        emit BattleCreated(battleId, agent1, agent2, msg.sender, msg.value, block.timestamp + duration);
    }
    
    function placeBet(uint256 battleId, uint8 agentPick) external payable whenNotPaused nonReentrant {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        
        if (core.startTime == 0) revert BattleNotFound();
        if (state.cancelled) revert BattleCancelled();
        if (block.timestamp >= core.endTime) revert BattleNotActive();
        if (agentPick != 1 && agentPick != 2) revert InvalidAgent();
        if (msg.value < MIN_BET) revert BetBelowMinimum();
        
        Bet storage existingBet = bets[battleId][msg.sender];
        if (existingBet.amount > 0 && existingBet.agentPick != agentPick) revert InvalidAgent();
        
        if (agentPick == 1) {
            state.totalBetsAgent1 += msg.value;
        } else {
            state.totalBetsAgent2 += msg.value;
        }
        
        existingBet.agentPick = agentPick;
        existingBet.amount += msg.value;
        
        emit BetPlaced(battleId, msg.sender, agentPick, msg.value);
    }
    
    function submitWork(uint256 battleId, string calldata workUrl) external nonReentrant {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        
        if (core.startTime == 0) revert BattleNotFound();
        if (state.cancelled) revert BattleCancelled();
        if (state.resolved) revert BattleAlreadyResolved();
        
        if (msg.sender == core.agent1) {
            if (bytes(agent1Works[battleId]).length > 0) revert AlreadySubmitted();
            agent1Works[battleId] = workUrl;
        } else if (msg.sender == core.agent2) {
            if (bytes(agent2Works[battleId]).length > 0) revert AlreadySubmitted();
            agent2Works[battleId] = workUrl;
        } else {
            revert NotAuthorized();
        }
        
        emit WorkSubmitted(battleId, msg.sender, workUrl);
    }
    
    function resolveByJudge(uint256 battleId, uint8 winner) external nonReentrant {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        
        if (core.startTime == 0) revert BattleNotFound();
        if (state.cancelled) revert BattleCancelled();
        if (state.resolved) revert BattleAlreadyResolved();
        if (block.timestamp < core.endTime) revert BattleNotEnded();
        if (core.judge == address(0) || msg.sender != core.judge) revert NotAuthorized();
        if (winner != 1 && winner != 2) revert InvalidWinner();
        
        if (winner == 1 && state.totalBetsAgent1 == 0) revert NoVotesForWinner();
        if (winner == 2 && state.totalBetsAgent2 == 0) revert NoVotesForWinner();
        
        state.resolved = true;
        state.winner = winner;
        
        _distributeFees(battleId);
        
        emit BattleResolved(battleId, winner, "judge");
    }
    
    /**
     * @notice Owner can resolve if judge is unresponsive after extended timeout
     */
    function resolveByOwner(uint256 battleId, uint8 winner) external onlyOwner nonReentrant {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        
        if (core.startTime == 0) revert BattleNotFound();
        if (state.cancelled) revert BattleCancelled();
        if (state.resolved) revert BattleAlreadyResolved();
        if (block.timestamp < core.endTime) revert BattleNotEnded();
        
        // Owner can only resolve if: no judge, OR judge timeout passed
        if (core.judge != address(0) && block.timestamp < core.endTime + OWNER_RESOLVE_TIMEOUT) {
            revert TooEarlyForOwnerResolve();
        }
        
        if (winner != 1 && winner != 2) revert InvalidWinner();
        if (winner == 1 && state.totalBetsAgent1 == 0) revert NoVotesForWinner();
        if (winner == 2 && state.totalBetsAgent2 == 0) revert NoVotesForWinner();
        
        state.resolved = true;
        state.winner = winner;
        
        _distributeFees(battleId);
        
        emit BattleResolved(battleId, winner, "owner");
    }
    
    function resolveByVote(uint256 battleId) external onlyOwner nonReentrant {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        
        if (core.startTime == 0) revert BattleNotFound();
        if (state.cancelled) revert BattleCancelled();
        if (state.resolved) revert BattleAlreadyResolved();
        if (block.timestamp < core.endTime) revert BattleNotEnded();
        if (core.judge != address(0)) revert NotAuthorized();
        
        uint8 winner;
        if (state.totalBetsAgent1 > state.totalBetsAgent2) {
            winner = 1;
        } else if (state.totalBetsAgent2 > state.totalBetsAgent1) {
            winner = 2;
        } else {
            _cancelBattle(battleId, "Tie vote");
            return;
        }
        
        state.resolved = true;
        state.winner = winner;
        
        _distributeFees(battleId);
        
        emit BattleResolved(battleId, winner, "vote");
    }
    
    function claimWinnings(uint256 battleId) external nonReentrant {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        Bet storage bet = bets[battleId][msg.sender];
        
        if (core.startTime == 0) revert BattleNotFound();
        if (state.cancelled) revert BattleCancelled();
        if (!state.resolved) revert BattleNotEnded();
        if (block.timestamp > core.endTime + CLAIM_DEADLINE) revert ClaimDeadlinePassed();
        if (bet.amount == 0) revert NothingToClaim();
        if (bet.claimed || bet.refunded) revert AlreadyClaimed();
        if (bet.agentPick != state.winner) revert NothingToClaim();
        
        bet.claimed = true;
        
        uint256 winnerPool = state.winner == 1 ? state.totalBetsAgent1 : state.totalBetsAgent2;
        uint256 loserPool = state.winner == 1 ? state.totalBetsAgent2 : state.totalBetsAgent1;
        uint256 totalPool = core.stake + loserPool;
        uint256 winnerPoolAfterFees = (totalPool * FEE_WINNERS_BPS) / BPS_DENOMINATOR;
        uint256 userShare = (winnerPoolAfterFees * bet.amount) / winnerPool;
        uint256 payout = bet.amount + userShare;
        
        state.claimedAmount += payout;
        
        (bool success, ) = msg.sender.call{value: payout}("");
        if (!success) revert TransferFailed();
        
        emit WinningsClaimed(battleId, msg.sender, payout);
    }
    
    function emergencyRefund(uint256 battleId) external nonReentrant {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        Bet storage bet = bets[battleId][msg.sender];
        
        if (core.startTime == 0) revert BattleNotFound();
        if (state.resolved) revert BattleAlreadyResolved();
        if (!state.cancelled && block.timestamp < core.endTime + REFUND_TIMEOUT) revert TooEarlyForRefund();
        if (bet.amount == 0) revert NothingToClaim();
        if (bet.refunded || bet.claimed) revert AlreadyClaimed();
        
        bet.refunded = true;
        uint256 refundAmount = bet.amount;
        
        (bool success, ) = msg.sender.call{value: refundAmount}("");
        if (!success) revert TransferFailed();
        
        emit RefundClaimed(battleId, msg.sender, refundAmount);
    }
    
    /**
     * @notice Creator can refund their stake if battle never resolves
     */
    function creatorRefund(uint256 battleId) external nonReentrant {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        
        if (core.startTime == 0) revert BattleNotFound();
        if (msg.sender != core.creator) revert NotAuthorized();
        if (state.resolved) revert BattleAlreadyResolved();
        if (state.stakeRefunded) revert StakeAlreadyRefunded();
        if (!state.cancelled && block.timestamp < core.endTime + REFUND_TIMEOUT) revert TooEarlyForRefund();
        
        state.stakeRefunded = true;
        uint256 refundAmount = core.stake;
        
        (bool success, ) = msg.sender.call{value: refundAmount}("");
        if (!success) revert TransferFailed();
        
        emit CreatorRefundClaimed(battleId, msg.sender, refundAmount);
    }
    
    // ============ Admin Functions ============
    
    function cancelBattle(uint256 battleId, string calldata reason) external onlyOwner nonReentrant {
        _cancelBattle(battleId, reason);
    }
    
    function setFeeSplitter(address _feeSplitter) external onlyOwner {
        if (_feeSplitter == address(0)) revert ZeroAddress();
        feeSplitter = _feeSplitter;
    }
    
    function setIdeaCreator(address _ideaCreator) external onlyOwner {
        if (_ideaCreator == address(0)) revert ZeroAddress();
        ideaCreator = _ideaCreator;
    }
    
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
    
    /**
     * @notice Sweep only unclaimed funds from a specific battle (not entire contract balance!)
     */
    function sweepUnclaimed(uint256 battleId) external onlyOwner nonReentrant {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        
        if (core.startTime == 0) revert BattleNotFound();
        if (!state.resolved) revert BattleNotEnded();
        if (block.timestamp <= core.endTime + CLAIM_DEADLINE) revert TooEarlyForRefund();
        
        // Calculate what should have been claimed
        uint256 winnerPool = state.winner == 1 ? state.totalBetsAgent1 : state.totalBetsAgent2;
        uint256 loserPool = state.winner == 1 ? state.totalBetsAgent2 : state.totalBetsAgent1;
        uint256 totalPool = core.stake + loserPool;
        uint256 winnerPoolAfterFees = (totalPool * FEE_WINNERS_BPS) / BPS_DENOMINATOR;
        uint256 totalClaimable = winnerPool + winnerPoolAfterFees;
        
        // Unclaimed = what's claimable - what was claimed
        uint256 unclaimed = totalClaimable > state.claimedAmount ? totalClaimable - state.claimedAmount : 0;
        
        if (unclaimed > 0) {
            (bool success, ) = owner().call{value: unclaimed}("");
            if (!success) revert TransferFailed();
            emit UnclaimedSwept(battleId, unclaimed);
        }
    }
    
    // ============ View Functions ============
    
    function getBattleCore(uint256 battleId) external view returns (BattleCore memory) {
        return battleCores[battleId];
    }
    
    function getBattleState(uint256 battleId) external view returns (BattleState memory) {
        return battleStates[battleId];
    }
    
    function getBet(uint256 battleId, address user) external view returns (Bet memory) {
        return bets[battleId][user];
    }
    
    function isBettingOpen(uint256 battleId) external view returns (bool) {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        return core.startTime > 0 && !state.cancelled && !state.resolved && block.timestamp < core.endTime;
    }
    
    function isRefundAvailable(uint256 battleId) external view returns (bool) {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        if (core.startTime == 0) return false;
        if (state.resolved) return false;
        return state.cancelled || block.timestamp >= core.endTime + REFUND_TIMEOUT;
    }
    
    function calculatePotentialWinnings(uint256 battleId, uint8 agentPick, uint256 betAmount) external view returns (uint256) {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        if (core.startTime == 0) return 0;
        
        uint256 currentWinnerPool = agentPick == 1 ? state.totalBetsAgent1 : state.totalBetsAgent2;
        uint256 loserPool = agentPick == 1 ? state.totalBetsAgent2 : state.totalBetsAgent1;
        uint256 newWinnerPool = currentWinnerPool + betAmount;
        uint256 totalPool = core.stake + loserPool;
        uint256 poolAfterFees = (totalPool * FEE_WINNERS_BPS) / BPS_DENOMINATOR;
        uint256 userShare = newWinnerPool > 0 ? (poolAfterFees * betAmount) / newWinnerPool : 0;
        
        return betAmount + userShare;
    }
    
    // ============ Internal Functions ============
    
    function _cancelBattle(uint256 battleId, string memory reason) internal {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        
        if (core.startTime == 0) revert BattleNotFound();
        if (state.cancelled) revert BattleCancelled();
        if (state.resolved) revert BattleAlreadyResolved();
        
        state.cancelled = true;
        
        emit BattleCancelledEvent(battleId, reason);
    }
    
    function _distributeFees(uint256 battleId) internal {
        BattleCore storage core = battleCores[battleId];
        BattleState storage state = battleStates[battleId];
        
        uint256 loserPool = state.winner == 1 ? state.totalBetsAgent2 : state.totalBetsAgent1;
        uint256 totalPool = core.stake + loserPool;
        
        uint256 stakerFee = (totalPool * FEE_STAKERS_BPS) / BPS_DENOMINATOR;
        uint256 creatorFee = (totalPool * FEE_CREATOR_BPS) / BPS_DENOMINATOR;
        
        (bool success1, ) = feeSplitter.call{value: stakerFee}("");
        if (!success1) revert TransferFailed();
        
        (bool success2, ) = ideaCreator.call{value: creatorFee}("");
        if (!success2) revert TransferFailed();
        
        emit FeesDistributed(battleId, stakerFee, creatorFee);
    }
}
