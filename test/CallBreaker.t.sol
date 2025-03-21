// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/CallBreaker.sol";
import { MockTestHelper } from "../test/contracts/MockTestHelper.sol";

contract CallBreakerTest is Test {
    CallBreaker callBreaker;
    MockTestHelper testHelper;

    uint256 userPrivateKey = 0x1;
    address user = vm.addr(userPrivateKey);
    address solver = address(0x02);
    address userTarget = address(0x02);

    function setUp() public {
        callBreaker = new CallBreaker();
        testHelper = new MockTestHelper();
        vm.deal(user, 100 ether); // Give user some ETH
        vm.deal(solver, 100 ether); // Give solver some ETH
    }

    function testDeposit() public {
        uint256 amount = 1 ether;
        uint256 userBalanceBefore = user.balance;
        uint256 callBreakerBalanceBefore = address(callBreaker).balance;
        vm.prank(user);
        callBreaker.deposit{value: amount}();
        uint256 userBalanceAfter = user.balance;
        uint256 callBreakerBalanceAfter = address(callBreaker).balance;
        assertEq(callBreaker.senderBalances(user), amount);
        assertEq(userBalanceBefore - userBalanceAfter, amount);
        assertEq(callBreakerBalanceAfter - callBreakerBalanceBefore, amount);
    }

    function testDepositFail() public {
        uint256 amount = 0;
        vm.prank(user);
        vm.expectRevert(CallBreaker.InvalidAmount.selector);
        callBreaker.deposit{value: amount}();
    }

    function testExecuteAndVerify() public {
        uint256 currentCounterValue = testHelper.counter();
        uint256 expectedReturnValue = currentCounterValue + 1;
        CallObject[] memory callObjs = new CallObject[](1);

        callObjs[0] = CallObject({
            salt: 1,
            amount: 0,
            gas: 100000,
            addr: address(testHelper),
            callvalue: abi.encodeWithSignature("incrementCounter()"),
            returnvalue: abi.encode(expectedReturnValue),
            skippable: false,
            verifiable: true,
            exposeReturn: false
        });

        UserObjective[] memory userObjs = new UserObjective[](1);
        userObjs[0] = UserObjective({
            nonce: 1,
            sender: user,
            tip: 0,
            chainId: 1,
            maxFeePerGas: 1 gwei,
            maxPriorityFeePerGas: 1 gwei,
            callObjects: callObjs
        });

        bytes32 messageHash = callBreaker.getMessageHash(userObjs[0]);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, messageHash);
        bytes[] memory signatures = new bytes[](1); 
        signatures[0] = abi.encodePacked(r, s, v);

        bytes[] memory returnValues = new bytes[](1);
        returnValues[0] = "";

        uint256[] memory orderOfExecution = new uint256[](1);
        orderOfExecution[0] = 0;

        MEVTimeData[] memory mevData = new MEVTimeData[](1);
        mevData[0] = MEVTimeData({
            key: keccak256(abi.encode(0)),
            value: abi.encode(0)
        });

        vm.prank(user);
        callBreaker.executeAndVerify(userObjs, signatures, returnValues, orderOfExecution, mevData);
    }
}
