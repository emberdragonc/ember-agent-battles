// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {AgentBattles} from "../src/AgentBattles.sol";

contract AgentBattlesTest is Test {
    AgentBattles public battles;
    
    address public owner = makeAddr("owner");
    address public feeSplitter = makeAddr("feeSplitter");
    address public ideaCreator = makeAddr("ideaCreator");
    address public agent1 = makeAddr("agent1");
    address public agent2 = makeAddr("agent2");
    address public judge = makeAddr("judge");
    address public bettor1 = makeAddr("bettor1");
    address public bettor2 = makeAddr("bettor2");
    address public bettor3 = makeAddr("bettor3");
    
    uint256 public constant STAKE = 1 ether;
    uint256 public constant BET_AMOUNT = 0.5 ether;
    uint256 public constant DURATION = 1 days;
    
    function setUp() public {
        vm.prank(owner);
        battles = new AgentBattles(feeSplitter, ideaCreator);
        
        vm.deal(owner, 100 ether);
        vm.deal(bettor1, 100 ether);
        vm.deal(bettor2, 100 ether);
        vm.deal(bettor3, 100 ether);
    }
    
    // ============ Constructor Tests ============
    
    function test_Constructor() public view {
        assertEq(battles.feeSplitter(), feeSplitter);
        assertEq(battles.ideaCreator(), ideaCreator);
        assertEq(battles.owner(), owner);
    }
    
    function test_Constructor_RevertZeroFeeSplitter() public {
        vm.expectRevert(AgentBattles.ZeroAddress.selector);
        new AgentBattles(address(0), ideaCreator);
    }
    
    function test_Constructor_RevertZeroIdeaCreator() public {
        vm.expectRevert(AgentBattles.ZeroAddress.selector);
        new AgentBattles(feeSplitter, address(0));
    }
    
    // ============ Create Battle Tests ============
    
    function test_CreateBattle() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Build a DEX", agent1, agent2, DURATION, address(0));
        
        assertEq(battleId, 1);
        assertEq(battles.battleCount(), 1);
        
        AgentBattles.BattleCore memory core = battles.getBattleCore(battleId);
        assertEq(core.agent1, agent1);
        assertEq(core.agent2, agent2);
        assertEq(core.stake, STAKE);
        assertEq(core.judge, address(0));
        
        AgentBattles.BattleState memory state = battles.getBattleState(battleId);
        assertFalse(state.resolved);
        assertFalse(state.cancelled);
    }
    
    function test_CreateBattle_WithJudge() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Build a DEX", agent1, agent2, DURATION, judge);
        
        AgentBattles.BattleCore memory core = battles.getBattleCore(battleId);
        assertEq(core.judge, judge);
    }
    
    function test_CreateBattle_RevertZeroAgent() public {
        vm.prank(owner);
        vm.expectRevert(AgentBattles.ZeroAddress.selector);
        battles.createBattle{value: STAKE}("Task", address(0), agent2, DURATION, address(0));
    }
    
    function test_CreateBattle_RevertSameAgent() public {
        vm.prank(owner);
        vm.expectRevert(AgentBattles.InvalidAgent.selector);
        battles.createBattle{value: STAKE}("Task", agent1, agent1, DURATION, address(0));
    }
    
    function test_CreateBattle_RevertLowStake() public {
        vm.prank(owner);
        vm.expectRevert(AgentBattles.StakeBelowMinimum.selector);
        battles.createBattle{value: 0.0001 ether}("Task", agent1, agent2, DURATION, address(0));
    }
    
    function test_CreateBattle_RevertInvalidDuration() public {
        vm.prank(owner);
        vm.expectRevert(AgentBattles.InvalidDuration.selector);
        battles.createBattle{value: STAKE}("Task", agent1, agent2, 1 minutes, address(0));
    }
    
    // ============ Place Bet Tests ============
    
    function test_PlaceBet() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(bettor1);
        battles.placeBet{value: BET_AMOUNT}(battleId, 1);
        
        AgentBattles.Bet memory bet = battles.getBet(battleId, bettor1);
        assertEq(bet.agentPick, 1);
        assertEq(bet.amount, BET_AMOUNT);
        
        AgentBattles.BattleState memory state = battles.getBattleState(battleId);
        assertEq(state.totalBetsAgent1, BET_AMOUNT);
    }
    
    function test_PlaceBet_AddToExisting() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.startPrank(bettor1);
        battles.placeBet{value: BET_AMOUNT}(battleId, 1);
        battles.placeBet{value: BET_AMOUNT}(battleId, 1);
        vm.stopPrank();
        
        AgentBattles.Bet memory bet = battles.getBet(battleId, bettor1);
        assertEq(bet.amount, BET_AMOUNT * 2);
    }
    
    function test_PlaceBet_RevertChangeSide() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.startPrank(bettor1);
        battles.placeBet{value: BET_AMOUNT}(battleId, 1);
        
        vm.expectRevert(AgentBattles.InvalidAgent.selector);
        battles.placeBet{value: BET_AMOUNT}(battleId, 2);
        vm.stopPrank();
    }
    
    function test_PlaceBet_RevertAfterEnd() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(bettor1);
        vm.expectRevert(AgentBattles.BattleNotActive.selector);
        battles.placeBet{value: BET_AMOUNT}(battleId, 1);
    }
    
    function test_PlaceBet_RevertLowBet() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(bettor1);
        vm.expectRevert(AgentBattles.BetBelowMinimum.selector);
        battles.placeBet{value: 0.00001 ether}(battleId, 1);
    }
    
    // ============ Submit Work Tests ============
    
    function test_SubmitWork() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(agent1);
        battles.submitWork(battleId, "ipfs://work1");
        
        vm.prank(agent2);
        battles.submitWork(battleId, "ipfs://work2");
        
        assertEq(battles.agent1Works(battleId), "ipfs://work1");
        assertEq(battles.agent2Works(battleId), "ipfs://work2");
    }
    
    function test_SubmitWork_RevertNotAgent() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(bettor1);
        vm.expectRevert(AgentBattles.NotAuthorized.selector);
        battles.submitWork(battleId, "ipfs://work");
    }
    
    function test_SubmitWork_RevertAlreadySubmitted() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.startPrank(agent1);
        battles.submitWork(battleId, "ipfs://work1");
        
        vm.expectRevert(AgentBattles.AlreadySubmitted.selector);
        battles.submitWork(battleId, "ipfs://work1-updated");
        vm.stopPrank();
    }
    
    // ============ Resolution Tests ============
    
    function test_ResolveByJudge() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: BET_AMOUNT}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: BET_AMOUNT}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(judge);
        battles.resolveByJudge(battleId, 1);
        
        AgentBattles.BattleState memory state = battles.getBattleState(battleId);
        assertTrue(state.resolved);
        assertEq(state.winner, 1);
    }
    
    function test_ResolveByJudge_RevertNotJudge() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: BET_AMOUNT}(battleId, 1);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(owner);
        vm.expectRevert(AgentBattles.NotAuthorized.selector);
        battles.resolveByJudge(battleId, 1);
    }
    
    function test_ResolveByJudge_RevertBeforeEnd() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: BET_AMOUNT}(battleId, 1);
        
        vm.prank(judge);
        vm.expectRevert(AgentBattles.BattleNotEnded.selector);
        battles.resolveByJudge(battleId, 1);
    }
    
    function test_ResolveByVote() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(bettor1);
        battles.placeBet{value: 2 ether}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(owner);
        battles.resolveByVote(battleId);
        
        AgentBattles.BattleState memory state = battles.getBattleState(battleId);
        assertTrue(state.resolved);
        assertEq(state.winner, 1);
    }
    
    function test_ResolveByVote_Tie() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(owner);
        battles.resolveByVote(battleId);
        
        AgentBattles.BattleState memory state = battles.getBattleState(battleId);
        assertTrue(state.cancelled);
    }
    
    // ============ Claim Winnings Tests ============
    
    function test_ClaimWinnings() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(judge);
        battles.resolveByJudge(battleId, 1);
        
        uint256 feeSplitterBal = feeSplitter.balance;
        uint256 ideaCreatorBal = ideaCreator.balance;
        
        // Total pool = 1 ETH stake + 1 ETH loser bets = 2 ETH
        assertEq(feeSplitterBal, 0.1 ether);
        assertEq(ideaCreatorBal, 0.1 ether);
        
        uint256 balBefore = bettor1.balance;
        vm.prank(bettor1);
        battles.claimWinnings(battleId);
        uint256 balAfter = bettor1.balance;
        
        assertEq(balAfter - balBefore, 1 ether + 1.8 ether);
    }
    
    function test_ClaimWinnings_MultipleWinners() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: 3 ether}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.prank(bettor3);
        battles.placeBet{value: 2 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(judge);
        battles.resolveByJudge(battleId, 1);
        
        uint256 bal1Before = bettor1.balance;
        vm.prank(bettor1);
        battles.claimWinnings(battleId);
        assertEq(bettor1.balance - bal1Before, 5.025 ether);
        
        uint256 bal2Before = bettor2.balance;
        vm.prank(bettor2);
        battles.claimWinnings(battleId);
        assertEq(bettor2.balance - bal2Before, 1.675 ether);
    }
    
    function test_ClaimWinnings_RevertLoser() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(judge);
        battles.resolveByJudge(battleId, 1);
        
        vm.prank(bettor2);
        vm.expectRevert(AgentBattles.NothingToClaim.selector);
        battles.claimWinnings(battleId);
    }
    
    function test_ClaimWinnings_RevertDoubleClaim() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(judge);
        battles.resolveByJudge(battleId, 1);
        
        vm.startPrank(bettor1);
        battles.claimWinnings(battleId);
        
        vm.expectRevert(AgentBattles.AlreadyClaimed.selector);
        battles.claimWinnings(battleId);
        vm.stopPrank();
    }
    
    // ============ Emergency Refund Tests ============
    
    function test_EmergencyRefund() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.warp(block.timestamp + DURATION + battles.REFUND_TIMEOUT() + 1);
        
        uint256 balBefore = bettor1.balance;
        vm.prank(bettor1);
        battles.emergencyRefund(battleId);
        
        assertEq(bettor1.balance - balBefore, 1 ether);
    }
    
    function test_EmergencyRefund_RevertTooEarly() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(bettor1);
        vm.expectRevert(AgentBattles.TooEarlyForRefund.selector);
        battles.emergencyRefund(battleId);
    }
    
    function test_EmergencyRefund_RevertAfterResolution() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(judge);
        battles.resolveByJudge(battleId, 1);
        
        vm.warp(block.timestamp + battles.REFUND_TIMEOUT() + 1);
        
        vm.prank(bettor1);
        vm.expectRevert(AgentBattles.BattleAlreadyResolved.selector);
        battles.emergencyRefund(battleId);
    }
    
    // ============ Double Withdrawal Prevention Tests ============
    
    function test_CannotClaimAfterRefund() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.prank(owner);
        battles.cancelBattle(battleId, "Test cancel");
        
        vm.prank(bettor1);
        battles.emergencyRefund(battleId);
        
        vm.prank(bettor1);
        vm.expectRevert(AgentBattles.AlreadyClaimed.selector);
        battles.emergencyRefund(battleId);
    }
    
    // ============ Cancel Battle Tests ============
    
    function test_CancelBattle() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(owner);
        battles.cancelBattle(battleId, "Test reason");
        
        AgentBattles.BattleState memory state = battles.getBattleState(battleId);
        assertTrue(state.cancelled);
    }
    
    function test_CancelBattle_RevertNotOwner() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(bettor1);
        vm.expectRevert();
        battles.cancelBattle(battleId, "Test reason");
    }
    
    // ============ View Function Tests ============
    
    function test_IsBettingOpen() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        assertTrue(battles.isBettingOpen(battleId));
        
        vm.warp(block.timestamp + DURATION + 1);
        assertFalse(battles.isBettingOpen(battleId));
    }
    
    function test_IsBettingOpen_Cancelled() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(owner);
        battles.cancelBattle(battleId, "Test");
        
        assertFalse(battles.isBettingOpen(battleId));
    }
    
    function test_CalculatePotentialWinnings() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        uint256 potential = battles.calculatePotentialWinnings(battleId, 1, 1 ether);
        assertEq(potential, 2.8 ether);
    }
    
    // ============ Pause Tests ============
    
    function test_Pause() public {
        vm.prank(owner);
        battles.pause();
        
        vm.prank(owner);
        vm.expectRevert();
        battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
    }
    
    function test_Unpause() public {
        vm.prank(owner);
        battles.pause();
        
        vm.prank(owner);
        battles.unpause();
        
        vm.prank(owner);
        battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
    }
    
    // ============ Admin Tests ============
    
    function test_SetFeeSplitter() public {
        address newSplitter = makeAddr("newSplitter");
        vm.prank(owner);
        battles.setFeeSplitter(newSplitter);
        assertEq(battles.feeSplitter(), newSplitter);
    }
    
    function test_SetIdeaCreator() public {
        address newCreator = makeAddr("newCreator");
        vm.prank(owner);
        battles.setIdeaCreator(newCreator);
        assertEq(battles.ideaCreator(), newCreator);
    }
    
    // ============ Fuzz Tests ============
    
    function testFuzz_PlaceBet(uint256 amount) public {
        amount = bound(amount, battles.MIN_BET(), 10 ether);
        
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.deal(bettor1, amount);
        vm.prank(bettor1);
        battles.placeBet{value: amount}(battleId, 1);
        
        AgentBattles.Bet memory bet = battles.getBet(battleId, bettor1);
        assertEq(bet.amount, amount);
    }
    
    // ============ Pass 2: Adversarial Tests ============
    
    // Attack: Try to claim then refund
    function test_CannotRefundAfterClaim() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(judge);
        battles.resolveByJudge(battleId, 1);
        
        // Winner claims
        vm.prank(bettor1);
        battles.claimWinnings(battleId);
        
        // Try to also get refund - should fail (resolved)
        vm.warp(block.timestamp + battles.REFUND_TIMEOUT() + 1);
        vm.prank(bettor1);
        vm.expectRevert(AgentBattles.BattleAlreadyResolved.selector);
        battles.emergencyRefund(battleId);
    }
    
    // Attack: Resolution with zero bets on winning side
    function test_ResolveByJudge_RevertNoWinnerBets() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        // Only bet on agent2
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        // Try to resolve with agent1 as winner (no bets)
        vm.prank(judge);
        vm.expectRevert(AgentBattles.NoVotesForWinner.selector);
        battles.resolveByJudge(battleId, 1);
    }
    
    // Attack: Bet on cancelled battle
    function test_PlaceBet_RevertCancelled() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, address(0));
        
        vm.prank(owner);
        battles.cancelBattle(battleId, "Cancelled");
        
        vm.prank(bettor1);
        vm.expectRevert(AgentBattles.BattleCancelled.selector);
        battles.placeBet{value: BET_AMOUNT}(battleId, 1);
    }
    
    // Attack: Submit work after resolution
    function test_SubmitWork_RevertAfterResolution() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(judge);
        battles.resolveByJudge(battleId, 1);
        
        // Try to submit work after resolution
        vm.prank(agent1);
        vm.expectRevert(AgentBattles.BattleAlreadyResolved.selector);
        battles.submitWork(battleId, "ipfs://late");
    }
    
    // Attack: Claim after deadline
    function test_ClaimWinnings_RevertDeadlinePassed() public {
        vm.prank(owner);
        uint256 battleId = battles.createBattle{value: STAKE}("Task", agent1, agent2, DURATION, judge);
        
        vm.prank(bettor1);
        battles.placeBet{value: 1 ether}(battleId, 1);
        
        vm.prank(bettor2);
        battles.placeBet{value: 1 ether}(battleId, 2);
        
        vm.warp(block.timestamp + DURATION + 1);
        
        vm.prank(judge);
        battles.resolveByJudge(battleId, 1);
        
        // Warp past claim deadline
        vm.warp(block.timestamp + battles.CLAIM_DEADLINE() + 1);
        
        vm.prank(bettor1);
        vm.expectRevert(AgentBattles.ClaimDeadlinePassed.selector);
        battles.claimWinnings(battleId);
    }
    
    // Attack: Non-existent battle
    function test_PlaceBet_RevertBattleNotFound() public {
        vm.prank(bettor1);
        vm.expectRevert(AgentBattles.BattleNotFound.selector);
        battles.placeBet{value: BET_AMOUNT}(999, 1);
    }
}
