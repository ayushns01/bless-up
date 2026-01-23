// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../src/ACTXToken.sol";

contract ACTXTokenHandler is Test {
    ACTXToken public token;
    address public treasury;
    address public reservoir;
    address public rewardManager;

    uint256 public totalDistributed;
    address[] public actors;
    mapping(address => bool) public isActor;

    constructor(
        ACTXToken _token,
        address _treasury,
        address _reservoir,
        address _rewardManager
    ) {
        token = _token;
        treasury = _treasury;
        reservoir = _reservoir;
        rewardManager = _rewardManager;
        _addActor(treasury);
        _addActor(reservoir);
        _addActor(address(token));
    }

    function _addActor(address actor) internal {
        if (!isActor[actor]) {
            isActor[actor] = true;
            actors.push(actor);
        }
    }

    function getActors() external view returns (address[] memory) {
        return actors;
    }

    function fundPool(uint256 amount) public {
        amount = bound(amount, 1, token.balanceOf(treasury));
        vm.prank(treasury);
        token.fundRewardPool(amount);
    }

    uint256 public distributeCount;

    function distribute(uint256 amount, address recipient) public {
        if (token.rewardPoolBalance() == 0) return;
        amount = bound(amount, 1, token.rewardPoolBalance());
        recipient = recipient == address(0) ? address(1) : recipient;

        bytes32 rewardId = keccak256(
            abi.encodePacked("reward", distributeCount++)
        );
        vm.prank(rewardManager);
        token.distributeReward(recipient, amount, rewardId);
        totalDistributed += amount;
        _addActor(recipient);
    }

    function transfer(address from, address to, uint256 amount) public {
        if (from == address(0) || to == address(0)) return;
        if (token.balanceOf(from) == 0) return;

        amount = bound(amount, 1, token.balanceOf(from));
        vm.prank(from);
        token.transfer(to, amount);
        _addActor(from);
        _addActor(to);
    }
}

contract ACTXTokenInvariantTest is Test {
    ACTXToken public token;
    ACTXTokenHandler public handler;

    address public treasury = makeAddr("treasury");
    address public reservoir = makeAddr("reservoir");
    address public rewardManager = makeAddr("rewardManager");

    uint256 public constant TOTAL_SUPPLY = 100_000_000 ether;

    function setUp() public {
        ACTXToken implementation = new ACTXToken();
        bytes memory initData = abi.encodeWithSelector(
            ACTXToken.initialize.selector,
            treasury,
            reservoir,
            200
        );
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        token = ACTXToken(address(proxy));

        vm.startPrank(treasury);
        token.grantRole(token.REWARD_MANAGER_ROLE(), rewardManager);
        vm.stopPrank();

        handler = new ACTXTokenHandler(
            token,
            treasury,
            reservoir,
            rewardManager
        );

        targetContract(address(handler));
    }

    function invariant_TotalSupplyExactly100M() public view {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function invariant_RewardPoolNeverNegative() public view {
        assertGe(token.rewardPoolBalance(), 0);
    }

    function invariant_TaxRateNeverExceedsMax() public view {
        assertLe(token.taxRateBasisPoints(), 1000);
    }

    function invariant_ReservoirAddressNeverZero() public view {
        assertTrue(token.reservoirAddress() != address(0));
    }

    /// @dev Verifies that sum of all tracked balances equals total supply
    /// This catches tax calculation bugs that could leak or create tokens
    function invariant_BalanceSumEqualsSupply() public view {
        address[] memory actors = handler.getActors();
        uint256 sum = 0;
        for (uint256 i = 0; i < actors.length; i++) {
            sum += token.balanceOf(actors[i]);
        }
        // Sum of tracked actors should equal total supply
        // (assuming no tokens sent to untracked addresses)
        assertEq(sum, TOTAL_SUPPLY);
    }
}
