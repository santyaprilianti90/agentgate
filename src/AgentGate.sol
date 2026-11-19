// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal read interface of the SPACE ID Agent ID contract
///         (BNB Chain mainnet: 0x60b9262456de011f7d15a54cdd8c48baaa8b022f).
interface IAgentId {
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentGate Badge
/// @notice A soulbound proof-of-agent badge and lightweight reputation
///         registry for Agent ID holders on BNB Chain.
///
///         How Agent ID is used (core logic, not decoration):
///         - A badge can only be claimed by the current owner of an
///           Agent ID NFT, and the badge is bound to that Agent ID
///           token id (token id = uint256(keccak256(label)), e.g. the
///           hash of "novia" for novia.ai).
///         - One badge per Agent ID and one badge per wallet. Agent IDs
///           are non-transferable and limited to one per user, so a
///           badge is a Sybil-resistant proof that a wallet belongs to
///           a named on-chain agent.
///         - Badge holders check in once per day; check-ins accrue
///           reputation points to the Agent ID (via its badge), which
///           any other contract can read through pointsOfAgent() and
///           isVerifiedAgent().
///
///         Safety properties:
///         - Free forever: no function takes payment, there is no mint
///           price, no sale, and no promise of returns.
///         - No owner and no admin functions at all: nobody can mint,
///           pause, freeze, reassign, or withdraw anything. The Agent
///           ID contract address is immutable.
///         - Badges are soulbound: every transfer/approval path reverts.
contract AgentGate {
    // ------------------------------------------------------------------
    // ERC-721 metadata
    // ------------------------------------------------------------------
    string public constant name = "AgentGate Badge";
    string public constant symbol = "AGB";

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event BadgeClaimed(address indexed wallet, uint256 indexed agentIdTokenId, uint256 indexed badgeId);
    event CheckedIn(address indexed wallet, uint256 indexed badgeId, uint256 points);

    // ------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------
    error NotAgentIdOwner();
    error AgentAlreadyHasBadge();
    error WalletAlreadyHasBadge();
    error NoBadge();
    error CheckInTooSoon();
    error Soulbound();
    error BadgeDoesNotExist();

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------
    IAgentId public immutable agentId;

    uint256 public totalBadges;
    uint256 public totalCheckIns;

    mapping(uint256 => address) private _badgeOwner; // badgeId => wallet
    mapping(address => uint256) private _badgeBalance; // wallet => badge count (0 or 1)
    mapping(uint256 => uint256) public badgeByAgentId; // agentIdTokenId => badgeId
    mapping(uint256 => uint256) public agentIdOfBadge; // badgeId => agentIdTokenId
    mapping(address => uint256) public badgeOfWallet; // wallet => badgeId
    mapping(uint256 => uint256) public points; // badgeId => reputation points
    mapping(uint256 => uint256) public lastCheckIn; // badgeId => unix timestamp

    uint256 public constant CHECK_IN_INTERVAL = 1 days;

    constructor(address agentIdContract) {
        agentId = IAgentId(agentIdContract);
    }

    // ------------------------------------------------------------------
    // Core: claim a badge bound to your Agent ID
    // ------------------------------------------------------------------
    /// @notice Claim the soulbound badge for an Agent ID you own.
    /// @param agentIdTokenId The Agent ID token id (uint256(keccak256(label))).
    /// @return badgeId The newly minted badge id.
    function claimBadge(uint256 agentIdTokenId) external returns (uint256 badgeId) {
        if (agentId.ownerOf(agentIdTokenId) != msg.sender) revert NotAgentIdOwner();
        if (badgeByAgentId[agentIdTokenId] != 0) revert AgentAlreadyHasBadge();
        if (badgeOfWallet[msg.sender] != 0) revert WalletAlreadyHasBadge();

        badgeId = ++totalBadges;
        _badgeOwner[badgeId] = msg.sender;
        _badgeBalance[msg.sender] = 1;
        badgeByAgentId[agentIdTokenId] = badgeId;
        agentIdOfBadge[badgeId] = agentIdTokenId;
        badgeOfWallet[msg.sender] = badgeId;

        emit Transfer(address(0), msg.sender, badgeId);
        emit BadgeClaimed(msg.sender, agentIdTokenId, badgeId);
    }

    // ------------------------------------------------------------------
    // Core: daily check-in, reputation accrues to the Agent ID's badge
    // ------------------------------------------------------------------
    /// @notice Check in once per day. Each check-in adds 1 reputation
    ///         point to your badge (and therefore to your Agent ID).
    function checkIn() external {
        uint256 badgeId = badgeOfWallet[msg.sender];
        if (badgeId == 0) revert NoBadge();
        uint256 last = lastCheckIn[badgeId];
        if (last != 0 && block.timestamp < last + CHECK_IN_INTERVAL) {
            revert CheckInTooSoon();
        }
        lastCheckIn[badgeId] = block.timestamp;
        uint256 newPoints = ++points[badgeId];
        ++totalCheckIns;
        emit CheckedIn(msg.sender, badgeId, newPoints);
    }

    // ------------------------------------------------------------------
    // Public reads for other contracts / front-ends
    // ------------------------------------------------------------------
    /// @notice True if this wallet has claimed a badge, i.e. it proved
    ///         ownership of an Agent ID and registered it here.
    function isVerifiedAgent(address wallet) external view returns (bool) {
        return badgeOfWallet[wallet] != 0;
    }

    /// @notice Reputation points accumulated by an Agent ID (via its badge).
    function pointsOfAgent(uint256 agentIdTokenId) external view returns (uint256) {
        return points[badgeByAgentId[agentIdTokenId]];
    }

    // ------------------------------------------------------------------
    // ERC-721 surface (soulbound: transfers and approvals always revert)
    // ------------------------------------------------------------------
    function ownerOf(uint256 badgeId) external view returns (address) {
        address owner = _badgeOwner[badgeId];
        if (owner == address(0)) revert BadgeDoesNotExist();
        return owner;
    }

    function balanceOf(address wallet) external view returns (uint256) {
        return _badgeBalance[wallet];
    }

    function tokenURI(uint256 badgeId) external view returns (string memory) {
        if (_badgeOwner[badgeId] == address(0)) revert BadgeDoesNotExist();
        return
            string(
                abi.encodePacked(
                    "data:application/json;utf8,{\"name\":\"AgentGate Badge #",
                    _toString(badgeId),
                    "\",\"description\":\"Soulbound proof-of-agent badge bound to Agent ID token ",
                    _toString(agentIdOfBadge[badgeId]),
                    ". Reputation points: ",
                    _toString(points[badgeId]),
                    ".\",\"attributes\":[{\"trait_type\":\"Agent ID token\",\"value\":",
                    _toString(agentIdOfBadge[badgeId]),
                    "},{\"trait_type\":\"Reputation points\",\"value\":",
                    _toString(points[badgeId]),
                    "}]}"
                )
            );
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC-165
            interfaceId == 0x80ac58cd || // ERC-721
            interfaceId == 0x5b5e139f; // ERC-721 metadata
    }

    function getApproved(uint256) external pure returns (address) {
        return address(0);
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }

    function approve(address, uint256) external pure {
        revert Soulbound();
    }

    function setApprovalForAll(address, bool) external pure {
        revert Soulbound();
    }

    function transferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert Soulbound();
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            ++digits;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            buffer[--digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
