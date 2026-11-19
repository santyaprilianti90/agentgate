// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AgentGate} from "../src/AgentGate.sol";

interface Vm {
    function warp(uint256 newTimestamp) external;
    function prank(address newSender) external;
    function expectRevert(bytes4 revertData) external;
}

/// @notice Minimal stand-in for the SPACE ID Agent ID contract.
contract MockAgentId {
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    function mint(address to, uint256 tokenId) external {
        _owners[tokenId] = to;
        _balances[to] += 1;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }

    function balanceOf(address owner) external view returns (uint256) {
        return _balances[owner];
    }
}

contract AgentGateTest {
    Vm private constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    AgentGate private gate;
    MockAgentId private agentId;

    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);

    uint256 private constant NOVIA = 424242; // fake Agent ID token id for alice
    uint256 private constant SETYA = 777; // fake Agent ID token id for bob

    function setUp() public {
        agentId = new MockAgentId();
        gate = new AgentGate(address(agentId));
        agentId.mint(alice, NOVIA);
        agentId.mint(bob, SETYA);
    }

    function assertEq(uint256 a, uint256 b, string memory what) internal pure {
        require(a == b, what);
    }

    function assertEq(address a, address b, string memory what) internal pure {
        require(a == b, what);
    }

    function assertTrue(bool c, string memory what) internal pure {
        require(c, what);
    }

    function testClaimBadge() public {
        vm.prank(alice);
        uint256 badgeId = gate.claimBadge(NOVIA);
        assertEq(badgeId, 1, "first badge id is 1");
        assertEq(gate.ownerOf(1), alice, "badge owner");
        assertEq(gate.balanceOf(alice), 1, "badge balance");
        assertEq(gate.badgeByAgentId(NOVIA), 1, "badgeByAgentId");
        assertEq(gate.agentIdOfBadge(1), NOVIA, "agentIdOfBadge");
        assertEq(gate.badgeOfWallet(alice), 1, "badgeOfWallet");
        assertTrue(gate.isVerifiedAgent(alice), "alice verified");
        assertEq(gate.totalBadges(), 1, "totalBadges");
    }

    function testClaimRevertsForNonOwner() public {
        vm.prank(bob);
        vm.expectRevert(AgentGate.NotAgentIdOwner.selector);
        gate.claimBadge(NOVIA);
    }

    function testDoubleClaimSameAgentReverts() public {
        vm.prank(alice);
        gate.claimBadge(NOVIA);
        vm.prank(alice);
        vm.expectRevert(AgentGate.AgentAlreadyHasBadge.selector);
        gate.claimBadge(NOVIA);
    }

    function testSecondAgentSameWalletReverts() public {
        agentId.mint(alice, 999);
        vm.prank(alice);
        gate.claimBadge(NOVIA);
        vm.prank(alice);
        vm.expectRevert(AgentGate.WalletAlreadyHasBadge.selector);
        gate.claimBadge(999);
    }

    function testTransfersRevert() public {
        vm.prank(alice);
        gate.claimBadge(NOVIA);
        vm.prank(alice);
        vm.expectRevert(AgentGate.Soulbound.selector);
        gate.transferFrom(alice, bob, 1);
        vm.prank(alice);
        vm.expectRevert(AgentGate.Soulbound.selector);
        gate.approve(bob, 1);
    }

    function testCheckInAccruesPoints() public {
        vm.prank(alice);
        gate.claimBadge(NOVIA);
        vm.prank(alice);
        gate.checkIn();
        assertEq(gate.points(1), 1, "1 point after first check-in");
        assertEq(gate.pointsOfAgent(NOVIA), 1, "pointsOfAgent");
        assertEq(gate.totalCheckIns(), 1, "totalCheckIns");

        // Too soon: same day again
        vm.prank(alice);
        vm.expectRevert(AgentGate.CheckInTooSoon.selector);
        gate.checkIn();

        // Next day works
        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        gate.checkIn();
        assertEq(gate.points(1), 2, "2 points after second check-in");
    }

    function testCheckInWithoutBadgeReverts() public {
        vm.prank(bob);
        vm.expectRevert(AgentGate.NoBadge.selector);
        gate.checkIn();
    }

    function testTwoAgentsIndependent() public {
        vm.prank(alice);
        gate.claimBadge(NOVIA);
        vm.prank(bob);
        uint256 bobBadge = gate.claimBadge(SETYA);
        assertEq(bobBadge, 2, "bob badge id 2");
        vm.prank(bob);
        gate.checkIn();
        assertEq(gate.pointsOfAgent(SETYA), 1, "bob points");
        assertEq(gate.pointsOfAgent(NOVIA), 0, "alice points still 0");
    }

    function testTokenUri() public {
        vm.prank(alice);
        gate.claimBadge(NOVIA);
        string memory uri = gate.tokenURI(1);
        assertTrue(bytes(uri).length > 50, "tokenURI non-trivial");
    }
}
